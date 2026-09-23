//! ofCamera.h and ofEasyCam.h: a camera, and the mouse-driven one.
//!
//! ```zig
//! var cam: of.EasyCam = undefined;   // a field of the app struct
//! cam.init();                        // in setup
//! defer cam.deinit();                // in exit
//!
//! cam.begin();
//! of.drawGrid(50, 4, .{ .y = true, .x = false, .z = false });
//! cam.end();
//! ```
//!
//! `EasyCam` derives from `Camera`, which derives from `Node`. Each class
//! binds only the methods it declares, and the base ones are reached through
//! an accessor: `cam.camera().setFov(...)`, `cam.node().setPosition(...)`.
//! The accessor is `cpp.basePtr`, a checked upcast, and `cam.end()` is the
//! one base method bound on the derived class, because `begin`/`end` is a
//! pair. Both go through the same machinery: cpp-bindgen computes where each
//! base sits from `cpp_bases`, and the glue asserts the relation and the
//! size against the real headers.
//!
//! Field of view is in radians here, as every angle is; oF's `setFov` takes
//! degrees and the wrapper converts.
const std = @import("std");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const matrix = @import("matrix.zig");
const rectangle = @import("rectangle.zig");
const Node = @import("node.zig").Node;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const GlmVec2 = math.GlmVec2;
const GlmVec3 = math.GlmVec3;
const Mat4 = matrix.Mat4;
const Rectangle = rectangle.Rectangle;
const OfRectangle = rectangle.OfRectangle;

