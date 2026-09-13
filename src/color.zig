//! ofColor.h: `ofColor_<T>` for the three pixel types oF uses.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;

/// `ofColor` = `ofColor_<unsigned char>`
pub const Color = extern struct {
    r: u8 = 255,
    g: u8 = 255,
    b: u8 = 255,
    a: u8 = 255,
    pub const cpp_template = cpp.Template{ .name = "ofColor_", .args = &.{.{ .type = cpp.uchar }}, .kind = .class };
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }
    pub fn grey(v: u8) Color {
        return .{ .r = v, .g = v, .b = v };
    }

    /// `ofColor::fromHsb(hue, saturation, brightness, alpha)`, all in `[0, 255]`.
    pub const fromHsb_sig: Signature = .{ .name = "fromHsb", .args = &.{ f32, f32, f32, f32 }, .ret = Color, .class = Color };
    pub fn fromHsb(hue: f32, saturation: f32, brightness: f32, alpha: f32) Color {
        return cpp.bind(fromHsb_sig)(hue, saturation, brightness, alpha);
    }

    /// `getHue()`, in `[0, 255]`.
    pub const getHue_sig: Signature = .{ .name = "getHue", .ret = f32, .this = *const Color };
    pub fn getHue(self: *const Color) f32 {
        return cpp.bind(getHue_sig)(self);
    }

    /// `setHsb(hue, saturation, brightness, alpha)`
    pub const setHsb_sig: Signature = .{ .name = "setHsb", .args = &.{ f32, f32, f32, f32 }, .this = *Color };
    pub fn setHsb(self: *Color, hue: f32, saturation: f32, brightness: f32, alpha: f32) void {
        cpp.bind(setHsb_sig)(self, hue, saturation, brightness, alpha);
    }

    pub const white: Color = .{ .r = 255, .g = 255, .b = 255 };
    pub const black: Color = .{ .r = 0, .g = 0, .b = 0 };
    pub const red: Color = .{ .r = 255, .g = 0, .b = 0 };
    pub const green: Color = .{ .r = 0, .g = 255, .b = 0 };
    pub const blue: Color = .{ .r = 0, .g = 0, .b = 255 };
};

/// `ofFloatColor` = `ofColor_<float>`
pub const FloatColor = extern struct {
    r: f32 = 1,
    g: f32 = 1,
    b: f32 = 1,
    a: f32 = 1,
    pub const cpp_template = cpp.Template{ .name = "ofColor_", .args = &.{.{ .type = f32 }}, .kind = .class };
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;
};

/// `ofShortColor` = `ofColor_<unsigned short>`
pub const ShortColor = extern struct {
    r: u16 = 65535,
    g: u16 = 65535,
    b: u16 = 65535,
    a: u16 = 65535,
    pub const cpp_template = cpp.Template{ .name = "ofColor_", .args = &.{.{ .type = u16 }}, .kind = .class };
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;
};
