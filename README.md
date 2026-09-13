# openFrameworks-zig

openFrameworks from Zig, with no C shim: every call goes straight to the C++
symbol through [cpp-bindgen](https://github.com/PeterCastell/cpp-bindgen).

This package owns the *compilation* of openFrameworks but not its source. Point
it at an existing oF 0.12 release and it compiles the oF core with the Zig
toolchain for the MSVC ABI, links oF's own prebuilt third-party libraries, and
checks every binding against the headers it was given.

## Requirements

- Zig 0.17.0-dev.1683 or later.
- Visual Studio 2022 with the C++ workload and a Windows 10/11 SDK. Zig uses
  their headers and import libraries; no `cl.exe` is run.
- An openFrameworks release in the `of_v0.12.x_vs_64_release` layout. The
  version it was developed against is 0.12.1.

Only `x86_64-windows-msvc` is supported. That is not incidental: the bindings
describe MSVC STL layouts and MSVC-mangled names, and the third-party libraries
oF ships for Windows are Visual Studio builds.

## Use from a project

```bash
zig fetch --save git+https://github.com/PeterCastell/openFrameworks-zig.git
```

```zig
// build.zig
const of_dep = b.dependency("openframeworks_zig", .{
    .target = target,
    .optimize = optimize,
    .@"of-root" = @as([]const u8, "C:/path/to/of_v0.12.1_vs_64_release"),
});
exe_mod.addImport("of", of_dep.module("of"));

// Every oF build on Windows uses the dynamic CRT; so must the executable.
const exe = b.addExecutable(.{ .name = "app", .root_module = exe_mod, .linkage = .dynamic });
```

The `of` module carries the compiled oF library and its whole link line, so the
import is all a project needs. `of-root` can also come from the `OF_ROOT`
environment variable.

```zig
const of = @import("of");

const App = struct {
    pub fn setup(_: *App) void {
        of.setWindowTitle("hello");
        of.background(of.Color.rgb(24, 24, 32));
    }
    pub fn draw(_: *App) void {
        of.setColor(of.Color.rgb(80, 200, 255));
        of.drawCircle(@floatFromInt(of.getMouseX()), @floatFromInt(of.getMouseY()), 40);
        of.drawBitmapString("hi from zig", 20, 30);
    }
    pub fn keyPressed(_: *App, k: of.KeyEventArgs) void {
        if (k.key == 'f') of.toggleFullscreen();
    }
};

pub fn main() u8 {
    var app: App = .{};
    return @intCast(of.run(App, &app, .{ .width = 900, .height = 600 }));
}
```

`of.run` wires up whichever of `setup`, `update`, `draw`, `exit`, the key,
mouse, touch, resize, drag and message handlers the app type declares, then
runs the oF main loop. See [example/main.zig](example/main.zig).

## Vectors

`of.Vec2`, `of.Vec3` and `of.Vec4` are Zig's builtin `@Vector`, so the
arithmetic is the language's own and nothing crosses into C++ to do it:

```zig
const a: of.Vec2 = .{ 10, 20 };
const b = a + @as(of.Vec2, @splat(5)); // { 15, 25 }
const away = of.normalize(b - a) * @as(of.Vec2, @splat(80));
of.drawCircleAt(a + away, 12);
```

Components are `v[0]` and `v[1]`, not `v.x`. Zig has no operator overloading,
so a type that gets `+` cannot also be a struct; that is the trade. `of.dot`,
`of.length`, `of.normalize` and `of.cross` cover what has no operator.

The element type is the suffix: `of.Vec2I`/`Vec3I`/`Vec4I` are `i32`
(`glm::ivec*`) and `of.Vec2U`/`Vec3U`/`Vec4U` are `u32` (`glm::uvec*`).
`of.vecCast` converts between any two of the same length:

```zig
const px = of.vecCast(of.Vec2I, @round(mouse));
const back = of.vecCast(of.Vec2, px);
```

Float to int truncates toward zero, as C does, so wrap the argument in
`@floor` or `@round` for another rounding mode. In a safety-checked build a
value the destination cannot hold panics — which is what a negative float
cast to a `*U` type does. `of.length` and `of.normalize` want float vectors;
`vecCast` an integer one first.

Of these, oF 0.12 itself uses only the float vectors and, in
`ofMaterial::setCustomUniform2i` and its siblings, `glm::vec<N, int>`. The
unsigned set is bound and layout-checked so a new binding that needs one does
not have to invent it.

Every wrapper takes and returns these. `glm::vec*` itself is `of.GlmVec2`,
`of.GlmVec3`, `of.GlmVec4` and the matching `I` and `U` names, and it appears
only where the ABI demands it:
inside a `Signature`, and as a field of another bound class such as
`Rectangle.position`. A `@Vector` can go in neither place — Zig rejects one as
an `extern struct` field, because it has no guaranteed in-memory
representation, and `@Vector(3, f32)` is 16 bytes against `glm::vec3`'s 12, so
an array of them strides wrong as well. Conversion is `GlmVec3.from(v)` going
out and `g.to()` coming back, it happens inside the wrapper body, and it does
not survive the optimizer. Accessors hand back the Zig spelling:
`rect.getPosition()`, `rect.getCenter()`, `mouse.pos()`.

## Matrices and transforms

`of.Mat3`, `of.Mat4` and `of.Quat` are `glm::mat3`, `glm::mat4` and
`glm::quat`. Unlike the vectors these have one spelling, not two: the vector
split exists to gain Zig's `@Vector` operators, and a matrix product is not
element-wise, so a second type would buy nothing but a conversion. `Mat4`
*is* the ABI type, and `&m` goes straight to a bound function. (The one
concession: glm declares `mat`'s storage private, so those two carry
`cpp_no_offsets` and are pinned by size, alignment and ABI category instead.)

Storage is glm's — column-major, `value[1]` is the second column, and
`a.mul(b)` applies `b` first. The arithmetic is written in Zig over `@Vector`
columns rather than bound from glm: a 4x4 product is about sixteen vector
instructions, cheaper than the call would be.

`of.Transform` holds the three things a sketch actually edits:

```zig
var t: of.Transform = .{ .origin = .{ 100, 100, 0 }, .scale = @splat(2) };
t.rotation[1] = of.getElapsedTimef() * 40; // yaw
of.pushMatrix();
of.multMatrix(t.matrix());
// ... draw in the transform's space ...
of.popMatrix();
```

`basis()` gives the rotation and scale as a `Mat3`, `matrix()` the whole
`T * R * S` as a `Mat4`, and `setBasis`/`setMatrix` decompose one back into
origin, rotation and scale. Decomposition is not always exact: shear cannot
be represented, and pitch is canonicalised into `[-90, 90]`, so a round trip
preserves the *rotation* but need not preserve the *numbers*.

Rotation is degrees, as yaw/pitch/roll:

| component | name | axis | |
|---|---|---|---|
| `rotation[0]` | pitch | X | right |
| `rotation[1]` | yaw | Y | up |
| `rotation[2]` | roll | Z | toward the viewer |

composed `Ry(yaw) * Rx(pitch) * Rz(roll)` — roll first, then pitch, then yaw,
the usual convention for a Y-up renderer. Note this is **not** what
`glm::quat(vec3)` builds (`Rz * Ry * Rx`), and so not what
`ofNode::setOrientation(const glm::vec3&)` takes. A quaternion carries no
convention, so `Quat` is the currency to interop through.

Every value above was checked against glm itself: a probe compiled with the
real headers prints glm's quaternions, matrices, products and inverses, and
the Zig side reproduces all 91 of them to four decimal places.

These bind the matrix half of `ofGraphics.h`: `ofLoadMatrix`, `ofMultMatrix`,
`ofLoadViewMatrix`, `ofMultViewMatrix`, `ofLoadIdentityMatrix`,
`ofSetMatrixMode`, and the four `ofGetCurrent*Matrix` queries.

## Try it

```bash
zig build run -Dof-root=C:/path/to/of_v0.12.1_vs_64_release
```

`zig build glue -Dof-root=...` writes the generated C++ glue to
`zig-out/glue/of_glue.cpp` for inspection.

## How it holds together

One file per area of the oF API in `src/`, each holding its types, with
their methods, and its free functions:

| File | What |
|---|---|
| `app.zig` | `run`, the window, frame, time and input queries, the callback table behind `run`. |
| `graphics.zig` | The immediate-mode drawing calls of `ofGraphics.h`. |
| `color.zig`, `math.zig`, `rectangle.zig`, `string.zig` | `Color`, `glm::vec*` (float, `int`, `unsigned`) and `ofMath.h`, `ofRectangle`, `std::string`. |
| `matrix.zig` | `glm::mat3`, `glm::mat4`, `glm::quat`, and the `Transform` that composes them. |
| `events.zig` | The event-argument types and the key, modifier and mouse-button constants. |
| `of.zig` | Re-exports everything flat, and is the root the glue scan starts from. |
| `glue_manifest.zig` | Build-side only: what the `glue` step hands cpp-bindgen's generator. |

A bound function is a public `Signature` constant, named after the C++
function, next to the Zig wrapper that binds it:

```zig
pub const ofDrawCircle_sig: Signature = .{ .name = "ofDrawCircle", .args = &.{ f32, f32, f32 } };
pub fn drawCircle(x: f32, y: f32, radius: f32) void {
    cpp.bind(ofDrawCircle_sig)(x, y, radius);
}
```

The constant is public so the glue scan finds it: the glue then takes the
function's address with that exact type, and a signature that names no real
overload fails to compile before it can fail to link. Overloads get a suffix
(`ofSetColor_alpha_sig`); a member's signature lives inside its type.

A type is an `extern struct` that describes its C++ class to cpp-bindgen
(`cpp_name` or `cpp_template`, `cpp_abi`) and carries its own methods; its
field names are the C++ member names because the glue checks each with
`offsetof`.

Two pieces of C++ are compiled into the library besides oF itself:

- **The generated glue.** `build.zig` points cpp-bindgen at `src/of.zig` and
  the headers; the scan walks it and every namespace it re-exports, then emits
  a translation unit that
  `static_assert`s the size, alignment, member offsets and ABI category of
  every type against the real headers, and forces definitions for the
  header-only `std::string` members. A layout that drifts between oF patch
  versions is therefore a compile error, not a memory corruption; a wrong
  signature is a link error.
- **`src/cpp/ofzig_app.cpp`.** oF drives an app through `ofBaseApp`'s virtual
  functions, and a subclass is the one thing cpp-bindgen cannot express. This
  file is that subclass; it forwards each virtual to a C function pointer that
  `app.zig` fills in from the app type.

The build always compiles oF in its Release configuration (`NDEBUG`,
`_ITERATOR_DEBUG_LEVEL=0`, dynamic CRT) whatever the Zig optimize mode. The
prebuilt libraries and the MSVC STL layouts the bindings describe are those of
a release build.

## Known limits

- **Coverage.** This is the first slice: app lifecycle and events, the 2D
  drawing calls in `ofGraphics.h`, colors, `ofRectangle`, the math helpers,
  and `std::string`. Everything else in oF is one `Signature` away, and the
  glue tells you when you get one wrong.
- **Not movable: `of.Rectangle`.** `ofRectangle` keeps C++ references into
  its own storage. Construct it in place with `init` and never copy it.

## Adding a binding

1. If the function needs a class the bindings do not have, add an
   `extern struct` with the C++ member names and a `cpp_abi` to the file for
   its area. The next build tells you if the layout or the category is wrong.
   `zig cc -target x86_64-windows-msvc -fsyntax-only -Xclang
   -fdump-record-layouts-complete` on a probe that includes `ofMain.h` prints
   the real layout.
2. Declare `pub const <cppName>_sig: Signature` next to a Zig wrapper that
   calls `cpp.bind(<cppName>_sig)`. For an overloaded function, suffix the
   constant and give the Zig function a distinct name.
3. That is all. The glue scan reads public signatures at module level and
   inside each type it finds, so a member's signature lives on its type and a
   header-only function's definition is forced without further listing.

`zig cc -target x86_64-windows-msvc -fsyntax-only -Xclang -ast-dump=json
-Xclang -ast-dump-filter=<name>` on the same probe prints the exact parameter
types and the mangled name clang will produce, which is what cpp-bindgen's name
has to match.

## Editor support

ZLS resolves `@import("of")` only after running its build runner over
`build.zig`. ZLS 0.17.0-dev.44, the newest prebuilt at the time of writing,
still invokes `zig build --build-runner`, which Zig 0.17.0-dev.1683's new build
driver rejects, so every named module is unresolved in the editor: not just
`of`, any dependency. That is a ZLS-version issue, not a project one; a ZLS
built from master against this Zig should fix it. Everything the wrappers
expose is a plain `pub fn`, so once the module resolves, hover and
go-to-definition work on all of it.

## License

MIT.
#   o p e n F r a m e w o r k s - z i g  
 