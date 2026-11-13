# openFrameworks-zig

Use openFrameworks (oF) from Zig, with no C shim. Every call goes directly to
the C++ symbol through [cpp-bindgen](https://github.com/PeterCastell/cpp-bindgen).

This package controls the compilation of oF, but it does not contain the oF
source. Point the package at an oF 0.12 release. The package then compiles the
oF core with the Zig toolchain for that platform's C++ ABI. It links the
prebuilt third-party libraries of oF. It also checks every binding against the
headers that you supply.

## Requirements

- Zig 0.17.0-dev.1683 or later.
- One of these two platforms, each with the oF release made for it.
  Development used oF 0.12.1.

| Platform | Target | oF release | Also needs |
|---|---|---|---|
| Windows | `x86_64-windows-msvc` | `of_v0.12.x_vs_64_release` | Visual Studio 2022 with the C++ workload and a Windows 10/11 SDK. Zig uses their headers and import libraries; it does not run `cl.exe`. |
| macOS | `aarch64-macos` or `x86_64-macos` | `of_v0.12.x_osx_release` | The Xcode command line tools, for the macOS SDK. |

The default target is the right one for the machine: the MSVC ABI on Windows,
the native target on a Mac. The two platforms differ in their C++ ABI (MSVC or
Itanium) and their standard library (the MSVC STL or libc++), and the bindings
spell the layouts of both. The release matters too: the third-party libraries
that oF supplies are built for one platform, so a vs_64 release does not work
on a Mac or an osx release on Windows. Other targets are refused.

## Use from a project

```bash
zig fetch --save git+https://github.com/PeterCastell/openFrameworks-zig.git
```

```zig
// build.zig
const of_dep = b.dependency("openframeworks_zig", .{
    .target = target,
    .optimize = optimize,
    .@"of-root" = @as([]const u8, "C:/path/to/of_v0.12.1_vs_64_release"), // or the osx release on a Mac
});
exe_mod.addImport("of", of_dep.module("of"));

// Every oF build on Windows uses the dynamic CRT, and on macOS everything links
// dynamically. The executable must do the same.
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
[example/main.zig](example/main.zig) for the 2D calls and
[example/3d.zig](example/3d.zig) for a camera, a primitive and a light, and
[example/transforms.zig](example/transforms.zig) for matrices built by hand,
a mesh transformed vertex by vertex, and a material, and
[example/shaders.zig](example/shaders.zig) for two GLSL programs compiled from
source, and [example/model.zig](example/model.zig) for a 3D model loaded
through the ofxAssimpModelLoader addon.

## 3D

`of.EasyCam`, `of.Camera`, the six primitives (`of.BoxPrimitive` and the rest)
and `of.Light` are all `ofNode`s in C++. Each Zig type binds the methods that
its own class declares, and reaches a base class through an accessor:

```zig
var cam: of.EasyCam = undefined;     // a field of the app struct
cam.init();                          // in setup; deinit in exit

cam.node().setPosition(.{ 0, 250, 450 });   // ofNode, two levels up
cam.node().lookAt(.{ 0, 0, 0 });
cam.camera().setFov(std.math.pi / 3.0);     // ofCamera, one level up

cam.begin();                         // in draw
of.drawGrid(50, 4, .{ .x = false, .y = true, .z = false });
of.drawCylinder(10, 40);
cam.end();
```

`node()` and `camera()` are `cpp.basePtr`: an upcast that cpp-bindgen checks
at compile time against the `cpp_bases` that the type declares. The
immediate-mode solids (`drawBox`, `drawSphere`, `drawCylinder`, `drawCone`,
`drawPlane`, `drawIcoSphere`, each with a `v` form that takes a `Vec3`),
`drawAxis`, `drawGrid`, `drawArrow` and the lighting switches are free
functions on `of`.

A Zig type can extend any of these classes and override its virtual
functions, with no C++. It holds the C++ object as a field, an `of.Subclass`,
and pairs each override with the base's signature:

```zig
const Beacon = struct {
    cpp: of.Subclass(of.Node, Beacon, "cpp"),
    radius: f32 = 8,

    pub const cpp_overrides = .{.{ of.Node.customDraw_sig, customDraw }};

    fn customDraw(self: *Beacon) void {
        of.drawIcoSphere(self.radius);
    }
};

beacon.cpp.init();           // in setup; beacon.cpp.deinit() in exit
beacon.cpp.base.draw();      // in draw
```

`draw` hands the node to oF's renderer, which applies the node's transform and
calls `customDraw`, so the beacon draws in its own coordinates. The protected
hooks `onPositionChanged`, `onOrientationChanged` and `onScaleChanged` are
overridden the same way. Inside an override, `of.bind(signature)` calls the
base's own definition. The wrappers for virtual functions, such as `draw`,
`begin` and `end`, make virtual calls, so an override is reached from Zig as it
is from C++. `example/3d.zig` parents a beacon to the turning box. Every other
class here with virtual functions, such as `of.Material` and `of.Mesh`, can be
extended the same way.

`of.Mesh` is `ofMesh`. Its bulk calls take slices of the ABI types and hand
them to oF's pointer-and-length overloads, so nothing is copied on the way in;
its getters return the mesh's own arrays as slices, so nothing is copied on the
way out either:

```zig
var mesh: of.Mesh = undefined;
mesh.init();
mesh.setMode(.triangle_fan);
mesh.addVertices(&.{ .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 50, .y = 0, .z = 0 }, .{ .x = 0, .y = 50, .z = 0 } });
for (mesh.getVertices()) |*v| v.y += 10;   // in place
mesh.draw();
```

The slices are of `GlmVec3`, not `Vec3`: a `Vec3` is 16 bytes and a
`glm::vec3` is 12, so an array of one is not an array of the other. A
primitive's `getMesh()` returns the mesh it draws, for editing in place.
`copyFrom` is `operator=`, for refilling a mesh from another; `initCopy` is
the copy constructor, for one not yet constructed.

`of.Material` is `ofMaterial`: the diffuse, ambient, specular and emissive
reflectance and the shininess that a light shades a mesh with. Between
`begin` and `end` it replaces the current color:

```zig
var material: of.Material = undefined;   // a field of the app struct
material.init();                         // in setup; deinit in exit
material.setDiffuseColor(of.FloatColor.steelBlue);
material.setShininess(120);