/// `ofCamera`: an `ofNode` with a projection.
///
/// `_bases` is the `ofNode` subobject, placed by cpp-bindgen; `_storage` is
/// what `ofCamera` adds -- its clip planes, lens offset and renderer -- as
/// bytes, since none of it is read from Zig.
pub const Camera = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [56]u8 align(8),

    pub const cpp_name = "ofCamera";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Node};
    pub const cpp_virtual_dtor = true;

    /// The `ofNode` this camera is: position, orientation, `lookAt` and the
    /// rest of `Node` are reached here.
    pub fn node(self: *Camera) *Node {
        return cpp.basePtr(Node, self);
    }
    pub fn nodeConst(self: *const Camera) *const Node {
        return cpp.basePtr(Node, self);
    }

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Camera };
    /// Runs `ofCamera()` on the storage of `self`: a perspective camera with
    /// a 60 degree field of view, at the origin, looking down -z.
    pub fn init(self: *Camera) void {
        cpp.bind(ctor_sig)(self);
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *Camera };
    pub fn deinit(self: *Camera) void {
        cpp.bind(dtor_sig)(self);
    }

    // settings

    /// `setFov(degrees)`, taking radians: the vertical field of view of a
    /// perspective camera. No effect in ortho mode.
    pub const setFov_sig: Signature = .{ .name = "setFov", .this = *Camera, .args = &.{f32} };
    pub fn setFov(self: *Camera, radians: f32) void {
        cpp.bind(setFov_sig)(self, std.math.radiansToDegrees(radians));
    }
    /// `getFov()`, in radians.
    pub const getFov_sig: Signature = .{ .name = "getFov", .this = *const Camera, .ret = f32 };
    pub fn getFov(self: *const Camera) f32 {
        return std.math.degreesToRadians(cpp.bind(getFov_sig)(self));
    }

    pub const setNearClip_sig: Signature = .{ .name = "setNearClip", .this = *Camera, .args = &.{f32} };
    pub fn setNearClip(self: *Camera, distance: f32) void {
        cpp.bind(setNearClip_sig)(self, distance);
    }
    pub const getNearClip_sig: Signature = .{ .name = "getNearClip", .this = *const Camera, .ret = f32 };
    pub fn getNearClip(self: *const Camera) f32 {
        return cpp.bind(getNearClip_sig)(self);
    }
    pub const setFarClip_sig: Signature = .{ .name = "setFarClip", .this = *Camera, .args = &.{f32} };
    pub fn setFarClip(self: *Camera, distance: f32) void {
        cpp.bind(setFarClip_sig)(self, distance);
    }
    pub const getFarClip_sig: Signature = .{ .name = "getFarClip", .this = *const Camera, .ret = f32 };
    pub fn getFarClip(self: *const Camera) f32 {
        return cpp.bind(getFarClip_sig)(self);
    }

    /// An asymmetric frustum: the projection's centre, offset from the
    /// viewport's, as a fraction of the viewport.
    pub const setLensOffset_sig: Signature = .{ .name = "setLensOffset", .this = *Camera, .args = &.{Ref(*const GlmVec2)} };
    pub fn setLensOffset(self: *Camera, offset: Vec2) void {
        const g: GlmVec2 = .from(offset);
        cpp.bind(setLensOffset_sig)(self, &g);
    }
    pub const getLensOffset_sig: Signature = .{ .name = "getLensOffset", .this = *const Camera, .ret = GlmVec2 };
    pub fn getLensOffset(self: *const Camera) Vec2 {
        return cpp.bind(getLensOffset_sig)(self).to();
    }

    /// Sets the aspect ratio and turns `setForceAspectRatio` on. Without it
    /// the camera takes the viewport's.
    pub const setAspectRatio_sig: Signature = .{ .name = "setAspectRatio", .this = *Camera, .args = &.{f32} };
    pub fn setAspectRatio(self: *Camera, ratio: f32) void {
        cpp.bind(setAspectRatio_sig)(self, ratio);
    }
    pub const getAspectRatio_sig: Signature = .{ .name = "getAspectRatio", .this = *const Camera, .ret = f32 };
    pub fn getAspectRatio(self: *const Camera) f32 {
        return cpp.bind(getAspectRatio_sig)(self);
    }
    pub const setForceAspectRatio_sig: Signature = .{ .name = "setForceAspectRatio", .this = *Camera, .args = &.{bool} };
    pub fn setForceAspectRatio(self: *Camera, force: bool) void {
        cpp.bind(setForceAspectRatio_sig)(self, force);
    }
    pub const getForceAspectRatio_sig: Signature = .{ .name = "getForceAspectRatio", .this = *const Camera, .ret = bool };
    pub fn getForceAspectRatio(self: *const Camera) bool {
        return cpp.bind(getForceAspectRatio_sig)(self);
    }

    // setup

    /// The arguments of `setupPerspective` that oF defaults.
    pub const PerspectiveOptions = struct {
        v_flip: bool = true,
        /// Vertical field of view, radians.
        fov: f32 = std.math.degreesToRadians(60.0),
        /// `0` lets oF pick a distance from the field of view and the
        /// viewport, as it does for a fresh camera.
        near_clip: f32 = 0,
        far_clip: f32 = 0,
        lens_offset: Vec2 = @splat(0),
    };
    /// `setupPerspective(vFlip, fov, nearDist, farDist, lensOffset)`: sets
    /// the projection and moves the camera to where oF's default 2D screen
    /// setup would put it, so that world units are pixels at z = 0.
    pub const setupPerspective_sig: Signature = .{
        .name = "setupPerspective",
        .this = *Camera,
        .args = &.{ bool, f32, f32, f32, Ref(*const GlmVec2) },
    };
    pub fn setupPerspective(self: *Camera, opts: PerspectiveOptions) void {
        const g: GlmVec2 = .from(opts.lens_offset);
        cpp.bind(setupPerspective_sig)(self, opts.v_flip, std.math.radiansToDegrees(opts.fov), opts.near_clip, opts.far_clip, &g);
    }

    /// `setupOffAxisViewPortal(topLeft, bottomLeft, bottomRight)`: the
    /// frustum through a rectangle in world space, for a projection onto a
    /// physical surface.
    pub const setupOffAxisViewPortal_sig: Signature = .{
        .name = "setupOffAxisViewPortal",
        .this = *Camera,
        .args = &.{ Ref(*const GlmVec3), Ref(*const GlmVec3), Ref(*const GlmVec3) },
    };
    pub fn setupOffAxisViewPortal(self: *Camera, top_left: Vec3, bottom_left: Vec3, bottom_right: Vec3) void {
        const tl: GlmVec3 = .from(top_left);
        const bl: GlmVec3 = .from(bottom_left);
        const br: GlmVec3 = .from(bottom_right);
        cpp.bind(setupOffAxisViewPortal_sig)(self, &tl, &bl, &br);
    }

    /// Whether y runs down the screen, as it does in oF's 2D default.
    pub const setVFlip_sig: Signature = .{ .name = "setVFlip", .this = *Camera, .args = &.{bool} };
    pub fn setVFlip(self: *Camera, flip: bool) void {
        cpp.bind(setVFlip_sig)(self, flip);
    }
    pub const isVFlipped_sig: Signature = .{ .name = "isVFlipped", .this = *const Camera, .ret = bool };
    pub fn isVFlipped(self: *const Camera) bool {
        return cpp.bind(isVFlipped_sig)(self);
    }

    pub const enableOrtho_sig: Signature = .{ .name = "enableOrtho", .this = *Camera };
    pub fn enableOrtho(self: *Camera) void {
        cpp.bind(enableOrtho_sig)(self);
    }
    pub const disableOrtho_sig: Signature = .{ .name = "disableOrtho", .this = *Camera };
    pub fn disableOrtho(self: *Camera) void {
        cpp.bind(disableOrtho_sig)(self);
    }
    pub const getOrtho_sig: Signature = .{ .name = "getOrtho", .this = *const Camera, .ret = bool };
    pub fn getOrtho(self: *const Camera) bool {
        return cpp.bind(getOrtho_sig)(self);
    }

    /// `getImagePlaneDistance(viewport)`: how far from the camera a plane
    /// has to be for one world unit to cover one pixel of `viewport`.
    pub const getImagePlaneDistance_sig: Signature = .{ .name = "getImagePlaneDistance", .this = *const Camera, .args = &.{Ref(*const OfRectangle)}, .ret = f32 };
    pub fn getImagePlaneDistance(self: *const Camera, viewport: Rectangle) f32 {
        var tmp: OfRectangle = undefined;
        const p = viewport.stage(&tmp);
        defer tmp.deinit();
        return cpp.bind(getImagePlaneDistance_sig)(self, p);
    }

    // rendering

    /// `begin()`: pushes the camera's view and projection onto the current
    /// renderer, over the whole window. Everything until `end` is drawn
    /// through it.
    pub const begin_sig: Signature = .{ .name = "begin", .this = *Camera, .virtual = true };
    pub fn begin(self: *Camera) void {
        cpp.bind(begin_sig)(self);
    }
    /// `begin(const ofRectangle&)`: the same, into `viewport`.
    pub const begin_viewport_sig: Signature = .{ .name = "begin", .this = *Camera, .args = &.{Ref(*const OfRectangle)}, .virtual = true };
    pub fn beginViewport(self: *Camera, viewport: Rectangle) void {
        var tmp: OfRectangle = undefined;
        const p = viewport.stage(&tmp);
        defer tmp.deinit();
        cpp.bind(begin_viewport_sig)(self, p);
    }
    pub const end_sig: Signature = .{ .name = "end", .this = *Camera, .virtual = true };
    pub fn end(self: *Camera) void {
        cpp.bind(end_sig)(self);
    }

    // matrices

    /// `getProjectionMatrix()`, for the current viewport.
    pub const getProjectionMatrix_sig: Signature = .{ .name = "getProjectionMatrix", .this = *const Camera, .ret = Mat4 };
    pub fn getProjectionMatrix(self: *const Camera) Mat4 {
        return cpp.bind(getProjectionMatrix_sig)(self);
    }
    pub const getProjectionMatrix_viewport_sig: Signature = .{ .name = "getProjectionMatrix", .this = *const Camera, .args = &.{Ref(*const OfRectangle)}, .ret = Mat4 };
    pub fn getProjectionMatrixFor(self: *const Camera, viewport: Rectangle) Mat4 {
        var tmp: OfRectangle = undefined;
        const p = viewport.stage(&tmp);
        defer tmp.deinit();
        return cpp.bind(getProjectionMatrix_viewport_sig)(self, p);
    }
    /// The inverse of the camera's global transform.
    pub const getModelViewMatrix_sig: Signature = .{ .name = "getModelViewMatrix", .this = *const Camera, .ret = Mat4 };
    pub fn getModelViewMatrix(self: *const Camera) Mat4 {
        return cpp.bind(getModelViewMatrix_sig)(self);
    }
    pub const getModelViewProjectionMatrix_sig: Signature = .{ .name = "getModelViewProjectionMatrix", .this = *const Camera, .ret = Mat4 };
    pub fn getModelViewProjectionMatrix(self: *const Camera) Mat4 {
        return cpp.bind(getModelViewProjectionMatrix_sig)(self);
    }

    // coordinate conversion, for the current viewport

    /// Where a world point lands on the window. The result's z is depth.
    pub const worldToScreen_sig: Signature = .{ .name = "worldToScreen", .this = *const Camera, .args = &.{GlmVec3}, .ret = GlmVec3 };
    pub fn worldToScreen(self: *const Camera, world: Vec3) Vec3 {
        return cpp.bind(worldToScreen_sig)(self, .from(world)).to();
    }
    /// The world point behind a window position; `screen[2]` is how far into
    /// the scene, in normalized depth.
    pub const screenToWorld_sig: Signature = .{ .name = "screenToWorld", .this = *const Camera, .args = &.{GlmVec3}, .ret = GlmVec3 };
    pub fn screenToWorld(self: *const Camera, screen: Vec3) Vec3 {
        return cpp.bind(screenToWorld_sig)(self, .from(screen)).to();
    }
    /// A world point in the camera's clip space.
    pub const worldToCamera_sig: Signature = .{ .name = "worldToCamera", .this = *const Camera, .args = &.{GlmVec3}, .ret = GlmVec3 };
    pub fn worldToCamera(self: *const Camera, world: Vec3) Vec3 {
        return cpp.bind(worldToCamera_sig)(self, .from(world)).to();
    }
    pub const cameraToWorld_sig: Signature = .{ .name = "cameraToWorld", .this = *const Camera, .args = &.{GlmVec3}, .ret = GlmVec3 };
    pub fn cameraToWorld(self: *const Camera, camera: Vec3) Vec3 {
        return cpp.bind(cameraToWorld_sig)(self, .from(camera)).to();
    }

    /// `drawFrustum()`: the camera's view volume as lines, visible when this
    /// camera is looked at through another one.
    pub const drawFrustum_sig: Signature = .{ .name = "drawFrustum", .this = *const Camera };
    pub fn drawFrustum(self: *const Camera) void {
        cpp.bind(drawFrustum_sig)(self);
    }
};

