# Inheritance in cpp-bindgen

A feature proposal, written from the openFrameworks side. Every claim about
layout below was measured with the toolchain this project uses
(`zig cc`, clang, `x86_64-windows-msvc`), not taken from the ABI documents.

## Why

`ofEasyCam` is the first oF class this package needs that has a base:

```
ofNode                  ~101 member declarations
  ofCamera              ~52
    ofEasyCam           ~51
```

A sketch that writes `cam.begin()` reaches `ofEasyCam`. A sketch that writes
`cam.setPosition(...)` reaches `ofNode`, two classes up. Both must work, and
both must be checked the way every other binding here is checked.

`ofEasyCam` is not a special case. `of3dPrimitives.h` puts five more leaf
classes over `ofNode` (`ofPlanePrimitive`, `ofSpherePrimitive`,
`ofBoxPrimitive` and the rest), and the renderer, sound and video headers are
built the same way. A hierarchy of three classes solved by hand is a hierarchy
of three classes solved by hand. The same thing solved once in cpp-bindgen is
the rest of the oF API.

## What cpp-bindgen can express today

One thing, and it is not nothing: a qualified name overrides the class, so a
base method can be called through a derived pointer.

```zig
pub const setPosition_sig: Signature = .{
    .name = "ofNode::setPosition",   // the symbol is ofNode's
    .this = *EasyCam,                // the pointer is the derived one
    .args = &.{ f32, f32, f32 },
};
```

That mangles to `?setPosition@ofNode@@QEAAXMMM@Z`, which is the right symbol,
and it passes the `ofEasyCam*` straight through as `this`. It works.

It works because `ofNode` happens to sit at offset 0 inside `ofEasyCam`.
Nothing states that, and nothing checks it. The same signature written against
a class whose base is not at offset 0 compiles, links, and corrupts memory.
cpp-bindgen has no way to know, because it has no notion of a base class at
all: `cpp_virtual_bases` and `cpp_virtual_dtor` exist, but they steer the
mangling and the hidden "most derived" flag MSVC constructors take — nothing
about layout — and `testing.zig`'s `Derived` fixture (a *virtual* base, which
neither mode below covers) spells its base's members out by hand as ordinary
fields.

So three things are missing:

1. **Layout.** A derived class must be re-measured whole. Five leaf classes
   over `ofNode` means five `_storage` blobs, each independently wrong.
2. **Upcasting.** `ofNode::setParent(ofNode&)` and `ofEasyCam::setTarget(ofNode&)`
   need a `*Node` from a `*EasyCam`. Today that is a bare `@ptrCast`.
3. **Checking.** Nothing verifies that the class named in a qualified signature
   is a base of the class the pointer points at.

## Two modes

Two spellings, both composing, differing in how much the language does for you:

| | Mode 1 — base as a typed field | Mode 2 — base as a computed span |
|---|---|---|
| the base is | `cpp_base_Node: Node` | `_bases: [cpp.baseExtent(...)]u8` |
| its span is | `@sizeOf(Node)` — padded | `extent(Node)` — ABI-aware |
| own members | fields, opaque or spelled | the same |
| sizes declared | none | none |
| base offset | `@offsetOf` | `@offsetOf` |
| upcast | a field access | `cpp.basePtr` (the span is untyped) |
| ABI | MSVC only | any |

They differ in one thing: whether the base's span is `@sizeOf(Base)` or a
computed extent. `@sizeOf` is the padded size, which is the MSVC rule and wrong
on Itanium. Everything else is identical, and neither mode declares a size.

A binding author picks the spelling per class. Neither choice reaches a sketch,
because the binding hands out a named accessor either way — `&self.cpp_base_X`
in mode 1, `cpp.basePtr` in mode 2 — and `bind` resolves both through the same
chain walk.

## Mode 1: a base subobject is a field

Spell the base as a real field, named `cpp_base_<Base>`:

```zig
pub const Node = extern struct {
    _storage: [N]u8 align(8),
    pub const cpp_name = "ofNode";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;
};

pub const Camera = extern struct {
    cpp_base_Node: Node,
    _own: [M]u8 align(8),   // ofCamera's own members
    pub const cpp_name = "ofCamera";
    // ...
};

pub const EasyCam = extern struct {
    cpp_base_Camera: Camera,
    _own: [K]u8 align(8),   // ofEasyCam's own members
    pub const cpp_name = "ofEasyCam";
    // ...
};
```

