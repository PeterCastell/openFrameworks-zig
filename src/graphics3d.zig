//! of3dGraphics.h and of3dUtils.h: the immediate-mode 3D drawing calls.
//!
//! Each solid comes in two forms: at the origin of the current matrix
//! (`drawBox(w, h, d)`), and at a point (`drawBoxAt(p, w, h, d)`). oF also
//! spells every one as `x, y, [z,] ...` floats; those are the `At` form with
//! the vector unpacked, so they are not bound twice.
//!
//! Every solid is drawn with the resolution the matching `set*Resolution`
//! last set, in the current color and fill mode.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const GlmVec2 = math.GlmVec2;
const GlmVec3 = math.GlmVec3;

// axes and grids

/// `ofDrawAxis(size)`: the positive x, y and z axes in red, green and blue.
pub const ofDrawAxis_sig: Signature = .{ .name = "ofDrawAxis", .args = &.{f32} };
pub fn drawAxis(size: f32) void {
    cpp.bind(ofDrawAxis_sig)(size);
}

/// Which of `drawGrid`'s three planes to draw, and whether to label them.
pub const GridOptions = struct {
    /// Numbers along each axis, drawn with `drawBitmapString`.
    labels: bool = false,
    /// The yz plane, at x = 0, in red.
    x: bool = true,
    /// The xz plane, at y = 0, in green.
    y: bool = true,
    /// The xy plane, at z = 0, in blue.
    z: bool = true,
};
/// `ofDrawGrid(stepSize, numberOfSteps, labels, x, y, z)`: up to three
/// grid planes through the origin, `steps` lines each side of the axis,
/// `step_size` apart.
pub const ofDrawGrid_sig: Signature = .{ .name = "ofDrawGrid", .args = &.{ f32, usize, bool, bool, bool, bool } };
pub fn drawGrid(step_size: f32, steps: u32, opts: GridOptions) void {
    cpp.bind(ofDrawGrid_sig)(step_size, steps, opts.labels, opts.x, opts.y, opts.z);
}

/// `ofDrawGridPlane(stepSize, numberOfSteps, labels)`: the yz plane alone,
/// in the current color.
pub const ofDrawGridPlane_sig: Signature = .{ .name = "ofDrawGridPlane", .args = &.{ f32, usize, bool } };
pub fn drawGridPlane(step_size: f32, steps: u32, labels: bool) void {
    cpp.bind(ofDrawGridPlane_sig)(step_size, steps, labels);
}

/// `ofDrawArrow(start, end, headSize)`: a line with a cone at `end`.
pub const ofDrawArrow_sig: Signature = .{ .name = "ofDrawArrow", .args = &.{ Ref(*const GlmVec3), Ref(*const GlmVec3), f32 } };
pub fn drawArrow(start: Vec3, end: Vec3, head_size: f32) void {
    const s: GlmVec3 = .from(start);
    const e: GlmVec3 = .from(end);
    cpp.bind(ofDrawArrow_sig)(&s, &e, head_size);
}

/// `ofDrawRotationAxes(radius, stripWidth, circleRes)`: three rings about
/// the axes, in red, green and blue.
pub const ofDrawRotationAxes_sig: Signature = .{ .name = "ofDrawRotationAxes", .args = &.{ f32, f32, i32 } };
pub fn drawRotationAxes(radius: f32, strip_width: f32, circle_resolution: u32) void {
    cpp.bind(ofDrawRotationAxes_sig)(radius, strip_width, @bitCast(circle_resolution));
}

// planes

pub const ofSetPlaneResolution_sig: Signature = .{ .name = "ofSetPlaneResolution", .args = &.{ i32, i32 } };
pub fn setPlaneResolution(columns: u32, rows: u32) void {
    cpp.bind(ofSetPlaneResolution_sig)(@bitCast(columns), @bitCast(rows));
}
/// Columns, rows.
pub const ofGetPlaneResolution_sig: Signature = .{ .name = "ofGetPlaneResolution", .ret = GlmVec2 };
pub fn getPlaneResolution() Vec2 {
    return cpp.bind(ofGetPlaneResolution_sig)().to();
}
/// `ofDrawPlane(width, height)`: in the xy plane, centred on the origin.
pub const ofDrawPlane_sig: Signature = .{ .name = "ofDrawPlane", .args = &.{ f32, f32 } };
pub fn drawPlane(width: f32, height: f32) void {
    cpp.bind(ofDrawPlane_sig)(width, height);
}
/// `ofDrawPlane(const glm::vec3& center, width, height)`
pub const ofDrawPlane_at_sig: Signature = .{ .name = "ofDrawPlane", .args = &.{ Ref(*const GlmVec3), f32, f32 } };
pub fn drawPlaneAt(center: Vec3, width: f32, height: f32) void {
    const c: GlmVec3 = .from(center);
    cpp.bind(ofDrawPlane_at_sig)(&c, width, height);
}

