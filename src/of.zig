//! openFrameworks for Zig.
//!
//! One file per area of the oF API, each holding its types, with their
//! methods, and its free functions. Every call goes straight to the C++
//! symbol through cpp-bindgen: a function is `cpp.bind(signature)(args...)`,
//! with the signature written at the one place it is used.
//!
//! **Every angle is in radians**, taken and returned, with no `Deg`/`Rad`
//! suffix anywhere. oF itself is degrees-first -- it spells most rotations
//! twice (`ofRotateDeg` and `ofRotateRad`, `ofNode::panDeg` and `panRad`)
//! and a few only in degrees (`ofPath::arc`, `ofCamera::setFov`,
//! `ofMesh::smoothNormals`, `ofNode::setOrientation(const glm::vec3&)`).
//! Where a pair exists this package binds the radian half; where oF offers
//! only degrees the wrapper converts at the call. Zig's own `std.math` trig
//! is radians, so this keeps a sketch in one unit throughout; `degToRad` and
//! `radToDeg` are there for porting a degree literal out of oF code.
//!
//! This file is also the root of the glue scan: `build.zig` hands it to
//! cpp-bindgen, which walks the namespaces re-exported below for the types
//! and signatures it must instantiate and layout-check against the installed
//! oF headers. Nothing here declares how that build works.

const std = @import("std");

pub const app = @import("app.zig");
pub const color = @import("color.zig");
pub const events = @import("events.zig");
pub const font = @import("font.zig");
pub const graphics = @import("graphics.zig");
pub const math = @import("math.zig");
pub const matrix = @import("matrix.zig");
pub const rectangle = @import("rectangle.zig");
pub const string = @import("string.zig");

// Types.
pub const Vec2 = math.Vec2;
pub const Vec3 = math.Vec3;
pub const Vec4 = math.Vec4;
pub const Vec2I = math.Vec2I;
pub const Vec3I = math.Vec3I;
pub const Vec4I = math.Vec4I;
pub const Vec2U = math.Vec2U;
pub const Vec3U = math.Vec3U;
pub const Vec4U = math.Vec4U;
pub const GlmVec2 = math.GlmVec2;
pub const GlmVec3 = math.GlmVec3;
pub const GlmVec4 = math.GlmVec4;
pub const GlmVec2I = math.GlmVec2I;
pub const GlmVec3I = math.GlmVec3I;
pub const GlmVec4I = math.GlmVec4I;
pub const GlmVec2U = math.GlmVec2U;
pub const GlmVec3U = math.GlmVec3U;
pub const GlmVec4U = math.GlmVec4U;
pub const Mat3 = matrix.Mat3;
pub const Mat4 = matrix.Mat4;
pub const Quat = matrix.Quat;
pub const Transform = matrix.Transform;
pub const Color = color.Color;
pub const FloatColor = color.FloatColor;
pub const ShortColor = color.ShortColor;
pub const Rectangle = rectangle.Rectangle;
pub const OfRectangle = rectangle.OfRectangle;
pub const String = string.String;
pub const Font = font.Font;
pub const FontLoadOptions = font.LoadOptions;
pub const FontSettings = font.Settings;
pub const UnicodeRange = font.UnicodeRange;
pub const WindowMode = app.WindowMode;
pub const RectMode = graphics.RectMode;
pub const MatrixMode = graphics.MatrixMode;
pub const DrawBitmapMode = graphics.DrawBitmapMode;
pub const KeyEventArgs = events.KeyEventArgs;
pub const MouseEventArgs = events.MouseEventArgs;
pub const ResizeEventArgs = events.ResizeEventArgs;
pub const TouchEventArgs = events.TouchEventArgs;
pub const DragInfo = events.DragInfo;
pub const Message = events.Message;
pub const key = events.key;
pub const modifier = events.modifier;
pub const mouse_button = events.mouse_button;

// App, window, frames, input.
pub const run = app.run;
pub const RunOptions = app.RunOptions;
pub const exit = app.exit;
pub const getWidth = app.getWidth;
pub const getHeight = app.getHeight;
pub const getWindowWidth = app.getWindowWidth;
pub const getWindowHeight = app.getWindowHeight;
pub const getScreenWidth = app.getScreenWidth;
pub const getScreenHeight = app.getScreenHeight;
pub const getWindowPositionX = app.getWindowPositionX;
pub const getWindowPositionY = app.getWindowPositionY;
pub const setWindowShape = app.setWindowShape;
pub const setWindowPosition = app.setWindowPosition;
pub const setWindowTitle = app.setWindowTitle;
pub const setFullscreen = app.setFullscreen;
pub const toggleFullscreen = app.toggleFullscreen;
pub const getWindowMode = app.getWindowMode;
pub const hideCursor = app.hideCursor;
pub const showCursor = app.showCursor;
pub const setEscapeQuitsApp = app.setEscapeQuitsApp;
pub const setFrameRate = app.setFrameRate;
pub const getFrameRate = app.getFrameRate;
pub const getTargetFrameRate = app.getTargetFrameRate;
pub const getFrameNum = app.getFrameNum;
pub const getLastFrameTime = app.getLastFrameTime;
pub const setVerticalSync = app.setVerticalSync;
pub const getElapsedTime = app.getElapsedTime;
pub const getElapsedTimeMillis = app.getElapsedTimeMillis;
pub const sleepMillis = app.sleepMillis;
pub const getMouseX = app.getMouseX;
pub const getMouseY = app.getMouseY;
pub const getPreviousMouseX = app.getPreviousMouseX;
pub const getPreviousMouseY = app.getPreviousMouseY;
pub const getMousePressed = app.getMousePressed;
pub const getKeyPressed = app.getKeyPressed;