The own members are a blob rather than named fields for the reason they are a
blob everywhere else in this package: `emit.zig`'s `offsetChecks` emits an
`offsetof` for every field whose name does not begin with `_`, and oF's
members are private, so a named field would not compile in the glue. `M` and
`K` are the *own* sizes — what the class adds after its base — and nothing
measures them directly; the `sizeof` assert on the whole class pins each one
once the base below it is pinned.

The rule for the binder: **a field whose name begins with `cpp_base_` is a base
subobject, not a member.** The field's *type* is the authoritative statement of
which base it is. The suffix is a label — it makes the field unique and makes
the chain readable — so it should be the base's Zig type name and it never has
to be a qualified C++ name. (`cpp_base` bare is worth allowing for the single
base case, which is almost all of them.) Mode 1 needs no `cpp_bases`
declaration: the fields are the declaration, so there is one source of truth
rather than two that can disagree.

Four things fall out, and none of them needs a new builtin:

- **Layout composes.** `EasyCam` is `Camera` plus its own fields; `Camera` is
  `Node` plus its own. One `_storage` measurement for `ofNode`, not one per
  leaf class. The `sizeof`/`alignof` asserts the glue already emits then check
  the whole chain.
- **The upcast is a field access.** `&cam.cpp_base_Camera` *is* a `*Camera`.
  `&cam.cpp_base_Camera.cpp_base_Node` *is* a `*Node`. No cast, no builtin, no
  trust — and it stays correct if a base is ever not at offset 0, because the
  field offset moves with it.
- **The offset becomes a Zig comptime constant.** `@offsetOf(EasyCam, "cpp_base_Camera")`.
  This is the number the C++ side otherwise has to hand over, and (see below)
  frequently cannot.
- **Reflection finds bases.** `emit.zig` already walks fields. The prefix is all
  it needs to tell a base from a member.

### Name the base, do not number it

`cpp_base_0`, `cpp_base_1` reads like declaration order. It is not. MSVC picks a
*primary* base and puts it at offset 0, whatever order the declaration used:

```cpp
struct MI { int m; };
struct PB { virtual ~PB(); int a; char c; };
struct MID : MI, PB { };     // MI declared first
```
```
0 | struct MID
0 |   struct PB (primary base)     <- declared second, laid out first
16|   struct MI (base)
```

A number would have to mean layout order, and would then quietly disagree with
the C++ header every time the two differ. A name cannot be wrong in that way.

## Why this is sound on MSVC, and not on Itanium

The question that decides the whole proposal: does a derived class put its own
members *after* the base, or *inside the base's tail padding*? A struct field
can only model the first.

Same source, both ABIs:

```cpp
struct B { B(); int a; char c; };   // non-POD, sizeof 8, 3 bytes tail padding
struct D : B { char d; };
struct P { virtual ~P(); int a; char c; };
struct PD : P { char d; };
```

| | `B` occupies | `d` at | `sizeof(D)` | `d` at (polymorphic) | `sizeof(PD)` |
|---|---|---|---|---|---|
| **MSVC** | all 8 bytes | **8** | 12 | **16** | 24 |
| **Itanium** | its 5-byte data size | **5** | 8 | **13** | 16 |

On MSVC a non-virtual base subobject occupies exactly `sizeof(Base)` and the
derived class's own members start after it. That is precisely what a struct
field does, so the model is not merely usually right — it is the ABI rule.

On Itanium a non-POD base occupies only its `nvsize`, and the derived class
packs its members into the base's tail padding. The field model is wrong there
whenever the base has tail padding.

(A *POD* base is not repacked on either ABI — C compatibility forbids it — so
the naive test with a trivial base shows agreement and hides this. The base has
to be non-POD to see it, which every oF class is.)

**So mode 1 must be gated to MSVC**, and refused at comptime elsewhere. This
project is `x86_64-windows-msvc` only and says so as a deliberate limit, so
mode 1 alone unblocks it. Mode 2 is what the other ABI needs.

## Mode 2: a computed base span

Mode 2 differs from mode 1 in one thing only: the base is an **untyped span
whose length the calculator supplies**, rather than a typed field whose length
Zig takes as `@sizeOf(Base)`. That is the whole of it, because `@sizeOf` is the
padded size and Itanium needs the unpadded one.

```zig
pub const Camera = extern struct {
    _bases: [cpp.baseExtent(@This())]u8 align(cpp.baseAlign(@This())),
    /// ofCamera's own members. Sized to the DATA, not to the padded total.
    _own: [9]u8 align(8),
    pub const cpp_bases: []const type = &.{Node};
    pub const cpp_name = "ofCamera";
};
```

