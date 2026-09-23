//! of3dPrimitives.h: meshes with a transform -- a plane, a sphere, an
//! icosphere, a cylinder, a cone and a box -- each an `ofNode`.
//!
//! ```zig
//! var box: of.BoxPrimitive = undefined;   // a field of the app struct
//! box.init();                             // in setup
//! box.set(100, 60, 40);
//! box.node().setPosition(.{ 0, 30, 0 });
//!
//! box.draw();                             // in draw, inside a camera
//! box.node().pan(0.01);
//! ```
//!
//! The hierarchy is `ofNode` > `of3dPrimitive` > the six shapes. Each Zig
//! type binds the methods its class declares; `primitive()` and `node()` are
//! the checked upcasts to the two bases. `getMesh` is the `Mesh` a shape
//! draws, to read or edit in place.
//!
//! Every primitive is drawn at its node's transform, so `draw` needs no
//! position: set one on the node, or leave it at the origin and use
//! `pushMatrix`/`translate`.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const Color = @import("color.zig").Color;
const Node = @import("node.zig").Node;
const Mesh = @import("mesh.zig").Mesh;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const GlmVec2 = math.GlmVec2;
const GlmVec3 = math.GlmVec3;

/// `ofPolyRenderMode`: how a mesh is drawn.
pub const PolyRenderMode = enum(i32) {
    points = 0,
    wireframe = 1,
    fill = 2,
    pub const cpp_name = "ofPolyRenderMode";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

/// `ofPrimitiveMode`: how a mesh's vertices form its faces.
pub const PrimitiveMode = enum(i32) {
    triangles = 0,
    triangle_strip = 1,
    triangle_fan = 2,
    lines = 3,
    line_strip = 4,
    line_loop = 5,
    points = 6,
    lines_adjacency = 7,
    line_strip_adjacency = 8,
    triangles_adjacency = 9,
    triangle_strip_adjacency = 10,
    patches = 11,
    pub const cpp_name = "ofPrimitiveMode";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

/// `ofBoundingBox`: the corners of an axis-aligned box.
pub const BoundingBox = extern struct {
    min: GlmVec3,
    max: GlmVec3,
    pub const cpp_name = "ofBoundingBox";
    pub const cpp_kind: cpp.Kind = .@"struct";
    /// Its members have constructors, so it is not a plain C struct.
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

    pub fn size(b: BoundingBox) Vec3 {
        return b.max.to() - b.min.to();
    }
    pub fn center(b: BoundingBox) Vec3 {
        return (b.min.to() + b.max.to()) * @as(Vec3, @splat(0.5));
    }
};

/// `of3dPrimitive`: an `ofNode` that owns a mesh and draws it. The base of
/// the six shapes, and what their `primitive()` returns.
pub const Primitive = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [208]u8 align(8),

    pub const cpp_name = "of3dPrimitive";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Node};
    pub const cpp_virtual_dtor = true;

    pub fn node(self: *Primitive) *Node {
        return cpp.basePtr(Node, self);
    }
    pub fn nodeConst(self: *const Primitive) *const Node {
        return cpp.basePtr(Node, self);
    }

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Primitive };
    /// Runs `of3dPrimitive()` on the storage of `self`: an empty mesh.
    pub fn init(self: *Primitive) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Primitive };
    pub fn deinit(self: *Primitive) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `getMesh()`: the mesh the primitive draws. Editing it edits the
    /// shape; the shape's own `set` calls rebuild it.
    pub const getMesh_sig: Signature = .{ .name = "getMesh", .this = *Primitive, .ret = Ref(*Mesh) };
    pub fn getMesh(self: *Primitive) *Mesh {
        return cpp.bind(getMesh_sig)(self);
    }
    pub const getMesh_const_sig: Signature = .{ .name = "getMesh", .this = *const Primitive, .ret = Ref(*const Mesh) };
    pub fn getMeshConst(self: *const Primitive) *const Mesh {
        return cpp.bind(getMesh_const_sig)(self);
    }

    /// The mesh's extent in the node's own space, before its transform.
    pub const getBoundingBox_sig: Signature = .{ .name = "getBoundingBox", .this = *const Primitive, .ret = BoundingBox };
    pub fn getBoundingBox(self: *const Primitive) BoundingBox {
        return cpp.bind(getBoundingBox_sig)(self);
    }

    /// Stretches the texture coordinates over `u_min, v_min` to `u_max, v_max`.
    pub const mapTexCoords_sig: Signature = .{ .name = "mapTexCoords", .this = *Primitive, .args = &.{ f32, f32, f32, f32 } };
    pub fn mapTexCoords(self: *Primitive, u_min: f32, v_min: f32, u_max: f32, v_max: f32) void {
        cpp.bind(mapTexCoords_sig)(self, u_min, v_min, u_max, v_max);
    }

    pub const hasScaling_sig: Signature = .{ .name = "hasScaling", .this = *const Primitive, .ret = bool };
    pub fn hasScaling(self: *const Primitive) bool {
        return cpp.bind(hasScaling_sig)(self);
    }
    pub const hasNormalsEnabled_sig: Signature = .{ .name = "hasNormalsEnabled", .this = *const Primitive, .ret = bool };
    pub fn hasNormalsEnabled(self: *const Primitive) bool {
        return cpp.bind(hasNormalsEnabled_sig)(self);
    }

    pub const enableNormals_sig: Signature = .{ .name = "enableNormals", .this = *Primitive };
    pub fn enableNormals(self: *Primitive) void {
        cpp.bind(enableNormals_sig)(self);
    }
    pub const enableTextures_sig: Signature = .{ .name = "enableTextures", .this = *Primitive };
    pub fn enableTextures(self: *Primitive) void {
        cpp.bind(enableTextures_sig)(self);
    }
    pub const enableColors_sig: Signature = .{ .name = "enableColors", .this = *Primitive };
    pub fn enableColors(self: *Primitive) void {
        cpp.bind(enableColors_sig)(self);
    }
    pub const disableNormals_sig: Signature = .{ .name = "disableNormals", .this = *Primitive };
    pub fn disableNormals(self: *Primitive) void {
        cpp.bind(disableNormals_sig)(self);
    }
    pub const disableTextures_sig: Signature = .{ .name = "disableTextures", .this = *Primitive };
    pub fn disableTextures(self: *Primitive) void {
        cpp.bind(disableTextures_sig)(self);
    }
    pub const disableColors_sig: Signature = .{ .name = "disableColors", .this = *Primitive };
    pub fn disableColors(self: *Primitive) void {
        cpp.bind(disableColors_sig)(self);
    }

    // drawing, all at the node's transform and in the current color

    pub const drawVertices_sig: Signature = .{ .name = "drawVertices", .this = *const Primitive };
    pub fn drawVertices(self: *const Primitive) void {
        cpp.bind(drawVertices_sig)(self);
    }
    pub const drawWireframe_sig: Signature = .{ .name = "drawWireframe", .this = *const Primitive };
    pub fn drawWireframe(self: *const Primitive) void {
        cpp.bind(drawWireframe_sig)(self);
    }
    pub const drawFaces_sig: Signature = .{ .name = "drawFaces", .this = *const Primitive };
    pub fn drawFaces(self: *const Primitive) void {
        cpp.bind(drawFaces_sig)(self);
    }
    /// `draw(ofPolyRenderMode)`
    pub const draw_mode_sig: Signature = .{ .name = "draw", .this = *const Primitive, .args = &.{PolyRenderMode} };
    pub fn drawMode(self: *const Primitive, mode: PolyRenderMode) void {
        cpp.bind(draw_mode_sig)(self, mode);
    }
    /// `draw()`: filled, or as `ofFill`/`ofNoFill` says. This overrides
    /// `ofNode::draw`, and is virtual for it.
    pub const draw_sig: Signature = .{ .name = "draw", .this = *const Primitive, .virtual = true };
    pub fn draw(self: *const Primitive) void {
        cpp.bind(draw_sig)(self);
    }
    /// One line of `length` per vertex normal, or per face with
    /// `face_normals`.
    pub const drawNormals_sig: Signature = .{ .name = "drawNormals", .this = *const Primitive, .args = &.{ f32, bool } };
    pub fn drawNormals(self: *const Primitive, length: f32, face_normals: bool) void {
        cpp.bind(drawNormals_sig)(self, length, face_normals);
    }
    /// The node's axes, `size` long.
    pub const drawAxes_sig: Signature = .{ .name = "drawAxes", .this = *const Primitive, .args = &.{f32} };
    pub fn drawAxes(self: *const Primitive, size: f32) void {
        cpp.bind(drawAxes_sig)(self, size);
    }

    /// Whether the mesh is kept in a vertex buffer on the GPU. oF starts
    /// with it off.
    pub const setUseVbo_sig: Signature = .{ .name = "setUseVbo", .this = *Primitive, .args = &.{bool} };
    pub fn setUseVbo(self: *Primitive, use_vbo: bool) void {
        cpp.bind(setUseVbo_sig)(self, use_vbo);
    }
    pub const isUsingVbo_sig: Signature = .{ .name = "isUsingVbo", .this = *const Primitive, .ret = bool };
    pub fn isUsingVbo(self: *const Primitive) bool {
        return cpp.bind(isUsingVbo_sig)(self);
    }
};

