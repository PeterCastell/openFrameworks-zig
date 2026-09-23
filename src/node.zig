//! ofNode.h: a transform in a scene graph, and the base of every camera,
//! light and 3D primitive in oF.
//!
//! A `Camera`, an `EasyCam`, a `Light` or a `BoxPrimitive` *is* a `Node`,
//! and reaches this API through its `node()` accessor:
//!
//! ```zig
//! cam.node().setPosition(.{ 0, 100, 300 });
//! cam.node().lookAt(.{ 0, 0, 0 });
//! ```
//!
//! The accessor is a checked upcast (`cpp.basePtr`), not a cast: cpp-bindgen
//! places every base from the class's `cpp_bases`, and the glue asserts the
//! relation against the real header. See `camera.zig` for the derived side.
//!
//! Every angle is radians and every orientation a `Quat`. oF's euler
//! setters take degrees in glm's composition order, which is not the order
//! `Transform` uses, so they are not bound; `setTransform` goes through the
//! quaternion, where neither question arises.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const matrix = @import("matrix.zig");

const Vec3 = math.Vec3;
const GlmVec3 = math.GlmVec3;
const Mat4 = matrix.Mat4;
const Quat = matrix.Quat;
const Transform = matrix.Transform;

/// `ofBaseRenderer`, the renderer interface. Only ever a pointer here, and
/// only ever null: `transformGL(null)` means the current renderer.
pub const BaseRenderer = opaque {
    pub const cpp_name = "ofBaseRenderer";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
};