material.begin();                        // in draw, with lighting on
mesh.draw();
material.end();
```

Its colors are `FloatColor`s, as a light's are. Every one of oF's named
colors (`wheat`, `steelBlue`, `indianRed` and the rest of `ofColor.h`) is a
constant on `of.Color`, `of.FloatColor` and `of.ShortColor`, with oF's own
values; `.from(of.Color.wheat)` converts between the three.

## Vectors

`of.Vec2`, `of.Vec3` and `of.Vec4` are the builtin `@Vector` type of Zig. Thus
the arithmetic is a language operation, and no code calls C++ for it:

```zig
const a: of.Vec2 = .{ 10, 20 };
const b = a + @as(of.Vec2, @splat(5)); // { 15, 25 }
const away = of.normalize(b - a) * @as(of.Vec2, @splat(80));
of.drawCirclev(a + away, 12);
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

`Mat3.fromEuler` and `Quat.fromEuler` take euler angles in radians, as yaw,
pitch and roll, and `toEuler` returns them the same way:

| component | name | axis | axis direction |
|---|---|---|---|
| `[0]` | pitch | X | right |
| `[1]` | yaw | Y | up |
| `[2]` | roll | Z | toward the viewer |

The composition is `Ry(yaw) * Rx(pitch) * Rz(roll)`. Roll occurs first, then
pitch, then yaw. This is the usual convention for a Y-up renderer.
`glm::quat(vec3)` does not build this composition. It builds `Rz * Ry * Rx`.
Thus `ofNode::setOrientation(const glm::vec3&)` does not accept this
composition.

A quaternion has no convention. Thus use `Quat` to exchange a rotation with oF.

A test compared every value above against glm. A probe that compiles with the
real headers prints the quaternions, matrices, products and inverses of glm. The
Zig code reproduces all 91 values to four decimal places.