`_own` may equally be a run of real fields. Nothing below cares which, because
everything it needs is read off the layout Zig computes.

### No size declarations are needed

An opaque *field* still has a size; only an opaque *class* does not. So every
quantity the calculator needs comes out of reflection:

```zig
data_end = @offsetOf(T, last) + @sizeOf(@FieldType(T, last))   // nvsize
sizeof   = @sizeOf(T)                                          // Zig pads
```

`cpp_own_size` and `cpp_own_align` both disappear. The fields carry them.

Note what this does *not* ask. There is no storage-versus-member distinction in
the layout math at all: `data_end` is where the last field ends, whatever the
fields are. A class may spell its own members as typed fields, collapse them
into one opaque array, or mix the two, and the calculator cannot tell. That is
what makes per-member opacity free — it needs no support, because there is
nothing to support.

This rests on a property of Zig worth stating outright: **`align(N)` on a field
aligns its offset, it does not pad its size.**

```zig
extern struct { a: [25]u8 align(8), b: [1]u8 }   // b@25, sizeof 32, align 8
extern struct { a: [13]u8 align(8), b: [9]u8 align(8) }   // b@16, sizeof 32, align 8
```

So a 25-byte field can be followed at offset 25 while the struct still rounds
to 32. That is tail-padding reuse, expressible directly. Size a storage field
to the *data* size rather than the padded total and two things follow at once:
`@sizeOf` becomes the C++ `sizeof`, and the array length remains `nvsize`.

The round trip is guaranteed rather than lucky: `sizeof = roundUp(dsize, align)`
puts `dsize` in `(sizeof - align, sizeof]`, and every value in that range rounds
back. For `Font._storage`'s 728 at align 8 that is 721 through 728, all of which
give `@sizeOf` 728.

**But only Itanium consumes a data size**, so on MSVC the distinction is free to
ignore and costs something to observe. MSVC's record dump reports `nvsize` as
the *padded* size — it printed `nvsize=16` for the class whose data ends at 13 —
so a data size has to be derived from the last member's offset plus its size,
which for a class like `ofTrueTypeFont` means modelling the member the blob
exists to avoid modelling. An MSVC-only binding should size its blobs to the
padded total, as this package already does. The data size matters when a class
is derived from *and* the binding targets Itanium.

### The one computed quantity

Only `_bases` needs the calculator, and only because `extent` is where the ABI
difference lives:

```zig
fn dataEnd(T)    = @offsetOf(T, last field) + @sizeOf(that field)
fn extent(T)     = if (msvc or T.cpp_abi == .c_struct) @sizeOf(T) else dataEnd(T)
fn baseExtent(T) = extent(last of T.cpp_bases)     // 0 when there are none
fn baseAlign(T)  = max(@alignOf(each base))         // 1 when there are none
```

Two things in that are easy to get wrong, and the first draft of this document
got both of them wrong:

- **`extent` has to know whether the base is POD.** Itanium repacks into the
  tail padding of a *non-POD* base only; a POD base keeps its padded size on
  both ABIs (measured: `struct Plain { int a; char c; }` has `dsize = 8 =
  sizeof`, and a class over it puts its first member at 8, where the non-POD
  twin puts it at 5). `cpp_abi == .c_struct` is the binding already saying
  "POD", and the glue already asserts it with `__is_trivial &&
  __is_standard_layout`, so `extent` reads that rather than asking again.
- **`baseAlign` must not consult `@alignOf(T)`.** It is evaluated inside `T`'s
  own field list, and asking for `T`'s alignment there is a dependency loop
  (`error: type 'Camera' depends on itself for alignment query here`). It does
  not need to: the base span only has to be aligned as its bases are, and the
  struct's overall alignment falls out of `max` over all its fields, because
  `_own` carries its own `align`.

Implemented and run, with every class declared by fields alone, against clang's
numbers for this three-deep chain — `N` polymorphic with data ending at 13 of
a padded 16, `C` adding nine bytes of 8-aligned data, `E` adding one byte at
align 1:

```cpp
struct N { virtual ~N(); int a; char c; };
struct C : N { double x; char z; };
struct E : C { char y; };
```

On the Zig side `N` is `_storage: [13]u8 align(8)` — the data size — which
`@sizeOf` rounds to 16 on both ABIs, and `C` and `E` are the `_bases`/`_own`
spelling above. One number per blob, and it is the same number on both ABIs:

