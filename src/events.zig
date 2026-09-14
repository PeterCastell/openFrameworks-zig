//! ofEvents.h: the argument types oF hands to an app's event handlers, and
//! the key, modifier and mouse-button constants.
const cpp = @import("cpp_bindgen");
const math = @import("math.zig");
const Vec2 = math.Vec2;
const GlmVec2 = math.GlmVec2;
const String = @import("string.zig").String;

/// `ofKeyEventArgs`
pub const KeyEventArgs = extern struct {
    type: Type,
    key: i32,
    keycode: i32,
    scancode: i32,
    codepoint: u32,
    isRepeat: bool,
    modifiers: i32,

    pub const Type = enum(i32) {
        pressed,
        released,
        pub const cpp_name = "ofKeyEventArgs::Type";
        pub const cpp_kind: cpp.Kind = .@"enum";
    };
    pub const cpp_name = "ofKeyEventArgs";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

    pub fn hasModifier(self: KeyEventArgs, m: i32) bool {
        return self.modifiers & m != 0;
    }
};

/// `ofMouseEventArgs`. It derives from `glm::vec2`, hence `x` and `y`.
pub const MouseEventArgs = extern struct {
    x: f32,
    y: f32,
    type: Type,
    button: i32,
    scrollX: f32,
    scrollY: f32,
    modifiers: i32,

    pub const Type = enum(i32) {
        pressed,
        moved,
        released,
        dragged,
        scrolled,
        entered,
        exited,
        pub const cpp_name = "ofMouseEventArgs::Type";
        pub const cpp_kind: cpp.Kind = .@"enum";
    };
    pub const cpp_name = "ofMouseEventArgs";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

    pub fn hasModifier(self: MouseEventArgs, m: i32) bool {
        return self.modifiers & m != 0;
    }

    /// The cursor, as a `Vec2` you can do arithmetic on.
    pub fn pos(self: MouseEventArgs) Vec2 {
        return .{ self.x, self.y };
    }

    /// The scroll delta.
    pub fn scroll(self: MouseEventArgs) Vec2 {
        return .{ self.scrollX, self.scrollY };
    }
};

/// `ofResizeEventArgs`
pub const ResizeEventArgs = extern struct {
    width: i32,
    height: i32,
    pub const cpp_name = "ofResizeEventArgs";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;
};

/// `ofTouchEventArgs`. Also derives from `glm::vec2`.
pub const TouchEventArgs = extern struct {
    x: f32,
    y: f32,
    type: Type,
    id: i32,
    time: i32,
    numTouches: i32,
    width: f32,
    height: f32,
    /// Reported by the platform's touch API and passed through unconverted.
    /// oF declares it without a unit and never reads it, so unlike every
    /// other angle here it is not guaranteed to be radians -- check against
    /// the platform you are targeting before you trust it.
    angle: f32,
    minoraxis: f32,
    majoraxis: f32,
    pressure: f32,
    xspeed: f32,
    yspeed: f32,
    xaccel: f32,
    yaccel: f32,

    pub const Type = enum(i32) {
        down,
        up,
        move,
        double_tap,
        cancel,
        pub const cpp_name = "ofTouchEventArgs::Type";
        pub const cpp_kind: cpp.Kind = .@"enum";
    };
    /// Where the touch is, as a `Vec2` you can do arithmetic on.
    pub fn pos(self: TouchEventArgs) Vec2 {
        return .{ self.x, self.y };
    }

    pub const cpp_name = "ofTouchEventArgs";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;
};

/// `ofDragInfo`: a `std::vector<std::filesystem::path>` of dropped files,
/// and where they were dropped. The vector is not readable from Zig yet.
pub const DragInfo = extern struct {
    _files: [3]usize,
    /// `glm::vec2`, so the ABI spelling; `pos` hands back a `Vec2`.
    position: GlmVec2,

    pub fn pos(self: DragInfo) Vec2 {
        return self.position.to();
    }

    pub const cpp_name = "ofDragInfo";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
};

/// `ofMessage`
pub const Message = extern struct {
    message: String,
    pub const cpp_name = "ofMessage";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
};

/// `enum ofKey`: what `KeyEventArgs.key` holds for special keys.
pub const key = struct {
    pub const @"return": i32 = 13;
    pub const esc: i32 = 27;
    pub const tab: i32 = 9;
    pub const backspace: i32 = 8;
    pub const del: i32 = 127;
    pub const space: i32 = 32;
    pub const left_shift: i32 = 0xe60;
    pub const right_shift: i32 = 0xe61;
    pub const left_control: i32 = 0xe62;
    pub const right_control: i32 = 0xe63;
    pub const left_alt: i32 = 0xe64;
    pub const right_alt: i32 = 0xe65;
    pub const left_super: i32 = 0xe66;
    pub const right_super: i32 = 0xe67;
    pub const f1: i32 = 0xe000;
    pub const f2: i32 = 0xe001;
    pub const f3: i32 = 0xe002;
    pub const f4: i32 = 0xe003;
    pub const f5: i32 = 0xe004;
    pub const f6: i32 = 0xe005;
    pub const f7: i32 = 0xe006;
    pub const f8: i32 = 0xe007;
    pub const f9: i32 = 0xe008;
    pub const f10: i32 = 0xe009;
    pub const f11: i32 = 0xe00A;
    pub const f12: i32 = 0xe00B;
    pub const left: i32 = 0xe00C;
    pub const up: i32 = 0xe00D;
    pub const right: i32 = 0xe00E;
    pub const down: i32 = 0xe00F;
    pub const page_up: i32 = 0xe010;
    pub const page_down: i32 = 0xe011;
    pub const home: i32 = 0xe012;
    pub const end: i32 = 0xe013;
    pub const insert: i32 = 0xe014;
};

/// Bits of `KeyEventArgs.modifiers` and `MouseEventArgs.modifiers`.
pub const modifier = struct {
    pub const shift: i32 = 0x1;
    pub const control: i32 = 0x2;
    pub const alt: i32 = 0x4;
    pub const super: i32 = 0x10;
};

/// Values of `MouseEventArgs.button`.
pub const mouse_button = struct {
    pub const left: i32 = 0;
    pub const middle: i32 = 1;
    pub const right: i32 = 2;
};