`Mat4` also builds the elementary matrices the way glm does. `Mat4.translation(v)`,
`Mat4.rotation(radians, axis)` and `Mat4.scaling(s)` each build one on their own,
and `m.translate(v)`, `m.rotate(radians, axis)` and `m.scale(s)` post-multiply one
onto `m`, as `glm::translate(m, v)` does. So `T * R * S` is either
`Mat4.translation(t).mul(.rotation(a, axis)).mul(.scaling(s))` or
`Mat4.identity.translate(t).rotate(a, axis).scale(s)`. `transformPoint` applies a
matrix to a position (`w` = 1), `transformDir` to a direction (`w` = 0), and
`projectPoint` divides by the `w` that comes out, for a projection.

`inverse` and `determinant` are general; `affineInverse` is the cheaper one for
a matrix whose last row is `0 0 0 1`. `perspective`, `ortho` and `lookAt` are
glm's, right-handed with clip depth in `[-1, 1]`, and reproduce what
`ofCamera` returns from `getProjectionMatrix` and `getModelViewMatrix`.
`Mat3.fromAxisAngle`, `Mat4.fromMat3`, `Mat4.fromQuat` and `Quat.toMat4` convert
between the three.

These types bind the matrix functions of `ofGraphics.h`: `ofLoadMatrix`,
`ofMultMatrix`, `ofLoadViewMatrix`, `ofMultViewMatrix`, `ofLoadIdentityMatrix`,
`ofSetMatrixMode`, and the four `ofGetCurrent*Matrix` queries.

## Shaders

`of.Shader` is `ofShader`. Compile it from GLSL in memory, or `load` the
`.vert` and `.frag` files under `bin/data`, then bracket the draw calls with
`begin` and `end`:

```zig
shader.init(); // in setup; deinit in exit
_ = shader.setupShaderFromSource(.vertex, vert_src);
_ = shader.setupShaderFromSource(.fragment, frag_src);
_ = shader.linkProgram();

shader.begin(); // in draw
shader.setUniform1f("time", of.getElapsedTime());
shader.setUniform3f("tint", .{ 1, 0.5, 0.2 });
sphere.draw();
shader.end();
```

`of.run` opens an OpenGL 2.1 context with the fixed-function renderer. Thus a
shader is GLSL 1.20 (`#version 120`), and it reads the geometry of oF through
the built-ins: `gl_Vertex`, `gl_Normal`, `gl_Color` and
`gl_ModelViewProjectionMatrix`.

The uniform setters take `Vec2`, `Vec3`, `Vec4`, `Mat3`, `Mat4` and
`FloatColor`. The array setters (`setUniform3fv` and the others) take a slice of
`GlmVec*`, as the bulk calls of `Mesh` do. Set a uniform between `begin` and
`end`. A uniform that the program does not use is ignored. The texture uniforms
are not bound yet.

## Models: the ofxAssimpModelLoader addon

Every oF release ships the `ofxAssimpModelLoader` addon and a prebuilt assimp
under `addons/`. As in an oF project, an addon is opt-in. Pass `-Dassimp`, or
`.assimp = true` to the dependency, and the build compiles the addon's four
`.cpp` files, links the release's assimp, and fills in `of.assimp`:

```zig
const of_dep = b.dependency("openframeworks_zig", .{
    .target = target,
    .optimize = optimize,
    .@"of-root" = @as([]const u8, "C:/path/to/of_v0.12.1_vs_64_release"),
    .assimp = true,
});
```

```zig
model: of.assimp.ModelLoader = undefined, // a field of the app

// setup
self.model.init(); // deinit in exit
_ = self.model.load("Fox/Fox_05.fbx", .optimize_default);
self.model.playAllAnimations();

// update
self.model.update(); // advances the animations and re-skins the meshes

// draw, inside a camera, with depth testing on
self.model.drawFaces();
```

