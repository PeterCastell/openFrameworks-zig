# macOS support in cpp-bindgen

**Status:** proposed. Nothing here is implemented yet.

A feature request, written from the openFrameworks side. The goal: a Mac user
clones this repo, points `-Dof-root` at their own `of_v0.12.x_osx_release`,
and builds and runs the same sketches. oF's macOS libraries are built by Apple
clang with libc++, so on the C++ side macOS is the Itanium ABI with libc++.
cpp-bindgen already supports that pairing as `x86_64-windows-gnu`. Most of it
carries over. This document lists what does not.

Measured on Windows with zig 0.17.0-dev.2138, which bundles libc++ 22.1.8, by
cross-compiling to `aarch64-macos` and `x86_64-macos`. Nothing here has run on
a Mac. The probes compiled C++ with `zig c++ -S` and read the symbols, built
cpp-bindgen's own tests for both macOS targets, and printed `mangledName` for
the openFrameworks-zig string bindings.

## What already works

- **cpp-bindgen's test suite compiles and links for `x86_64-macos`.** The
  Mach-O linker rejects undefined symbols, so every fixture symbol the tests
  bind resolved. The run step fails only because Windows cannot run the binary.
- **The Mach-O underscore.** `@extern(.., .{ .name = "_ZN3foo3barEv" })`
  emits `__ZN3foo3barEv`, the same symbol clang emits. Nothing to do.
- **Integer mangling.** `usize` mangles as `m`, because `c_ulong` is 64-bit on
  macOS, and Apple's `int64_t` is `long long`, which matches `i64 =>
  .longlong`. `wchar_t` is already 32-bit off Windows.
- **x86_64 calls.** The hidden return pointer goes before `this`, as on
  `windows-gnu`. Small trivial classes travel in registers under SysV, and
  Zig's `callconv(.c)` does that classification.
- **Vtables.** The layout is plain Itanium on both Apple architectures.
  `Subclass` reuses the base's RTTI, so Apple's non-unique RTTI on arm64 does
  not come up.

## What is missing

Items 1 and 2 block every macOS build. Items 3 to 5 block only Apple Silicon.
An `x86_64-macos` build, which runs natively on Intel and under Rosetta on
Apple Silicon, needs only 1 and 2.

### 1. `std::` names in the Itanium mangler (all macOS targets)

`itanium.qualified` has no special handling for `std`. libc++ also puts its
whole library in the inline namespace `std::__1`, which appears in every
mangled name. So none of the libc++ symbols that openFrameworks-zig binds can
link:

| binding | cpp-bindgen emits | libc++ defines |
|---|---|---|
| `String.size` | `_ZNK3std12basic_string…4sizeEv` | `_ZNKSt3__112basic_string…4sizeB9nie220108Ev` |
| `String` ctor | `_ZN3std12basic_string…C2EPKcm` | `_ZNSt3__112basic_string…C2B9nie220108EPKcm` |
| `String` dtor | `_ZN3std12basic_string…D2Ev` | `_ZNSt3__112basic_string…D2Ev` |
| `Path` ctor | `_ZN3std10filesystem4pathC2EO…` | `_ZNSt3__14__fs10filesystem4pathC2B9nie220108EO…NS2_6formatE` |

The `…` is `IcNS_11char_traitsIcEENS_9allocatorIcEEE` in both columns, but it
only looks the same. In the first column `S_` refers to `std`. In the second
it refers to `std::__1`. The `B9…` suffix is item 2.

Proposal:

- A leading `std` component mangles as `St`. That is the mandatory
  abbreviation for `::std::`. `St` is not a substitution candidate itself, so
  the first registered prefix is `St3__1`, which becomes `S_`.
- Under Itanium, insert libc++'s ABI namespace (`__1`) after `std` when
  mangling. The glue keeps writing `std::basic_string`, which is still valid
  C++. Zig's libc++ uses `__1` on every target. Have the glue check that
  assumption the way it checks layouts, for example
  `static_assert(std::is_same_v<std::string, std::__1::string>)`.
- Not needed: the other standard abbreviations (`Sa`, `Sb`, `Ss`, `Si`, `So`,
  `Sd`). They apply only to names directly in `::std`, which means libstdc++,
  and Zig never links libstdc++.
- `std::filesystem` is a namespace *alias* in libc++, for
  `std::__fs::filesystem`, and a mangler cannot see through an alias. That one
  belongs on the binding side: openFrameworks-zig spells
  `std::__fs::filesystem::path` under libc++, and that is valid C++ for the
  glue too.

### 2. libc++ ABI tags (all macOS targets, and `windows-gnu` too)

libc++ marks its header-only members `_LIBCPP_HIDE_FROM_ABI`, which adds
`__attribute__((abi_tag(_LIBCPP_ODR_SIGNATURE)))`. The tag goes into the
mangled name as `B<len><tag>`, after the unqualified name, or after
`C1`/`C2`/`D1`/`D2`. The probe found it on `size`, `c_str`, the
`(const char*, size_t)` and `(basic_string&&)` constructors, and `path`'s
constructor. Members that libc++ exports from its own library, such as the
destructor, have no tag. The same tag shows up on `x86_64-windows-gnu`. It is
latent there only because nothing has bound the STL on that target yet.

The tag is `nie220108` in this zig: hardening mode `n`(one), assertion
semantic `i`(gnore), exceptions `e`(nabled), then the libc++ version. The
probe built the same TU in Debug, ReleaseSafe, ReleaseFast and ReleaseSmall
and got the same tag every time. `-fno-exceptions` changes it to `nin220108`,
and each Zig upgrade that bumps libc++ changes the version part.

A Zig signature cannot reveal which members carry the tag, so the binding has
to say so. Proposal:

- `Signature.abi_tags: []const []const u8 = &.{}`, mangled by the Itanium
  rules: `B<len><tag>` per tag, in sorted order, placed after the unqualified
  name or the ctor/dtor code. MSVC ignores it.
- `cpp.libcxx_abi_tag`, the current tag, so a binding writes
  `.abi_tags = &.{cpp.libcxx_abi_tag}`.
- Keep the constant honest with a glue check instead of a build-time probe.
  The glue is compiled with the real flags, so it is the right place to
  verify: `static_assert(std::string_view(STR(_LIBCPP_ODR_SIGNATURE)) ==
  "nie220108")`. A Zig upgrade then fails with a message naming the new tag,
  not with an undefined symbol.

The glue's existing forcing still works for these members. They have hidden
visibility, but hidden symbols resolve fine between objects in the same link.

### 3. `@alignCast` on vtable slots (AArch64)

The test suite does not compile for `aarch64-macos`. It reports 17 errors at
`root.zig:361`:

```
error: @ptrCast increases pointer alignment
    return @ptrCast(vptr.*[loc.index]);
