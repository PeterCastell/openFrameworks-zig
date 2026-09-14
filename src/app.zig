//! ofAppRunner.h: running an app, and the window, frame and input queries.
//!
//! An app is any Zig type. `run` looks for the methods oF would call on an
//! `ofBaseApp` subclass and wires up only the ones the type declares:
//!
//! ```zig
//! const App = struct {
//!     pub fn setup(self: *App) void { ... }
//!     pub fn update(self: *App) void { ... }
//!     pub fn draw(self: *App) void { ... }
//!     pub fn keyPressed(self: *App, key: of.KeyEventArgs) void { ... }
//!     pub fn mousePressed(self: *App, mouse: of.MouseEventArgs) void { ... }
//! };
//! var app: App = .{};
//! _ = of.run(App, &app, .{ .width = 1024, .height = 768 });
//! ```
const std = @import("std");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const events = @import("events.zig");
const String = @import("string.zig").String;

const KeyEventArgs = events.KeyEventArgs;
const MouseEventArgs = events.MouseEventArgs;
const ResizeEventArgs = events.ResizeEventArgs;
const TouchEventArgs = events.TouchEventArgs;
const DragInfo = events.DragInfo;
const Message = events.Message;

/// `ofWindowMode`
pub const WindowMode = enum(i32) {
    window = 0,
    fullscreen = 1,
    game_mode = 2,
    pub const cpp_name = "ofWindowMode";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

/// `ofBaseApp`. Only ever handled through a pointer; instances come from the
/// C++ trampoline in `src/cpp/ofzig_app.cpp`.
pub const BaseApp = opaque {
    pub const cpp_name = "ofBaseApp";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
};

pub const RunOptions = struct {
    width: i32 = 1024,
    height: i32 = 768,
    mode: WindowMode = .window,
};

/// Creates the window, runs the main loop with `app` as the application, and
/// returns when the app exits. Equivalent to the classic
/// `ofSetupOpenGL(w, h, mode); return ofRunApp(new App());` in main.cpp.
///
/// `app` must outlive the call; it is not copied.
pub const ofSetupOpenGL_sig: Signature = .{ .name = "ofSetupOpenGL", .args = &.{ i32, i32, WindowMode } };
pub fn run(comptime T: type, app: *T, opts: RunOptions) i32 {
    std.debug.assert(ofzig_callbacks_size() == @sizeOf(Callbacks));
    const cbs = comptime callbacksFor(T);
    cpp.bind(ofSetupOpenGL_sig)(opts.width, opts.height, opts.mode);
    const base = ofzig_app_new(&cbs, @ptrCast(app));
    return cpp.bind(.{ .name = "ofRunApp", .args = &.{*BaseApp}, .ret = i32 })(base);
}

/// `ofExit(0)`: ends the main loop after the current frame.
pub const ofExit_sig: Signature = .{ .name = "ofExit", .args = &.{i32} };
pub fn exit() void {
    cpp.bind(ofExit_sig)(0);
}

// window

pub const ofGetWidth_sig: Signature = .{ .name = "ofGetWidth", .ret = i32 };
pub fn getWidth() i32 {
    return cpp.bind(ofGetWidth_sig)();
}
pub const ofGetHeight_sig: Signature = .{ .name = "ofGetHeight", .ret = i32 };
pub fn getHeight() i32 {
    return cpp.bind(ofGetHeight_sig)();
}
pub const ofGetWindowWidth_sig: Signature = .{ .name = "ofGetWindowWidth", .ret = i32 };
pub fn getWindowWidth() i32 {
    return cpp.bind(ofGetWindowWidth_sig)();
}
pub const ofGetWindowHeight_sig: Signature = .{ .name = "ofGetWindowHeight", .ret = i32 };
pub fn getWindowHeight() i32 {
    return cpp.bind(ofGetWindowHeight_sig)();
}
pub const ofGetScreenWidth_sig: Signature = .{ .name = "ofGetScreenWidth", .ret = i32 };
pub fn getScreenWidth() i32 {
    return cpp.bind(ofGetScreenWidth_sig)();
}
pub const ofGetScreenHeight_sig: Signature = .{ .name = "ofGetScreenHeight", .ret = i32 };
pub fn getScreenHeight() i32 {
    return cpp.bind(ofGetScreenHeight_sig)();
}
pub const ofGetWindowPositionX_sig: Signature = .{ .name = "ofGetWindowPositionX", .ret = i32 };
pub fn getWindowPositionX() i32 {
    return cpp.bind(ofGetWindowPositionX_sig)();
}
pub const ofGetWindowPositionY_sig: Signature = .{ .name = "ofGetWindowPositionY", .ret = i32 };
pub fn getWindowPositionY() i32 {
    return cpp.bind(ofGetWindowPositionY_sig)();
}
pub const ofSetWindowShape_sig: Signature = .{ .name = "ofSetWindowShape", .args = &.{ i32, i32 } };
pub fn setWindowShape(w: i32, h: i32) void {
    cpp.bind(ofSetWindowShape_sig)(w, h);
}
pub const ofSetWindowPosition_sig: Signature = .{ .name = "ofSetWindowPosition", .args = &.{ i32, i32 } };
pub fn setWindowPosition(x: i32, y: i32) void {
    cpp.bind(ofSetWindowPosition_sig)(x, y);
}
/// `ofSetWindowTitle` takes its `std::string` by value: the temporary is
/// consumed by the call.
pub const ofSetWindowTitle_sig: Signature = .{ .name = "ofSetWindowTitle", .args = &.{String} };
pub fn setWindowTitle(title: []const u8) void {
    var s = String.init(title);
    cpp.bind(ofSetWindowTitle_sig)(&s);
}
pub const ofSetFullscreen_sig: Signature = .{ .name = "ofSetFullscreen", .args = &.{bool} };
pub fn setFullscreen(on: bool) void {
    cpp.bind(ofSetFullscreen_sig)(on);
}
pub const ofToggleFullscreen_sig: Signature = .{ .name = "ofToggleFullscreen" };
pub fn toggleFullscreen() void {
    cpp.bind(ofToggleFullscreen_sig)();
}
pub const ofGetWindowMode_sig: Signature = .{ .name = "ofGetWindowMode", .ret = i32 };
pub fn getWindowMode() WindowMode {
    return @fromBackingInt(@intCast(cpp.bind(ofGetWindowMode_sig)()));
}
pub const ofHideCursor_sig: Signature = .{ .name = "ofHideCursor" };
pub fn hideCursor() void {
    cpp.bind(ofHideCursor_sig)();
}
pub const ofShowCursor_sig: Signature = .{ .name = "ofShowCursor" };
pub fn showCursor() void {
    cpp.bind(ofShowCursor_sig)();
}
pub const ofSetEscapeQuitsApp_sig: Signature = .{ .name = "ofSetEscapeQuitsApp", .args = &.{bool} };
pub fn setEscapeQuitsApp(on: bool) void {
    cpp.bind(ofSetEscapeQuitsApp_sig)(on);
}

// frames and time

pub const ofSetFrameRate_sig: Signature = .{ .name = "ofSetFrameRate", .args = &.{i32} };
pub fn setFrameRate(fps: i32) void {
    cpp.bind(ofSetFrameRate_sig)(fps);
}
pub const ofGetFrameRate_sig: Signature = .{ .name = "ofGetFrameRate", .ret = f32 };
pub fn getFrameRate() f32 {
    return cpp.bind(ofGetFrameRate_sig)();
}
pub const ofGetTargetFrameRate_sig: Signature = .{ .name = "ofGetTargetFrameRate", .ret = f32 };
pub fn getTargetFrameRate() f32 {
    return cpp.bind(ofGetTargetFrameRate_sig)();
}
pub const ofGetFrameNum_sig: Signature = .{ .name = "ofGetFrameNum", .ret = u64 };
pub fn getFrameNum() u64 {
    return cpp.bind(ofGetFrameNum_sig)();
}
/// Seconds the last frame took.
pub const ofGetLastFrameTime_sig: Signature = .{ .name = "ofGetLastFrameTime", .ret = f64 };
pub fn getLastFrameTime() f64 {
    return cpp.bind(ofGetLastFrameTime_sig)();
}
pub const ofSetVerticalSync_sig: Signature = .{ .name = "ofSetVerticalSync", .args = &.{bool} };
pub fn setVerticalSync(on: bool) void {
    cpp.bind(ofSetVerticalSync_sig)(on);
}
/// Seconds since the app started.
pub const ofGetElapsedTime_sig: Signature = .{ .name = "ofGetElapsedTimef", .ret = f32 };
pub fn getElapsedTime() f32 {
    return cpp.bind(ofGetElapsedTime_sig)();
}
pub const ofGetElapsedTimeMillis_sig: Signature = .{ .name = "ofGetElapsedTimeMillis", .ret = u64 };
pub fn getElapsedTimeMillis() u64 {
    return cpp.bind(ofGetElapsedTimeMillis_sig)();
}
pub const ofSleepMillis_sig: Signature = .{ .name = "ofSleepMillis", .args = &.{i32} };
pub fn sleepMillis(ms: i32) void {
    cpp.bind(ofSleepMillis_sig)(ms);
}

// input

pub const ofGetMouseX_sig: Signature = .{ .name = "ofGetMouseX", .ret = i32 };
pub fn getMouseX() i32 {
    return cpp.bind(ofGetMouseX_sig)();
}
pub const ofGetMouseY_sig: Signature = .{ .name = "ofGetMouseY", .ret = i32 };
pub fn getMouseY() i32 {
    return cpp.bind(ofGetMouseY_sig)();
}
pub const ofGetPreviousMouseX_sig: Signature = .{ .name = "ofGetPreviousMouseX", .ret = i32 };
pub fn getPreviousMouseX() i32 {
    return cpp.bind(ofGetPreviousMouseX_sig)();
}
pub const ofGetPreviousMouseY_sig: Signature = .{ .name = "ofGetPreviousMouseY", .ret = i32 };
pub fn getPreviousMouseY() i32 {
    return cpp.bind(ofGetPreviousMouseY_sig)();
}
/// `button` is one of `of.mouse_button`, or -1 for any.
pub const ofGetMousePressed_sig: Signature = .{ .name = "ofGetMousePressed", .args = &.{i32}, .ret = bool };
pub fn getMousePressed(button: i32) bool {
    return cpp.bind(ofGetMousePressed_sig)(button);
}
/// `k` is a character or one of `of.key`, or -1 for any.
pub const ofGetKeyPressed_sig: Signature = .{ .name = "ofGetKeyPressed", .args = &.{i32}, .ret = bool };
pub fn getKeyPressed(k: i32) bool {
    return cpp.bind(ofGetKeyPressed_sig)(k);
}

// the trampoline

/// Mirror of `ofzig_callbacks` in src/cpp/ofzig_app.cpp. Same order.
pub const Callbacks = extern struct {
    setup: ?PlainFn = null,
    update: ?PlainFn = null,
    draw: ?PlainFn = null,
    exit: ?PlainFn = null,
    key_pressed: ?EventFn(KeyEventArgs) = null,
    key_released: ?EventFn(KeyEventArgs) = null,
    mouse_moved: ?EventFn(MouseEventArgs) = null,
    mouse_dragged: ?EventFn(MouseEventArgs) = null,
    mouse_pressed: ?EventFn(MouseEventArgs) = null,
    mouse_released: ?EventFn(MouseEventArgs) = null,
    mouse_scrolled: ?EventFn(MouseEventArgs) = null,
    mouse_entered: ?EventFn(MouseEventArgs) = null,
    mouse_exited: ?EventFn(MouseEventArgs) = null,
    window_resized: ?EventFn(ResizeEventArgs) = null,
    drag_event: ?EventFn(DragInfo) = null,
    got_message: ?EventFn(Message) = null,
    touch_down: ?EventFn(TouchEventArgs) = null,
    touch_moved: ?EventFn(TouchEventArgs) = null,
    touch_up: ?EventFn(TouchEventArgs) = null,
    touch_double_tap: ?EventFn(TouchEventArgs) = null,
    touch_cancelled: ?EventFn(TouchEventArgs) = null,
};

const PlainFn = *const fn (*anyopaque) callconv(.c) void;
fn EventFn(comptime Args: type) type {
    return *const fn (*anyopaque, *const Args) callconv(.c) void;
}

extern fn ofzig_app_new(cb: *const Callbacks, user: *anyopaque) *BaseApp;
extern fn ofzig_callbacks_size() usize;

/// Method name on the Zig type -> callback slot, for every slot.
const plain_slots = .{
    .{ "setup", "setup" },
    .{ "update", "update" },
    .{ "draw", "draw" },
    .{ "exit", "exit" },
};
const event_slots = .{
    .{ "key_pressed", "keyPressed", KeyEventArgs },
    .{ "key_released", "keyReleased", KeyEventArgs },
    .{ "mouse_moved", "mouseMoved", MouseEventArgs },
    .{ "mouse_dragged", "mouseDragged", MouseEventArgs },
    .{ "mouse_pressed", "mousePressed", MouseEventArgs },
    .{ "mouse_released", "mouseReleased", MouseEventArgs },
    .{ "mouse_scrolled", "mouseScrolled", MouseEventArgs },
    .{ "mouse_entered", "mouseEntered", MouseEventArgs },
    .{ "mouse_exited", "mouseExited", MouseEventArgs },
    .{ "window_resized", "windowResized", ResizeEventArgs },
    .{ "drag_event", "dragEvent", DragInfo },
    .{ "got_message", "gotMessage", Message },
    .{ "touch_down", "touchDown", TouchEventArgs },
    .{ "touch_moved", "touchMoved", TouchEventArgs },
    .{ "touch_up", "touchUp", TouchEventArgs },
    .{ "touch_double_tap", "touchDoubleTap", TouchEventArgs },
    .{ "touch_cancelled", "touchCancelled", TouchEventArgs },
};

fn callbacksFor(comptime T: type) Callbacks {
    var cbs: Callbacks = .{};
    inline for (plain_slots) |slot| {
        if (@hasDecl(T, slot[1])) @field(cbs, slot[0]) = plainCallback(T, slot[1]);
    }
    inline for (event_slots) |slot| {
        if (@hasDecl(T, slot[1])) @field(cbs, slot[0]) = eventCallback(T, slot[1], slot[2]);
    }
    return cbs;
}

fn plainCallback(comptime T: type, comptime method: []const u8) PlainFn {
    return &struct {
        fn f(user: *anyopaque) callconv(.c) void {
            @field(T, method)(self(T, user));
        }
    }.f;
}

/// The Zig method receives a trivially copyable event by value, and a
/// managed one (`DragInfo`, `Message`) by const pointer.
fn eventCallback(comptime T: type, comptime method: []const u8, comptime Args: type) EventFn(Args) {
    return &struct {
        fn f(user: *anyopaque, args: *const Args) callconv(.c) void {
            const by_ref = Args == DragInfo or Args == Message;
            if (by_ref) @field(T, method)(self(T, user), args) else @field(T, method)(self(T, user), args.*);
        }
    }.f;
}

fn self(comptime T: type, user: *anyopaque) *T {
    return @ptrCast(@alignCast(user));
}