// spheres

pub const ofSetSphereResolution_sig: Signature = .{ .name = "ofSetSphereResolution", .args = &.{i32} };
pub fn setSphereResolution(resolution: u32) void {
    cpp.bind(ofSetSphereResolution_sig)(@bitCast(resolution));
}
pub const ofGetSphereResolution_sig: Signature = .{ .name = "ofGetSphereResolution", .ret = i32 };
pub fn getSphereResolution() u32 {
    return @bitCast(cpp.bind(ofGetSphereResolution_sig)());
}
/// `ofDrawSphere(radius)`: centred on the origin.
pub const ofDrawSphere_sig: Signature = .{ .name = "ofDrawSphere", .args = &.{f32} };
pub fn drawSphere(radius: f32) void {
    cpp.bind(ofDrawSphere_sig)(radius);
}
/// `ofDrawSphere(const glm::vec3& center, radius)`
pub const ofDrawSphere_at_sig: Signature = .{ .name = "ofDrawSphere", .args = &.{ Ref(*const GlmVec3), f32 } };
pub fn drawSphereAt(center: Vec3, radius: f32) void {
    const c: GlmVec3 = .from(center);
    cpp.bind(ofDrawSphere_at_sig)(&c, radius);
}

pub const ofSetIcoSphereResolution_sig: Signature = .{ .name = "ofSetIcoSphereResolution", .args = &.{i32} };
pub fn setIcoSphereResolution(resolution: u32) void {
    cpp.bind(ofSetIcoSphereResolution_sig)(@bitCast(resolution));
}
pub const ofGetIcoSphereResolution_sig: Signature = .{ .name = "ofGetIcoSphereResolution", .ret = i32 };
pub fn getIcoSphereResolution() u32 {
    return @bitCast(cpp.bind(ofGetIcoSphereResolution_sig)());
}
/// `ofDrawIcoSphere(radius)`: centred on the origin.
pub const ofDrawIcoSphere_sig: Signature = .{ .name = "ofDrawIcoSphere", .args = &.{f32} };
pub fn drawIcoSphere(radius: f32) void {
    cpp.bind(ofDrawIcoSphere_sig)(radius);
}
/// `ofDrawIcoSphere(const glm::vec3& center, radius)`
pub const ofDrawIcoSphere_at_sig: Signature = .{ .name = "ofDrawIcoSphere", .args = &.{ Ref(*const GlmVec3), f32 } };
pub fn drawIcoSphereAt(center: Vec3, radius: f32) void {
    const c: GlmVec3 = .from(center);
    cpp.bind(ofDrawIcoSphere_at_sig)(&c, radius);
}

// cylinders

/// `ofSetCylinderResolution(radiusSegments, heightSegments, capSegments)`
pub const ofSetCylinderResolution_sig: Signature = .{ .name = "ofSetCylinderResolution", .args = &.{ i32, i32, i32 } };
pub fn setCylinderResolution(radius_segments: u32, height_segments: u32, cap_segments: u32) void {
    cpp.bind(ofSetCylinderResolution_sig)(@bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments));
}
/// Radius, height and cap segments.
pub const ofGetCylinderResolution_sig: Signature = .{ .name = "ofGetCylinderResolution", .ret = GlmVec3 };
pub fn getCylinderResolution() Vec3 {
    return cpp.bind(ofGetCylinderResolution_sig)().to();
}
/// `ofDrawCylinder(radius, height)`: along y, centred on the origin.
pub const ofDrawCylinder_sig: Signature = .{ .name = "ofDrawCylinder", .args = &.{ f32, f32 } };
pub fn drawCylinder(radius: f32, height: f32) void {
    cpp.bind(ofDrawCylinder_sig)(radius, height);
}
/// `ofDrawCylinder(const glm::vec3& center, radius, height)`
pub const ofDrawCylinder_at_sig: Signature = .{ .name = "ofDrawCylinder", .args = &.{ Ref(*const GlmVec3), f32, f32 } };
pub fn drawCylinderAt(center: Vec3, radius: f32, height: f32) void {
    const c: GlmVec3 = .from(center);
    cpp.bind(ofDrawCylinder_at_sig)(&c, radius, height);
}