```
    msvc: N.own= 0 C.own=16 sizeof(N)=16 sizeof(C)=32 E.own=32 sizeof(E)=40  == clang
 itanium: N.own= 0 C.own=16 sizeof(N)=16 sizeof(C)=32 E.own=25 sizeof(E)=32  == clang
```

Every number matches. `E.own` at 25 on Itanium against 32 on MSVC is the
tail-padding reuse, produced by Zig's own field layout rather than worked
around.

### What this leaves

- **`cpp_bases: []const type`** — the relation, for the glue's `__is_base_of`
  assert and for the chain walk. No offsets, no sizes.
- **One measured number per opaque span**, which is the size of the C++ members
  it stands for — the same measurement `Font._storage` already is, and needed
  only for members the binding declines to model.
- **Base offsets computed**, so mode 2 composes exactly as mode 1 does:
  `ofNode` states its own extent once, `ofCamera` and `ofEasyCam` state only
  what they add.

Which narrows mode 1's remaining advantage to visibility: the base is a typed
field, so `&cam.cpp_base_Camera` is a `*Camera` with no machinery. Mode 2 needs
`cpp.basePtr` because its base span is untyped. That is a real ergonomic
difference and not a capability one.

### The domain

Single, non-virtual, public inheritance. Multiple inheritance needs primary-base
selection replicated — MSVC put the *polymorphic* base at offset 0 regardless of
declaration order — and empty bases need the empty-base-optimization search.
Virtual bases are excluded outright. The calculator should compute within that
domain and refuse outside it, and the `sizeof`/`alignof` asserts the glue
already emits stay the safety net.

## What the binder actually needs bases for

Not upcasting. In mode 1 the upcast is `&cam.cpp_base_Camera`, which is plain
Zig, obvious to a reader, and needs nothing from cpp-bindgen. A `basePtr`
helper adds nothing there and should not pretend to: mode 2 needs a function
because it has no field to take the address of, and that is the whole of its
job.

The reason the binder must know about bases is **`this`**. This signature is
how a base method is bound today:

```zig
.{ .name = "setPosition", .class = Node, .this = *EasyCam, .args = &.{ f32, f32, f32 } }
```

It already works — `.class` names the class a bare `name` belongs to, and
`pathOf` takes the path from `Node.cpp_name` while leaving `this` as the
derived pointer. Verified: it mangles to `?setPosition@ofNode@@QEAAXMMM@Z`,
byte-identical to the `"ofNode::setPosition"` string form, and it names the
base *by Zig type* rather than by a string the binder cannot resolve.

Two things are wrong with it, and both are the same missing fact:

- **It is unchecked.** Nothing verifies that `Node` is a base of `EasyCam`. A
  wrong class name compiles, links, and corrupts memory.
- **It is unadjusted.** `planFor` passes the `*EasyCam` through as `this`
  unchanged. That is correct only when the base is at offset 0. Since MSVC
  picks a primary base and puts *that* one at 0, any second base is silently
  wrong.

With bases declared, `bind` can resolve `.class` against the chain, refuse what
is not a base, and add `baseOffset(EasyCam, Node)` to `this` in the trampoline
— where the existing `Plan`/`Source` machinery already rewrites arguments, so
there is a place to put it. Not a free one: it is a new `Source` variant, the
extern parameter's type changes from `*EasyCam` to `*Node` (with the method's
constness carried across), and `Plan.isIdentity` then reports false, so a base
method at a nonzero offset goes through the trampoline where today it is a bare
`@extern`. A base at offset 0 — every base in the oF hierarchy — needs no
source rewrite and stays on the identity path.

That is the feature. `baseOffset` is internal machinery for `bind`; `basePtr`
is mode 2's implementation detail; mode 1 users write a field access and never
call either.

### The chain walk

`directBases` reads whichever spelling a class used; `baseOffset` walks the
chain transitively and sums. Both are comptime, and this is tested working:

```zig
fn directBases(comptime T: type) []const BaseRef {
    // Mode 1: fields named cpp_base_*, offsets from @offsetOf.
    comptime var out: []const BaseRef = &.{};
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        if (!std.mem.startsWith(u8, name, "cpp_base_")) continue;
        out = out ++ &[_]BaseRef{.{ .type = @FieldType(T, name), .offset = @offsetOf(T, name) }};
    }
    if (out.len > 0) return out;
    // Mode 2: within the domain (one non-virtual base) the base is at 0.
    if (@hasDecl(T, "cpp_bases")) return &.{.{ .type = T.cpp_bases[0], .offset = 0 }};
    return &.{};
}

pub fn baseOffset(comptime Self: type, comptime Target: type) ?comptime_int {
    if (Self == Target) return 0;
    inline for (directBases(Self)) |b| {
        if (baseOffset(b.type, Target)) |inner| return b.offset + inner;
    }
    return null;
}
```