/// `ofEasyCam`: an `ofCamera` the mouse can orbit, pan and zoom. Drag with
/// the left button to rotate about the target, the right button (or the
/// wheel) to zoom, the middle button (or the left one with `m` held) to pan.
///
/// The first `begin` hooks the camera into oF's mouse events, which is why a
/// camera cannot move once constructed and is destroyed in `exit`.
pub const EasyCam = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [784]u8 align(8),

    pub const cpp_name = "ofEasyCam";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Camera};
    pub const cpp_virtual_dtor = true;

    /// The `ofCamera` this is: field of view, clip planes, projection and
    /// the coordinate conversions.
    pub fn camera(self: *EasyCam) *Camera {
        return cpp.basePtr(Camera, self);
    }
    pub fn cameraConst(self: *const EasyCam) *const Camera {
        return cpp.basePtr(Camera, self);
    }
    /// The `ofNode` this is, two levels up.
    pub fn node(self: *EasyCam) *Node {
        return cpp.basePtr(Node, self);
    }
    pub fn nodeConst(self: *const EasyCam) *const Node {
        return cpp.basePtr(Node, self);
    }

    /// `ofEasyCam::TransformType`: what a mouse button (and key) does.
    pub const TransformType = enum(i32) {
        none = 0,
        rotate = 1,
        translate_xy = 2,
        translate_z = 3,
        scale = 4,
        pub const cpp_name = "ofEasyCam::TransformType";
        pub const cpp_kind: cpp.Kind = .@"enum";
    };

    pub const ctor_sig: Signature = .{ .name = "*", .this = *EasyCam };
    /// Runs `ofEasyCam()` on the storage of `self`: the camera looks at the
    /// origin from a distance that will fit the window, with the default
    /// mouse interactions.
    pub fn init(self: *EasyCam) void {
        cpp.bind(ctor_sig)(self);
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *EasyCam };
    pub fn deinit(self: *EasyCam) void {
        cpp.bind(dtor_sig)(self);
    }

    // rendering

    /// `ofEasyCam::begin()`: `Camera.begin`, after wiring the mouse the first
    /// time and remembering the viewport for it.
    pub const begin_sig: Signature = .{ .name = "begin", .this = *EasyCam, .virtual = true };
    pub fn begin(self: *EasyCam) void {
        cpp.bind(begin_sig)(self);
    }
    pub const begin_viewport_sig: Signature = .{ .name = "begin", .this = *EasyCam, .args = &.{Ref(*const OfRectangle)}, .virtual = true };
    pub fn beginViewport(self: *EasyCam, viewport: Rectangle) void {
        var tmp: OfRectangle = undefined;
        const p = viewport.stage(&tmp);
        defer tmp.deinit();
        cpp.bind(begin_viewport_sig)(self, p);
    }
    /// `ofCamera::end()`, which `ofEasyCam` does not override: bound here
    /// through the base so that `begin` and `end` sit together. `.class`
    /// names the base and cpp-bindgen checks it is one.
    pub const end_sig: Signature = .{ .name = "end", .class = Camera, .this = *EasyCam, .virtual = true };
    pub fn end(self: *EasyCam) void {
        cpp.bind(end_sig)(self);
    }

    /// Back to the starting view: the target at the origin, the camera on
    /// +z at its distance, no rotation.
    pub const reset_sig: Signature = .{ .name = "reset", .this = *EasyCam };
    pub fn reset(self: *EasyCam) void {
        cpp.bind(reset_sig)(self);
    }

    // target

    /// `setTarget(const glm::vec3&)`: what the camera orbits and looks at.
    pub const setTarget_sig: Signature = .{ .name = "setTarget", .this = *EasyCam, .args = &.{Ref(*const GlmVec3)} };
    pub fn setTarget(self: *EasyCam, target: Vec3) void {
        const g: GlmVec3 = .from(target);
        cpp.bind(setTarget_sig)(self, &g);
    }
    /// `setTarget(ofNode&)`: the camera's own target node becomes a child
    /// of `target` and follows it. `target` must outlive the link.
    pub const setTarget_node_sig: Signature = .{ .name = "setTarget", .this = *EasyCam, .args = &.{Ref(*Node)} };
    pub fn setTargetNode(self: *EasyCam, target: *Node) void {
        cpp.bind(setTarget_node_sig)(self, target);
    }
    /// The camera's own target node, which `setTarget` positions.
    pub const getTarget_sig: Signature = .{ .name = "getTarget", .this = *const EasyCam, .ret = Ref(*const Node) };
    pub fn getTarget(self: *const EasyCam) *const Node {
        return cpp.bind(getTarget_sig)(self);
    }

    /// Distance from the target. Turns `setAutoDistance` off.
    pub const setDistance_sig: Signature = .{ .name = "setDistance", .this = *EasyCam, .args = &.{f32} };
    pub fn setDistance(self: *EasyCam, distance: f32) void {
        cpp.bind(setDistance_sig)(self, distance);
    }
    pub const getDistance_sig: Signature = .{ .name = "getDistance", .this = *const EasyCam, .ret = f32 };
    pub fn getDistance(self: *const EasyCam) f32 {
        return cpp.bind(getDistance_sig)(self);
    }

    /// How quickly the camera coasts to a stop after a drag with inertia
    /// on, in `[0, 1]`. oF starts at 0.9.
    pub const setDrag_sig: Signature = .{ .name = "setDrag", .this = *EasyCam, .args = &.{f32} };
    pub fn setDrag(self: *EasyCam, drag: f32) void {
        cpp.bind(setDrag_sig)(self, drag);
    }
    pub const getDrag_sig: Signature = .{ .name = "getDrag", .this = *const EasyCam, .ret = f32 };
    pub fn getDrag(self: *const EasyCam) f32 {
        return cpp.bind(getDrag_sig)(self);
    }

    /// Whether the first `begin` picks a distance that fits the viewport.
    /// On until `setDistance` is called.
    pub const setAutoDistance_sig: Signature = .{ .name = "setAutoDistance", .this = *EasyCam, .args = &.{bool} };
    pub fn setAutoDistance(self: *EasyCam, auto: bool) void {
        cpp.bind(setAutoDistance_sig)(self, auto);
    }

    // sensitivity

    /// Rotation per mouse movement, per axis: at 1 a drag across the
    /// arcball is half a turn.
    pub const setRotationSensitivity_sig: Signature = .{ .name = "setRotationSensitivity", .this = *EasyCam, .args = &.{Ref(*const GlmVec3)} };
    pub fn setRotationSensitivity(self: *EasyCam, sensitivity: Vec3) void {
        const g: GlmVec3 = .from(sensitivity);
        cpp.bind(setRotationSensitivity_sig)(self, &g);
    }
    pub const setTranslationSensitivity_sig: Signature = .{ .name = "setTranslationSensitivity", .this = *EasyCam, .args = &.{Ref(*const GlmVec3)} };
    pub fn setTranslationSensitivity(self: *EasyCam, sensitivity: Vec3) void {
        const g: GlmVec3 = .from(sensitivity);
        cpp.bind(setTranslationSensitivity_sig)(self, &g);
    }

    /// The key that turns a left drag into a pan. oF starts at `'m'`.
    pub const setTranslationKey_sig: Signature = .{ .name = "setTranslationKey", .this = *EasyCam, .args = &.{u8} };
    pub fn setTranslationKey(self: *EasyCam, key: u8) void {
        cpp.bind(setTranslationKey_sig)(self, key);
    }
    pub const getTranslationKey_sig: Signature = .{ .name = "getTranslationKey", .this = *const EasyCam, .ret = u8 };
    pub fn getTranslationKey(self: *const EasyCam) u8 {
        return cpp.bind(getTranslationKey_sig)(self);
    }

    // mouse

    pub const enableMouseInput_sig: Signature = .{ .name = "enableMouseInput", .this = *EasyCam };
    pub fn enableMouseInput(self: *EasyCam) void {
        cpp.bind(enableMouseInput_sig)(self);
    }
    pub const disableMouseInput_sig: Signature = .{ .name = "disableMouseInput", .this = *EasyCam };
    pub fn disableMouseInput(self: *EasyCam) void {
        cpp.bind(disableMouseInput_sig)(self);
    }
    pub const getMouseInputEnabled_sig: Signature = .{ .name = "getMouseInputEnabled", .this = *const EasyCam, .ret = bool };
    pub fn getMouseInputEnabled(self: *const EasyCam) bool {
        return cpp.bind(getMouseInputEnabled_sig)(self);
    }

    pub const enableMouseMiddleButton_sig: Signature = .{ .name = "enableMouseMiddleButton", .this = *EasyCam };
    pub fn enableMouseMiddleButton(self: *EasyCam) void {
        cpp.bind(enableMouseMiddleButton_sig)(self);
    }
    pub const disableMouseMiddleButton_sig: Signature = .{ .name = "disableMouseMiddleButton", .this = *EasyCam };
    pub fn disableMouseMiddleButton(self: *EasyCam) void {
        cpp.bind(disableMouseMiddleButton_sig)(self);
    }
    pub const getMouseMiddleButtonEnabled_sig: Signature = .{ .name = "getMouseMiddleButtonEnabled", .this = *const EasyCam, .ret = bool };
    pub fn getMouseMiddleButtonEnabled(self: *const EasyCam) bool {
        return cpp.bind(getMouseMiddleButtonEnabled_sig)(self);
    }

    /// Whether a drag rotates about the camera's own y axis rather than the
    /// fixed up axis.
    pub const setRelativeYAxis_sig: Signature = .{ .name = "setRelativeYAxis", .this = *EasyCam, .args = &.{bool} };
    pub fn setRelativeYAxis(self: *EasyCam, relative: bool) void {
        cpp.bind(setRelativeYAxis_sig)(self, relative);
    }
    pub const getRelativeYAxis_sig: Signature = .{ .name = "getRelativeYAxis", .this = *const EasyCam, .ret = bool };
    pub fn getRelativeYAxis(self: *const EasyCam) bool {
        return cpp.bind(getRelativeYAxis_sig)(self);
    }

    /// The fixed up axis a drag rotates about. oF starts at `{0, 1, 0}`.
    pub const setUpAxis_sig: Signature = .{ .name = "setUpAxis", .this = *EasyCam, .args = &.{Ref(*const GlmVec3)} };
    pub fn setUpAxis(self: *EasyCam, up: Vec3) void {
        const g: GlmVec3 = .from(up);
        cpp.bind(setUpAxis_sig)(self, &g);
    }
    pub const getUpAxis_sig: Signature = .{ .name = "getUpAxis", .this = *const EasyCam, .ret = Ref(*const GlmVec3) };
    pub fn getUpAxis(self: *const EasyCam) Vec3 {
        return cpp.bind(getUpAxis_sig)(self).to();
    }

    pub const enableInertia_sig: Signature = .{ .name = "enableInertia", .this = *EasyCam };
    pub fn enableInertia(self: *EasyCam) void {
        cpp.bind(enableInertia_sig)(self);
    }
    pub const disableInertia_sig: Signature = .{ .name = "disableInertia", .this = *EasyCam };
    pub fn disableInertia(self: *EasyCam) void {
        cpp.bind(disableInertia_sig)(self);
    }
    pub const getInertiaEnabled_sig: Signature = .{ .name = "getInertiaEnabled", .this = *const EasyCam, .ret = bool };
    pub fn getInertiaEnabled(self: *const EasyCam) bool {
        return cpp.bind(getInertiaEnabled_sig)(self);
    }

    /// The part of the window a drag must start in to move the camera.
    /// The whole viewport until this is set.
    pub const setControlArea_sig: Signature = .{ .name = "setControlArea", .this = *EasyCam, .args = &.{Ref(*const OfRectangle)} };
    pub fn setControlArea(self: *EasyCam, area: Rectangle) void {
        var tmp: OfRectangle = undefined;
        const p = area.stage(&tmp);
        defer tmp.deinit();
        cpp.bind(setControlArea_sig)(self, p);
    }
    pub const clearControlArea_sig: Signature = .{ .name = "clearControlArea", .this = *EasyCam };
    pub fn clearControlArea(self: *EasyCam) void {
        cpp.bind(clearControlArea_sig)(self);
    }
    pub const getControlArea_sig: Signature = .{ .name = "getControlArea", .this = *const EasyCam, .ret = OfRectangle };
    pub fn getControlArea(self: *const EasyCam) Rectangle {
        var box: OfRectangle = undefined;
        cpp.bind(getControlArea_sig)(&box, self);
        defer box.deinit();
        return .fromOf(box);
    }

    // interactions

    /// `addInteraction(type, mouseButton, key)`: `button` is one of
    /// `of.mouse_button`, `key` a character or `-1` for none.
    pub const addInteraction_sig: Signature = .{ .name = "addInteraction", .this = *EasyCam, .args = &.{ TransformType, i32, i32 } };
    pub fn addInteraction(self: *EasyCam, kind: TransformType, button: i32, key: i32) void {
        cpp.bind(addInteraction_sig)(self, kind, button, key);
    }
    pub const removeInteraction_sig: Signature = .{ .name = "removeInteraction", .this = *EasyCam, .args = &.{ TransformType, i32, i32 } };
    pub fn removeInteraction(self: *EasyCam, kind: TransformType, button: i32, key: i32) void {
        cpp.bind(removeInteraction_sig)(self, kind, button, key);
    }
    pub const hasInteraction_sig: Signature = .{ .name = "hasInteraction", .this = *EasyCam, .args = &.{ TransformType, i32, i32 }, .ret = bool };
    pub fn hasInteraction(self: *EasyCam, kind: TransformType, button: i32, key: i32) bool {
        return cpp.bind(hasInteraction_sig)(self, kind, button, key);
    }
    pub const removeAllInteractions_sig: Signature = .{ .name = "removeAllInteractions", .this = *EasyCam };
    pub fn removeAllInteractions(self: *EasyCam) void {
        cpp.bind(removeAllInteractions_sig)(self);
    }
};
