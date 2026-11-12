//! ofAppRunner.h: running an app, and the window, frame and input queries.
//!
//! An app is any Zig type. `run` looks for the methods oF would call on an
//! `ofBaseApp` subclass and wires up only the ones the type declares:
//!
//! ```zig
//! const App = struct {
//!     pub fn setup(self: *App) void { ... }      // or `!void`: see below
//!     pub fn update(self: *App) void { ... }
//!     pub fn draw(self: *App) void { ... }
//!     pub fn keyPressed(self: *App, key: of.KeyEventArgs) void { ... }
//!     pub fn mousePressed(self: *App, mouse: of.MouseEventArgs) void { ... }
//! };
//! var app: App = .{};
//! _ = of.run(App, &app, .{ .width = 1024, .height = 768 });
//! ```
//!
//! Any of these methods may return `!void`. oF drives them from the C++ main
//! loop, where an error has nowhere to propagate to, so a returned error
//! dumps its error return trace and panics at the throw site.
const std = @import("std");
const builtin = @import("builtin");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const events = @import("events.zig");
const String = @import("string.zig").String;
const Path = @import("string.zig").Path;
const math = @import("math.zig");
const Vec2I = math.Vec2I;
const Vec2U = math.Vec2U;

const KeyEventArgs = events.KeyEventArgs;
const MouseEventArgs = events.MouseEventArgs;
const ResizeEventArgs = events.ResizeEventArgs;
const TouchEventArgs = events.TouchEventArgs;
const DragInfo = events.DragInfo;
const Message = events.Message;
const EventArgs = events.EventArgs;

/// `ofWindowMode`
pub const WindowMode = enum(i32) {
    window = 0,
    fullscreen = 1,
    game_mode = 2,
    pub const cpp_name = "ofWindowMode";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

/// `ofSoundBuffer`. Only ever passed by reference here.
pub const SoundBuffer = opaque {
    pub const cpp_name = "ofSoundBuffer";
    pub const cpp_kind: cpp.Kind = .class;
};

/// `ofBaseSoundInput`, the first base of `ofBaseApp`: a vtable pointer and
/// nothing else.
pub const BaseSoundInput = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),

    pub const cpp_name = "ofBaseSoundInput";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    const Self = BaseSoundInput;
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Self };
    pub const audioIn_buffer_sig: Signature = .{ .name = "audioIn", .this = *Self, .args = &.{cpp.Ref(*SoundBuffer)}, .virtual = true };
    pub const audioIn_device_sig: Signature = .{ .name = "audioIn", .this = *Self, .args = &.{ [*]f32, i32, i32, i32, u64 }, .virtual = true };
    pub const audioIn_sig: Signature = .{ .name = "audioIn", .this = *Self, .args = &.{ [*]f32, i32, i32 }, .virtual = true };
    pub const audioReceived_sig: Signature = .{ .name = "audioReceived", .this = *Self, .args = &.{ [*]f32, i32, i32 }, .virtual = true };
    pub const cpp_virtuals: []const Signature = &.{ dtor_sig, audioIn_buffer_sig, audioIn_device_sig, audioIn_sig, audioReceived_sig };
};

/// `ofBaseSoundOutput`, the second base of `ofBaseApp`.
pub const BaseSoundOutput = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),

    pub const cpp_name = "ofBaseSoundOutput";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    const Self = BaseSoundOutput;
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Self };
    pub const audioOut_buffer_sig: Signature = .{ .name = "audioOut", .this = *Self, .args = &.{cpp.Ref(*SoundBuffer)}, .virtual = true };
    pub const audioOut_device_sig: Signature = .{ .name = "audioOut", .this = *Self, .args = &.{ [*]f32, i32, i32, i32, u64 }, .virtual = true };
    pub const audioOut_sig: Signature = .{ .name = "audioOut", .this = *Self, .args = &.{ [*]f32, i32, i32 }, .virtual = true };
    pub const audioRequested_sig: Signature = .{ .name = "audioRequested", .this = *Self, .args = &.{ [*]f32, i32, i32 }, .virtual = true };
    pub const cpp_virtuals: []const Signature = &.{ dtor_sig, audioOut_buffer_sig, audioOut_device_sig, audioOut_sig, audioRequested_sig };
};