/// The methods every shape shares: construction, the two upcasts, and the
/// `draw` family forwarded to `Primitive`, so that `box.draw()` works
/// without spelling the base. Mixed into each shape with `pub const x =
/// Shape(@This()).x` lines, since Zig has no way to splice declarations.
fn Shape(comptime T: type) type {
    return struct {
        pub fn primitive(self: *T) *Primitive {
            return cpp.basePtr(Primitive, self);
        }
        pub fn primitiveConst(self: *const T) *const Primitive {
            return cpp.basePtr(Primitive, self);
        }
        pub fn node(self: *T) *Node {
            return cpp.basePtr(Node, self);
        }
        pub fn nodeConst(self: *const T) *const Node {
            return cpp.basePtr(Node, self);
        }
        pub fn draw(self: *const T) void {
            self.primitiveConst().draw();
        }
        pub fn drawMode(self: *const T, mode: PolyRenderMode) void {
            self.primitiveConst().drawMode(mode);
        }
        pub fn drawWireframe(self: *const T) void {
            self.primitiveConst().drawWireframe();
        }
        pub fn drawFaces(self: *const T) void {
            self.primitiveConst().drawFaces();
        }
        pub fn drawVertices(self: *const T) void {
            self.primitiveConst().drawVertices();
        }
        pub fn drawNormals(self: *const T, length: f32, face_normals: bool) void {
            self.primitiveConst().drawNormals(length, face_normals);
        }
        pub fn drawAxes(self: *const T, size: f32) void {
            self.primitiveConst().drawAxes(size);
        }
        pub fn getMesh(self: *T) *Mesh {
            return self.primitive().getMesh();
        }
        pub fn getMeshConst(self: *const T) *const Mesh {
            return self.primitiveConst().getMeshConst();
        }
        pub fn getBoundingBox(self: *const T) BoundingBox {
            return self.primitiveConst().getBoundingBox();
        }
    };
}