Checked against a deliberately awkward hierarchy — a mode-1 leaf with two base
fields over a mode-2 middle class whose base was *declared* at a nonzero
offset, to exercise the summing rather than anything the domain admits:

```
sizeof(EasyCam)=56  Camera@8 (mode 1, @offsetOf)  Node@16 (8 + 8, mode 2 declared)
baseOffset(EasyCam, Node) = 16     baseOffset(Node, EasyCam) = null
```

(Within the stated domain a mode-2 base is always at 0 and only mode 1 can
put one anywhere else, so the nonzero mode-2 offset above is a test fixture,
not a capability.)

Transitivity is what `bind` needs: a signature with `.class = Node` on a
`*EasyCam` has to find `ofNode` two hops up. A class that is not a base returns
`null`, which becomes the `@compileError` that is missing today.

## A third option worth having: a generated thunk

Neither mode can place a **virtual** base, whose offset is not fixed relative
to the derived class, and neither can help where the offset assert below cannot
be written. One escape hatch covers both, correctly on any ABI and any
inheritance form, because the C++ compiler does the adjustment:

```cpp
extern "C" ofNode* cppbindgen_up_7(ofEasyCam* p) { return static_cast<ofNode*>(p); }
```

It costs one non-inlinable call per upcast, so it should be opt-in per base
(`.{ .type = Node, .thunk = true }`) rather than the default. It is the only
form that is correct by construction rather than by assertion.

## What the glue should check

The existing contract is "the binding claims a layout, the glue checks it
against the real header". Base fields fit it. Per base field, emit:

**1. The relation.** Portable, and catches the copy-paste error where the field
type points at the wrong class:

```cpp
static_assert(__is_base_of(ofCamera, ofEasyCam), "...");
```

Verified available under `zig cc -target x86_64-windows-msvc`. Note it is
*access-blind*: it is true for a private base too, so it proves the subobject
exists, not that the upcast is legal. `__is_polymorphic` is available on the
same terms and is worth asserting alongside, since a non-polymorphic base under
a polymorphic derived class is pushed past the vfptr and is the likeliest way
for a hand-written offset to be wrong.

**2. The offset.** Harder, and worth stating exactly, because the obvious forms
do not work. Measured, on this toolchain:

| form | constant expression? |
|---|---|
| `__is_base_of(B, D)` | yes |
| `__is_polymorphic(T)` | yes |
| `offsetof(D, m) - offsetof(B, m)`, `m` an accessible member of `B` | **yes** |
| `(char*)(B*)(D*)16 == (char*)16` | no — `reinterpret_cast` is banned |
| `__builtin_bit_cast(unsigned, static_cast<int D::*>(&B::m))` | no — bit_cast from a member pointer is banned |

So the offset is checkable, through `offsetof` on an inherited member — but only
one that is *accessible at the point of the assert*. `ofNode`'s members are
`private` except `parent`, which is `protected`; `ofCamera`'s are all private.
At namespace scope neither is reachable.

A generated probe struct fixes the protected case, because access is checked in
the scope where the `offsetof` is written, not where the type is declared:

```cpp
struct probe_node : ofNode { static constexpr size_t off(); };
constexpr size_t probe_node::off() { return __builtin_offsetof(probe_node, parent); }
struct probe_cam : ofEasyCam { static constexpr size_t off(); };
constexpr size_t probe_cam::off() { return __builtin_offsetof(probe_cam, parent); }

static_assert(probe_cam::off() - probe_node::off() == 0, "ofNode is not at offset 0 in ofEasyCam");
```

Verified working, and verified to *catch* a real mismatch — the same construct
correctly reported a base at a nonzero offset under multiple inheritance. The
`offsetof` must be written inside a member of the probe; at namespace scope it
is rejected for access even through a derived probe type.

Each probe draws one `-Winvalid-offsetof` warning, since a polymorphic class is
not standard-layout. The glue already suppresses that warning for its whole
checks section (`#pragma GCC diagnostic ignored "-Winvalid-offsetof"`, emitted
by `checks()` for exactly this reason), so the probes only need to be emitted
inside it.

This leaves one genuine hole: a base whose every member is private, such as
`ofCamera`. Nothing reaches it. But the arithmetic closes over the chain —