/// `ofBaseApp`. Its two sound bases each bring a vtable, so an app object
/// holds two vtable pointers, then `mouseX` and `mouseY`.
///
/// `run` subclasses it from Zig (`cpp.Subclass`), so every virtual function
/// the header declares is listed below, in header order: cpp-bindgen
/// computes the slots from that list, and checks them against the vtable
/// `ofBaseApp()` installs every time an app starts in a safe build.
pub const BaseApp = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    mouseX: i32,
    mouseY: i32,

    pub const cpp_name = "ofBaseApp";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{ BaseSoundInput, BaseSoundOutput };
    pub const cpp_virtual_dtor = true;

    const Self = BaseApp;
    const Ref = cpp.Ref;
    fn virt(comptime name: []const u8, comptime args: []const type) Signature {
        return .{ .name = name, .this = *Self, .args = args, .virtual = true };
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *Self };
    pub const setup_sig = virt("setup", &.{});
    pub const update_sig = virt("update", &.{});
    pub const draw_sig = virt("draw", &.{});
    pub const exit_sig = virt("exit", &.{});
    pub const windowResized_size_sig = virt("windowResized", &.{ i32, i32 });
    pub const keyPressed_key_sig = virt("keyPressed", &.{i32});
    pub const keyReleased_key_sig = virt("keyReleased", &.{i32});
    pub const mouseMoved_xy_sig = virt("mouseMoved", &.{ i32, i32 });
    pub const mouseDragged_xy_sig = virt("mouseDragged", &.{ i32, i32, i32 });
    pub const mousePressed_xy_sig = virt("mousePressed", &.{ i32, i32, i32 });
    pub const mouseReleased_xy_sig = virt("mouseReleased", &.{ i32, i32, i32 });
    pub const mouseScrolled_xy_sig = virt("mouseScrolled", &.{ i32, i32, f32, f32 });
    pub const mouseEntered_xy_sig = virt("mouseEntered", &.{ i32, i32 });
    pub const mouseExited_xy_sig = virt("mouseExited", &.{ i32, i32 });
    pub const dragEvent_sig = virt("dragEvent", &.{DragInfo});
    pub const gotMessage_sig = virt("gotMessage", &.{Message});
    // The overloads oF's events actually call. Their definitions in
    // ofBaseApp.cpp forward to the plain ones above.
    pub const setup_args_sig = virt("setup", &.{Ref(*EventArgs)});
    pub const update_args_sig = virt("update", &.{Ref(*EventArgs)});
    pub const draw_args_sig = virt("draw", &.{Ref(*EventArgs)});
    pub const exit_args_sig = virt("exit", &.{Ref(*EventArgs)});
    pub const windowResized_sig = virt("windowResized", &.{Ref(*ResizeEventArgs)});
    pub const keyPressed_sig = virt("keyPressed", &.{Ref(*KeyEventArgs)});
    pub const keyReleased_sig = virt("keyReleased", &.{Ref(*KeyEventArgs)});
    pub const mouseMoved_sig = virt("mouseMoved", &.{Ref(*MouseEventArgs)});
    pub const mouseDragged_sig = virt("mouseDragged", &.{Ref(*MouseEventArgs)});
    pub const mousePressed_sig = virt("mousePressed", &.{Ref(*MouseEventArgs)});
    pub const mouseReleased_sig = virt("mouseReleased", &.{Ref(*MouseEventArgs)});
    pub const mouseScrolled_sig = virt("mouseScrolled", &.{Ref(*MouseEventArgs)});
    pub const mouseEntered_sig = virt("mouseEntered", &.{Ref(*MouseEventArgs)});
    pub const mouseExited_sig = virt("mouseExited", &.{Ref(*MouseEventArgs)});
    pub const dragged_sig = virt("dragged", &.{Ref(*DragInfo)});
    pub const messageReceived_sig = virt("messageReceived", &.{Ref(*Message)});
    pub const touchDown_xy_sig = virt("touchDown", &.{ i32, i32, i32 });
    pub const touchMoved_xy_sig = virt("touchMoved", &.{ i32, i32, i32 });
    pub const touchUp_xy_sig = virt("touchUp", &.{ i32, i32, i32 });
    pub const touchDoubleTap_xy_sig = virt("touchDoubleTap", &.{ i32, i32, i32 });
    pub const touchCancelled_xy_sig = virt("touchCancelled", &.{ i32, i32, i32 });
    pub const touchDown_sig = virt("touchDown", &.{Ref(*TouchEventArgs)});
    pub const touchMoved_sig = virt("touchMoved", &.{Ref(*TouchEventArgs)});
    pub const touchUp_sig = virt("touchUp", &.{Ref(*TouchEventArgs)});
    pub const touchDoubleTap_sig = virt("touchDoubleTap", &.{Ref(*TouchEventArgs)});
    pub const touchCancelled_sig = virt("touchCancelled", &.{Ref(*TouchEventArgs)});

    pub const cpp_virtuals: []const Signature = &.{
        dtor_sig,
        setup_sig,
        update_sig,
        draw_sig,
        exit_sig,
        windowResized_size_sig,
        keyPressed_key_sig,
        keyReleased_key_sig,
        mouseMoved_xy_sig,
        mouseDragged_xy_sig,
        mousePressed_xy_sig,
        mouseReleased_xy_sig,
        mouseScrolled_xy_sig,
        mouseEntered_xy_sig,
        mouseExited_xy_sig,
        dragEvent_sig,
        gotMessage_sig,
        setup_args_sig,
        update_args_sig,
        draw_args_sig,
        exit_args_sig,
        windowResized_sig,
        keyPressed_sig,
        keyReleased_sig,
        mouseMoved_sig,
        mouseDragged_sig,
        mousePressed_sig,
        mouseReleased_sig,
        mouseScrolled_sig,
        mouseEntered_sig,
        mouseExited_sig,
        dragged_sig,
        messageReceived_sig,
        touchDown_xy_sig,
        touchMoved_xy_sig,
        touchUp_xy_sig,
        touchDoubleTap_xy_sig,
        touchCancelled_xy_sig,
        touchDown_sig,
        touchMoved_sig,
        touchUp_sig,
        touchDoubleTap_sig,
        touchCancelled_sig,
    };
};