/// `ofPlanePrimitive`: a rectangle in the xy plane, centred on the node.
pub const PlanePrimitive = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [16]u8 align(4),

    pub const cpp_name = "ofPlanePrimitive";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Primitive};
    pub const cpp_virtual_dtor = true;

    const shape = Shape(@This());
    pub const primitive = shape.primitive;
    pub const primitiveConst = shape.primitiveConst;
    pub const node = shape.node;
    pub const nodeConst = shape.nodeConst;
    pub const draw = shape.draw;
    pub const drawMode = shape.drawMode;
    pub const drawWireframe = shape.drawWireframe;
    pub const drawFaces = shape.drawFaces;
    pub const drawVertices = shape.drawVertices;
    pub const drawNormals = shape.drawNormals;
    pub const drawAxes = shape.drawAxes;
    pub const getMesh = shape.getMesh;
    pub const getMeshConst = shape.getMeshConst;
    pub const getBoundingBox = shape.getBoundingBox;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *PlanePrimitive };
    /// Runs `ofPlanePrimitive()` on the storage of `self`: a 200 by 100
    /// plane of 6 by 4 vertices. `set` changes it.
    pub fn init(self: *PlanePrimitive) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *PlanePrimitive };
    pub fn deinit(self: *PlanePrimitive) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `set(width, height, columns, rows, mode)`: rebuilds the mesh.
    pub const set_full_sig: Signature = .{ .name = "set", .this = *PlanePrimitive, .args = &.{ f32, f32, i32, i32, PrimitiveMode } };
    pub fn setFull(self: *PlanePrimitive, width: f32, height: f32, columns: u32, rows: u32, mode: PrimitiveMode) void {
        cpp.bind(set_full_sig)(self, width, height, @bitCast(columns), @bitCast(rows), mode);
    }
    /// `set(width, height)`: keeps the resolution.
    pub const set_sig: Signature = .{ .name = "set", .this = *PlanePrimitive, .args = &.{ f32, f32 } };
    pub fn set(self: *PlanePrimitive, width: f32, height: f32) void {
        cpp.bind(set_sig)(self, width, height);
    }
    pub const setWidth_sig: Signature = .{ .name = "setWidth", .this = *PlanePrimitive, .args = &.{f32} };
    pub fn setWidth(self: *PlanePrimitive, width: f32) void {
        cpp.bind(setWidth_sig)(self, width);
    }
    pub const setHeight_sig: Signature = .{ .name = "setHeight", .this = *PlanePrimitive, .args = &.{f32} };
    pub fn setHeight(self: *PlanePrimitive, height: f32) void {
        cpp.bind(setHeight_sig)(self, height);
    }
    pub const setColumns_sig: Signature = .{ .name = "setColumns", .this = *PlanePrimitive, .args = &.{i32} };
    pub fn setColumns(self: *PlanePrimitive, columns: u32) void {
        cpp.bind(setColumns_sig)(self, @bitCast(columns));
    }
    pub const setRows_sig: Signature = .{ .name = "setRows", .this = *PlanePrimitive, .args = &.{i32} };
    pub fn setRows(self: *PlanePrimitive, rows: u32) void {
        cpp.bind(setRows_sig)(self, @bitCast(rows));
    }
    pub const setResolution_sig: Signature = .{ .name = "setResolution", .this = *PlanePrimitive, .args = &.{ i32, i32 } };
    pub fn setResolution(self: *PlanePrimitive, columns: u32, rows: u32) void {
        cpp.bind(setResolution_sig)(self, @bitCast(columns), @bitCast(rows));
    }
    pub const setMode_sig: Signature = .{ .name = "setMode", .this = *PlanePrimitive, .args = &.{PrimitiveMode} };
    pub fn setMode(self: *PlanePrimitive, mode: PrimitiveMode) void {
        cpp.bind(setMode_sig)(self, mode);
    }

    pub const getNumColumns_sig: Signature = .{ .name = "getNumColumns", .this = *const PlanePrimitive, .ret = i32 };
    pub fn getNumColumns(self: *const PlanePrimitive) u32 {
        return @bitCast(cpp.bind(getNumColumns_sig)(self));
    }
    pub const getNumRows_sig: Signature = .{ .name = "getNumRows", .this = *const PlanePrimitive, .ret = i32 };
    pub fn getNumRows(self: *const PlanePrimitive) u32 {
        return @bitCast(cpp.bind(getNumRows_sig)(self));
    }
    /// Columns, rows.
    pub const getResolution_sig: Signature = .{ .name = "getResolution", .this = *const PlanePrimitive, .ret = GlmVec2 };
    pub fn getResolution(self: *const PlanePrimitive) Vec2 {
        return cpp.bind(getResolution_sig)(self).to();
    }
    pub const getWidth_sig: Signature = .{ .name = "getWidth", .this = *const PlanePrimitive, .ret = f32 };
    pub fn getWidth(self: *const PlanePrimitive) f32 {
        return cpp.bind(getWidth_sig)(self);
    }
    pub const getHeight_sig: Signature = .{ .name = "getHeight", .this = *const PlanePrimitive, .ret = f32 };
    pub fn getHeight(self: *const PlanePrimitive) f32 {
        return cpp.bind(getHeight_sig)(self);
    }
};