/// `ofNode`.
///
/// The class holds three `ofParameter`s, a `std::set` of children and its
/// cached matrix; none of it is read from Zig, so the binding gives the
/// storage rather than the members and the glue checks the size and the
/// alignment. `_bases` is the vtable pointer, which is what a class with a
/// virtual destructor and no base of its own starts with.
///
/// A `Node` registers itself with its parent and its children by address,
/// so it cannot be copied or moved: construct it where it will live.
///
/// ```zig
/// var node: of.Node = undefined;   // a field of the app struct
/// node.init();
/// defer node.deinit();
/// ```
pub const Node = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [392]u8 align(8),

    pub const cpp_name = "ofNode";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Node };
    /// Runs `ofNode()` on the storage of `self`: identity transform, no parent.
    pub fn init(self: *Node) void {
        cpp.bind(ctor_sig)(self);
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *Node };
    pub fn deinit(self: *Node) void {
        cpp.bind(dtor_sig)(self);
    }

    // parent

    /// `setParent(parent, maintainGlobalTransform)`. The node then inherits
    /// `parent`'s transform. `parent` must outlive the link.
    pub const setParent_sig: Signature = .{ .name = "setParent", .this = *Node, .args = &.{ Ref(*Node), bool } };
    pub fn setParent(self: *Node, parent: *Node, maintain_global_transform: bool) void {
        cpp.bind(setParent_sig)(self, parent, maintain_global_transform);
    }

    pub const clearParent_sig: Signature = .{ .name = "clearParent", .this = *Node, .args = &.{bool} };
    pub fn clearParent(self: *Node, maintain_global_transform: bool) void {
        cpp.bind(clearParent_sig)(self, maintain_global_transform);
    }

    pub const getParent_sig: Signature = .{ .name = "getParent", .this = *const Node, .ret = ?*Node };
    pub fn getParent(self: *const Node) ?*Node {
        return cpp.bind(getParent_sig)(self);
    }

    // local getters

    pub const getPosition_sig: Signature = .{ .name = "getPosition", .this = *const Node, .ret = GlmVec3 };
    pub fn getPosition(self: *const Node) Vec3 {
        return cpp.bind(getPosition_sig)(self).to();
    }

    pub const getX_sig: Signature = .{ .name = "getX", .this = *const Node, .ret = f32 };
    pub fn getX(self: *const Node) f32 {
        return cpp.bind(getX_sig)(self);
    }
    pub const getY_sig: Signature = .{ .name = "getY", .this = *const Node, .ret = f32 };
    pub fn getY(self: *const Node) f32 {
        return cpp.bind(getY_sig)(self);
    }
    pub const getZ_sig: Signature = .{ .name = "getZ", .this = *const Node, .ret = f32 };
    pub fn getZ(self: *const Node) f32 {
        return cpp.bind(getZ_sig)(self);
    }

    /// The local x axis in world space, normalized.
    pub const getXAxis_sig: Signature = .{ .name = "getXAxis", .this = *const Node, .ret = GlmVec3 };
    pub fn getXAxis(self: *const Node) Vec3 {
        return cpp.bind(getXAxis_sig)(self).to();
    }
    pub const getYAxis_sig: Signature = .{ .name = "getYAxis", .this = *const Node, .ret = GlmVec3 };
    pub fn getYAxis(self: *const Node) Vec3 {
        return cpp.bind(getYAxis_sig)(self).to();
    }
    pub const getZAxis_sig: Signature = .{ .name = "getZAxis", .this = *const Node, .ret = GlmVec3 };
    pub fn getZAxis(self: *const Node) Vec3 {
        return cpp.bind(getZAxis_sig)(self).to();
    }

    /// The local x axis: the same vector as `getXAxis`.
    pub const getSideDir_sig: Signature = .{ .name = "getSideDir", .this = *const Node, .ret = GlmVec3 };
    pub fn getSideDir(self: *const Node) Vec3 {
        return cpp.bind(getSideDir_sig)(self).to();
    }
    /// The local -z axis: where the node looks.
    pub const getLookAtDir_sig: Signature = .{ .name = "getLookAtDir", .this = *const Node, .ret = GlmVec3 };
    pub fn getLookAtDir(self: *const Node) Vec3 {
        return cpp.bind(getLookAtDir_sig)(self).to();
    }
    /// The local y axis: the same vector as `getYAxis`.
    pub const getUpDir_sig: Signature = .{ .name = "getUpDir", .this = *const Node, .ret = GlmVec3 };
    pub fn getUpDir(self: *const Node) Vec3 {
        return cpp.bind(getUpDir_sig)(self).to();
    }

    /// Rotation about the local x axis, in radians.
    pub const getPitchRad_sig: Signature = .{ .name = "getPitchRad", .this = *const Node, .ret = f32 };
    pub fn getPitch(self: *const Node) f32 {
        return cpp.bind(getPitchRad_sig)(self);
    }
    /// Rotation about the local y axis, in radians. oF calls it heading.
    pub const getHeadingRad_sig: Signature = .{ .name = "getHeadingRad", .this = *const Node, .ret = f32 };
    pub fn getHeading(self: *const Node) f32 {
        return cpp.bind(getHeadingRad_sig)(self);
    }
    /// Rotation about the local z axis, in radians.
    pub const getRollRad_sig: Signature = .{ .name = "getRollRad", .this = *const Node, .ret = f32 };
    pub fn getRoll(self: *const Node) f32 {
        return cpp.bind(getRollRad_sig)(self);
    }

    pub const getOrientationQuat_sig: Signature = .{ .name = "getOrientationQuat", .this = *const Node, .ret = Quat };
    pub fn getOrientation(self: *const Node) Quat {
        return cpp.bind(getOrientationQuat_sig)(self);
    }

    pub const getScale_sig: Signature = .{ .name = "getScale", .this = *const Node, .ret = GlmVec3 };
    pub fn getScale(self: *const Node) Vec3 {
        return cpp.bind(getScale_sig)(self).to();
    }

    /// `getLocalTransformMatrix()`, which returns a reference to the cached
    /// matrix; this copies it out.
    pub const getLocalTransformMatrix_sig: Signature = .{ .name = "getLocalTransformMatrix", .this = *const Node, .ret = Ref(*const Mat4) };
    pub fn getLocalTransformMatrix(self: *const Node) Mat4 {
        return cpp.bind(getLocalTransformMatrix_sig)(self).*;
    }

    // global getters

    pub const getGlobalTransformMatrix_sig: Signature = .{ .name = "getGlobalTransformMatrix", .this = *const Node, .ret = Mat4 };
    pub fn getGlobalTransformMatrix(self: *const Node) Mat4 {
        return cpp.bind(getGlobalTransformMatrix_sig)(self);
    }
    pub const getGlobalPosition_sig: Signature = .{ .name = "getGlobalPosition", .this = *const Node, .ret = GlmVec3 };
    pub fn getGlobalPosition(self: *const Node) Vec3 {
        return cpp.bind(getGlobalPosition_sig)(self).to();
    }
    pub const getGlobalOrientation_sig: Signature = .{ .name = "getGlobalOrientation", .this = *const Node, .ret = Quat };
    pub fn getGlobalOrientation(self: *const Node) Quat {
        return cpp.bind(getGlobalOrientation_sig)(self);
    }
    pub const getGlobalScale_sig: Signature = .{ .name = "getGlobalScale", .this = *const Node, .ret = GlmVec3 };
    pub fn getGlobalScale(self: *const Node) Vec3 {
        return cpp.bind(getGlobalScale_sig)(self).to();
    }

    // setters

    /// `setPosition(const glm::vec3&)`
    pub const setPosition_sig: Signature = .{ .name = "setPosition", .this = *Node, .args = &.{Ref(*const GlmVec3)} };
    pub fn setPosition(self: *Node, p: Vec3) void {
        const g: GlmVec3 = .from(p);
        cpp.bind(setPosition_sig)(self, &g);
    }
    pub const setGlobalPosition_sig: Signature = .{ .name = "setGlobalPosition", .this = *Node, .args = &.{Ref(*const GlmVec3)} };
    pub fn setGlobalPosition(self: *Node, p: Vec3) void {
        const g: GlmVec3 = .from(p);
        cpp.bind(setGlobalPosition_sig)(self, &g);
    }
    /// `setOrientation(const glm::quat&)`
    pub const setOrientation_sig: Signature = .{ .name = "setOrientation", .this = *Node, .args = &.{Ref(*const Quat)} };
    pub fn setOrientation(self: *Node, q: Quat) void {
        cpp.bind(setOrientation_sig)(self, &q);
    }
    pub const setGlobalOrientation_sig: Signature = .{ .name = "setGlobalOrientation", .this = *Node, .args = &.{Ref(*const Quat)} };
    pub fn setGlobalOrientation(self: *Node, q: Quat) void {
        cpp.bind(setGlobalOrientation_sig)(self, &q);
    }
    /// `setScale(float)`: the same factor on every axis.
    pub const setScale_uniform_sig: Signature = .{ .name = "setScale", .this = *Node, .args = &.{f32} };
    pub fn setScaleUniform(self: *Node, s: f32) void {
        cpp.bind(setScale_uniform_sig)(self, s);
    }
    /// `setScale(const glm::vec3&)`
    pub const setScale_sig: Signature = .{ .name = "setScale", .this = *Node, .args = &.{Ref(*const GlmVec3)} };
    pub fn setScale(self: *Node, s: Vec3) void {
        const g: GlmVec3 = .from(s);
        cpp.bind(setScale_sig)(self, &g);
    }
    /// `setPositionOrientationScale(const glm::vec3&, const glm::quat&, const glm::vec3&)`
    pub const setPositionOrientationScale_sig: Signature = .{
        .name = "setPositionOrientationScale",
        .this = *Node,
        .args = &.{ Ref(*const GlmVec3), Ref(*const Quat), Ref(*const GlmVec3) },
    };
    pub fn setPositionOrientationScale(self: *Node, p: Vec3, q: Quat, s: Vec3) void {
        const gp: GlmVec3 = .from(p);
        const gs: GlmVec3 = .from(s);
        cpp.bind(setPositionOrientationScale_sig)(self, &gp, &q, &gs);
    }

    /// All three of a `Transform` at once. `Transform.rotation` is euler in
    /// this package's convention; it goes through the quaternion, so oF's
    /// own euler order never enters.
    pub fn setTransform(self: *Node, t: Transform) void {
        self.setPositionOrientationScale(t.origin, t.quat(), t.scale);
    }

    /// The local transform as a `Transform`. See `Transform.setQuat` for
    /// what a round trip through euler angles does and does not preserve.
    pub fn getTransform(self: *const Node) Transform {
        var t: Transform = .{ .origin = self.getPosition(), .scale = self.getScale() };
        t.setQuat(self.getOrientation());
        return t;
    }

    // modifiers

    /// `move(const glm::vec3&)`: a relative move in the parent's space.
    pub const move_sig: Signature = .{ .name = "move", .this = *Node, .args = &.{Ref(*const GlmVec3)} };
    pub fn move(self: *Node, offset: Vec3) void {
        const g: GlmVec3 = .from(offset);
        cpp.bind(move_sig)(self, &g);
    }
    /// Along the local x axis.
    pub const truck_sig: Signature = .{ .name = "truck", .this = *Node, .args = &.{f32} };
    pub fn truck(self: *Node, amount: f32) void {
        cpp.bind(truck_sig)(self, amount);
    }
    /// Along the local y axis.
    pub const boom_sig: Signature = .{ .name = "boom", .this = *Node, .args = &.{f32} };
    pub fn boom(self: *Node, amount: f32) void {
        cpp.bind(boom_sig)(self, amount);
    }
    /// Along the local z axis.
    pub const dolly_sig: Signature = .{ .name = "dolly", .this = *Node, .args = &.{f32} };
    pub fn dolly(self: *Node, amount: f32) void {
        cpp.bind(dolly_sig)(self, amount);
    }

    /// `tiltRad`: about the local x axis.
    pub const tiltRad_sig: Signature = .{ .name = "tiltRad", .this = *Node, .args = &.{f32} };
    pub fn tilt(self: *Node, radians: f32) void {
        cpp.bind(tiltRad_sig)(self, radians);
    }
    /// `panRad`: about the local y axis.
    pub const panRad_sig: Signature = .{ .name = "panRad", .this = *Node, .args = &.{f32} };
    pub fn pan(self: *Node, radians: f32) void {
        cpp.bind(panRad_sig)(self, radians);
    }
    /// `rollRad`: about the local z axis.
    pub const rollRad_sig: Signature = .{ .name = "rollRad", .this = *Node, .args = &.{f32} };
    pub fn roll(self: *Node, radians: f32) void {
        cpp.bind(rollRad_sig)(self, radians);
    }

    /// `rotate(const glm::quat&)`: a relative rotation.
    pub const rotate_sig: Signature = .{ .name = "rotate", .this = *Node, .args = &.{Ref(*const Quat)} };
    pub fn rotate(self: *Node, q: Quat) void {
        cpp.bind(rotate_sig)(self, &q);
    }
    /// `rotateRad(radians, const glm::vec3& axis)`
    pub const rotateRad_sig: Signature = .{ .name = "rotateRad", .this = *Node, .args = &.{ f32, Ref(*const GlmVec3) } };
    pub fn rotateAxis(self: *Node, radians: f32, axis: Vec3) void {
        const g: GlmVec3 = .from(axis);
        cpp.bind(rotateRad_sig)(self, radians, &g);
    }
    /// `rotateAround(const glm::quat&, const glm::vec3& point)`
    pub const rotateAround_sig: Signature = .{ .name = "rotateAround", .this = *Node, .args = &.{ Ref(*const Quat), Ref(*const GlmVec3) } };
    pub fn rotateAround(self: *Node, q: Quat, point: Vec3) void {
        const g: GlmVec3 = .from(point);
        cpp.bind(rotateAround_sig)(self, &q, &g);
    }
    /// `rotateAroundRad(radians, axis, point)`
    pub const rotateAroundRad_sig: Signature = .{
        .name = "rotateAroundRad",
        .this = *Node,
        .args = &.{ f32, Ref(*const GlmVec3), Ref(*const GlmVec3) },
    };
    pub fn rotateAroundAxis(self: *Node, radians: f32, axis: Vec3, point: Vec3) void {
        const ga: GlmVec3 = .from(axis);
        const gp: GlmVec3 = .from(point);
        cpp.bind(rotateAroundRad_sig)(self, radians, &ga, &gp);
    }

    /// `lookAt(const glm::vec3&)`: points the local -z axis at a global
    /// position, choosing an up vector close to the current one.
    pub const lookAt_sig: Signature = .{ .name = "lookAt", .this = *Node, .args = &.{Ref(*const GlmVec3)} };
    pub fn lookAt(self: *Node, target: Vec3) void {
        const g: GlmVec3 = .from(target);
        cpp.bind(lookAt_sig)(self, &g);
    }
    /// `lookAt(const glm::vec3&, glm::vec3 up)`: the same, with the up
    /// vector given. oF takes `up` by value.
    pub const lookAt_up_sig: Signature = .{ .name = "lookAt", .this = *Node, .args = &.{ Ref(*const GlmVec3), GlmVec3 } };
    pub fn lookAtUp(self: *Node, target: Vec3, up: Vec3) void {
        const g: GlmVec3 = .from(target);
        cpp.bind(lookAt_up_sig)(self, &g, .from(up));
    }
    /// `lookAt(const ofNode&)`
    pub const lookAt_node_sig: Signature = .{ .name = "lookAt", .this = *Node, .args = &.{Ref(*const Node)} };
    pub fn lookAtNode(self: *Node, target: *const Node) void {
        cpp.bind(lookAt_node_sig)(self, target);
    }

    /// `orbitRad(longitude, latitude, radius, const glm::vec3& center)`:
    /// places the node on a sphere about `center` and points it inward.
    pub const orbitRad_sig: Signature = .{ .name = "orbitRad", .this = *Node, .args = &.{ f32, f32, f32, Ref(*const GlmVec3) } };
    pub fn orbit(self: *Node, longitude: f32, latitude: f32, radius: f32, center: Vec3) void {
        const g: GlmVec3 = .from(center);
        cpp.bind(orbitRad_sig)(self, longitude, latitude, radius, &g);
    }
    /// `orbitRad(longitude, latitude, radius, ofNode& center)`
    pub const orbitRad_node_sig: Signature = .{ .name = "orbitRad", .this = *Node, .args = &.{ f32, f32, f32, Ref(*Node) } };
    pub fn orbitNode(self: *Node, longitude: f32, latitude: f32, radius: f32, center: *Node) void {
        cpp.bind(orbitRad_node_sig)(self, longitude, latitude, radius, center);
    }

    // GL

    /// `transformGL(nullptr)`: multiplies the node's global transform onto
    /// the current renderer's modelview, to be undone by `restoreTransformGL`.
    /// Draw calls in between happen in the node's space.
    pub const transformGL_sig: Signature = .{ .name = "transformGL", .this = *const Node, .args = &.{?*BaseRenderer} };
    pub fn transformGL(self: *const Node) void {
        cpp.bind(transformGL_sig)(self, null);
    }
    pub const restoreTransformGL_sig: Signature = .{ .name = "restoreTransformGL", .this = *const Node, .args = &.{?*BaseRenderer} };
    pub fn restoreTransformGL(self: *const Node) void {
        cpp.bind(restoreTransformGL_sig)(self, null);
    }

    /// Back to the identity: origin, no rotation, unit scale.
    pub const resetTransform_sig: Signature = .{ .name = "resetTransform", .this = *Node };
    pub fn resetTransform(self: *Node) void {
        cpp.bind(resetTransform_sig)(self);
    }

    /// `ofNode::draw()`: the node as a small white box with its axes. This is
    /// `ofNode`'s own implementation, whatever a derived class would draw;
    /// a primitive has its own `draw`.
    pub const draw_sig: Signature = .{ .name = "draw", .this = *const Node, .virtual = true };
    pub fn draw(self: *const Node) void {
        cpp.bind(draw_sig)(self);
    }
};
