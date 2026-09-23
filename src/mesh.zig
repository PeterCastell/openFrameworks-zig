//! ofMesh.h: a mesh -- vertices, normals, colors, texture coordinates and
//! indices -- that the renderer draws, and that every 3D primitive holds.
//!
//! ```zig
//! var mesh: of.Mesh = undefined;   // a field of the app struct
//! mesh.init();                     // in setup; deinit in exit
//! mesh.setMode(.triangle_fan);
//! mesh.addVertices(&.{ .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 50, .y = 0, .z = 0 }, .{ .x = 0, .y = 50, .z = 0 } });
//! mesh.addColor(.{ .r = 1, .g = 0.5, .b = 0 });
//!
//! mesh.draw();                     // in draw, inside a camera
//! for (mesh.getVertices()) |*v| v.y += 1;   // the real vertex array, in place
//! ```
//!
//! **The bulk calls take slices of the ABI types**, `GlmVec3`, `GlmVec2`
//! and `FloatColor`, not of `Vec3`. A `Vec3` is a `@Vector(3, f32)`, which
//! is 16 bytes, and `glm::vec3` is 12, so an array of one cannot be handed
//! to C++ as an array of the other. `addVertices` binds oF's
//! `addVertices(const V*, size_t)` overload, so a slice goes straight
//! through with no copy and no `std::vector` on either side. The
//! one-at-a-time calls (`addVertex`, `getVertex`, `setVertex`) take and
//! return `Vec3`, since a single conversion is free.
//!
//! `getVertices` and its siblings return the mesh's own arrays as slices,
//! read off the `std::vector`'s three pointers. A slice is valid until the
//! next call that can grow that array. Writing through it is what oF's
//! non-const `getVertices()` is for; it also marks the mesh changed, so a
//! VBO-backed primitive re-uploads.
//!
//! `ofMesh` is a class template, `ofMesh_<glm::vec3, glm::vec3,
//! ofFloatColor, glm::vec2>`, so every method is header-only and the glue
//! forces each one this file names. Angles are radians: `smoothNormals`
//! converts to the degrees oF wants.
const std = @import("std");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const color = @import("color.zig");
const string = @import("string.zig");
const primitives = @import("primitives.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const GlmVec2 = math.GlmVec2;
const GlmVec3 = math.GlmVec3;
const FloatColor = color.FloatColor;
const Path = string.Path;
const PrimitiveMode = primitives.PrimitiveMode;
const PolyRenderMode = primitives.PolyRenderMode;

/// `cpp.bind` with a larger comptime budget. `ofMesh_` carries four
/// template arguments and returns `std::vector`s of them, so a mangled
/// name here is a few hundred characters, past what the default quota of
/// a thousand branches computes.
inline fn bind(comptime sig: Signature) Bound(sig) {
    @setEvalBranchQuota(1 << 16);
    return cpp.bind(sig);
}
/// The bound function's type, computed under the same budget: a return
/// type is evaluated outside the function body, where the quota above does
/// not reach.
fn Bound(comptime sig: Signature) type {
    @setEvalBranchQuota(1 << 16);
    return *const cpp.FnType(cpp.default_mangling, sig);
}

/// `std::vector<T>` as the MSVC release STL lays it out: begin, end, and
/// the end of the allocation. Zig never builds one and never frees one; it
/// reads the first two pointers off a vector the mesh owns, which is what
/// `Mesh.getVertices` hands back as a slice.
pub fn Vector(comptime T: type) type {
    return extern struct {
        _first: ?[*]T,
        _last: ?[*]T,
        _end: ?[*]T,

        pub const cpp_template: cpp.Template = .{
            .name = "std::vector",
            .args = &.{
                .{ .type = T },
                .{ .template = .{ .name = "std::allocator", .args = &.{.{ .type = T }}, .kind = .class } },
            },
            .kind = .class,
        };
        pub const cpp_abi: cpp.ClassAbi = .managed_copy;
        /// The layout is all Zig needs; no member is called, so nothing is
        /// instantiated.
        pub const cpp_no_instantiate = true;
        pub const cpp_no_offsets = true;

        pub fn items(self: *@This()) []T {
            const first = self._first orelse return &.{};
            return first[0 .. self._last.? - first];
        }
        pub fn constItems(self: *const @This()) []const T {
            const first = self._first orelse return &.{};
            return first[0 .. self._last.? - first];
        }
    };
}

pub const Vec3Vector = Vector(GlmVec3);
pub const Vec2Vector = Vector(GlmVec2);
pub const FloatColorVector = Vector(FloatColor);
pub const IndexVector = Vector(u32);

/// `ofMesh`, which is `ofMesh_<glm::vec3, glm::vec3, ofFloatColor, glm::vec2>`.
///
/// Six `std::vector`s behind a vtable pointer; the binding gives the storage
/// and reaches the arrays through the getters. The class has no pointer to
/// itself, but it owns heap, so as with every class here: construct it
/// where it will live, and `deinit` it.
pub const Mesh = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [160]u8 align(8),

    pub const cpp_template: cpp.Template = .{
        .name = "ofMesh_",
        .args = &.{ .{ .type = GlmVec3 }, .{ .type = GlmVec3 }, .{ .type = FloatColor }, .{ .type = GlmVec2 } },
        .kind = .class,
    };
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Mesh };
    /// Runs `ofMesh()` on the storage of `self`: empty, in `.triangles` mode,
    /// with colors, normals, textures and indices all enabled.
    pub fn init(self: *Mesh) void {
        bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Mesh };
    pub fn deinit(self: *Mesh) void {
        bind(dtor_sig)(self);
    }

    pub const setMode_sig: Signature = .{ .name = "setMode", .this = *Mesh, .args = &.{PrimitiveMode} };
    pub fn setMode(self: *Mesh, mode: PrimitiveMode) void {
        bind(setMode_sig)(self, mode);
    }
    pub const getMode_sig: Signature = .{ .name = "getMode", .this = *const Mesh, .ret = PrimitiveMode };
    pub fn getMode(self: *const Mesh) PrimitiveMode {
        return bind(getMode_sig)(self);
    }

    // shapes: each of oF's static factories, run into `self`'s storage,
    // which must be uninitialized -- they construct, not assign

    /// `ofMesh::plane(width, height, columns, rows, mode)`, constructed into
    /// `self`. Takes the place of `init`.
    pub const plane_sig: Signature = .{ .name = "plane", .class = Mesh, .args = &.{ f32, f32, i32, i32, PrimitiveMode }, .ret = Mesh };
    pub fn initPlane(self: *Mesh, width: f32, height: f32, columns: u32, rows: u32, mode: PrimitiveMode) void {
        bind(plane_sig)(self, width, height, @bitCast(columns), @bitCast(rows), mode);
    }
    /// `ofMesh::sphere(radius, resolution, mode)`
    pub const sphere_sig: Signature = .{ .name = "sphere", .class = Mesh, .args = &.{ f32, i32, PrimitiveMode }, .ret = Mesh };
    pub fn initSphere(self: *Mesh, radius: f32, resolution: u32, mode: PrimitiveMode) void {
        bind(sphere_sig)(self, radius, @bitCast(resolution), mode);
    }
    /// `ofMesh::icosahedron(radius)`
    pub const icosahedron_sig: Signature = .{ .name = "icosahedron", .class = Mesh, .args = &.{f32}, .ret = Mesh };
    pub fn initIcosahedron(self: *Mesh, radius: f32) void {
        bind(icosahedron_sig)(self, radius);
    }
    /// `ofMesh::icosphere(radius, iterations)`
    pub const icosphere_sig: Signature = .{ .name = "icosphere", .class = Mesh, .args = &.{ f32, usize }, .ret = Mesh };
    pub fn initIcosphere(self: *Mesh, radius: f32, iterations: u32) void {
        bind(icosphere_sig)(self, radius, iterations);
    }
    /// `ofMesh::cylinder(radius, height, radiusSegments, heightSegments, capSegments, capped, mode)`
    pub const cylinder_sig: Signature = .{ .name = "cylinder", .class = Mesh, .args = &.{ f32, f32, i32, i32, i32, bool, PrimitiveMode }, .ret = Mesh };
    pub fn initCylinder(self: *Mesh, radius: f32, height: f32, radius_segments: u32, height_segments: u32, cap_segments: u32, capped: bool, mode: PrimitiveMode) void {
        bind(cylinder_sig)(self, radius, height, @bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments), capped, mode);
    }
    /// `ofMesh::cone(radius, height, radiusSegments, heightSegments, capSegments, mode)`
    pub const cone_sig: Signature = .{ .name = "cone", .class = Mesh, .args = &.{ f32, f32, i32, i32, i32, PrimitiveMode }, .ret = Mesh };
    pub fn initCone(self: *Mesh, radius: f32, height: f32, radius_segments: u32, height_segments: u32, cap_segments: u32, mode: PrimitiveMode) void {
        bind(cone_sig)(self, radius, height, @bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments), mode);
    }
    /// `ofMesh::box(width, height, depth, resX, resY, resZ)`
    pub const box_sig: Signature = .{ .name = "box", .class = Mesh, .args = &.{ f32, f32, f32, i32, i32, i32 }, .ret = Mesh };
    pub fn initBox(self: *Mesh, width: f32, height: f32, depth: f32, res_x: u32, res_y: u32, res_z: u32) void {
        bind(box_sig)(self, width, height, depth, @bitCast(res_x), @bitCast(res_y), @bitCast(res_z));
    }
    /// `ofMesh::axis(size)`: three colored lines along x, y and z.
    pub const axis_sig: Signature = .{ .name = "axis", .class = Mesh, .args = &.{f32}, .ret = Mesh };
    pub fn initAxis(self: *Mesh, size: f32) void {
        bind(axis_sig)(self, size);
    }

    // vertices

    pub const addVertex_sig: Signature = .{ .name = "addVertex", .this = *Mesh, .args = &.{Ref(*const GlmVec3)} };
    pub fn addVertex(self: *Mesh, v: Vec3) void {
        const g: GlmVec3 = .from(v);
        bind(addVertex_sig)(self, &g);
    }
    /// `addVertices(const glm::vec3*, size_t)`: appends the slice as it is.
    pub const addVertices_sig: Signature = .{ .name = "addVertices", .this = *Mesh, .args = &.{ [*]const GlmVec3, usize } };
    pub fn addVertices(self: *Mesh, verts: []const GlmVec3) void {
        bind(addVertices_sig)(self, verts.ptr, verts.len);
    }
    pub const removeVertex_sig: Signature = .{ .name = "removeVertex", .this = *Mesh, .args = &.{u32} };
    pub fn removeVertex(self: *Mesh, index: u32) void {
        bind(removeVertex_sig)(self, index);
    }
    /// Removes `start` up to and including `end`, as oF does.
    pub const removeVertices_sig: Signature = .{ .name = "removeVertices", .this = *Mesh, .args = &.{ u32, u32 } };
    pub fn removeVertices(self: *Mesh, start: u32, end: u32) void {
        bind(removeVertices_sig)(self, start, end);
    }
    pub const setVertex_sig: Signature = .{ .name = "setVertex", .this = *Mesh, .args = &.{ u32, Ref(*const GlmVec3) } };
    pub fn setVertex(self: *Mesh, index: u32, v: Vec3) void {
        const g: GlmVec3 = .from(v);
        bind(setVertex_sig)(self, index, &g);
    }
    pub const clearVertices_sig: Signature = .{ .name = "clearVertices", .this = *Mesh };
    pub fn clearVertices(self: *Mesh) void {
        bind(clearVertices_sig)(self);
    }
    /// Empties every array.
    pub const clear_sig: Signature = .{ .name = "clear", .this = *Mesh };
    pub fn clear(self: *Mesh) void {
        bind(clear_sig)(self);
    }
    pub const getNumVertices_sig: Signature = .{ .name = "getNumVertices", .this = *const Mesh, .ret = usize };
    pub fn getNumVertices(self: *const Mesh) usize {
        return bind(getNumVertices_sig)(self);
    }
    pub const getVertex_sig: Signature = .{ .name = "getVertex", .this = *const Mesh, .args = &.{u32}, .ret = GlmVec3 };
    pub fn getVertex(self: *const Mesh, index: u32) Vec3 {
        return bind(getVertex_sig)(self, index).to();
    }
    /// The vertex array itself, writable. Marks the mesh changed.
    pub const getVertices_sig: Signature = .{ .name = "getVertices", .this = *Mesh, .ret = Ref(*Vec3Vector) };
    pub fn getVertices(self: *Mesh) []GlmVec3 {
        return bind(getVertices_sig)(self).items();
    }
    pub const getVertices_const_sig: Signature = .{ .name = "getVertices", .this = *const Mesh, .ret = Ref(*const Vec3Vector) };
    pub fn getVerticesConst(self: *const Mesh) []const GlmVec3 {
        return bind(getVertices_const_sig)(self).constItems();
    }
    pub const hasVertices_sig: Signature = .{ .name = "hasVertices", .this = *const Mesh, .ret = bool };
    pub fn hasVertices(self: *const Mesh) bool {
        return bind(hasVertices_sig)(self);
    }
    /// Appends every array of `other`, with its indices offset to follow.
    pub const append_sig: Signature = .{ .name = "append", .this = *Mesh, .args = &.{Ref(*const Mesh)} };
    pub fn append(self: *Mesh, other: *const Mesh) void {
        bind(append_sig)(self, other);
    }
    /// Welds vertices at the same position and rewrites the indices.
    pub const mergeDuplicateVertices_sig: Signature = .{ .name = "mergeDuplicateVertices", .this = *Mesh };
    pub fn mergeDuplicateVertices(self: *Mesh) void {
        bind(mergeDuplicateVertices_sig)(self);
    }
    /// The mean of the vertices.
    pub const getCentroid_sig: Signature = .{ .name = "getCentroid", .this = *const Mesh, .ret = GlmVec3 };
    pub fn getCentroid(self: *const Mesh) Vec3 {
        return bind(getCentroid_sig)(self).to();
    }

    // normals

    pub const getNormal_sig: Signature = .{ .name = "getNormal", .this = *const Mesh, .args = &.{u32}, .ret = GlmVec3 };
    pub fn getNormal(self: *const Mesh, index: u32) Vec3 {
        return bind(getNormal_sig)(self, index).to();
    }
    pub const addNormal_sig: Signature = .{ .name = "addNormal", .this = *Mesh, .args = &.{Ref(*const GlmVec3)} };
    pub fn addNormal(self: *Mesh, n: Vec3) void {
        const g: GlmVec3 = .from(n);
        bind(addNormal_sig)(self, &g);
    }
    pub const addNormals_sig: Signature = .{ .name = "addNormals", .this = *Mesh, .args = &.{ [*]const GlmVec3, usize } };
    pub fn addNormals(self: *Mesh, normals: []const GlmVec3) void {
        bind(addNormals_sig)(self, normals.ptr, normals.len);
    }
    pub const removeNormal_sig: Signature = .{ .name = "removeNormal", .this = *Mesh, .args = &.{u32} };
    pub fn removeNormal(self: *Mesh, index: u32) void {
        bind(removeNormal_sig)(self, index);
    }
    pub const removeNormals_sig: Signature = .{ .name = "removeNormals", .this = *Mesh, .args = &.{ u32, u32 } };
    pub fn removeNormals(self: *Mesh, start: u32, end: u32) void {
        bind(removeNormals_sig)(self, start, end);
    }
    pub const setNormal_sig: Signature = .{ .name = "setNormal", .this = *Mesh, .args = &.{ u32, Ref(*const GlmVec3) } };
    pub fn setNormal(self: *Mesh, index: u32, n: Vec3) void {
        const g: GlmVec3 = .from(n);
        bind(setNormal_sig)(self, index, &g);
    }
    pub const clearNormals_sig: Signature = .{ .name = "clearNormals", .this = *Mesh };
    pub fn clearNormals(self: *Mesh) void {
        bind(clearNormals_sig)(self);
    }
    pub const getNumNormals_sig: Signature = .{ .name = "getNumNormals", .this = *const Mesh, .ret = usize };
    pub fn getNumNormals(self: *const Mesh) usize {
        return bind(getNumNormals_sig)(self);
    }
    pub const getNormals_sig: Signature = .{ .name = "getNormals", .this = *Mesh, .ret = Ref(*Vec3Vector) };
    pub fn getNormals(self: *Mesh) []GlmVec3 {
        return bind(getNormals_sig)(self).items();
    }
    pub const getNormals_const_sig: Signature = .{ .name = "getNormals", .this = *const Mesh, .ret = Ref(*const Vec3Vector) };
    pub fn getNormalsConst(self: *const Mesh) []const GlmVec3 {
        return bind(getNormals_const_sig)(self).constItems();
    }
    pub const hasNormals_sig: Signature = .{ .name = "hasNormals", .this = *const Mesh, .ret = bool };
    pub fn hasNormals(self: *const Mesh) bool {
        return bind(hasNormals_sig)(self);
    }
    pub const enableNormals_sig: Signature = .{ .name = "enableNormals", .this = *Mesh, .virtual = true };
    pub fn enableNormals(self: *Mesh) void {
        bind(enableNormals_sig)(self);
    }
    pub const disableNormals_sig: Signature = .{ .name = "disableNormals", .this = *Mesh, .virtual = true };
    pub fn disableNormals(self: *Mesh) void {
        bind(disableNormals_sig)(self);
    }
    pub const usingNormals_sig: Signature = .{ .name = "usingNormals", .this = *const Mesh, .ret = bool, .virtual = true };
    pub fn usingNormals(self: *const Mesh) bool {
        return bind(usingNormals_sig)(self);
    }
    /// `smoothNormals(degrees)`, taking radians: recomputes the normals,
    /// averaging across faces that meet at less than `angle`.
    pub const smoothNormals_sig: Signature = .{ .name = "smoothNormals", .this = *Mesh, .args = &.{f32} };
    pub fn smoothNormals(self: *Mesh, angle: f32) void {
        bind(smoothNormals_sig)(self, std.math.radiansToDegrees(angle));
    }
    /// One normal per face, duplicating shared vertices to do it.
    pub const flatNormals_sig: Signature = .{ .name = "flatNormals", .this = *Mesh };
    pub fn flatNormals(self: *Mesh) void {
        bind(flatNormals_sig)(self);
    }

    // colors

    pub const getColor_sig: Signature = .{ .name = "getColor", .this = *const Mesh, .args = &.{u32}, .ret = FloatColor };
    pub fn getColor(self: *const Mesh, index: u32) FloatColor {
        return bind(getColor_sig)(self, index);
    }
    pub const addColor_sig: Signature = .{ .name = "addColor", .this = *Mesh, .args = &.{Ref(*const FloatColor)} };
    pub fn addColor(self: *Mesh, c: FloatColor) void {
        bind(addColor_sig)(self, &c);
    }
    pub const addColors_sig: Signature = .{ .name = "addColors", .this = *Mesh, .args = &.{ [*]const FloatColor, usize } };
    pub fn addColors(self: *Mesh, colors: []const FloatColor) void {
        bind(addColors_sig)(self, colors.ptr, colors.len);
    }
    pub const removeColor_sig: Signature = .{ .name = "removeColor", .this = *Mesh, .args = &.{u32} };
    pub fn removeColor(self: *Mesh, index: u32) void {
        bind(removeColor_sig)(self, index);
    }
    pub const removeColors_sig: Signature = .{ .name = "removeColors", .this = *Mesh, .args = &.{ u32, u32 } };
    pub fn removeColors(self: *Mesh, start: u32, end: u32) void {
        bind(removeColors_sig)(self, start, end);
    }
    pub const setColor_sig: Signature = .{ .name = "setColor", .this = *Mesh, .args = &.{ u32, Ref(*const FloatColor) } };
    pub fn setColor(self: *Mesh, index: u32, c: FloatColor) void {
        bind(setColor_sig)(self, index, &c);
    }
    pub const clearColors_sig: Signature = .{ .name = "clearColors", .this = *Mesh };
    pub fn clearColors(self: *Mesh) void {
        bind(clearColors_sig)(self);
    }
    pub const getNumColors_sig: Signature = .{ .name = "getNumColors", .this = *const Mesh, .ret = usize };
    pub fn getNumColors(self: *const Mesh) usize {
        return bind(getNumColors_sig)(self);
    }
    pub const getColors_sig: Signature = .{ .name = "getColors", .this = *Mesh, .ret = Ref(*FloatColorVector) };
    pub fn getColors(self: *Mesh) []FloatColor {
        return bind(getColors_sig)(self).items();
    }
    pub const getColors_const_sig: Signature = .{ .name = "getColors", .this = *const Mesh, .ret = Ref(*const FloatColorVector) };
    pub fn getColorsConst(self: *const Mesh) []const FloatColor {
        return bind(getColors_const_sig)(self).constItems();
    }
    pub const hasColors_sig: Signature = .{ .name = "hasColors", .this = *const Mesh, .ret = bool };
    pub fn hasColors(self: *const Mesh) bool {
        return bind(hasColors_sig)(self);
    }
    pub const enableColors_sig: Signature = .{ .name = "enableColors", .this = *Mesh, .virtual = true };
    pub fn enableColors(self: *Mesh) void {
        bind(enableColors_sig)(self);
    }
    pub const disableColors_sig: Signature = .{ .name = "disableColors", .this = *Mesh, .virtual = true };
    pub fn disableColors(self: *Mesh) void {
        bind(disableColors_sig)(self);
    }
    pub const usingColors_sig: Signature = .{ .name = "usingColors", .this = *const Mesh, .ret = bool, .virtual = true };
    pub fn usingColors(self: *const Mesh) bool {
        return bind(usingColors_sig)(self);
    }

    // texture coordinates

    pub const getTexCoord_sig: Signature = .{ .name = "getTexCoord", .this = *const Mesh, .args = &.{u32}, .ret = GlmVec2 };
    pub fn getTexCoord(self: *const Mesh, index: u32) Vec2 {
        return bind(getTexCoord_sig)(self, index).to();
    }
    pub const addTexCoord_sig: Signature = .{ .name = "addTexCoord", .this = *Mesh, .args = &.{Ref(*const GlmVec2)} };
    pub fn addTexCoord(self: *Mesh, t: Vec2) void {
        const g: GlmVec2 = .from(t);
        bind(addTexCoord_sig)(self, &g);
    }
    pub const addTexCoords_sig: Signature = .{ .name = "addTexCoords", .this = *Mesh, .args = &.{ [*]const GlmVec2, usize } };
    pub fn addTexCoords(self: *Mesh, coords: []const GlmVec2) void {
        bind(addTexCoords_sig)(self, coords.ptr, coords.len);
    }
    pub const removeTexCoord_sig: Signature = .{ .name = "removeTexCoord", .this = *Mesh, .args = &.{u32} };
    pub fn removeTexCoord(self: *Mesh, index: u32) void {
        bind(removeTexCoord_sig)(self, index);
    }
    pub const removeTexCoords_sig: Signature = .{ .name = "removeTexCoords", .this = *Mesh, .args = &.{ u32, u32 } };
    pub fn removeTexCoords(self: *Mesh, start: u32, end: u32) void {
        bind(removeTexCoords_sig)(self, start, end);
    }
    pub const setTexCoord_sig: Signature = .{ .name = "setTexCoord", .this = *Mesh, .args = &.{ u32, Ref(*const GlmVec2) } };
    pub fn setTexCoord(self: *Mesh, index: u32, t: Vec2) void {
        const g: GlmVec2 = .from(t);
        bind(setTexCoord_sig)(self, index, &g);
    }
    pub const clearTexCoords_sig: Signature = .{ .name = "clearTexCoords", .this = *Mesh };
    pub fn clearTexCoords(self: *Mesh) void {
        bind(clearTexCoords_sig)(self);
    }
    pub const getNumTexCoords_sig: Signature = .{ .name = "getNumTexCoords", .this = *const Mesh, .ret = usize };
    pub fn getNumTexCoords(self: *const Mesh) usize {
        return bind(getNumTexCoords_sig)(self);
    }
    pub const getTexCoords_sig: Signature = .{ .name = "getTexCoords", .this = *Mesh, .ret = Ref(*Vec2Vector) };
    pub fn getTexCoords(self: *Mesh) []GlmVec2 {
        return bind(getTexCoords_sig)(self).items();
    }
    pub const getTexCoords_const_sig: Signature = .{ .name = "getTexCoords", .this = *const Mesh, .ret = Ref(*const Vec2Vector) };
    pub fn getTexCoordsConst(self: *const Mesh) []const GlmVec2 {
        return bind(getTexCoords_const_sig)(self).constItems();
    }
    pub const hasTexCoords_sig: Signature = .{ .name = "hasTexCoords", .this = *const Mesh, .ret = bool };
    pub fn hasTexCoords(self: *const Mesh) bool {
        return bind(hasTexCoords_sig)(self);
    }
    pub const enableTextures_sig: Signature = .{ .name = "enableTextures", .this = *Mesh, .virtual = true };
    pub fn enableTextures(self: *Mesh) void {
        bind(enableTextures_sig)(self);
    }
    pub const disableTextures_sig: Signature = .{ .name = "disableTextures", .this = *Mesh, .virtual = true };
    pub fn disableTextures(self: *Mesh) void {
        bind(disableTextures_sig)(self);
    }
    pub const usingTextures_sig: Signature = .{ .name = "usingTextures", .this = *const Mesh, .ret = bool, .virtual = true };
    pub fn usingTextures(self: *const Mesh) bool {
        return bind(usingTextures_sig)(self);
    }

    // indices

    /// Indices `0, 1, 2, ...` one per vertex, replacing what was there.
    pub const setupIndicesAuto_sig: Signature = .{ .name = "setupIndicesAuto", .this = *Mesh };
    pub fn setupIndicesAuto(self: *Mesh) void {
        bind(setupIndicesAuto_sig)(self);
    }
    pub const getIndex_sig: Signature = .{ .name = "getIndex", .this = *const Mesh, .args = &.{u32}, .ret = u32 };
    pub fn getIndex(self: *const Mesh, index: u32) u32 {
        return bind(getIndex_sig)(self, index);
    }
    pub const addIndex_sig: Signature = .{ .name = "addIndex", .this = *Mesh, .args = &.{u32} };
    pub fn addIndex(self: *Mesh, vertex_index: u32) void {
        bind(addIndex_sig)(self, vertex_index);
    }
    pub const addIndices_sig: Signature = .{ .name = "addIndices", .this = *Mesh, .args = &.{ [*]const u32, usize } };
    pub fn addIndices(self: *Mesh, indices: []const u32) void {
        bind(addIndices_sig)(self, indices.ptr, indices.len);
    }
    pub const removeIndex_sig: Signature = .{ .name = "removeIndex", .this = *Mesh, .args = &.{u32} };
    pub fn removeIndex(self: *Mesh, index: u32) void {
        bind(removeIndex_sig)(self, index);
    }
    pub const removeIndices_sig: Signature = .{ .name = "removeIndices", .this = *Mesh, .args = &.{ u32, u32 } };
    pub fn removeIndices(self: *Mesh, start: u32, end: u32) void {
        bind(removeIndices_sig)(self, start, end);
    }
    pub const setIndex_sig: Signature = .{ .name = "setIndex", .this = *Mesh, .args = &.{ u32, u32 } };
    pub fn setIndex(self: *Mesh, index: u32, vertex_index: u32) void {
        bind(setIndex_sig)(self, index, vertex_index);
    }
    pub const clearIndices_sig: Signature = .{ .name = "clearIndices", .this = *Mesh };
    pub fn clearIndices(self: *Mesh) void {
        bind(clearIndices_sig)(self);
    }
    pub const getNumIndices_sig: Signature = .{ .name = "getNumIndices", .this = *const Mesh, .ret = usize };
    pub fn getNumIndices(self: *const Mesh) usize {
        return bind(getNumIndices_sig)(self);
    }
    pub const getIndices_sig: Signature = .{ .name = "getIndices", .this = *Mesh, .ret = Ref(*IndexVector) };
    pub fn getIndices(self: *Mesh) []u32 {
        return bind(getIndices_sig)(self).items();
    }
    pub const getIndices_const_sig: Signature = .{ .name = "getIndices", .this = *const Mesh, .ret = Ref(*const IndexVector) };
    pub fn getIndicesConst(self: *const Mesh) []const u32 {
        return bind(getIndices_const_sig)(self).constItems();
    }
    pub const hasIndices_sig: Signature = .{ .name = "hasIndices", .this = *const Mesh, .ret = bool };
    pub fn hasIndices(self: *const Mesh) bool {
        return bind(hasIndices_sig)(self);
    }
    /// Three indices at once.
    pub const addTriangle_sig: Signature = .{ .name = "addTriangle", .this = *Mesh, .args = &.{ u32, u32, u32 } };
    pub fn addTriangle(self: *Mesh, a: u32, b: u32, c: u32) void {
        bind(addTriangle_sig)(self, a, b, c);
    }
    pub const enableIndices_sig: Signature = .{ .name = "enableIndices", .this = *Mesh, .virtual = true };
    pub fn enableIndices(self: *Mesh) void {
        bind(enableIndices_sig)(self);
    }
    pub const disableIndices_sig: Signature = .{ .name = "disableIndices", .this = *Mesh, .virtual = true };
    pub fn disableIndices(self: *Mesh) void {
        bind(disableIndices_sig)(self);
    }
    pub const usingIndices_sig: Signature = .{ .name = "usingIndices", .this = *const Mesh, .ret = bool, .virtual = true };
    pub fn usingIndices(self: *const Mesh) bool {
        return bind(usingIndices_sig)(self);
    }
    /// Colors every vertex that the indices from `start` up to and including
    /// `end` refer to.
    pub const setColorForIndices_sig: Signature = .{ .name = "setColorForIndices", .this = *Mesh, .args = &.{ u32, u32, FloatColor } };
    pub fn setColorForIndices(self: *Mesh, start: u32, end: u32, c: FloatColor) void {
        bind(setColorForIndices_sig)(self, start, end, c);
    }
    /// `getMeshForIndices(start, end)`: the part of `self` that the indices
    /// from `start` up to and including `end` describe, constructed into
    /// `out`, which must be uninitialized.
    pub const getMeshForIndices_sig: Signature = .{ .name = "getMeshForIndices", .this = *const Mesh, .args = &.{ u32, u32 }, .ret = Mesh };
    pub fn getMeshForIndices(self: *const Mesh, out: *Mesh, start: u32, end: u32) void {
        bind(getMeshForIndices_sig)(out, self, start, end);
    }

    // drawing, in the current color where the mesh has none

    pub const drawVertices_sig: Signature = .{ .name = "drawVertices", .this = *const Mesh };
    pub fn drawVertices(self: *const Mesh) void {
        bind(drawVertices_sig)(self);
    }
    pub const drawWireframe_sig: Signature = .{ .name = "drawWireframe", .this = *const Mesh };
    pub fn drawWireframe(self: *const Mesh) void {
        bind(drawWireframe_sig)(self);
    }
    pub const drawFaces_sig: Signature = .{ .name = "drawFaces", .this = *const Mesh };
    pub fn drawFaces(self: *const Mesh) void {
        bind(drawFaces_sig)(self);
    }
    /// `draw()`: filled, or as `ofFill`/`ofNoFill` says.
    pub const draw_sig: Signature = .{ .name = "draw", .this = *const Mesh };
    pub fn draw(self: *const Mesh) void {
        bind(draw_sig)(self);
    }
    /// `draw(ofPolyRenderMode)`
    pub const draw_mode_sig: Signature = .{ .name = "draw", .this = *const Mesh, .args = &.{PolyRenderMode}, .virtual = true };
    pub fn drawMode(self: *const Mesh, mode: PolyRenderMode) void {
        bind(draw_mode_sig)(self, mode);
    }

    // files

    /// `load(path)`: a PLY file, under `bin/data` or absolute. Reports
    /// whether the path could be built; a file that does not load leaves the
    /// mesh empty and says so through `ofLogError`.
    pub const load_sig: Signature = .{ .name = "load", .this = *Mesh, .args = &.{Ref(*const Path)} };
    pub fn load(self: *Mesh, file: []const u8) bool {
        var path = Path.init(file) orelse return false;
        defer path.deinit();
        bind(load_sig)(self, &path);
        return true;
    }
    /// `save(path, useBinary)`: writes a PLY file.
    pub const save_sig: Signature = .{ .name = "save", .this = *const Mesh, .args = &.{ Ref(*const Path), bool } };
    pub fn save(self: *const Mesh, file: []const u8, binary: bool) bool {
        var path = Path.init(file) orelse return false;
        defer path.deinit();
        bind(save_sig)(self, &path, binary);
        return true;
    }
};