// cones

/// `ofSetConeResolution(radiusSegments, heightSegments, capSegments)`
pub const ofSetConeResolution_sig: Signature = .{ .name = "ofSetConeResolution", .args = &.{ i32, i32, i32 } };
pub fn setConeResolution(radius_segments: u32, height_segments: u32, cap_segments: u32) void {
    cpp.bind(ofSetConeResolution_sig)(@bitCast(radius_segments), @bitCast(height_segments), @bitCast(cap_segments));
}
/// Radius, height and cap segments.
pub const ofGetConeResolution_sig: Signature = .{ .name = "ofGetConeResolution", .ret = GlmVec3 };
pub fn getConeResolution() Vec3 {
    return cpp.bind(ofGetConeResolution_sig)().to();
}
/// `ofDrawCone(radius, height)`: along y, apex up, centred on the origin.
pub const ofDrawCone_sig: Signature = .{ .name = "ofDrawCone", .args = &.{ f32, f32 } };
pub fn drawCone(radius: f32, height: f32) void {
    cpp.bind(ofDrawCone_sig)(radius, height);
}
/// `ofDrawCone(const glm::vec3& center, radius, height)`
pub const ofDrawCone_at_sig: Signature = .{ .name = "ofDrawCone", .args = &.{ Ref(*const GlmVec3), f32, f32 } };
pub fn drawConeAt(center: Vec3, radius: f32, height: f32) void {
    const c: GlmVec3 = .from(center);
    cpp.bind(ofDrawCone_at_sig)(&c, radius, height);
}

// boxes

/// `ofSetBoxResolution(res)`: the same on every side.
pub const ofSetBoxResolution_sig: Signature = .{ .name = "ofSetBoxResolution", .args = &.{i32} };
pub fn setBoxResolution(resolution: u32) void {
    cpp.bind(ofSetBoxResolution_sig)(@bitCast(resolution));
}
/// `ofSetBoxResolution(resWidth, resHeight, resDepth)`
pub const ofSetBoxResolution_3_sig: Signature = .{ .name = "ofSetBoxResolution", .args = &.{ i32, i32, i32 } };
pub fn setBoxResolution3(res_width: u32, res_height: u32, res_depth: u32) void {
    cpp.bind(ofSetBoxResolution_3_sig)(@bitCast(res_width), @bitCast(res_height), @bitCast(res_depth));
}
/// Width, height and depth subdivisions.
pub const ofGetBoxResolution_sig: Signature = .{ .name = "ofGetBoxResolution", .ret = GlmVec3 };
pub fn getBoxResolution() Vec3 {
    return cpp.bind(ofGetBoxResolution_sig)().to();
}
/// `ofDrawBox(width, height, depth)`: centred on the origin.
pub const ofDrawBox_sig: Signature = .{ .name = "ofDrawBox", .args = &.{ f32, f32, f32 } };
pub fn drawBox(width: f32, height: f32, depth: f32) void {
    cpp.bind(ofDrawBox_sig)(width, height, depth);
}
/// `ofDrawBox(const glm::vec3& center, width, height, depth)`
pub const ofDrawBox_at_sig: Signature = .{ .name = "ofDrawBox", .args = &.{ Ref(*const GlmVec3), f32, f32, f32 } };
pub fn drawBoxAt(center: Vec3, width: f32, height: f32, depth: f32) void {
    const c: GlmVec3 = .from(center);
    cpp.bind(ofDrawBox_at_sig)(&c, width, height, depth);
}
/// `ofDrawBox(size)`: a cube centred on the origin.
pub const ofDrawBox_cube_sig: Signature = .{ .name = "ofDrawBox", .args = &.{f32} };
pub fn drawCube(size: f32) void {
    cpp.bind(ofDrawBox_cube_sig)(size);
}
/// `ofDrawBox(const glm::vec3& center, size)`
pub const ofDrawBox_cube_at_sig: Signature = .{ .name = "ofDrawBox", .args = &.{ Ref(*const GlmVec3), f32 } };
pub fn drawCubeAt(center: Vec3, size: f32) void {
    const c: GlmVec3 = .from(center);
    cpp.bind(ofDrawBox_cube_at_sig)(&c, size);
}
