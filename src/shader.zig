//! ofShader.h: a GLSL program -- a vertex and a fragment stage, and
//! optionally a geometry stage -- that replaces the renderer's own shading
//! for everything drawn between `begin` and `end`.
//!
//! ```zig
//! var shader: of.Shader = undefined;   // a field of the app struct
//! shader.init();                       // in setup; deinit in exit
//! _ = shader.setupShaderFromSource(.vertex, vert_src);
//! _ = shader.setupShaderFromSource(.fragment, frag_src);
//! _ = shader.linkProgram();
//!
//! shader.begin();                      // in draw
//! shader.setUniform1f("time", of.getElapsedTime());
//! sphere.draw();
//! shader.end();
//! ```
//!
//! Or from files under `bin/data`: `load("shaders/glow")` reads
//! `glow.vert` and `glow.frag` (and `glow.geom`, if there is one), compiles
//! them and links the program in one call.
//!
//! By default `of.run` opens an OpenGL 2.1 context with oF's fixed-function
//! renderer, so a shader is GLSL 1.20 (`#version 120`) and reads oF's
//! geometry through the compatibility built-ins: `gl_Vertex`, `gl_Normal`,
//! `gl_Color`, `gl_MultiTexCoord0` and `gl_ModelViewProjectionMatrix`. With
//! `RunOptions.gl_version` 3.2 or higher, the context is core profile and the
//! shader reads oF's uniforms and attributes instead; see `RunOptions`.
//!
//! A uniform is set on the program that is in use, so set it between
//! `begin` and `end`. A name the program does not declare (or one the GLSL
//! compiler optimized out) is ignored. Textures are not bound in this
//! package yet, so `setUniformTexture` is not either.
const cpp = @import("cpp_bindgen");
/// The MSVC ABI and STL (Windows), or else Itanium with libc++ (macOS):
/// the opaque storage sizes below differ between them.
const msvc = @import("builtin").target.abi == .msvc;
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const matrix = @import("matrix.zig");
const FloatColor = @import("color.zig").FloatColor;
const string = @import("string.zig");
const String = string.String;
const Path = string.Path;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec2I = math.Vec2I;
const Vec3I = math.Vec3I;
const Vec4I = math.Vec4I;
const GlmVec2 = math.GlmVec2;
const GlmVec3 = math.GlmVec3;
const GlmVec4 = math.GlmVec4;
const Mat3 = matrix.Mat3;
const Mat4 = matrix.Mat4;

/// The `GLenum` that names a shader stage. oF takes the raw `GL_*_SHADER`
/// value; these are those values.
pub const Stage = enum(u32) {
    vertex = 0x8B31, // GL_VERTEX_SHADER
    fragment = 0x8B30, // GL_FRAGMENT_SHADER
    geometry = 0x8DD9, // GL_GEOMETRY_SHADER
};

/// The `GLenum` primitive types a geometry stage takes in or puts out.
/// Input is one of `points`, `lines`, `lines_adjacency`, `triangles` and
/// `triangles_adjacency`; output one of `points`, `line_strip` and
/// `triangle_strip`.
pub const GeometryPrimitive = enum(u32) {
    points = 0x0000,
    lines = 0x0001,
    line_strip = 0x0003,
    triangles = 0x0004,
    triangle_strip = 0x0005,
    lines_adjacency = 0x000A,
    triangles_adjacency = 0x000C,
};