// Graphics.
pub const background = graphics.background;
pub const backgroundGrey = graphics.backgroundGrey;
pub const setBackgroundAuto = graphics.setBackgroundAuto;
pub const clear = graphics.clear;
pub const setColor = graphics.setColor;
pub const setColorAlpha = graphics.setColorAlpha;
pub const setFloatColor = graphics.setFloatColor;
pub const setColorGrey = graphics.setColorGrey;
pub const fill = graphics.fill;
pub const noFill = graphics.noFill;
pub const setLineWidth = graphics.setLineWidth;
pub const setCircleResolution = graphics.setCircleResolution;
pub const setRectMode = graphics.setRectMode;
pub const drawRectangle = graphics.drawRectangle;
pub const drawRectanglei = graphics.drawRectanglei;
pub const drawRectangleAt = graphics.drawRectangleAt;
pub const drawRectangleAti = graphics.drawRectangleAti;
pub const drawRectRounded = graphics.drawRectRounded;
pub const drawRectRoundedi = graphics.drawRectRoundedi;
pub const drawCircle = graphics.drawCircle;
pub const drawCirclei = graphics.drawCirclei;
pub const drawCircleAt = graphics.drawCircleAt;
pub const drawCircleAti = graphics.drawCircleAti;
pub const drawEllipse = graphics.drawEllipse;
pub const drawEllipsei = graphics.drawEllipsei;
pub const drawLine = graphics.drawLine;
pub const drawLinei = graphics.drawLinei;
pub const drawLineBetween = graphics.drawLineBetween;
pub const drawLineBetweeni = graphics.drawLineBetweeni;
pub const drawTriangle = graphics.drawTriangle;
pub const drawTrianglei = graphics.drawTrianglei;
pub const setDrawBitmapMode = graphics.setDrawBitmapMode;
pub const drawBitmapString = graphics.drawBitmapString;
pub const drawBitmapStringi = graphics.drawBitmapStringi;
pub const pushMatrix = graphics.pushMatrix;
pub const popMatrix = graphics.popMatrix;
pub const translate = graphics.translate;
pub const translatei = graphics.translatei;
pub const rotate = graphics.rotate;
pub const rotateAxis = graphics.rotateAxis;
pub const scale = graphics.scale;
pub const scalei = graphics.scalei;
pub const loadIdentityMatrix = graphics.loadIdentityMatrix;
pub const setMatrixMode = graphics.setMatrixMode;
pub const loadMatrix = graphics.loadMatrix;
pub const multMatrix = graphics.multMatrix;
pub const loadViewMatrix = graphics.loadViewMatrix;
pub const multViewMatrix = graphics.multViewMatrix;
pub const getCurrentMatrix = graphics.getCurrentMatrix;
pub const getCurrentViewMatrix = graphics.getCurrentViewMatrix;
pub const getCurrentOrientationMatrix = graphics.getCurrentOrientationMatrix;
pub const getCurrentNormalMatrix = graphics.getCurrentNormalMatrix;
pub const enableAlphaBlending = graphics.enableAlphaBlending;
pub const disableAlphaBlending = graphics.disableAlphaBlending;
pub const enableDepthTest = graphics.enableDepthTest;
pub const disableDepthTest = graphics.disableDepthTest;
pub const enableSmoothing = graphics.enableSmoothing;
pub const disableSmoothing = graphics.disableSmoothing;
pub const enableAntiAliasing = graphics.enableAntiAliasing;
pub const disableAntiAliasing = graphics.disableAntiAliasing;

// Math.
pub const random = math.random;
pub const randomi = math.randomi;
pub const randomRange = math.randomRange;
pub const randomRangei = math.randomRangei;
pub const seedRandom = math.seedRandom;
pub const map = math.map;
pub const clamp = math.clamp;
pub const lerp = math.lerp;
pub const noise = math.noise;
pub const noise1 = math.noise1;
pub const noise3 = math.noise3;
pub const signedNoise = math.signedNoise;
pub const degToRad = math.degToRad;
pub const radToDeg = math.radToDeg;

// Vector math. The operators are Zig's own: `a + b`, `a * @as(Vec2,
// @splat(k))`, `a[0]`. These are the parts that have no operator.
pub const vecCast = math.vecCast;
pub const dot = math.dot;
pub const length = math.length;
pub const normalize = math.normalize;
pub const cross = math.cross;

/// `std.meta.eql`: structural equality, for the types here that `==` will not
/// compare. `==` on a `Vec2` is elementwise and yields a `@Vector(2, bool)`,
/// and on a struct like `Color` or `Rectangle` it does not compile at all.
pub const eql = std.meta.eql;