pub const RunOptions = struct {
    width: u32 = 1024,
    height: u32 = 768,
    mode: WindowMode = .window,
};

/// Creates the window, runs the main loop with `app` as the application, and
/// returns when the app exits. Equivalent to the classic
/// `ofSetupOpenGL(w, h, mode); return ofRunApp(new App());` in main.cpp.
///
/// `app` must outlive the call; it is not copied.
pub const ofSetupOpenGL_sig: Signature = .{ .name = "ofSetupOpenGL", .args = &.{ i32, i32, WindowMode } };
pub const ofRunApp_sig: Signature = .{ .name = "ofRunApp", .args = &.{*BaseApp}, .ret = i32 };
pub fn run(comptime T: type, app: *T, opts: RunOptions) i32 {
    if (builtin.os.tag == .macos) useDataBesideExe();
    cpp.bind(ofSetupOpenGL_sig)(@bitCast(opts.width), @bitCast(opts.height), opts.mode);
    const S = AppBase(T);
    S.instance = .{ .cpp = undefined, .app = app };
    S.instance.cpp.init();
    return cpp.bind(ofRunApp_sig)(&S.instance.cpp.base);
}

/// `ofFilePath`, a namespace of static functions in a class.
pub const FilePath = opaque {
    pub const cpp_name = "ofFilePath";
    pub const cpp_kind: cpp.Kind = .class;
};
pub const getCurrentExeDir_sig: Signature = .{ .name = "getCurrentExeDir", .class = FilePath, .ret = String };
pub const ofSetDataPathRoot_sig: Signature = .{ .name = "ofSetDataPathRoot", .args = &.{cpp.Ref(*const Path)} };

/// On macOS, oF looks for `data/` three levels above the executable, which
/// is beside the bundle when the executable is `<app>.app/Contents/MacOS/<app>`.
/// A Zig build makes a bare executable, so point oF at `data/` next to it,
/// which is where it looks on Windows. A sketch's own `ofSetDataPathRoot` in
/// `setup` still wins, since this runs first.
fn useDataBesideExe() void {
    var dir: String = undefined;
    cpp.bind(getCurrentExeDir_sig)(&dir);
    defer dir.deinit();
    const exe_dir = dir.slice();
    const sep = if (std.mem.endsWith(u8, exe_dir, "/")) "" else "/";
    var buf: [Path.max_units]u8 = undefined;
    const root = std.fmt.bufPrint(&buf, "{s}{s}data/", .{ exe_dir, sep }) catch return;
    var path = Path.init(root) orelse return;
    defer path.deinit();
    cpp.bind(ofSetDataPathRoot_sig)(&path);
}

/// `ofExit(0)`: ends the main loop after the current frame.
pub const ofExit_sig: Signature = .{ .name = "ofExit", .args = &.{i32} };
pub fn exit() void {
    cpp.bind(ofExit_sig)(0);
}

// window