/// `ofShader`.
///
/// The class holds the GL program name, a loaded flag, and four
/// `std::unordered_map`s (the compiled stages with their sources, and the
/// uniform, attribute and uniform-block location caches). None of it is
/// read from Zig, so the binding gives the storage and the glue checks the
/// size. It owns heap and a GL program, so `deinit` it, and construct it
/// where it will live rather than copying it.
pub const Shader = extern struct {
    _storage: [if (msvc) 264 else 168]u8 align(8),

    pub const cpp_name = "ofShader";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Shader };
    /// Runs `ofShader()` on the storage of `self`: no program, nothing
    /// loaded. The GL work happens in the loads, which need the window, so
    /// call them from `setup`.
    pub fn init(self: *Shader) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Shader };
    /// Deletes the program and its stages, and frees the caches.
    pub fn deinit(self: *Shader) void {
        cpp.bind(dtor_sig)(self);
    }

    // loading

    /// `load(const of::filesystem::path&)`: reads `name.vert`, `name.frag`
    /// and, if it exists, `name.geom`, then links them. `name` is a path
    /// under `bin/data` or an absolute one, without the extension. Reports
    /// whether the program linked; a stage that fails to compile says why
    /// through `ofLogError`.
    pub const load_sig: Signature = .{ .name = "load", .this = *Shader, .args = &.{Ref(*const Path)}, .ret = bool };
    pub fn load(self: *Shader, name: []const u8) bool {
        var path = Path.init(name) orelse return false;
        defer path.deinit();
        return cpp.bind(load_sig)(self, &path);
    }
    /// `load(vertName, fragName, geomName)`: the stages from three files,
    /// each named in full. Pass `null` for no geometry stage.
    pub const load_files_sig: Signature = .{
        .name = "load",
        .this = *Shader,
        .args = &.{ Ref(*const Path), Ref(*const Path), Ref(*const Path) },
        .ret = bool,
    };
    pub fn loadFiles(self: *Shader, vert: []const u8, frag: []const u8, geom: ?[]const u8) bool {
        var v = Path.init(vert) orelse return false;
        defer v.deinit();
        var f = Path.init(frag) orelse return false;
        defer f.deinit();
        var g = Path.init(geom orelse "") orelse return false;
        defer g.deinit();
        return cpp.bind(load_files_sig)(self, &v, &f, &g);
    }

    /// `setupShaderFromSource(GLenum, std::string, of::filesystem::path)`:
    /// compiles one stage from GLSL in memory. Call it once per stage, then
    /// `linkProgram`. Reports whether the stage compiled.
    ///
    /// The source may `#pragma include "file"`; a relative include resolves
    /// against `include_dir`, which `setupShaderFromSource` leaves empty.
    pub const setupShaderFromSource_sig: Signature = .{
        .name = "setupShaderFromSource",
        .this = *Shader,
        .args = &.{ u32, String, Path },
        .ret = bool,
    };
    pub fn setupShaderFromSource(self: *Shader, stage: Stage, source: []const u8) bool {
        return self.setupShaderFromSourceIn(stage, source, "");
    }
    pub fn setupShaderFromSourceIn(self: *Shader, stage: Stage, source: []const u8, include_dir: []const u8) bool {
        var dir = Path.init(include_dir) orelse return false;
        // Both are passed by value, so the call consumes them.
        var src = String.init(source);
        return cpp.bind(setupShaderFromSource_sig)(self, @backingInt(stage), &src, &dir);
    }
    /// `setupShaderFromFile(GLenum, const of::filesystem::path&)`: compiles
    /// one stage from a file under `bin/data`.
    pub const setupShaderFromFile_sig: Signature = .{
        .name = "setupShaderFromFile",
        .this = *Shader,
        .args = &.{ u32, Ref(*const Path) },
        .ret = bool,
    };
    pub fn setupShaderFromFile(self: *Shader, stage: Stage, file: []const u8) bool {
        var path = Path.init(file) orelse return false;
        defer path.deinit();
        return cpp.bind(setupShaderFromFile_sig)(self, @backingInt(stage), &path);
    }
    /// Links the stages compiled so far into the program. Reports whether
    /// it linked.
    pub const linkProgram_sig: Signature = .{ .name = "linkProgram", .this = *Shader, .ret = bool };
    pub fn linkProgram(self: *Shader) bool {
        return cpp.bind(linkProgram_sig)(self);
    }
    /// Binds oF's default attribute locations (`position`, `color`,
    /// `normal`, `texcoord`) to the program, for a GLSL 1.50+ shader under
    /// the programmable renderer. Call it before `linkProgram`; `load` and
    /// the setups through `ofShaderSettings` do it themselves.
    pub const bindDefaults_sig: Signature = .{ .name = "bindDefaults", .this = *Shader, .ret = bool };
    pub fn bindDefaults(self: *Shader) bool {
        return cpp.bind(bindDefaults_sig)(self);
    }
    /// Deletes the program and its stages; the shader can be loaded again.
    pub const unload_sig: Signature = .{ .name = "unload", .this = *Shader };
    pub fn unload(self: *Shader) void {
        cpp.bind(unload_sig)(self);
    }
    /// Whether a program is linked.
    pub const isLoaded_sig: Signature = .{ .name = "isLoaded", .this = *const Shader, .ret = bool };
    pub fn isLoaded(self: *const Shader) bool {
        return cpp.bind(isLoaded_sig)(self);
    }

    // geometry stage: set these before `linkProgram`

    pub const setGeometryInputType_sig: Signature = .{ .name = "setGeometryInputType", .this = *Shader, .args = &.{u32} };
    pub fn setGeometryInputType(self: *Shader, kind: GeometryPrimitive) void {
        cpp.bind(setGeometryInputType_sig)(self, @backingInt(kind));
    }
    pub const setGeometryOutputType_sig: Signature = .{ .name = "setGeometryOutputType", .this = *Shader, .args = &.{u32} };
    pub fn setGeometryOutputType(self: *Shader, kind: GeometryPrimitive) void {
        cpp.bind(setGeometryOutputType_sig)(self, @backingInt(kind));
    }
    /// The most vertices one invocation of the geometry stage emits.
    pub const setGeometryOutputCount_sig: Signature = .{ .name = "setGeometryOutputCount", .this = *Shader, .args = &.{i32} };
    pub fn setGeometryOutputCount(self: *Shader, count: u32) void {
        cpp.bind(setGeometryOutputCount_sig)(self, @bitCast(count));
    }
    /// The driver's limit on `setGeometryOutputCount`.
    pub const getGeometryMaxOutputCount_sig: Signature = .{ .name = "getGeometryMaxOutputCount", .this = *const Shader, .ret = i32 };
    pub fn getGeometryMaxOutputCount(self: *const Shader) u32 {
        return @bitCast(cpp.bind(getGeometryMaxOutputCount_sig)(self));
    }

    // use

    /// Makes the program current: everything drawn until `end` goes through
    /// it.
    pub const begin_sig: Signature = .{ .name = "begin", .this = *const Shader };
    pub fn begin(self: *const Shader) void {
        cpp.bind(begin_sig)(self);
    }
    pub const end_sig: Signature = .{ .name = "end", .this = *const Shader };
    pub fn end(self: *const Shader) void {
        cpp.bind(end_sig)(self);
    }

    // uniforms. Each name becomes a `std::string` for the call; oF caches
    // the location it looks up under that name.

    const Name = Ref(*const String);

    pub const setUniform1i_sig: Signature = .{ .name = "setUniform1i", .this = *const Shader, .args = &.{ Name, i32 } };
    pub fn setUniform1i(self: *const Shader, name: []const u8, v: i32) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform1i_sig)(self, &s, v);
    }
    pub const setUniform2i_sig: Signature = .{ .name = "setUniform2i", .this = *const Shader, .args = &.{ Name, i32, i32 } };
    pub fn setUniform2i(self: *const Shader, name: []const u8, v: Vec2I) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform2i_sig)(self, &s, v[0], v[1]);
    }
    pub const setUniform3i_sig: Signature = .{ .name = "setUniform3i", .this = *const Shader, .args = &.{ Name, i32, i32, i32 } };
    pub fn setUniform3i(self: *const Shader, name: []const u8, v: Vec3I) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform3i_sig)(self, &s, v[0], v[1], v[2]);
    }
    pub const setUniform4i_sig: Signature = .{ .name = "setUniform4i", .this = *const Shader, .args = &.{ Name, i32, i32, i32, i32 } };
    pub fn setUniform4i(self: *const Shader, name: []const u8, v: Vec4I) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform4i_sig)(self, &s, v[0], v[1], v[2], v[3]);
    }

    pub const setUniform1f_sig: Signature = .{ .name = "setUniform1f", .this = *const Shader, .args = &.{ Name, f32 } };
    pub fn setUniform1f(self: *const Shader, name: []const u8, v: f32) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform1f_sig)(self, &s, v);
    }
    /// `setUniform2f(const std::string&, const glm::vec2&)`.
    pub const setUniform2f_sig: Signature = .{ .name = "setUniform2f", .this = *const Shader, .args = &.{ Name, Ref(*const GlmVec2) } };
    pub fn setUniform2f(self: *const Shader, name: []const u8, v: Vec2) void {
        var s = String.init(name);
        defer s.deinit();
        const g: GlmVec2 = .from(v);
        cpp.bind(setUniform2f_sig)(self, &s, &g);
    }
    pub const setUniform3f_sig: Signature = .{ .name = "setUniform3f", .this = *const Shader, .args = &.{ Name, Ref(*const GlmVec3) } };
    pub fn setUniform3f(self: *const Shader, name: []const u8, v: Vec3) void {
        var s = String.init(name);
        defer s.deinit();
        const g: GlmVec3 = .from(v);
        cpp.bind(setUniform3f_sig)(self, &s, &g);
    }
    pub const setUniform4f_sig: Signature = .{ .name = "setUniform4f", .this = *const Shader, .args = &.{ Name, Ref(*const GlmVec4) } };
    pub fn setUniform4f(self: *const Shader, name: []const u8, v: Vec4) void {
        var s = String.init(name);
        defer s.deinit();
        const g: GlmVec4 = .from(v);
        cpp.bind(setUniform4f_sig)(self, &s, &g);
    }
    /// `setUniform4f(const std::string&, const ofFloatColor&)`: a `vec4`
    /// of `r`, `g`, `b`, `a`.
    pub const setUniform4f_color_sig: Signature = .{ .name = "setUniform4f", .this = *const Shader, .args = &.{ Name, Ref(*const FloatColor) } };
    pub fn setUniformColor(self: *const Shader, name: []const u8, c: FloatColor) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform4f_color_sig)(self, &s, &c);
    }

    // uniform arrays: `uniform float x[n]` and the like. The slice's length
    // is the element count oF passes on.

    pub const setUniform1iv_sig: Signature = .{ .name = "setUniform1iv", .this = *const Shader, .args = &.{ Name, [*]const i32, i32 } };
    pub fn setUniform1iv(self: *const Shader, name: []const u8, v: []const i32) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform1iv_sig)(self, &s, v.ptr, @intCast(v.len));
    }
    pub const setUniform1fv_sig: Signature = .{ .name = "setUniform1fv", .this = *const Shader, .args = &.{ Name, [*]const f32, i32 } };
    pub fn setUniform1fv(self: *const Shader, name: []const u8, v: []const f32) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform1fv_sig)(self, &s, v.ptr, @intCast(v.len));
    }
    pub const setUniform2fv_sig: Signature = .{ .name = "setUniform2fv", .this = *const Shader, .args = &.{ Name, [*]const f32, i32 } };
    pub fn setUniform2fv(self: *const Shader, name: []const u8, v: []const GlmVec2) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform2fv_sig)(self, &s, @ptrCast(v.ptr), @intCast(v.len));
    }
    pub const setUniform3fv_sig: Signature = .{ .name = "setUniform3fv", .this = *const Shader, .args = &.{ Name, [*]const f32, i32 } };
    pub fn setUniform3fv(self: *const Shader, name: []const u8, v: []const GlmVec3) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform3fv_sig)(self, &s, @ptrCast(v.ptr), @intCast(v.len));
    }
    pub const setUniform4fv_sig: Signature = .{ .name = "setUniform4fv", .this = *const Shader, .args = &.{ Name, [*]const f32, i32 } };
    pub fn setUniform4fv(self: *const Shader, name: []const u8, v: []const GlmVec4) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniform4fv_sig)(self, &s, @ptrCast(v.ptr), @intCast(v.len));
    }

    // matrices. glm's storage is GL's, column-major, so they go up as is.

    pub const setUniformMatrix3f_sig: Signature = .{ .name = "setUniformMatrix3f", .this = *const Shader, .args = &.{ Name, Ref(*const Mat3), i32 } };
    pub fn setUniformMatrix3f(self: *const Shader, name: []const u8, m: Mat3) void {
        self.setUniformMatrix3fv(name, &.{m});
    }
    /// A `mat3` array: `ms[0]` is element 0.
    pub fn setUniformMatrix3fv(self: *const Shader, name: []const u8, ms: []const Mat3) void {
        if (ms.len == 0) return;
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniformMatrix3f_sig)(self, &s, &ms[0], @intCast(ms.len));
    }
    pub const setUniformMatrix4f_sig: Signature = .{ .name = "setUniformMatrix4f", .this = *const Shader, .args = &.{ Name, Ref(*const Mat4), i32 } };
    pub fn setUniformMatrix4f(self: *const Shader, name: []const u8, m: Mat4) void {
        self.setUniformMatrix4fv(name, &.{m});
    }
    /// A `mat4` array: `ms[0]` is element 0.
    pub fn setUniformMatrix4fv(self: *const Shader, name: []const u8, ms: []const Mat4) void {
        if (ms.len == 0) return;
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setUniformMatrix4f_sig)(self, &s, &ms[0], @intCast(ms.len));
    }

    /// The location of a uniform in the linked program, or `-1` when it
    /// has none.
    pub const getUniformLocation_sig: Signature = .{ .name = "getUniformLocation", .this = *const Shader, .args = &.{Name}, .ret = i32 };
    pub fn getUniformLocation(self: *const Shader, name: []const u8) i32 {
        var s = String.init(name);
        defer s.deinit();
        return cpp.bind(getUniformLocation_sig)(self, &s);
    }

    // attributes: per-vertex inputs. A constant attribute value applies to
    // every vertex of a draw that does not supply that attribute itself.

    /// The location of an attribute in the linked program, or `-1` when it
    /// has none.
    pub const getAttributeLocation_sig: Signature = .{ .name = "getAttributeLocation", .this = *const Shader, .args = &.{Name}, .ret = i32 };
    pub fn getAttributeLocation(self: *const Shader, name: []const u8) i32 {
        var s = String.init(name);
        defer s.deinit();
        return cpp.bind(getAttributeLocation_sig)(self, &s);
    }
    /// Gives the attribute `name` the location `location`. Call it before
    /// `linkProgram`.
    pub const bindAttribute_sig: Signature = .{ .name = "bindAttribute", .this = *const Shader, .args = &.{ u32, Name } };
    pub fn bindAttribute(self: *const Shader, location: u32, name: []const u8) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(bindAttribute_sig)(self, location, &s);
    }
    pub const setAttribute1f_sig: Signature = .{ .name = "setAttribute1f", .this = *const Shader, .args = &.{ i32, f32 } };
    pub fn setAttribute1f(self: *const Shader, location: i32, v: f32) void {
        cpp.bind(setAttribute1f_sig)(self, location, v);
    }
    pub const setAttribute2f_sig: Signature = .{ .name = "setAttribute2f", .this = *const Shader, .args = &.{ i32, f32, f32 } };
    pub fn setAttribute2f(self: *const Shader, location: i32, v: Vec2) void {
        cpp.bind(setAttribute2f_sig)(self, location, v[0], v[1]);
    }
    pub const setAttribute3f_sig: Signature = .{ .name = "setAttribute3f", .this = *const Shader, .args = &.{ i32, f32, f32, f32 } };
    pub fn setAttribute3f(self: *const Shader, location: i32, v: Vec3) void {
        cpp.bind(setAttribute3f_sig)(self, location, v[0], v[1], v[2]);
    }
    pub const setAttribute4f_sig: Signature = .{ .name = "setAttribute4f", .this = *const Shader, .args = &.{ i32, f32, f32, f32, f32 } };
    pub fn setAttribute4f(self: *const Shader, location: i32, v: Vec4) void {
        cpp.bind(setAttribute4f_sig)(self, location, v[0], v[1], v[2], v[3]);
    }

    // introspection

    /// The GL name of the linked program, for raw GL calls; `0` before a
    /// link.
    pub const getProgram_sig: Signature = .{ .name = "getProgram", .this = *const Shader, .ret = u32 };
    pub fn getProgram(self: *const Shader) u32 {
        return cpp.bind(getProgram_sig)(self);
    }
    /// The GL name of one compiled stage, or `0` when there is none.
    pub const getShader_sig: Signature = .{ .name = "getShader", .this = *const Shader, .args = &.{u32}, .ret = u32 };
    pub fn getShader(self: *const Shader, stage: Stage) u32 {
        return cpp.bind(getShader_sig)(self, @backingInt(stage));
    }
    /// The source of one stage as the GLSL compiler saw it, with oF's
    /// `#pragma include`s and defines expanded. The caller owns the
    /// returned string: `deinit` it.
    pub const getShaderSource_sig: Signature = .{ .name = "getShaderSource", .this = *const Shader, .args = &.{u32}, .ret = String };
    pub fn getShaderSource(self: *const Shader, stage: Stage) String {
        var out: String = undefined;
        cpp.bind(getShaderSource_sig)(&out, self, @backingInt(stage));
        return out;
    }
    /// Lists the program's active uniforms through `ofLogNotice`.
    pub const printActiveUniforms_sig: Signature = .{ .name = "printActiveUniforms", .this = *const Shader };
    pub fn printActiveUniforms(self: *const Shader) void {
        cpp.bind(printActiveUniforms_sig)(self);
    }
    /// Lists the program's active attributes through `ofLogNotice`.
    pub const printActiveAttributes_sig: Signature = .{ .name = "printActiveAttributes", .this = *const Shader };
    pub fn printActiveAttributes(self: *const Shader) void {
        cpp.bind(printActiveAttributes_sig)(self);
    }
};
