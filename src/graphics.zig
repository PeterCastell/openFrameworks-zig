//! ofGraphics.h: the immediate-mode 2D drawing calls.
//!
//! Every call taking coordinates also has an `i` variant taking integer
//! pixels, where positions are `i32` and extents `u32` to match `getMouseX`
//! and `getWidth`, so the screen queries compose without a cast.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const Color = @import("color.zig").Color;
const FloatColor = @import("color.zig").FloatColor;
const math = @import("math.zig");
const Vec2 = math.Vec2;
const Vec2I = math.Vec2I;
const GlmVec2 = math.GlmVec2;
const String = @import("string.zig").String;
const Mat4 = @import("matrix.zig").Mat4;

/// `ofRectMode`
pub const RectMode = enum(i32) {
    corner = 0,
    center = 1,
    pub const cpp_name = "ofRectMode";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

// background / color

/// `ofBackground(color)`
pub const ofBackground_sig: Signature = .{ .name = "ofBackground", .args = &.{Ref(*const Color)} };
pub fn background(c: Color) void {
    cpp.bind(ofBackground_sig)(&c);
}
/// `ofBackground(grey, 255)`
pub const ofBackground_grey_sig: Signature = .{ .name = "ofBackground", .args = &.{ i32, i32 } };
pub fn backgroundGrey(v: u32) void {
    cpp.bind(ofBackground_grey_sig)(@bitCast(v), 255);
}
pub const ofSetBackgroundAuto_sig: Signature = .{ .name = "ofSetBackgroundAuto", .args = &.{bool} };
pub fn setBackgroundAuto(on: bool) void {
    cpp.bind(ofSetBackgroundAuto_sig)(on);
}
/// `ofClear(color)`
pub const ofClear_sig: Signature = .{ .name = "ofClear", .args = &.{Ref(*const Color)} };
pub fn clear(c: Color) void {
    cpp.bind(ofClear_sig)(&c);
}
/// `ofSetColor(color)`
pub const ofSetColor_sig: Signature = .{ .name = "ofSetColor", .args = &.{Ref(*const Color)} };
pub fn setColor(c: Color) void {
    cpp.bind(ofSetColor_sig)(&c);
}
/// `ofSetColor(color, alpha)`
pub const ofSetColor_alpha_sig: Signature = .{ .name = "ofSetColor", .args = &.{ Ref(*const Color), i32 } };
pub fn setColorAlpha(c: Color, alpha: u32) void {
    cpp.bind(ofSetColor_alpha_sig)(&c, @bitCast(alpha));
}
/// `ofSetColor(floatColor)`
pub const ofSetColor_float_sig: Signature = .{ .name = "ofSetColor", .args = &.{Ref(*const FloatColor)} };
pub fn setFloatColor(c: FloatColor) void {
    cpp.bind(ofSetColor_float_sig)(&c);
}
/// `ofSetColor(grey)`
pub const ofSetColor_grey_sig: Signature = .{ .name = "ofSetColor", .args = &.{i32} };
pub fn setColorGrey(v: u32) void {
    cpp.bind(ofSetColor_grey_sig)(@bitCast(v));
}

// fill / stroke state

pub const ofFill_sig: Signature = .{ .name = "ofFill" };
pub fn fill() void {
    cpp.bind(ofFill_sig)();
}
pub const ofNoFill_sig: Signature = .{ .name = "ofNoFill" };
pub fn noFill() void {
    cpp.bind(ofNoFill_sig)();
}
pub const ofSetLineWidth_sig: Signature = .{ .name = "ofSetLineWidth", .args = &.{f32} };
pub fn setLineWidth(w: f32) void {
    cpp.bind(ofSetLineWidth_sig)(w);
}
pub const ofSetCircleResolution_sig: Signature = .{ .name = "ofSetCircleResolution", .args = &.{i32} };
pub fn setCircleResolution(n: u32) void {
    cpp.bind(ofSetCircleResolution_sig)(@bitCast(n));
}
pub const ofSetRectMode_sig: Signature = .{ .name = "ofSetRectMode", .args = &.{RectMode} };
pub fn setRectMode(mode: RectMode) void {
    cpp.bind(ofSetRectMode_sig)(mode);
}

// shapes

pub const ofDrawRectangle_sig: Signature = .{ .name = "ofDrawRectangle", .args = &.{ f32, f32, f32, f32 } };
pub fn drawRectangle(x: f32, y: f32, w: f32, h: f32) void {
    cpp.bind(ofDrawRectangle_sig)(x, y, w, h);
}
pub fn drawRectanglei(x: i32, y: i32, w: u32, h: u32) void {
    drawRectangle(@floatFromInt(x), @floatFromInt(y), @floatFromInt(w), @floatFromInt(h));
}
/// `ofDrawRectangle(const glm::vec2&, w, h)`. This is what the `ofRectangle`
/// overload calls into after hardcoding z to zero, so `Rectangle.draw` uses
/// it and no `ofRectangle` has to be built.
pub const ofDrawRectangle_vec2_sig: Signature = .{ .name = "ofDrawRectangle", .args = &.{ Ref(*const GlmVec2), f32, f32 } };
pub fn drawRectangleAt(p: Vec2, w: f32, h: f32) void {
    const g: GlmVec2 = .from(p);
    cpp.bind(ofDrawRectangle_vec2_sig)(&g, w, h);
}
pub fn drawRectangleAti(p: Vec2I, w: u32, h: u32) void {
    drawRectangleAt(@floatFromInt(p), @floatFromInt(w), @floatFromInt(h));
}
pub const ofDrawRectRounded_sig: Signature = .{ .name = "ofDrawRectRounded", .args = &.{ f32, f32, f32, f32, f32 } };
pub fn drawRectRounded(x: f32, y: f32, w: f32, h: f32, radius: f32) void {
    cpp.bind(ofDrawRectRounded_sig)(x, y, w, h, radius);
}
pub fn drawRectRoundedi(x: i32, y: i32, w: u32, h: u32, radius: u32) void {
    drawRectRounded(@floatFromInt(x), @floatFromInt(y), @floatFromInt(w), @floatFromInt(h), @floatFromInt(radius));
}
pub const ofDrawCircle_sig: Signature = .{ .name = "ofDrawCircle", .args = &.{ f32, f32, f32 } };
pub fn drawCircle(x: f32, y: f32, radius: f32) void {
    cpp.bind(ofDrawCircle_sig)(x, y, radius);
}
pub fn drawCirclei(x: i32, y: i32, radius: u32) void {
    drawCircle(@floatFromInt(x), @floatFromInt(y), @floatFromInt(radius));
}
pub const ofDrawCircle_vec2_sig: Signature = .{ .name = "ofDrawCircle", .args = &.{ Ref(*const GlmVec2), f32 } };
pub fn drawCircleAt(center: Vec2, radius: f32) void {
    const c: GlmVec2 = .from(center);
    cpp.bind(ofDrawCircle_vec2_sig)(&c, radius);
}
pub fn drawCircleAti(center: Vec2I, radius: u32) void {
    drawCircleAt(@floatFromInt(center), @floatFromInt(radius));
}
pub const ofDrawEllipse_sig: Signature = .{ .name = "ofDrawEllipse", .args = &.{ f32, f32, f32, f32 } };
pub fn drawEllipse(x: f32, y: f32, w: f32, h: f32) void {
    cpp.bind(ofDrawEllipse_sig)(x, y, w, h);
}
pub fn drawEllipsei(x: i32, y: i32, w: u32, h: u32) void {
    drawEllipse(@floatFromInt(x), @floatFromInt(y), @floatFromInt(w), @floatFromInt(h));
}
pub const ofDrawLine_sig: Signature = .{ .name = "ofDrawLine", .args = &.{ f32, f32, f32, f32 } };
pub fn drawLine(x1: f32, y1: f32, x2: f32, y2: f32) void {
    cpp.bind(ofDrawLine_sig)(x1, y1, x2, y2);
}
pub fn drawLinei(x1: i32, y1: i32, x2: i32, y2: i32) void {
    drawLine(@floatFromInt(x1), @floatFromInt(y1), @floatFromInt(x2), @floatFromInt(y2));
}
pub const ofDrawLine_vec2_sig: Signature = .{ .name = "ofDrawLine", .args = &.{ Ref(*const GlmVec2), Ref(*const GlmVec2) } };
pub fn drawLineBetween(a: Vec2, b: Vec2) void {
    const ga: GlmVec2 = .from(a);
    const gb: GlmVec2 = .from(b);
    cpp.bind(ofDrawLine_vec2_sig)(&ga, &gb);
}
pub fn drawLineBetweeni(a: Vec2I, b: Vec2I) void {
    drawLineBetween(@floatFromInt(a), @floatFromInt(b));
}
pub const ofDrawTriangle_sig: Signature = .{ .name = "ofDrawTriangle", .args = &.{ f32, f32, f32, f32, f32, f32 } };
pub fn drawTriangle(x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32) void {
    cpp.bind(ofDrawTriangle_sig)(x1, y1, x2, y2, x3, y3);
}
pub fn drawTrianglei(x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32) void {
    drawTriangle(@floatFromInt(x1), @floatFromInt(y1), @floatFromInt(x2), @floatFromInt(y2), @floatFromInt(x3), @floatFromInt(y3));
}

/// `ofDrawBitmapMode`: where `drawBitmapString` puts its text. oF starts in
/// `.screen`.
pub const DrawBitmapMode = enum(i32) {
    /// 2D only: z is discarded, so a nonzero z draws in the wrong place.
    simple = 0,
    /// Projects the 3D position onto the window. The letters keep one size.
    screen = 1,
    /// `.screen`, against the current viewport rather than the whole window.
    viewport = 2,
    /// Real 3D coordinates, so text off the z=0 plane is scaled.
    model = 3,
    /// Real 3D coordinates, but the text always faces the camera.
    model_billboard = 4,
    pub const cpp_name = "ofDrawBitmapMode";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

pub const ofSetDrawBitmapMode_sig: Signature = .{ .name = "ofSetDrawBitmapMode", .args = &.{DrawBitmapMode} };
pub fn setDrawBitmapMode(mode: DrawBitmapMode) void {
    cpp.bind(ofSetDrawBitmapMode_sig)(mode);
}

/// `template<> void ofDrawBitmapString(const std::string&, float x, float y, float z)`,
/// a specialization of `template<typename T> void ofDrawBitmapString(const T&, float, float, float)`.
pub const ofDrawBitmapString_sig: Signature = .{
    .name = "ofDrawBitmapString",
    .template_args = &.{.{ .type = String }},
    .args = &.{ Ref(*const cpp.TParam(0)), f32, f32, f32 },
};
pub fn drawBitmapString(text: []const u8, x: f32, y: f32) void {
    var s = String.init(text);
    defer s.deinit();
    cpp.bind(ofDrawBitmapString_sig)(&s, x, y, 0);
}
pub fn drawBitmapStringi(text: []const u8, x: i32, y: i32) void {
    drawBitmapString(text, @floatFromInt(x), @floatFromInt(y));
}

// matrix stack

pub const ofPushMatrix_sig: Signature = .{ .name = "ofPushMatrix" };
pub fn pushMatrix() void {
    cpp.bind(ofPushMatrix_sig)();
}
pub const ofPopMatrix_sig: Signature = .{ .name = "ofPopMatrix" };
pub fn popMatrix() void {
    cpp.bind(ofPopMatrix_sig)();
}
pub const ofTranslate_sig: Signature = .{ .name = "ofTranslate", .args = &.{ f32, f32, f32 } };
pub fn translate(x: f32, y: f32, z: f32) void {
    cpp.bind(ofTranslate_sig)(x, y, z);
}
pub fn translatei(x: i32, y: i32, z: i32) void {
    translate(@floatFromInt(x), @floatFromInt(y), @floatFromInt(z));
}
/// `ofRotateRad(radians)`: about the z axis. oF spells this rotation twice,
/// as `ofRotateDeg` and `ofRotateRad`; this package binds the radian half of
/// every such pair and drops the suffix, so a Zig angle is always radians.
pub const ofRotateRad_sig: Signature = .{ .name = "ofRotateRad", .args = &.{f32} };
pub fn rotate(radians: f32) void {
    cpp.bind(ofRotateRad_sig)(radians);
}
/// `ofRotateRad(radians, x, y, z)`: about the given axis.
pub const ofRotateRad_axis_sig: Signature = .{ .name = "ofRotateRad", .args = &.{ f32, f32, f32, f32 } };
pub fn rotateAxis(radians: f32, x: f32, y: f32, z: f32) void {
    cpp.bind(ofRotateRad_axis_sig)(radians, x, y, z);
}
pub const ofScale_sig: Signature = .{ .name = "ofScale", .args = &.{ f32, f32, f32 } };
pub fn scale(x: f32, y: f32, z: f32) void {
    cpp.bind(ofScale_sig)(x, y, z);
}
pub fn scalei(x: i32, y: i32, z: i32) void {
    scale(@floatFromInt(x), @floatFromInt(y), @floatFromInt(z));
}

/// `ofMatrixMode`: which stack `ofGetCurrentMatrix` and `ofSetMatrixMode` mean.
pub const MatrixMode = enum(i32) {
    modelview = 0,
    projection = 1,
    texture = 2,
    pub const cpp_name = "ofMatrixMode";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

pub const ofLoadIdentityMatrix_sig: Signature = .{ .name = "ofLoadIdentityMatrix" };
pub fn loadIdentityMatrix() void {
    cpp.bind(ofLoadIdentityMatrix_sig)();
}
pub const ofSetMatrixMode_sig: Signature = .{ .name = "ofSetMatrixMode", .args = &.{MatrixMode} };
pub fn setMatrixMode(mode: MatrixMode) void {
    cpp.bind(ofSetMatrixMode_sig)(mode);
}

/// `ofLoadMatrix(const glm::mat4&)`, the overload that takes a matrix rather
/// than a `const float*`.
pub const ofLoadMatrix_sig: Signature = .{ .name = "ofLoadMatrix", .args = &.{Ref(*const Mat4)} };
pub fn loadMatrix(m: Mat4) void {
    cpp.bind(ofLoadMatrix_sig)(&m);
}
pub const ofMultMatrix_sig: Signature = .{ .name = "ofMultMatrix", .args = &.{Ref(*const Mat4)} };
pub fn multMatrix(m: Mat4) void {
    cpp.bind(ofMultMatrix_sig)(&m);
}
pub const ofLoadViewMatrix_sig: Signature = .{ .name = "ofLoadViewMatrix", .args = &.{Ref(*const Mat4)} };
pub fn loadViewMatrix(m: Mat4) void {
    cpp.bind(ofLoadViewMatrix_sig)(&m);
}
pub const ofMultViewMatrix_sig: Signature = .{ .name = "ofMultViewMatrix", .args = &.{Ref(*const Mat4)} };
pub fn multViewMatrix(m: Mat4) void {
    cpp.bind(ofMultViewMatrix_sig)(&m);
}

pub const ofGetCurrentMatrix_sig: Signature = .{ .name = "ofGetCurrentMatrix", .args = &.{MatrixMode}, .ret = Mat4 };
pub fn getCurrentMatrix(mode: MatrixMode) Mat4 {
    return cpp.bind(ofGetCurrentMatrix_sig)(mode);
}
pub const ofGetCurrentViewMatrix_sig: Signature = .{ .name = "ofGetCurrentViewMatrix", .ret = Mat4 };
pub fn getCurrentViewMatrix() Mat4 {
    return cpp.bind(ofGetCurrentViewMatrix_sig)();
}
pub const ofGetCurrentOrientationMatrix_sig: Signature = .{ .name = "ofGetCurrentOrientationMatrix", .ret = Mat4 };
pub fn getCurrentOrientationMatrix() Mat4 {
    return cpp.bind(ofGetCurrentOrientationMatrix_sig)();
}
pub const ofGetCurrentNormalMatrix_sig: Signature = .{ .name = "ofGetCurrentNormalMatrix", .ret = Mat4 };
pub fn getCurrentNormalMatrix() Mat4 {
    return cpp.bind(ofGetCurrentNormalMatrix_sig)();
}

// render state

pub const ofEnableAlphaBlending_sig: Signature = .{ .name = "ofEnableAlphaBlending" };
pub fn enableAlphaBlending() void {
    cpp.bind(ofEnableAlphaBlending_sig)();
}
pub const ofDisableAlphaBlending_sig: Signature = .{ .name = "ofDisableAlphaBlending" };
pub fn disableAlphaBlending() void {
    cpp.bind(ofDisableAlphaBlending_sig)();
}
pub const ofEnableDepthTest_sig: Signature = .{ .name = "ofEnableDepthTest" };
pub fn enableDepthTest() void {
    cpp.bind(ofEnableDepthTest_sig)();
}
pub const ofDisableDepthTest_sig: Signature = .{ .name = "ofDisableDepthTest" };
pub fn disableDepthTest() void {
    cpp.bind(ofDisableDepthTest_sig)();
}
pub const ofEnableSmoothing_sig: Signature = .{ .name = "ofEnableSmoothing" };
pub fn enableSmoothing() void {
    cpp.bind(ofEnableSmoothing_sig)();
}
pub const ofDisableSmoothing_sig: Signature = .{ .name = "ofDisableSmoothing" };
pub fn disableSmoothing() void {
    cpp.bind(ofDisableSmoothing_sig)();
}
pub const ofEnableAntiAliasing_sig: Signature = .{ .name = "ofEnableAntiAliasing" };
pub fn enableAntiAliasing() void {
    cpp.bind(ofEnableAntiAliasing_sig)();
}
pub const ofDisableAntiAliasing_sig: Signature = .{ .name = "ofDisableAntiAliasing" };
pub fn disableAntiAliasing() void {
    cpp.bind(ofDisableAntiAliasing_sig)();
}