```
offset(ofNode in ofEasyCam) = offset(ofCamera in ofEasyCam) + offset(ofNode in ofCamera)
```

— so checking the two `ofNode` offsets pins the `ofCamera` one. Where the chain
does not close, the honest answer is to emit the relation assert, skip the
offset assert, and say which base was not verified. A check that is absent and
named is worth more than one that is silently assumed.

## Ergonomics, and the part Zig will not do

Layout and upcasting are solved above. Reuse is not, and it is worth being
blunt about why: **`usingnamespace` was removed in Zig 0.15**, and `@Type`
cannot synthesize declarations. Confirmed against the compiler in use:

```
error: expected function or variable declaration after pub
const D = struct { pub usingnamespace Base; };
```

So there is no way — not in cpp-bindgen, not anywhere — to splice `ofNode`'s
101 methods into `EasyCam` as callable methods. The options are:

- **Write each method once, on the class that declares it, and reach it through
  the base.** One wrapper per C++ method, total. Call sites name the base.
- **Hand-write a forwarder per method per leaf class.** ~150 lines for
  `ofEasyCam`, and again for each of the five `of3dPrimitives` classes.
- **Generate the forwarders** with a build-time codegen step that writes Zig
  text. Solves it, and adds a code generator to a project that currently has
  none.

The first is the only one that stays proportionate, and the base field makes it
cheap. Pair it with a one-line accessor so the chain does not leak into user
code:

```zig
pub fn node(self: *EasyCam) *Node {
    return &self.cpp_base_Camera.cpp_base_Node;
}
```

```zig
cam.node().setPosition(0, 0, 0);
cam.begin();
```

The field is the ABI truth; the accessor is the API. This is also why the field
name's ugliness costs little — it appears once per hop per class, in the
binding, and never in a sketch.

## Limits and non-goals

- **Virtual bases.** A virtual base subobject is not at a fixed offset from the
  derived class in general; it moves with the most-derived type. Neither mode
  can model that, so the binder should reject both spellings on a type
  declaring `cpp_virtual_bases` and require the thunk. No oF class in this
  hierarchy has one.
- **Empty bases.** The empty base optimization gives an empty base zero bytes in
  a derived class, though it has `sizeof` 1 standalone. A Zig `extern struct {}`
  field is zero-sized, so this happens to agree — but it agrees by luck, and a
  base written as `_storage: [1]u8` would not.
- **Subclassing from Zig.** Overriding a C++ virtual from Zig is still out of
  reach, and `src/cpp/ofzig_app.cpp` still has to exist for `ofBaseApp`. Base
  fields do not change this and are not a step toward it.
- **Virtual dispatch.** `bind` makes a qualified, non-virtual call. Binding
  `ofCamera::begin` and calling it on an `ofEasyCam` silently runs the base
  implementation. With bases declared, cpp-bindgen could at least detect that
  the named class is not the most-derived override and say so.

## Suggested order

Mode 2 is the general mechanism, and mode 1 still goes first: it is what this
project needs to build today, and nothing in it is thrown away when mode 2
lands — the chain walk, the asserts, and `bind`'s adjustment are the same code
for both spellings. Note that mode 1 is refused off MSVC, and the native abi on
a Windows host is `gnu`, so its fixtures can only run under `test-msvc`, which
`build.zig` gates on a Windows x86_64 host; a Linux CI never sees them.

1. **Mode 1**: `cpp_base_` fields recognized by `ctype`/`emit`, skipped by the
   `offsetof` member check, with `__is_base_of` and `__is_polymorphic` asserted
   per base, and refused on a non-MSVC target. This alone makes `ofEasyCam`
   expressible and checked, and unblocks openFrameworks-zig.
2. **`directBases`/`baseOffset` wired into `bind`**, so `.class = Base` with a
   derived `this` is refused when `Base` is not a base, and adjusted when it is
   not at offset 0. This is the feature; step 1 is what makes it possible. No
   new public API, and no call site changes — the signatures that exist today
   keep working and start being checked.
3. **The offset assert**: the probe-struct form, emitted where an accessible
   inherited member exists, with a diagnostic naming each base it could not
   verify.
4. **Mode 2**: `cpp.baseExtent`/`cpp.baseAlign` for the base span, read by the
   same `directBases`, plus `basePtr` for the upcast whose span is untyped.
   Portable, and the general mechanism. Test it against `-fdump-record-layouts`
   on both ABIs — the chain above is the fixture.
5. Optional: the thunk escape hatch, for virtual bases and unverifiable
   offsets.