/// `ofSpherePrimitive`: a UV sphere, centred on the node.
pub const SpherePrimitive = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [8]u8 align(4),

    pub const cpp_name = "ofSpherePrimitive";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Primitive};
    pub const cpp_virtual_dtor = true;

    const shape = Shape(@This());
    pub const primitive = shape.primitive;
    pub const primitiveConst = shape.primitiveConst;
    pub const node = shape.node;
    pub const nodeConst = shape.nodeConst;
    pub const draw = shape.draw;
    pub const drawMode = shape.drawMode;
    pub const drawWireframe = shape.drawWireframe;
    pub const drawFaces = shape.drawFaces;
    pub const drawVertices = shape.drawVertices;
    pub const drawNormals = shape.drawNormals;
    pub const drawAxes = shape.drawAxes;
    pub const getMesh = shape.getMesh;
    pub const getMeshConst = shape.getMeshConst;
    pub const getBoundingBox = shape.getBoundingBox;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *SpherePrimitive };
    /// Runs `ofSpherePrimitive()` on the storage of `self`: radius 20,
    /// resolution 16.
    pub fn init(self: *SpherePrimitive) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *SpherePrimitive };
    pub fn deinit(self: *SpherePrimitive) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `set(radius, resolution, mode)`: rebuilds the mesh.
    pub const set_sig: Signature = .{ .name = "set", .this = *SpherePrimitive, .args = &.{ f32, i32, PrimitiveMode } };
    pub fn set(self: *SpherePrimitive, radius: f32, resolution: u32, mode: PrimitiveMode) void {
        cpp.bind(set_sig)(self, radius, @bitCast(resolution), mode);
    }
    pub const setResolution_sig: Signature = .{ .name = "setResolution", .this = *SpherePrimitive, .args = &.{i32} };
    pub fn setResolution(self: *SpherePrimitive, resolution: u32) void {
        cpp.bind(setResolution_sig)(self, @bitCast(resolution));
    }
    pub const setRadius_sig: Signature = .{ .name = "setRadius", .this = *SpherePrimitive, .args = &.{f32} };
    pub fn setRadius(self: *SpherePrimitive, radius: f32) void {
        cpp.bind(setRadius_sig)(self, radius);
    }
    pub const setMode_sig: Signature = .{ .name = "setMode", .this = *SpherePrimitive, .args = &.{PrimitiveMode} };
    pub fn setMode(self: *SpherePrimitive, mode: PrimitiveMode) void {
        cpp.bind(setMode_sig)(self, mode);
    }
    pub const getRadius_sig: Signature = .{ .name = "getRadius", .this = *const SpherePrimitive, .ret = f32 };
    pub fn getRadius(self: *const SpherePrimitive) f32 {
        return cpp.bind(getRadius_sig)(self);
    }
    pub const getResolution_sig: Signature = .{ .name = "getResolution", .this = *const SpherePrimitive, .ret = i32 };
    pub fn getResolution(self: *const SpherePrimitive) u32 {
        return @bitCast(cpp.bind(getResolution_sig)(self));
    }
};

/// `ofIcoSpherePrimitive`: a subdivided icosahedron, centred on the node.
/// `resolution` is the number of subdivisions, so it grows fast.
pub const IcoSpherePrimitive = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [8]u8 align(4),

    pub const cpp_name = "ofIcoSpherePrimitive";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Primitive};
    pub const cpp_virtual_dtor = true;

    const shape = Shape(@This());
    pub const primitive = shape.primitive;
    pub const primitiveConst = shape.primitiveConst;
    pub const node = shape.node;
    pub const nodeConst = shape.nodeConst;
    pub const draw = shape.draw;
    pub const drawMode = shape.drawMode;
    pub const drawWireframe = shape.drawWireframe;
    pub const drawFaces = shape.drawFaces;
    pub const drawVertices = shape.drawVertices;
    pub const drawNormals = shape.drawNormals;
    pub const drawAxes = shape.drawAxes;
    pub const getMesh = shape.getMesh;
    pub const getMeshConst = shape.getMeshConst;
    pub const getBoundingBox = shape.getBoundingBox;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *IcoSpherePrimitive };
    /// Runs `ofIcoSpherePrimitive()` on the storage of `self`: radius 20,
    /// two subdivisions.
    pub fn init(self: *IcoSpherePrimitive) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *IcoSpherePrimitive };
    pub fn deinit(self: *IcoSpherePrimitive) void {
        cpp.bind(dtor_sig)(self);
    }

    pub const set_sig: Signature = .{ .name = "set", .this = *IcoSpherePrimitive, .args = &.{ f32, i32 } };
    pub fn set(self: *IcoSpherePrimitive, radius: f32, resolution: u32) void {
        cpp.bind(set_sig)(self, radius, @bitCast(resolution));
    }
    pub const setResolution_sig: Signature = .{ .name = "setResolution", .this = *IcoSpherePrimitive, .args = &.{i32} };
    pub fn setResolution(self: *IcoSpherePrimitive, resolution: u32) void {
        cpp.bind(setResolution_sig)(self, @bitCast(resolution));
    }
    pub const setRadius_sig: Signature = .{ .name = "setRadius", .this = *IcoSpherePrimitive, .args = &.{f32} };
    pub fn setRadius(self: *IcoSpherePrimitive, radius: f32) void {
        cpp.bind(setRadius_sig)(self, radius);
    }
    pub const setMode_sig: Signature = .{ .name = "setMode", .this = *IcoSpherePrimitive, .args = &.{PrimitiveMode} };
    pub fn setMode(self: *IcoSpherePrimitive, mode: PrimitiveMode) void {
        cpp.bind(setMode_sig)(self, mode);
    }
    pub const getRadius_sig: Signature = .{ .name = "getRadius", .this = *const IcoSpherePrimitive, .ret = f32 };
    pub fn getRadius(self: *const IcoSpherePrimitive) f32 {
        return cpp.bind(getRadius_sig)(self);
    }
    pub const getResolution_sig: Signature = .{ .name = "getResolution", .this = *const IcoSpherePrimitive, .ret = i32 };
    pub fn getResolution(self: *const IcoSpherePrimitive) u32 {
        return @bitCast(cpp.bind(getResolution_sig)(self));
    }
};