All four classes of the addon are bound: `ModelLoader`, `Animation`,
`MeshHelper`, whose public members are fields with their C++ names and
offsets checked by the glue, and `AssimpTexture`. `load` takes one of the
addon's presets (`.optimize_none`, `.optimize_default`, `.optimize_high`) or
an exact set of assimp post-processing steps, `.steps(.{ .triangulate = true,
... })`. `loadMemory` loads from bytes, `@embedFile` included. The copies
the loader returns by value (`getMesh`, `getMaterialForMesh`,
`getTextureForMesh`) run their constructor on storage you pass, so they are
built where they will live. The deprecated calls are left out.

The addon needs `of.Texture` (`ofTexture`, with its `ofBaseDraws` interface)
and `of.Buffer` (`ofBuffer`), which are core oF and always present.

On Windows, a Debug link with the addon prints LLD's warning LNK4099 for
each assimp object, and the build summary marks the step. The link succeeds:
oF's `libassimp.lib` names a PDB that existed only on the machine that built
it, so assimp's own frames have no symbols.

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

On a Mac, the same with the osx release:

```bash
zig build run -Dof-root=/path/to/of_v0.12.1_osx_release
```

The model example needs the addon, and takes any file assimp reads:

```bash
zig build run-model -Dassimp -Dof-root=C:/path/to/of_v0.12.1_vs_64_release -- path/to/model.gltf
```

An Intel build also runs on Apple Silicon, under Rosetta:
`zig build test -Dtarget=x86_64-macos -frosetta`. CI runs the tests both ways,
and builds the examples, on every push (`.github/workflows/ci.yml`).

`zig build test` checks the bindings against the oF build: the vtable layouts
they claim, and a Zig subclass of `ofBaseApp`. It needs `-Dof-root` too, but no
window.

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
| `font.zig` | `ofTrueTypeFont`: loading a face, measuring a string, drawing one. Also `ofTrueTypeFontSettings` and the `ofUnicode` ranges. |
| `color.zig`, `math.zig`, `rectangle.zig`, `string.zig` | `Color`, `glm::vec*` (float, `int`, `unsigned`) and `ofMath.h`, `ofRectangle`, and the `std::string`, `std::wstring` and `std::filesystem::path` that oF calls take. |
| `matrix.zig` | `glm::mat3`, `glm::mat4` and `glm::quat`. |
| `node.zig`, `camera.zig`, `primitives.zig`, `mesh.zig`, `light.zig`, `graphics3d.zig` | `ofNode`, `ofCamera` and `ofEasyCam`, the six `of3dPrimitives.h` shapes, `ofMesh`, `ofLight` and the lighting switches, and the immediate-mode solids of `of3dGraphics.h`. |
| `material.zig` | `ofMaterial`: the Phong colors and shininess, the PBR scalars, and the custom uniforms. |
| `shader.zig` | `ofShader`: compiling and linking a GLSL program, and setting its uniforms and attributes. |
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
`offsetof`. A field whose name starts with `_` is not checked. That is how a
binding spells a vtable pointer, and how `Font` gives the storage of
`ofTrueTypeFont` instead of its two dozen members: the glue still checks the
size and the alignment, which is all a caller of that class depends on.

A class with a base declares it in `cpp_bases` and starts with the field that
cpp-bindgen sizes for it:

```zig
pub const Camera = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),   // the ofNode
    _storage: [56]u8 align(8),                                     // what ofCamera adds
    pub const cpp_name = "ofCamera";
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Node};
    pub const cpp_virtual_dtor = true;

    pub fn node(self: *Camera) *Node {
        return cpp.basePtr(Node, self);
    }
};
```

`_storage` is the size of the class minus the space its base takes. On MSVC
that is the base's whole size. On Itanium it is only the base's data, since a
derived class packs its own members into the base's tail padding. The two
ABIs' standard libraries differ in size too, so a `_storage` size is written
once for each (`if (msvc) ... else ...`). cpp-bindgen computes the base's
offset, `basePtr` is the checked upcast, and the glue asserts that the base is
one and that the whole class has the declared size. A method that the base
declares is bound once, on the base; a derived type reaches it through the
accessor. The one exception is a method that pairs with one the derived class
overrides, such as `EasyCam.end` beside `EasyCam.begin`: it is bound on the
derived type with `.class = Camera`, which cpp-bindgen checks the same way.