pub const ofGetWidth_sig: Signature = .{ .name = "ofGetWidth", .ret = i32 };
pub fn getWidth() u32 {
    return @bitCast(cpp.bind(ofGetWidth_sig)());
}
pub const ofGetHeight_sig: Signature = .{ .name = "ofGetHeight", .ret = i32 };
pub fn getHeight() u32 {
    return @bitCast(cpp.bind(ofGetHeight_sig)());
}
pub const ofGetWindowWidth_sig: Signature = .{ .name = "ofGetWindowWidth", .ret = i32 };
pub fn getWindowWidth() u32 {
    return @bitCast(cpp.bind(ofGetWindowWidth_sig)());
}
pub const ofGetWindowHeight_sig: Signature = .{ .name = "ofGetWindowHeight", .ret = i32 };
pub fn getWindowHeight() u32 {
    return @bitCast(cpp.bind(ofGetWindowHeight_sig)());
}
pub const ofGetScreenWidth_sig: Signature = .{ .name = "ofGetScreenWidth", .ret = i32 };
pub fn getScreenWidth() u32 {
    return @bitCast(cpp.bind(ofGetScreenWidth_sig)());
}
pub const ofGetScreenHeight_sig: Signature = .{ .name = "ofGetScreenHeight", .ret = i32 };
pub fn getScreenHeight() u32 {
    return @bitCast(cpp.bind(ofGetScreenHeight_sig)());
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
pub fn setWindowShape(w: u32, h: u32) void {
    cpp.bind(ofSetWindowShape_sig)(@bitCast(w), @bitCast(h));
}
pub fn setWindowShapev(size: Vec2U) void {
    setWindowShape(size[0], size[1]);
}
pub const ofSetWindowPosition_sig: Signature = .{ .name = "ofSetWindowPosition", .args = &.{ i32, i32 } };
pub fn setWindowPosition(x: i32, y: i32) void {
    cpp.bind(ofSetWindowPosition_sig)(x, y);
}
pub fn setWindowPositionv(p: Vec2I) void {
    setWindowPosition(p[0], p[1]);
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
pub fn setFrameRate(fps: u32) void {
    cpp.bind(ofSetFrameRate_sig)(@bitCast(fps));
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
pub fn getLastFrameTime() f32 {
    return @floatCast(cpp.bind(ofGetLastFrameTime_sig)());
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
pub fn sleepMillis(ms: u32) void {
    cpp.bind(ofSleepMillis_sig)(@bitCast(ms));
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
/// Both mouse coordinates, as a vector.
pub fn getMousePos() Vec2I {
    return .{ getMouseX(), getMouseY() };
}
pub const ofGetPreviousMouseX_sig: Signature = .{ .name = "ofGetPreviousMouseX", .ret = i32 };
pub fn getPreviousMouseX() i32 {
    return cpp.bind(ofGetPreviousMouseX_sig)();
}
pub const ofGetPreviousMouseY_sig: Signature = .{ .name = "ofGetPreviousMouseY", .ret = i32 };
pub fn getPreviousMouseY() i32 {
    return cpp.bind(ofGetPreviousMouseY_sig)();
}
pub fn getPreviousMousePos() Vec2I {
    return .{ getPreviousMouseX(), getPreviousMouseY() };
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

// the app as an ofBaseApp

/// The `ofBaseApp` `run` hands to oF for an app type `T`: a Zig subclass,
/// with no C++ of its own, whose overrides call `T`'s methods. Only the
/// methods `T` declares are overridden; every other slot keeps `ofBaseApp`'s
/// own definition.
///
/// oF owns the app through a `shared_ptr` and deletes it when its main loop
/// is torn down, which can be after `ofRunApp` returns. So the object is a
/// static, one per app type, and the delete frees nothing.
fn AppBase(comptime T: type) type {
    return struct {
        cpp: cpp.Subclass(BaseApp, @This(), "cpp"),
        app: *T,

        const Self = @This();
        var instance: Self = undefined;

        pub const cpp_overrides = overrides(Self, T);

        pub fn cpp_free(_: *Self) void {}
    };
}

/// The `ofBaseApp` virtual function each app method overrides: the
/// overloads oF's events call, each with its argument by reference. `Args`
/// is the event type, or null for the ones whose `ofEventArgs` carries
/// nothing.
const Slot = struct { sig: Signature, method: []const u8, Args: ?type };
const slots = [_]Slot{
    .{ .sig = BaseApp.setup_args_sig, .method = "setup", .Args = null },
    .{ .sig = BaseApp.update_args_sig, .method = "update", .Args = null },
    .{ .sig = BaseApp.draw_args_sig, .method = "draw", .Args = null },
    .{ .sig = BaseApp.exit_args_sig, .method = "exit", .Args = null },
    .{ .sig = BaseApp.keyPressed_sig, .method = "keyPressed", .Args = KeyEventArgs },
    .{ .sig = BaseApp.keyReleased_sig, .method = "keyReleased", .Args = KeyEventArgs },
    .{ .sig = BaseApp.mouseMoved_sig, .method = "mouseMoved", .Args = MouseEventArgs },
    .{ .sig = BaseApp.mouseDragged_sig, .method = "mouseDragged", .Args = MouseEventArgs },
    .{ .sig = BaseApp.mousePressed_sig, .method = "mousePressed", .Args = MouseEventArgs },
    .{ .sig = BaseApp.mouseReleased_sig, .method = "mouseReleased", .Args = MouseEventArgs },
    .{ .sig = BaseApp.mouseScrolled_sig, .method = "mouseScrolled", .Args = MouseEventArgs },
    .{ .sig = BaseApp.mouseEntered_sig, .method = "mouseEntered", .Args = MouseEventArgs },
    .{ .sig = BaseApp.mouseExited_sig, .method = "mouseExited", .Args = MouseEventArgs },
    .{ .sig = BaseApp.windowResized_sig, .method = "windowResized", .Args = ResizeEventArgs },
    .{ .sig = BaseApp.dragged_sig, .method = "dragEvent", .Args = DragInfo },
    .{ .sig = BaseApp.messageReceived_sig, .method = "gotMessage", .Args = Message },
    .{ .sig = BaseApp.touchDown_sig, .method = "touchDown", .Args = TouchEventArgs },
    .{ .sig = BaseApp.touchMoved_sig, .method = "touchMoved", .Args = TouchEventArgs },
    .{ .sig = BaseApp.touchUp_sig, .method = "touchUp", .Args = TouchEventArgs },
    .{ .sig = BaseApp.touchDoubleTap_sig, .method = "touchDoubleTap", .Args = TouchEventArgs },
    .{ .sig = BaseApp.touchCancelled_sig, .method = "touchCancelled", .Args = TouchEventArgs },
};

/// `cpp_overrides` for `T`'s `AppBase`: a `.{ signature, method }` pair for
/// each slot whose method `T` declares.
fn overrides(comptime Shim: type, comptime T: type) Overrides(Shim, T) {
    comptime var out: Overrides(Shim, T) = undefined;
    comptime var i = 0;
    inline for (slots) |s| if (@hasDecl(T, s.method)) {
        out[i] = .{ s.sig, override(Shim, T, s) };
        i += 1;
    };
    return out;
}

fn Overrides(comptime Shim: type, comptime T: type) type {
    var pairs: []const type = &.{};
    for (slots) |s| if (@hasDecl(T, s.method)) {
        pairs = pairs ++ &[_]type{@Tuple(&.{ Signature, OverrideFn(Shim, s) })};
    };
    return @Tuple(pairs);
}

/// What the override takes: `cpp.bind`'s parameters for the slot, so the
/// event by pointer.
fn OverrideFn(comptime Shim: type, comptime s: Slot) type {
    return fn (*Shim, *(s.Args orelse EventArgs)) void;
}

/// The Zig method receives a trivially copyable event by value, and a
/// managed one (`DragInfo`, `Message`) by const pointer.
fn override(comptime Shim: type, comptime T: type, comptime s: Slot) OverrideFn(Shim, s) {
    return struct {
        fn f(shim: *Shim, arg: *(s.Args orelse EventArgs)) void {
            if (s.Args) |A| {
                if (comptime A == DragInfo or A == Message)
                    call(T, s.method, .{ shim.app, arg })
                else
                    call(T, s.method, .{ shim.app, arg.* });
            } else {
                call(T, s.method, .{shim.app});
            }
        }
    }.f;
}

inline fn call(comptime T: type, comptime method: []const u8, args: anytype) void {
    if (comptime throws(T, method)) {
        @call(.auto, @field(T, method), args) catch |err| panicError(method, err, @errorReturnTrace());
    } else {
        @call(.auto, @field(T, method), args);
    }
}

/// Whether an app method returns `!void` rather than `void`.
fn throws(comptime T: type, comptime method: []const u8) bool {
    const Ret = @typeInfo(@TypeOf(@field(T, method))).@"fn".return_type.?;
    const info = @typeInfo(Ret);
    if (info != .error_union) return false;
    if (info.error_union.payload != void) @compileError(
        "app method '" ++ method ++ "' must return void or !void, not " ++ @typeName(Ret),
    );
    return true;
}

/// oF calls the app from the C++ main loop, so an error has nowhere to
/// propagate to: dump the error return trace and panic at the throw site.
fn panicError(comptime method: []const u8, err: anyerror, trace: ?*std.builtin.StackTrace) noreturn {
    if (trace) |t| std.debug.dumpErrorReturnTrace(t);
    std.debug.panicExtra(@returnAddress(), "app method '" ++ method ++ "' returned error.{s}", .{@errorName(err)});
}