/// `ofCylinderPrimitive`: a cylinder along the node's y axis, centred on it.
pub const CylinderPrimitive = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [48]u8 align(4),

    pub const cpp_name = "ofCylinderPrimitive";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Primitive};
    pub const cpp_virtual_dtor = true;

    const shape = Shape(@This());
    pub const primitive = shape.primitive;
    pub const primitiveConst = shape.primitiveConst;
    pub const node = shape.node;
    pub const nodeConst = shape.nodeConst;
    pub const draw = shape.draw;
    pub const drawMode = shape.drawMode;
    pub const drawWireframe = shape.drawWireframe;
    pub const drawFaces = shape.drawFaces;
    pub const drawVertices = shape.drawVertices;
    pub const drawNormals = shape.drawNormals;
    pub const drawAxes = shape.drawAxes;
    pub const getMesh = shape.getMesh;
    pub const getMeshConst = shape.getMeshConst;
    pub const getBoundingBox = shape.getBoundingBox;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *CylinderPrimitive };
    /// Runs `ofCylinderPrimitive()` on the storage of `self`: radius 60,
    /// height 80, capped.
    pub fn init(self: *CylinderPrimitive) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *CylinderPrimitive };
    pub fn deinit(self: *CylinderPrimitive) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `set(radius, height, radiusSegments, heightSegments, capSegments, capped, mode)`
    pub const set_full_sig: Signature = .{
        .name = "set",
        .this = *CylinderPrimitive,
        .args = &.{ f32, f32, i32, i32, i32, bool, PrimitiveMode },
    };
    pub fn setFull(self: *CylinderPrimitive, radius: f32, height: f32, radius_segments: u32, height_segments: u32, cap_segments: u32, capped: bool, mode: PrimitiveMode) void {
        cpp.bind(set_full_sig)(self, radius, height, @bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments), capped, mode);
    }
    /// `set(radius, height, capped)`: keeps the resolution.
    pub const set_sig: Signature = .{ .name = "set", .this = *CylinderPrimitive, .args = &.{ f32, f32, bool } };
    pub fn set(self: *CylinderPrimitive, radius: f32, height: f32, capped: bool) void {
        cpp.bind(set_sig)(self, radius, height, capped);
    }
    pub const setRadius_sig: Signature = .{ .name = "setRadius", .this = *CylinderPrimitive, .args = &.{f32} };
    pub fn setRadius(self: *CylinderPrimitive, radius: f32) void {
        cpp.bind(setRadius_sig)(self, radius);
    }
    pub const setHeight_sig: Signature = .{ .name = "setHeight", .this = *CylinderPrimitive, .args = &.{f32} };
    pub fn setHeight(self: *CylinderPrimitive, height: f32) void {
        cpp.bind(setHeight_sig)(self, height);
    }
    pub const setCapped_sig: Signature = .{ .name = "setCapped", .this = *CylinderPrimitive, .args = &.{bool} };
    pub fn setCapped(self: *CylinderPrimitive, capped: bool) void {
        cpp.bind(setCapped_sig)(self, capped);
    }
    pub const setResolutionRadius_sig: Signature = .{ .name = "setResolutionRadius", .this = *CylinderPrimitive, .args = &.{i32} };
    pub fn setResolutionRadius(self: *CylinderPrimitive, segments: u32) void {
        cpp.bind(setResolutionRadius_sig)(self, @bitCast(segments));
    }
    pub const setResolutionHeight_sig: Signature = .{ .name = "setResolutionHeight", .this = *CylinderPrimitive, .args = &.{i32} };
    pub fn setResolutionHeight(self: *CylinderPrimitive, segments: u32) void {
        cpp.bind(setResolutionHeight_sig)(self, @bitCast(segments));
    }
    pub const setResolutionCap_sig: Signature = .{ .name = "setResolutionCap", .this = *CylinderPrimitive, .args = &.{i32} };
    pub fn setResolutionCap(self: *CylinderPrimitive, segments: u32) void {
        cpp.bind(setResolutionCap_sig)(self, @bitCast(segments));
    }
    pub const setResolution_sig: Signature = .{ .name = "setResolution", .this = *CylinderPrimitive, .args = &.{ i32, i32, i32 } };
    pub fn setResolution(self: *CylinderPrimitive, radius_segments: u32, height_segments: u32, cap_segments: u32) void {
        cpp.bind(setResolution_sig)(self, @bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments));
    }
    pub const setMode_sig: Signature = .{ .name = "setMode", .this = *CylinderPrimitive, .args = &.{PrimitiveMode} };
    pub fn setMode(self: *CylinderPrimitive, mode: PrimitiveMode) void {
        cpp.bind(setMode_sig)(self, mode);
    }

    /// Per-vertex colors for the top cap. Takes effect when colors are
    /// enabled on the primitive.
    pub const setTopCapColor_sig: Signature = .{ .name = "setTopCapColor", .this = *CylinderPrimitive, .args = &.{Color} };
    pub fn setTopCapColor(self: *CylinderPrimitive, color: Color) void {
        cpp.bind(setTopCapColor_sig)(self, color);
    }
    pub const setCylinderColor_sig: Signature = .{ .name = "setCylinderColor", .this = *CylinderPrimitive, .args = &.{Color} };
    pub fn setCylinderColor(self: *CylinderPrimitive, color: Color) void {
        cpp.bind(setCylinderColor_sig)(self, color);
    }
    pub const setBottomCapColor_sig: Signature = .{ .name = "setBottomCapColor", .this = *CylinderPrimitive, .args = &.{Color} };
    pub fn setBottomCapColor(self: *CylinderPrimitive, color: Color) void {
        cpp.bind(setBottomCapColor_sig)(self, color);
    }

    pub const getResolutionRadius_sig: Signature = .{ .name = "getResolutionRadius", .this = *const CylinderPrimitive, .ret = i32 };
    pub fn getResolutionRadius(self: *const CylinderPrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionRadius_sig)(self));
    }
    pub const getResolutionHeight_sig: Signature = .{ .name = "getResolutionHeight", .this = *const CylinderPrimitive, .ret = i32 };
    pub fn getResolutionHeight(self: *const CylinderPrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionHeight_sig)(self));
    }
    pub const getResolutionCap_sig: Signature = .{ .name = "getResolutionCap", .this = *const CylinderPrimitive, .ret = i32 };
    pub fn getResolutionCap(self: *const CylinderPrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionCap_sig)(self));
    }
    /// Radius, height and cap segments.
    pub const getResolution_sig: Signature = .{ .name = "getResolution", .this = *const CylinderPrimitive, .ret = GlmVec3 };
    pub fn getResolution(self: *const CylinderPrimitive) Vec3 {
        return cpp.bind(getResolution_sig)(self).to();
    }
    pub const getHeight_sig: Signature = .{ .name = "getHeight", .this = *const CylinderPrimitive, .ret = f32 };
    pub fn getHeight(self: *const CylinderPrimitive) f32 {
        return cpp.bind(getHeight_sig)(self);
    }
    pub const getRadius_sig: Signature = .{ .name = "getRadius", .this = *const CylinderPrimitive, .ret = f32 };
    pub fn getRadius(self: *const CylinderPrimitive) f32 {
        return cpp.bind(getRadius_sig)(self);
    }
    pub const getCapped_sig: Signature = .{ .name = "getCapped", .this = *const CylinderPrimitive, .ret = bool };
    pub fn getCapped(self: *const CylinderPrimitive) bool {
        return cpp.bind(getCapped_sig)(self);
    }
};