note: '*const fn (...) callconv(.c) ...' has alignment '4'
```

Function pointers are 4-byte aligned on AArch64 and 1-byte aligned on x86_64.
The fix is `@ptrCast(@alignCast(...))`, and `subclass.zig` probably needs the
same at its own slot reads.

### 4. Hidden return pointer in x8 (AArch64)

`planFor` already refuses this case (`root.zig:433`), and the test suite hits
that refusal 8 times. On AArch64 a hidden return pointer does not go in the
first argument register. It goes in x8, which is not an argument register at
all. Itanium takes this path for every `.managed_copy` return.
`.trivial_copy` returns are fine, because Zig's `callconv(.c)` already puts
large C struct returns in x8.

openFrameworks-zig has 13 signatures that hit it: the `ofMesh` factories
(`plane`, `sphere`, `box`, …), `getMeshForIndices`,
`ofGetCurrentViewport`, `ofEasyCam::getControlArea`,
`ofTrueTypeFont::getStringBoundingBox` and `of3dPrimitive::getBoundingBox`.

No Zig calling convention can place an argument in x8, so the move has to be
written in assembly. One naked function covers every signature, direct or
virtual:

```zig
/// x0 = callee, x1 = return slot, x2.. = the real arguments.
fn x8Call() callconv(.naked) void {
    asm volatile (
        \\mov x16, x0
        \\mov x8, x1
        \\mov x0, x2
        \\mov x1, x3
        \\mov x2, x4
        \\mov x3, x5
        \\mov x4, x6
        \\mov x5, x7
        \\br x16
    );
}
```

The plan for a hidden return on AArch64 becomes `(callee, ret, this?,
args...)`, and the call goes through `x8Call`. `Callee.get` already yields
the callee for both `Direct` and vtable calls. `br` is a tail call, so the C++
function returns straight to the Zig caller.

- **Floating-point arguments** sit in v0–v7 and are not shifted, which is
  correct.
- **The limit:** the real call can use at most 6 general-purpose registers,
  `this` included. More would put arguments on the stack, where shifting
  registers is no longer enough. Count GPRs by the AAPCS64 rules: an integer,
  pointer, enum or bool takes 1; a non-HFA aggregate takes 1 or 2 up to 16
  bytes, and 1 (as a pointer) above that. Raise a `@compileError` past 6.
- **Headroom:** the widest oF signature, `ofMesh::cylinder`, uses exactly 6.
  A per-symbol variant that does `b <symbol>` instead of `br x16` would allow
  7.

This compiles for `aarch64-macos` (prototype in the session scratchpad) and
produces the expected code, but it has not run.

### 5. `Subclass` overrides with a hidden return (AArch64)

There is no guard here today. `entryPoint` treats the hidden return pointer
as an ordinary first parameter. On AArch64, C++ passes it in x8, so the
adapter would read `this` as the return slot and compile without complaint.

- **Now:** a `@compileError` matching `planFor`'s.
- **Later:** the inverse thunk per override. Shift x0–x6 up one register,
  move x8 into x0, and branch to the `callconv(.c)` adapter. That allows at
  most 7 GPR arguments. This compiles too:

  ```zig
  fn entry() callconv(.naked) void {
      asm volatile (
          \\mov x7, x6
          \\mov x6, x5
          \\mov x5, x4
          \\mov x4, x3
          \\mov x3, x2
          \\mov x2, x1
          \\mov x1, x0
          \\mov x0, x8
          \\b %[adapter]
          :
          : [adapter] "X" (&adapter),
      );
  }
  ```

No oF virtual that openFrameworks-zig lists returns a managed class, so only
the guard is urgent.

### 6. Apple arm64 constructors and destructors return `this` (low)

Apple's arm64 C++ ABI (clang's `AppleARM64CXXABI`) makes base and complete
constructors and destructors return `this` in x0. The probe confirms it: the
C2 and D2 bodies end in `mov x0, x19; ret`.

- **Calls from Zig:** binding these as `void` is fine, because the caller
  ignores x0.
- **Destructors `Subclass` generates:** `Destructors.complete` returns `void`
  and leaves x0 holding whatever is there. clang did not rely on the returned
  value at a virtual destructor call in the probe, but the ABI says to return
  it. Return `this` from `complete` on Apple arm64. The deleting destructor
  returns `void` everywhere.

### 7. Testing without a Mac

- **A cross-link check on Windows.** `zig build test -Dtarget=x86_64-macos`
  already gets as far as linking, which is a real check of mangling. It then
  fails trying to run the binary. A build-only step, or a `-Dno-run` option,
  would let this pass on Windows, and the same goes for `aarch64-macos` once
  item 3 is fixed.
- **A macOS CI job.** GitHub's `macos-14` runners are arm64 and free for
  public repos. Run `zig build test` natively, and with
  `-Dtarget=x86_64-macos` under Rosetta. Items 4 and 6 can only be checked by
  running.

## Not cpp-bindgen's job

The openFrameworks-zig side needs these whatever happens in cpp-bindgen:

- **libc++ layouts.** `std::string` is 24 bytes (MSVC: 32), `std::function`
  32 (64), `std::filesystem::path` 24 and holds a UTF-8 `std::string`.
  `shared_ptr` (16) and `vector` (24, three pointers) are unchanged. These
  sizes come from the libc++ probe. The `_storage` sizes switch on the target,
  and the glue's `static_assert`s check them.
- **Signatures.** libc++'s `path(string_type&&, format = auto_format)` takes a
  second argument, which MSVC's single-argument overload does not.
- **The build.** `build.zig` gets a macOS branch: the AVFoundation `.mm`
  sources, the frameworks, and the `.a` files linked by path.

## Suggested order

1. **Item 3 (`@alignCast`) and the item 5 guard.** A few lines each, and the
   suite then compiles for `aarch64-macos`.
2. **Item 7's build-only step.** Every later change can then be checked by
   linking on Windows.
3. **Items 1 and 2 (`St`, `__1`, ABI tags).** This unblocks `x86_64-macos`
   end to end, and with it Apple Silicon under Rosetta.
4. **Item 4 (x8 calls).** This unblocks native Apple Silicon.
5. **Item 7's CI job, then item 6 and the full form of item 5.**
