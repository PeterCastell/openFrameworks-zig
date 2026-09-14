# openFrameworks-zig

Use openFrameworks (oF) from Zig, with no C shim. Every call goes directly to
the C++ symbol through [cpp-bindgen](https://github.com/PeterCastell/cpp-bindgen).

This package controls the compilation of oF, but it does not contain the oF
source. Point the package at an oF 0.12 release. The package then compiles the
oF core with the Zig toolchain for the MSVC ABI. It links the prebuilt
third-party libraries of oF. It also checks every binding against the headers
that you supply.

## Requirements

- Zig 0.17.0-dev.1683 or later.
- Visual Studio 2022 with the C++ workload and a Windows 10/11 SDK. Zig uses
  the headers and the import libraries of these tools. Zig does not run
  `cl.exe`.
- An oF release in the `of_v0.12.x_vs_64_release` layout. Development used
  version 0.12.1.

This package supports only `x86_64-windows-msvc`. This limit is deliberate. The
bindings describe MSVC STL layouts and MSVC-mangled names. Also, the
third-party libraries that oF supplies for Windows are Visual Studio builds.

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

// Every oF build on Windows uses the dynamic CRT. The executable must do the same.
const exe = b.addExecutable(.{ .name = "app", .root_module = exe_mod, .linkage = .dynamic });
```

The `of` module contains the compiled oF library and the full link line. Thus a
project needs only this import. The value for `of-root` can also come from the
`OF_ROOT` environment variable.

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

`of.run` connects the handlers that the app type declares. These handlers are
`setup`, `update`, `draw`, `exit`, and the key, mouse, touch, resize, drag and
message handlers. `of.run` then starts the oF main loop. See
[example/main.zig](example/main.zig).

## Vectors

`of.Vec2`, `of.Vec3` and `of.Vec4` are the builtin `@Vector` type of Zig. Thus
the arithmetic is a language operation, and no code calls C++ for it:

```zig
const a: of.Vec2 = .{ 10, 20 };
const b = a + @as(of.Vec2, @splat(5)); // { 15, 25 }
const away = of.normalize(b - a) * @as(of.Vec2, @splat(80));
of.drawCircleAt(a + away, 12);
```

Components are `v[0]` and `v[1]`, not `v.x`. Zig has no operator overloading.
Thus a type that accepts `+` cannot also be a struct. This is the trade.
`of.dot`, `of.length`, `of.normalize` and `of.cross` supply the operations that
have no operator.

The element type is the suffix. `of.Vec2I`, `Vec3I` and `Vec4I` are `i32`, which
is `glm::ivec*`. `of.Vec2U`, `Vec3U` and `Vec4U` are `u32`, which is
`glm::uvec*`. `of.vecCast` converts between any two vectors of the same length:

```zig
const px = of.vecCast(of.Vec2I, @round(mouse));
const back = of.vecCast(of.Vec2, px);
```

A float to int conversion truncates toward zero, as C does. For a different
rounding mode, put the argument in `@floor` or `@round`.

In a safety-checked build, a value that the destination cannot hold causes a
panic. A negative float that you cast to a `*U` type causes this panic.
`of.length` and `of.normalize` need float vectors. Convert an integer vector
with `of.vecCast` first.

Of these types, oF 0.12 uses only the float vectors. It also uses
`glm::vec<N, int>` in `ofMaterial::setCustomUniform2i` and the related
functions. This package binds and layout-checks the unsigned set as well. Thus a
new binding that needs an unsigned vector does not have to declare it.

Every wrapper accepts and returns these types. The `glm::vec*` types are
`of.GlmVec2`, `of.GlmVec3`, `of.GlmVec4` and the equivalent `I` and `U` names.
They appear only where the ABI needs them: in a `Signature`, and as a field of
another bound class such as `OfRectangle.position`.

A `@Vector` cannot go in either place. Zig rejects a `@Vector` as a field of an
`extern struct`, because a `@Vector` has no guaranteed in-memory representation.
Also, `@Vector(3, f32)` is 16 bytes and `glm::vec3` is 12 bytes. Thus an array
of them has the wrong stride.

To convert a value that goes out, use `GlmVec3.from(v)`. To convert a value that
comes back, use `g.to()`. The conversion occurs in the wrapper body, and the
optimizer removes it. Accessors return the Zig spelling: `rect.getPosition()`,
`rect.getCenter()` and `mouse.pos()`.

## Angles

Every angle in this package is in radians. It takes radians, and it returns
radians. No name carries a `Deg` or a `Rad` suffix.

openFrameworks is degrees-first. It spells most rotations twice, as
`ofRotateDeg` and `ofRotateRad`, or as `ofNode::panDeg` and `panRad`. Where a
pair exists, this package binds the radian half and drops the suffix. A few oF
calls have no radian half: `ofPath::arc`, `ofPolyline::arc`, `ofCamera::setFov`,
`ofMesh::smoothNormals` and `ofNode::setOrientation(const glm::vec3&)`. For
those, the wrapper converts, and the Zig signature still takes radians.

The reason is `std.math`. The trigonometry of Zig is in radians. A sketch that
works in degrees converts at every call. A sketch in radians never converts.
Note also that glm is radians-only, so oF converts at its own boundary already.

`of.degToRad` and `of.radToDeg` remain. Use them to read a degree literal out of
a design or out of oF code you are porting. They are not part of any signature.

One field is an exception. `TouchEventArgs.angle` comes from the touch API of
the platform. oF declares it without a unit, and oF never reads it. This package
passes it through as it arrives.

## Matrices and transforms

`of.Mat3`, `of.Mat4` and `of.Quat` are `glm::mat3`, `glm::mat4` and `glm::quat`.
These types have one spelling, not two, which is different from the vectors. The
two vector spellings exist to give the `@Vector` operators of Zig. A matrix
product is not element-wise. Thus a second matrix type would add only a
conversion. `Mat4` is the ABI type, and you can send `&m` directly to a bound
function.

There is one exception. glm declares the storage of `mat` as private. Thus
`Mat3` and `Mat4` carry `cpp_no_offsets`. The glue pins them by size, alignment
and ABI category instead.

The storage is the glm storage. It is column-major, and `value[1]` is the second
column. `a.mul(b)` applies `b` first. This package writes the arithmetic in Zig
over `@Vector` columns, and does not bind it from glm. A 4x4 product is
approximately sixteen vector instructions, which costs less than a call.

`of.Transform` contains the three values that a sketch changes:

```zig
var t: of.Transform = .{ .origin = .{ 100, 100, 0 }, .scale = @splat(2) };
t.rotation[1] = of.getElapsedTimef() * 0.7; // yaw, radians a second
of.pushMatrix();
of.multMatrix(t.matrix());
// ... draw in the transform's space ...
of.popMatrix();
```

`basis()` returns the rotation and the scale as a `Mat3`. `matrix()` returns the
full `T * R * S` as a `Mat4`. `setBasis` and `setMatrix` decompose a matrix back
into origin, rotation and scale.

The decomposition is not always exact. A `Transform` cannot represent shear.
Also, the code puts pitch into the range `[-pi/2, pi/2]`. Thus a round trip
keeps the rotation, but it can change the numbers.

Rotation is in radians, as yaw, pitch and roll:

| component | name | axis | axis direction |
|---|---|---|---|
| `rotation[0]` | pitch | X | right |
| `rotation[1]` | yaw | Y | up |
| `rotation[2]` | roll | Z | toward the viewer |

The composition is `Ry(yaw) * Rx(pitch) * Rz(roll)`. Roll occurs first, then
pitch, then yaw. This is the usual convention for a Y-up renderer.
`glm::quat(vec3)` does not build this composition. It builds `Rz * Ry * Rx`.
Thus `ofNode::setOrientation(const glm::vec3&)` does not accept this
composition.

A quaternion has no convention. Thus use `Quat` to exchange a rotation with oF.

A test compared every value above against glm. A probe that compiles with the
real headers prints the quaternions, matrices, products and inverses of glm. The
Zig code reproduces all 91 values to four decimal places.

These types bind the matrix functions of `ofGraphics.h`: `ofLoadMatrix`,
`ofMultMatrix`, `ofLoadViewMatrix`, `ofMultViewMatrix`, `ofLoadIdentityMatrix`,
`ofSetMatrixMode`, and the four `ofGetCurrent*Matrix` queries.

## Rectangles

`of.Rectangle` is a plain Zig struct of two `Vec2`s. Copy it, put it in an
array, return it from a function. It is four floats.

```zig
const box: of.Rectangle = .{ .position = .{ 40, 80 }, .size = .{ 220, 120 } };
if (box.inside(mouse)) box.draw();
```

Its methods are Zig, not calls into C++. They reproduce `ofRectangle`'s exact
behaviour, including the parts that surprise you: `getArea` is
`abs(width) * abs(height)`, so a negative side still gives a positive area, and
`inside` uses strict comparisons against the standardized corners, so a point
exactly on an edge is outside. A differential test checks all of this against
the real `ofRectangle`: 196 comparisons over seven rectangles and thirteen
points, including negative sides and exact corners, with no mismatch.

oF gives `ofRectangle` a `glm::vec3` position, but the z is dead. The class has
no `getZ` or `setZ`. `getCenter` returns z as `0.f`.
`ofDrawRectangle(const ofRectangle&)` passes a hardcoded `0.0f`. Only one
stream operator reads it, and its own writer does not write it. So
`of.Rectangle` is 2D, and `draw` calls
`ofDrawRectangle(const glm::vec2&, w, h)` directly.

`of.OfRectangle` is the ABI type, the layout the C++ class has. It stays out of
the public API for a reason: `ofRectangle` declares `float& x` and `float& y`
bound to its own `position`, so an instance cannot be copied or moved after
construction. A bound function that wants one gets a staged temporary:

```zig
var tmp: of.OfRectangle = undefined;
const p = rect.stage(&tmp);
defer tmp.deinit();
cpp.bind(some_sig)(p);
```

The constructor binds the two references into `tmp` itself, and a local whose
address you take does not move, so the temporary is valid for the call.

## Try it

```bash
zig build run -Dof-root=C:/path/to/of_v0.12.1_vs_64_release
```

`zig build glue` writes the generated C++ glue to `zig-out/glue/of_glue.cpp`.
Read that file to examine the glue. It is the same file the build compiles
into the library, not a second copy of it, and generating it needs no oF
headers -- so this step works without `-Dof-root`.

## How it works

`src/` has one file for each area of the oF API. Each file contains its types,
the methods of those types, and its free functions:

| File | What |
|---|---|
| `app.zig` | `run`, the window, frame, time and input queries, the callback table behind `run`. |
| `graphics.zig` | The immediate-mode drawing calls of `ofGraphics.h`. |
| `color.zig`, `math.zig`, `rectangle.zig`, `string.zig` | `Color`, `glm::vec*` (float, `int`, `unsigned`) and `ofMath.h`, `ofRectangle`, `std::string`. |
| `matrix.zig` | `glm::mat3`, `glm::mat4`, `glm::quat`, and the `Transform` that composes them. |
| `events.zig` | The event-argument types and the key, modifier and mouse-button constants. |
| `of.zig` | Re-exports everything flat, and is the root the glue scan starts from. |

A bound function is a public `Signature` constant. The constant has the name of
the C++ function, and it sits next to the Zig wrapper that binds it:

```zig
pub const ofDrawCircle_sig: Signature = .{ .name = "ofDrawCircle", .args = &.{ f32, f32, f32 } };
pub fn drawCircle(x: f32, y: f32, radius: f32) void {
    cpp.bind(ofDrawCircle_sig)(x, y, radius);
}
```

The constant is public so that the glue scan finds it. The glue then takes the
address of the function with that exact type. A signature that names no real
overload fails to compile, before it can fail to link. An overload gets a
suffix, such as `ofSetColor_alpha_sig`. The signature of a member stays inside
its type.

A type is an `extern struct`. It describes its C++ class to cpp-bindgen with
`cpp_name` or `cpp_template` and `cpp_abi`, and it contains its own methods. Its
field names are the C++ member names, because the glue checks each name with
`offsetof`.

The build compiles two pieces of C++ into the library, in addition to oF:

- **The generated glue.** `build.zig` points cpp-bindgen at `src/of.zig` and the
  headers. The scan reads that file and every namespace that it re-exports, then
  emits a translation unit. That unit applies `static_assert` to the size,
  alignment, member offsets and ABI category of every type, against the real
  headers. It also forces definitions for the header-only `std::string` members.
  Thus a layout that changes between oF patch versions is a compile error, not a
  memory corruption. A wrong signature is a link error.
- **`src/cpp/ofzig_app.cpp`.** oF drives an app through the virtual functions of
  `ofBaseApp`. A subclass is the one construct that cpp-bindgen cannot express.
  This file supplies that subclass. It sends each virtual call to a C function
  pointer. `app.zig` sets those pointers from the app type.

The build always compiles oF in its Release configuration, whatever the Zig
optimize mode. That configuration is `NDEBUG`, `_ITERATOR_DEBUG_LEVEL=0` and the
dynamic CRT. The prebuilt libraries are release builds. The MSVC STL layouts
that the bindings describe are also release layouts.

## Known limits

- **Coverage.** This is the first part of the API: the app lifecycle and events,
  the 2D drawing calls in `ofGraphics.h`, colors, `ofRectangle`, the math
  helpers, and `std::string`. To add any other oF function, write one
  `Signature`. The glue reports an error if that signature is incorrect.

## Adding a binding

1. If the bindings do not have the class that the function needs, add an
   `extern struct` to the file for that area. Give the struct the C++ member
   names and a `cpp_abi`. The next build reports an error if the layout or the
   category is incorrect.
2. Declare `pub const <cppName>_sig: Signature` next to a Zig wrapper that calls
   `cpp.bind(<cppName>_sig)`. For an overloaded function, add a suffix to the
   constant. Give the Zig function a distinct name.

That is all. The glue scan reads public signatures at module level, and inside
each type that it finds. Thus the signature of a member stays on its type, and
the glue forces the definition of a header-only function with no further
listing.

To print the real layout of a class, run this command on a probe that includes
`ofMain.h`:

```bash
zig cc -target x86_64-windows-msvc -fsyntax-only -Xclang -fdump-record-layouts-complete probe.cpp
```

To print the exact parameter types and the mangled name that clang produces, run
this command on the same probe:

```bash
zig cc -target x86_64-windows-msvc -fsyntax-only -Xclang -ast-dump=json -Xclang -ast-dump-filter=<name> probe.cpp
```

The name from cpp-bindgen must agree with the name that clang prints.

## Editor support

ZLS resolves `@import("of")` only after it runs its build runner on `build.zig`.
ZLS 0.17.0-dev.44 is the newest prebuilt version at this time. It still calls
`zig build --build-runner`. The new build driver of Zig 0.17.0-dev.1683 rejects
that argument. Thus the editor cannot resolve any named module, not only `of`.
This is a ZLS version problem, not a project problem.

A ZLS that you build from master against this Zig can correct the problem. The
wrappers expose only plain `pub fn` declarations. When the module resolves,
hover and go-to-definition work on all of them.

## License

MIT.