/// `ofConePrimitive`: a cone along the node's y axis, apex up, centred on it.
pub const ConePrimitive = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [40]u8 align(4),

    pub const cpp_name = "ofConePrimitive";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Primitive};
    pub const cpp_virtual_dtor = true;

    const shape = Shape(@This());
    pub const primitive = shape.primitive;
    pub const primitiveConst = shape.primitiveConst;
    pub const node = shape.node;
    pub const nodeConst = shape.nodeConst;
    pub const draw = shape.draw;
    pub const drawMode = shape.drawMode;
    pub const drawWireframe = shape.drawWireframe;
    pub const drawFaces = shape.drawFaces;
    pub const drawVertices = shape.drawVertices;
    pub const drawNormals = shape.drawNormals;
    pub const drawAxes = shape.drawAxes;
    pub const getMesh = shape.getMesh;
    pub const getMeshConst = shape.getMeshConst;
    pub const getBoundingBox = shape.getBoundingBox;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *ConePrimitive };
    /// Runs `ofConePrimitive()` on the storage of `self`: radius 20,
    /// height 70.
    pub fn init(self: *ConePrimitive) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *ConePrimitive };
    pub fn deinit(self: *ConePrimitive) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `set(radius, height, radiusSegments, heightSegments, capSegments, mode)`
    pub const set_full_sig: Signature = .{
        .name = "set",
        .this = *ConePrimitive,
        .args = &.{ f32, f32, i32, i32, i32, PrimitiveMode },
    };
    pub fn setFull(self: *ConePrimitive, radius: f32, height: f32, radius_segments: u32, height_segments: u32, cap_segments: u32, mode: PrimitiveMode) void {
        cpp.bind(set_full_sig)(self, radius, height, @bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments), mode);
    }
    /// `set(radius, height)`: keeps the resolution.
    pub const set_sig: Signature = .{ .name = "set", .this = *ConePrimitive, .args = &.{ f32, f32 } };
    pub fn set(self: *ConePrimitive, radius: f32, height: f32) void {
        cpp.bind(set_sig)(self, radius, height);
    }
    pub const setResolutionRadius_sig: Signature = .{ .name = "setResolutionRadius", .this = *ConePrimitive, .args = &.{i32} };
    pub fn setResolutionRadius(self: *ConePrimitive, segments: u32) void {
        cpp.bind(setResolutionRadius_sig)(self, @bitCast(segments));
    }
    pub const setResolutionHeight_sig: Signature = .{ .name = "setResolutionHeight", .this = *ConePrimitive, .args = &.{i32} };
    pub fn setResolutionHeight(self: *ConePrimitive, segments: u32) void {
        cpp.bind(setResolutionHeight_sig)(self, @bitCast(segments));
    }
    pub const setResolutionCap_sig: Signature = .{ .name = "setResolutionCap", .this = *ConePrimitive, .args = &.{i32} };
    pub fn setResolutionCap(self: *ConePrimitive, segments: u32) void {
        cpp.bind(setResolutionCap_sig)(self, @bitCast(segments));
    }
    pub const setResolution_sig: Signature = .{ .name = "setResolution", .this = *ConePrimitive, .args = &.{ i32, i32, i32 } };
    pub fn setResolution(self: *ConePrimitive, radius_segments: u32, height_segments: u32, cap_segments: u32) void {
        cpp.bind(setResolution_sig)(self, @bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments));
    }
    pub const setMode_sig: Signature = .{ .name = "setMode", .this = *ConePrimitive, .args = &.{PrimitiveMode} };
    pub fn setMode(self: *ConePrimitive, mode: PrimitiveMode) void {
        cpp.bind(setMode_sig)(self, mode);
    }
    pub const setRadius_sig: Signature = .{ .name = "setRadius", .this = *ConePrimitive, .args = &.{f32} };
    pub fn setRadius(self: *ConePrimitive, radius: f32) void {
        cpp.bind(setRadius_sig)(self, radius);
    }
    pub const setHeight_sig: Signature = .{ .name = "setHeight", .this = *ConePrimitive, .args = &.{f32} };
    pub fn setHeight(self: *ConePrimitive, height: f32) void {
        cpp.bind(setHeight_sig)(self, height);
    }

    /// Per-vertex colors for the side. Takes effect when colors are enabled
    /// on the primitive.
    pub const setTopColor_sig: Signature = .{ .name = "setTopColor", .this = *ConePrimitive, .args = &.{Color} };
    pub fn setTopColor(self: *ConePrimitive, color: Color) void {
        cpp.bind(setTopColor_sig)(self, color);
    }
    pub const setCapColor_sig: Signature = .{ .name = "setCapColor", .this = *ConePrimitive, .args = &.{Color} };
    pub fn setCapColor(self: *ConePrimitive, color: Color) void {
        cpp.bind(setCapColor_sig)(self, color);
    }

    pub const getResolutionRadius_sig: Signature = .{ .name = "getResolutionRadius", .this = *const ConePrimitive, .ret = i32 };
    pub fn getResolutionRadius(self: *const ConePrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionRadius_sig)(self));
    }
    pub const getResolutionHeight_sig: Signature = .{ .name = "getResolutionHeight", .this = *const ConePrimitive, .ret = i32 };
    pub fn getResolutionHeight(self: *const ConePrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionHeight_sig)(self));
    }
    pub const getResolutionCap_sig: Signature = .{ .name = "getResolutionCap", .this = *const ConePrimitive, .ret = i32 };
    pub fn getResolutionCap(self: *const ConePrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionCap_sig)(self));
    }
    /// Radius, height and cap segments.
    pub const getResolution_sig: Signature = .{ .name = "getResolution", .this = *const ConePrimitive, .ret = GlmVec3 };
    pub fn getResolution(self: *const ConePrimitive) Vec3 {
        return cpp.bind(getResolution_sig)(self).to();
    }
    pub const getRadius_sig: Signature = .{ .name = "getRadius", .this = *const ConePrimitive, .ret = f32 };
    pub fn getRadius(self: *const ConePrimitive) f32 {
        return cpp.bind(getRadius_sig)(self);
    }
    pub const getHeight_sig: Signature = .{ .name = "getHeight", .this = *const ConePrimitive, .ret = f32 };
    pub fn getHeight(self: *const ConePrimitive) f32 {
        return cpp.bind(getHeight_sig)(self);
    }
};