A virtual method is marked `.virtual = true` in its `Signature`, a pure one
`.pure = true`, and a non-public one `.access = .protected` or `.private`,
because MSVC mangles all three into the symbol. Its wrapper calls
`cpp.bindVirtual`, which loads the function from the object's vtable, so the
override runs whether a C++ class or a Zig type defines it. Every class with
virtual functions lists the ones its header declares in `cpp_virtuals`, in
header order, the destructor and overrides included. cpp-bindgen computes the
vtables from those lists, for virtual calls and for `of.Subclass`.

The build compiles two pieces of C++ into the library, in addition to oF:

- **The generated glue.** `build.zig` points cpp-bindgen at `src/of.zig` and the
  headers. The scan reads that file and every namespace that it re-exports, then
  emits a translation unit. That unit applies `static_assert` to the size,
  alignment, member offsets and ABI category of every type, against the real
  headers. It also forces definitions for the header-only `std::string` members.
  Thus a layout that changes between oF patch versions is a compile error, not a
  memory corruption. A wrong signature is a link error.
- **The app is a Zig subclass of `ofBaseApp`.** oF drives an app through the
  virtual functions of `ofBaseApp`. `run` wraps the app type in cpp-bindgen's
  `Subclass`, which builds that subclass's vtables at comptime, so C++ sees an
  `ofBaseApp` whose overrides call the app type's methods. There is no
  hand-written C++ in the package. In a Debug build the vtables `ofBaseApp()`
  installs are checked against the binding's list of virtual functions every
  time an app starts.

The build always compiles oF in its Release configuration, whatever the Zig
optimize mode. On Windows that configuration is `NDEBUG`,
`_ITERATOR_DEBUG_LEVEL=0` and the dynamic CRT. The prebuilt libraries are
release builds. The MSVC STL layouts that the bindings describe are also
release layouts.

On macOS the build follows oF's makefile (`config.osx.default.mk`). The core
compiles as Objective-C++ with ARC, plus the AVFoundation video and sound
players. The executable links every `libs/*/lib/osx/*.a` in the release and
oF's list of frameworks. oF expects a Mac app to be a bundle, and looks for
`data/` three directories above the executable. A Zig build makes a bare
executable, so `run` points oF at the `data/` directory beside it instead.
That is where oF looks on Windows.

## Known limits

- **Coverage.** The app lifecycle and events, the 2D drawing calls in
  `ofGraphics.h`, the 3D ones in `of3dGraphics.h` and `of3dUtils.h`, `ofNode`,
  `ofCamera`, `ofEasyCam`, the six `of3dPrimitives.h` shapes, `ofMesh`,
  `ofLight`, `ofMaterial`, `ofShader`, `ofTexture`, `ofBuffer`, TrueType text,
  colors, `ofRectangle`, the math helpers, `std::string`, and the
  ofxAssimpModelLoader addon. The sound, video, image and pixel classes are
  not bound, nor is the programmable renderer: `of.run` always opens an
  OpenGL 2.1 context. To add any other oF function, write one `Signature`. The glue
  reports an error if that signature is incorrect.
- **Paths.** A `std::filesystem::path` is built from a fixed buffer, so a name
  longer than 512 UTF-16 code units (Windows) or 512 bytes (macOS) does not
  load. See `string.Path`.

## Adding a binding

1. If the bindings do not have the class that the function needs, add an
   `extern struct` to the file for that area. Give the struct the C++ member
   names and a `cpp_abi`. The next build reports an error if the layout or the
   category is incorrect.
2. Declare `pub const <cppName>_sig: Signature` next to a Zig wrapper that calls
   `cpp.bind(<cppName>_sig)`, or `cpp.bindVirtual` for a virtual function. For
   an overloaded function, add a suffix to the constant. Give the Zig function
   a distinct name.
3. If the class has virtual functions, list every one its header declares in
   `cpp_virtuals`, and add the class to the `verifyVtable` test in
   `test/vtables.zig`. `zig build test` then checks each slot against the
   vtable the C++ compiler emitted.

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