/// `ofBoxPrimitive`: a box centred on the node.
pub const BoxPrimitive = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [72]u8 align(4),

    pub const cpp_name = "ofBoxPrimitive";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Primitive};
    pub const cpp_virtual_dtor = true;

    const shape = Shape(@This());
    pub const primitive = shape.primitive;
    pub const primitiveConst = shape.primitiveConst;
    pub const node = shape.node;
    pub const nodeConst = shape.nodeConst;
    pub const draw = shape.draw;
    pub const drawMode = shape.drawMode;
    pub const drawWireframe = shape.drawWireframe;
    pub const drawFaces = shape.drawFaces;
    pub const drawVertices = shape.drawVertices;
    pub const drawNormals = shape.drawNormals;
    pub const drawAxes = shape.drawAxes;
    pub const getMesh = shape.getMesh;
    pub const getMeshConst = shape.getMeshConst;
    pub const getBoundingBox = shape.getBoundingBox;

    /// `ofBoxPrimitive::BoxSides`, for `setSideColor`.
    pub const Side = enum(i32) {
        front = 0,
        right = 1,
        left = 2,
        back = 3,
        top = 4,
        bottom = 5,
        pub const cpp_name = "ofBoxPrimitive::BoxSides";
        pub const cpp_kind: cpp.Kind = .@"enum";
    };

    pub const ctor_sig: Signature = .{ .name = "*", .this = *BoxPrimitive };
    /// Runs `ofBoxPrimitive()` on the storage of `self`: a 100 unit cube.
    pub fn init(self: *BoxPrimitive) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *BoxPrimitive };
    pub fn deinit(self: *BoxPrimitive) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `set(width, height, depth, resWidth, resHeight, resDepth)`
    pub const set_full_sig: Signature = .{ .name = "set", .this = *BoxPrimitive, .args = &.{ f32, f32, f32, i32, i32, i32 } };
    pub fn setFull(self: *BoxPrimitive, width: f32, height: f32, depth: f32, res_width: u32, res_height: u32, res_depth: u32) void {
        cpp.bind(set_full_sig)(self, width, height, depth, @bitCast(res_width), @bitCast(res_height), @bitCast(res_depth));
    }
    /// `set(width, height, depth)`: keeps the resolution.
    pub const set_sig: Signature = .{ .name = "set", .this = *BoxPrimitive, .args = &.{ f32, f32, f32 } };
    pub fn set(self: *BoxPrimitive, width: f32, height: f32, depth: f32) void {
        cpp.bind(set_sig)(self, width, height, depth);
    }
    /// `set(size)`: a cube.
    pub const set_cube_sig: Signature = .{ .name = "set", .this = *BoxPrimitive, .args = &.{f32} };
    pub fn setCube(self: *BoxPrimitive, size: f32) void {
        cpp.bind(set_cube_sig)(self, size);
    }
    pub const setWidth_sig: Signature = .{ .name = "setWidth", .this = *BoxPrimitive, .args = &.{f32} };
    pub fn setWidth(self: *BoxPrimitive, width: f32) void {
        cpp.bind(setWidth_sig)(self, width);
    }
    pub const setHeight_sig: Signature = .{ .name = "setHeight", .this = *BoxPrimitive, .args = &.{f32} };
    pub fn setHeight(self: *BoxPrimitive, height: f32) void {
        cpp.bind(setHeight_sig)(self, height);
    }
    pub const setDepth_sig: Signature = .{ .name = "setDepth", .this = *BoxPrimitive, .args = &.{f32} };
    pub fn setDepth(self: *BoxPrimitive, depth: f32) void {
        cpp.bind(setDepth_sig)(self, depth);
    }
    /// `setResolution(res)`: the same on every side.
    pub const setResolution_uniform_sig: Signature = .{ .name = "setResolution", .this = *BoxPrimitive, .args = &.{i32} };
    pub fn setResolutionUniform(self: *BoxPrimitive, resolution: u32) void {
        cpp.bind(setResolution_uniform_sig)(self, @bitCast(resolution));
    }
    pub const setResolutionWidth_sig: Signature = .{ .name = "setResolutionWidth", .this = *BoxPrimitive, .args = &.{i32} };
    pub fn setResolutionWidth(self: *BoxPrimitive, resolution: u32) void {
        cpp.bind(setResolutionWidth_sig)(self, @bitCast(resolution));
    }
    pub const setResolutionHeight_sig: Signature = .{ .name = "setResolutionHeight", .this = *BoxPrimitive, .args = &.{i32} };
    pub fn setResolutionHeight(self: *BoxPrimitive, resolution: u32) void {
        cpp.bind(setResolutionHeight_sig)(self, @bitCast(resolution));
    }
    pub const setResolutionDepth_sig: Signature = .{ .name = "setResolutionDepth", .this = *BoxPrimitive, .args = &.{i32} };
    pub fn setResolutionDepth(self: *BoxPrimitive, resolution: u32) void {
        cpp.bind(setResolutionDepth_sig)(self, @bitCast(resolution));
    }
    pub const setResolution_sig: Signature = .{ .name = "setResolution", .this = *BoxPrimitive, .args = &.{ i32, i32, i32 } };
    pub fn setResolution(self: *BoxPrimitive, res_width: u32, res_height: u32, res_depth: u32) void {
        cpp.bind(setResolution_sig)(self, @bitCast(res_width), @bitCast(res_height), @bitCast(res_depth));
    }
    pub const setMode_sig: Signature = .{ .name = "setMode", .this = *BoxPrimitive, .args = &.{PrimitiveMode} };
    pub fn setMode(self: *BoxPrimitive, mode: PrimitiveMode) void {
        cpp.bind(setMode_sig)(self, mode);
    }
    /// Per-vertex colors for one side. Takes effect when colors are enabled
    /// on the primitive.
    pub const setSideColor_sig: Signature = .{ .name = "setSideColor", .this = *BoxPrimitive, .args = &.{ i32, Color } };
    pub fn setSideColor(self: *BoxPrimitive, side: Side, color: Color) void {
        cpp.bind(setSideColor_sig)(self, @backingInt(side), color);
    }

    pub const getResolutionWidth_sig: Signature = .{ .name = "getResolutionWidth", .this = *const BoxPrimitive, .ret = i32 };
    pub fn getResolutionWidth(self: *const BoxPrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionWidth_sig)(self));
    }
    pub const getResolutionHeight_sig: Signature = .{ .name = "getResolutionHeight", .this = *const BoxPrimitive, .ret = i32 };
    pub fn getResolutionHeight(self: *const BoxPrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionHeight_sig)(self));
    }
    pub const getResolutionDepth_sig: Signature = .{ .name = "getResolutionDepth", .this = *const BoxPrimitive, .ret = i32 };
    pub fn getResolutionDepth(self: *const BoxPrimitive) u32 {
        return @bitCast(cpp.bind(getResolutionDepth_sig)(self));
    }
    pub const getResolution_sig: Signature = .{ .name = "getResolution", .this = *const BoxPrimitive, .ret = GlmVec3 };
    pub fn getResolution(self: *const BoxPrimitive) Vec3 {
        return cpp.bind(getResolution_sig)(self).to();
    }
    pub const getWidth_sig: Signature = .{ .name = "getWidth", .this = *const BoxPrimitive, .ret = f32 };
    pub fn getWidth(self: *const BoxPrimitive) f32 {
        return cpp.bind(getWidth_sig)(self);
    }
    pub const getHeight_sig: Signature = .{ .name = "getHeight", .this = *const BoxPrimitive, .ret = f32 };
    pub fn getHeight(self: *const BoxPrimitive) f32 {
        return cpp.bind(getHeight_sig)(self);
    }
    pub const getDepth_sig: Signature = .{ .name = "getDepth", .this = *const BoxPrimitive, .ret = f32 };
    pub fn getDepth(self: *const BoxPrimitive) f32 {
        return cpp.bind(getDepth_sig)(self);
    }
    pub const getSize_sig: Signature = .{ .name = "getSize", .this = *const BoxPrimitive, .ret = GlmVec3 };
    pub fn getSize(self: *const BoxPrimitive) Vec3 {
        return cpp.bind(getSize_sig)(self).to();
    }
};
