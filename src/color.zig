//! ofColor.h: `ofColor_<T>` for the three pixel types oF uses.
//!
//! The three types are one generator, `ColorType`, instantiated three times,
//! so every method exists once and each type has all of them. What differs
//! is the channel type and its `limit`:
//!
//! | type | channel | `limit` |
//! |---|---|---|
//! | `Color` | `u8` | 255 |
//! | `FloatColor` | `f32` | 1.0 |
//! | `ShortColor` | `u16` | 65535 |
//!
//! oF's hue, saturation, brightness and lerp methods take `float`s **in the
//! channel's own range**, so `Color.fromHsb(128, 255, 255, 255)` and
//! `FloatColor.fromHsb(0.5, 1, 1, 1)` are the same color. `setNormalizedHsb`
//! and `getNormalizedHsb` are the ones in `[0, 1]` whatever the type, and
//! `from` converts between types by scaling. A hue *angle* is radians here,
//! as every angle in this package is; oF's is degrees.
//!
//! The arithmetic operators are not bound: they are per-channel with
//! saturation, which Zig spells as plainly. The named constants
//! (`ofColor::wheat` and the rest) are constants here too, with oF's own
//! values; cpp-bindgen binds functions, not data, so they are restated
//! rather than bound.
const std = @import("std");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");

const Vec3 = math.Vec3;
const GlmVec3 = math.GlmVec3;

/// `ofColor_<CppElem>` with channels of Zig type `E`, whose top value is
/// `max` -- what oF's `limit()` returns for that pixel type.
fn ColorType(comptime E: type, comptime CppElem: type, comptime max: E) type {
    return extern struct {
        r: E = max,
        g: E = max,
        b: E = max,
        a: E = max,

        const Self = @This();
        pub const cpp_template = cpp.Template{ .name = "ofColor_", .args = &.{.{ .type = CppElem }}, .kind = .class };
        pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

        /// `ofColor_<T>::limit()`: the top of every channel's range, and
        /// of every hue, saturation and brightness this type takes.
        pub const limit: E = max;

        pub fn rgb(r: E, g: E, b: E) Self {
            return .{ .r = r, .g = g, .b = b };
        }
        pub fn rgba(r: E, g: E, b: E, a: E) Self {
            return .{ .r = r, .g = g, .b = b, .a = a };
        }
        pub fn grey(v: E) Self {
            return .{ .r = v, .g = v, .b = v };
        }

        // The named colors of `ofColor.h`, in its order and with its
        // values: `ofColor.cpp` writes each channel as a fraction of
        // `limit()`, and an integer channel truncates the product as C++
        // does. So `Color.aliceBlue` is `239, 247, 255` as it is in oF,
        // where CSS says `240, 248, 255`; `FloatColor.aliceBlue` is exact.
        // oF's `grey` (the constant, `0.501961 * limit`) is left out: `grey`
        // is the function above, and `gray` is a count off it anyway.

        pub const white: Self = .{ .r = max, .g = max, .b = max };
        pub const gray: Self = .{ .r = max / 2, .g = max / 2, .b = max / 2 };
        pub const black: Self = .{ .r = 0, .g = 0, .b = 0 };
        pub const red: Self = .{ .r = max, .g = 0, .b = 0 };
        pub const green: Self = .{ .r = 0, .g = max, .b = 0 };
        pub const blue: Self = .{ .r = 0, .g = 0, .b = max };
        pub const cyan: Self = .{ .r = 0, .g = max, .b = max };
        pub const magenta: Self = .{ .r = max, .g = 0, .b = max };
        pub const yellow: Self = .{ .r = max, .g = max, .b = 0 };
        pub const aliceBlue: Self = named(0.941176, 0.972549, 1);
        pub const antiqueWhite: Self = named(0.980392, 0.921569, 0.843137);
        pub const aqua: Self = named(0, 1, 1);
        pub const aquamarine: Self = named(0.498039, 1, 0.831373);
        pub const azure: Self = named(0.941176, 1, 1);
        pub const beige: Self = named(0.960784, 0.960784, 0.862745);
        pub const bisque: Self = named(1, 0.894118, 0.768627);
        pub const blanchedAlmond: Self = named(1, 0.921569, 0.803922);
        pub const blueViolet: Self = named(0.541176, 0.168627, 0.886275);
        pub const brown: Self = named(0.647059, 0.164706, 0.164706);
        pub const burlyWood: Self = named(0.870588, 0.721569, 0.529412);
        pub const cadetBlue: Self = named(0.372549, 0.619608, 0.627451);
        pub const chartreuse: Self = named(0.498039, 1, 0);
        pub const chocolate: Self = named(0.823529, 0.411765, 0.117647);
        pub const coral: Self = named(1, 0.498039, 0.313726);
        pub const cornflowerBlue: Self = named(0.392157, 0.584314, 0.929412);
        pub const cornsilk: Self = named(1, 0.972549, 0.862745);
        pub const crimson: Self = named(0.862745, 0.0784314, 0.235294);
        pub const darkBlue: Self = named(0, 0, 0.545098);
        pub const darkCyan: Self = named(0, 0.545098, 0.545098);
        pub const darkGoldenRod: Self = named(0.721569, 0.52549, 0.0431373);
        pub const darkGray: Self = named(0.662745, 0.662745, 0.662745);
        pub const darkGrey: Self = darkGray;
        pub const darkGreen: Self = named(0, 0.392157, 0);
        pub const darkKhaki: Self = named(0.741176, 0.717647, 0.419608);
        pub const darkMagenta: Self = named(0.545098, 0, 0.545098);
        pub const darkOliveGreen: Self = named(0.333333, 0.419608, 0.184314);
        pub const darkOrange: Self = named(1, 0.54902, 0);
        pub const darkOrchid: Self = named(0.6, 0.196078, 0.8);
        pub const darkRed: Self = named(0.545098, 0, 0);
        pub const darkSalmon: Self = named(0.913725, 0.588235, 0.478431);
        pub const darkSeaGreen: Self = named(0.560784, 0.737255, 0.560784);
        pub const darkSlateBlue: Self = named(0.282353, 0.239216, 0.545098);
        pub const darkSlateGray: Self = named(0.184314, 0.309804, 0.309804);
        pub const darkSlateGrey: Self = darkSlateGray;
        pub const darkTurquoise: Self = named(0, 0.807843, 0.819608);
        pub const darkViolet: Self = named(0.580392, 0, 0.827451);
        pub const deepPink: Self = named(1, 0.0784314, 0.576471);
        pub const deepSkyBlue: Self = named(0, 0.74902, 1);
        pub const dimGray: Self = named(0.411765, 0.411765, 0.411765);
        pub const dimGrey: Self = dimGray;
        pub const dodgerBlue: Self = named(0.117647, 0.564706, 1);
        pub const fireBrick: Self = named(0.698039, 0.133333, 0.133333);
        pub const floralWhite: Self = named(1, 0.980392, 0.941176);
        pub const forestGreen: Self = named(0.133333, 0.545098, 0.133333);
        pub const fuchsia: Self = named(1, 0, 1);
        pub const gainsboro: Self = named(0.862745, 0.862745, 0.862745);
        pub const ghostWhite: Self = named(0.972549, 0.972549, 1);
        pub const gold: Self = named(1, 0.843137, 0);
        pub const goldenRod: Self = named(0.854902, 0.647059, 0.12549);
        pub const greenYellow: Self = named(0.678431, 1, 0.184314);
        pub const honeyDew: Self = named(0.941176, 1, 0.941176);
        pub const hotPink: Self = named(1, 0.411765, 0.705882);
        pub const indianRed: Self = named(0.803922, 0.360784, 0.360784);
        pub const indigo: Self = named(0.294118, 0, 0.509804);
        pub const ivory: Self = named(1, 1, 0.941176);
        pub const khaki: Self = named(0.941176, 0.901961, 0.54902);
        pub const lavender: Self = named(0.901961, 0.901961, 0.980392);
        pub const lavenderBlush: Self = named(1, 0.941176, 0.960784);
        pub const lawnGreen: Self = named(0.486275, 0.988235, 0);
        pub const lemonChiffon: Self = named(1, 0.980392, 0.803922);
        pub const lightBlue: Self = named(0.678431, 0.847059, 0.901961);
        pub const lightCoral: Self = named(0.941176, 0.501961, 0.501961);
        pub const lightCyan: Self = named(0.878431, 1, 1);
        pub const lightGoldenRodYellow: Self = named(0.980392, 0.980392, 0.823529);
        pub const lightGray: Self = named(0.827451, 0.827451, 0.827451);
        pub const lightGrey: Self = lightGray;
        pub const lightGreen: Self = named(0.564706, 0.933333, 0.564706);
        pub const lightPink: Self = named(1, 0.713726, 0.756863);
        pub const lightSalmon: Self = named(1, 0.627451, 0.478431);
        pub const lightSeaGreen: Self = named(0.12549, 0.698039, 0.666667);
        pub const lightSkyBlue: Self = named(0.529412, 0.807843, 0.980392);
        pub const lightSlateGray: Self = named(0.466667, 0.533333, 0.6);
        pub const lightSlateGrey: Self = lightSlateGray;
        pub const lightSteelBlue: Self = named(0.690196, 0.768627, 0.870588);
        pub const lightYellow: Self = named(1, 1, 0.878431);
        pub const lime: Self = named(0, 1, 0);
        pub const limeGreen: Self = named(0.196078, 0.803922, 0.196078);
        pub const linen: Self = named(0.980392, 0.941176, 0.901961);
        pub const maroon: Self = named(0.501961, 0, 0);
        pub const mediumAquaMarine: Self = named(0.4, 0.803922, 0.666667);
        pub const mediumBlue: Self = named(0, 0, 0.803922);
        pub const mediumOrchid: Self = named(0.729412, 0.333333, 0.827451);
        pub const mediumPurple: Self = named(0.576471, 0.439216, 0.858824);
        pub const mediumSeaGreen: Self = named(0.235294, 0.701961, 0.443137);
        pub const mediumSlateBlue: Self = named(0.482353, 0.407843, 0.933333);
        pub const mediumSpringGreen: Self = named(0, 0.980392, 0.603922);
        pub const mediumTurquoise: Self = named(0.282353, 0.819608, 0.8);
        pub const mediumVioletRed: Self = named(0.780392, 0.0823529, 0.521569);
        pub const midnightBlue: Self = named(0.0980392, 0.0980392, 0.439216);
        pub const mintCream: Self = named(0.960784, 1, 0.980392);
        pub const mistyRose: Self = named(1, 0.894118, 0.882353);
        pub const moccasin: Self = named(1, 0.894118, 0.709804);
        pub const navajoWhite: Self = named(1, 0.870588, 0.678431);
        pub const navy: Self = named(0, 0, 0.501961);
        pub const oldLace: Self = named(0.992157, 0.960784, 0.901961);
        pub const olive: Self = named(0.501961, 0.501961, 0);
        pub const oliveDrab: Self = named(0.419608, 0.556863, 0.137255);
        pub const orange: Self = named(1, 0.647059, 0);
        pub const orangeRed: Self = named(1, 0.270588, 0);
        pub const orchid: Self = named(0.854902, 0.439216, 0.839216);
        pub const paleGoldenRod: Self = named(0.933333, 0.909804, 0.666667);
        pub const paleGreen: Self = named(0.596078, 0.984314, 0.596078);
        pub const paleTurquoise: Self = named(0.686275, 0.933333, 0.933333);
        pub const paleVioletRed: Self = named(0.858824, 0.439216, 0.576471);
        pub const papayaWhip: Self = named(1, 0.937255, 0.835294);
        pub const peachPuff: Self = named(1, 0.854902, 0.72549);
        pub const peru: Self = named(0.803922, 0.521569, 0.247059);
        pub const pink: Self = named(1, 0.752941, 0.796078);
        pub const plum: Self = named(0.866667, 0.627451, 0.866667);
        pub const powderBlue: Self = named(0.690196, 0.878431, 0.901961);
        pub const purple: Self = named(0.501961, 0, 0.501961);
        pub const rosyBrown: Self = named(0.737255, 0.560784, 0.560784);
        pub const royalBlue: Self = named(0.254902, 0.411765, 0.882353);
        pub const saddleBrown: Self = named(0.545098, 0.270588, 0.0745098);
        pub const salmon: Self = named(0.980392, 0.501961, 0.447059);
        pub const sandyBrown: Self = named(0.956863, 0.643137, 0.376471);
        pub const seaGreen: Self = named(0.180392, 0.545098, 0.341176);
        pub const seaShell: Self = named(1, 0.960784, 0.933333);
        pub const sienna: Self = named(0.627451, 0.321569, 0.176471);
        pub const silver: Self = named(0.752941, 0.752941, 0.752941);
        pub const skyBlue: Self = named(0.529412, 0.807843, 0.921569);
        pub const slateBlue: Self = named(0.415686, 0.352941, 0.803922);
        pub const slateGray: Self = named(0.439216, 0.501961, 0.564706);
        pub const slateGrey: Self = slateGray;
        pub const snow: Self = named(1, 0.980392, 0.980392);
        pub const springGreen: Self = named(0, 1, 0.498039);
        pub const steelBlue: Self = named(0.27451, 0.509804, 0.705882);
        pub const blueSteel: Self = steelBlue;
        pub const tan: Self = named(0.823529, 0.705882, 0.54902);
        pub const teal: Self = named(0, 0.501961, 0.501961);
        pub const thistle: Self = named(0.847059, 0.74902, 0.847059);
        pub const tomato: Self = named(1, 0.388235, 0.278431);
        pub const turquoise: Self = named(0.25098, 0.878431, 0.815686);
        pub const violet: Self = named(0.933333, 0.509804, 0.933333);
        pub const wheat: Self = named(0.960784, 0.870588, 0.701961);
        pub const whiteSmoke: Self = named(0.960784, 0.960784, 0.960784);
        pub const yellowGreen: Self = named(0.603922, 0.803922, 0.196078);

        /// A named color from its channels as fractions of `limit`, the way
        /// `ofColor.cpp` writes them.
        fn named(comptime r: comptime_float, comptime g: comptime_float, comptime b: comptime_float) Self {
            return .{ .r = channel(r), .g = channel(g), .b = channel(b) };
        }

        /// oF's `fraction * limit()` assigned to a `PixelType`: exact for a
        /// float channel, truncated toward zero for an integer one.
        fn channel(comptime frac: comptime_float) E {
            return switch (@typeInfo(E)) {
                .float => frac * max,
                .int => @intFromFloat(@floor(frac * @as(comptime_float, max))),
                else => unreachable,
            };
        }

        /// The same color as another of the three types, each channel
        /// scaled from that type's `limit` to this one's. What oF's
        /// converting constructor does, in Zig.
        pub fn from(other: anytype) Self {
            const O = @TypeOf(other);
            return .{
                .r = convert(other.r, O.limit),
                .g = convert(other.g, O.limit),
                .b = convert(other.b, O.limit),
                .a = convert(other.a, O.limit),
            };
        }

        fn convert(v: anytype, from_limit: anytype) E {
            const scaled = toFloat(v) / toFloat(from_limit) * toFloat(max);
            return switch (@typeInfo(E)) {
                .float => @floatCast(scaled),
                .int => @intFromFloat(@round(std.math.clamp(scaled, 0, toFloat(max)))),
                else => unreachable,
            };
        }

        fn toFloat(v: anytype) f32 {
            return switch (@typeInfo(@TypeOf(v))) {
                .float, .comptime_float => @floatCast(v),
                .int, .comptime_int => @floatFromInt(v),
                else => unreachable,
            };
        }

        // constructors, as statics

        /// `ofColor_::fromHsb(hue, saturation, brightness, alpha)`, all in
        /// `[0, limit]`. A hue of `limit` is the same as 0.
        pub const fromHsb_sig: Signature = .{ .name = "fromHsb", .args = &.{ f32, f32, f32, f32 }, .ret = Self, .class = Self };
        pub fn fromHsb(hue: f32, saturation: f32, brightness: f32, alpha: f32) Self {
            return cpp.bind(fromHsb_sig)(hue, saturation, brightness, alpha);
        }
        /// `ofColor_::fromHex(0xRRGGBB, alpha)`, with `alpha` in `[0, limit]`.
        pub const fromHex_sig: Signature = .{ .name = "fromHex", .args = &.{ i32, f32 }, .ret = Self, .class = Self };
        pub fn fromHex(hex: u32, alpha: f32) Self {
            return cpp.bind(fromHex_sig)(@bitCast(hex), alpha);
        }

        // setters

        /// `setHex(0xRRGGBB, alpha)`
        pub const setHex_sig: Signature = .{ .name = "setHex", .args = &.{ i32, f32 }, .this = *Self };
        pub fn setHex(self: *Self, hex: u32, alpha: f32) void {
            cpp.bind(setHex_sig)(self, @bitCast(hex), alpha);
        }
        /// Keeps saturation and brightness. `hue` in `[0, limit]`.
        pub const setHue_sig: Signature = .{ .name = "setHue", .args = &.{f32}, .this = *Self };
        pub fn setHue(self: *Self, hue: f32) void {
            cpp.bind(setHue_sig)(self, hue);
        }
        /// `setHueAngle(degrees)`, taking radians: the hue as an angle
        /// around the color wheel, whatever the type's `limit`.
        pub const setHueAngle_sig: Signature = .{ .name = "setHueAngle", .args = &.{f32}, .this = *Self };
        pub fn setHueAngle(self: *Self, radians: f32) void {
            cpp.bind(setHueAngle_sig)(self, std.math.radiansToDegrees(radians));
        }
        pub const setSaturation_sig: Signature = .{ .name = "setSaturation", .args = &.{f32}, .this = *Self };
        pub fn setSaturation(self: *Self, saturation: f32) void {
            cpp.bind(setSaturation_sig)(self, saturation);
        }
        pub const setBrightness_sig: Signature = .{ .name = "setBrightness", .args = &.{f32}, .this = *Self };
        pub fn setBrightness(self: *Self, brightness: f32) void {
            cpp.bind(setBrightness_sig)(self, brightness);
        }
        /// `setHsb(hue, saturation, brightness, alpha)`, all in `[0, limit]`.
        pub const setHsb_sig: Signature = .{ .name = "setHsb", .args = &.{ f32, f32, f32, f32 }, .this = *Self };
        pub fn setHsb(self: *Self, hue: f32, saturation: f32, brightness: f32, alpha: f32) void {
            cpp.bind(setHsb_sig)(self, hue, saturation, brightness, alpha);
        }
        /// `setNormalizedHsb(glm::vec3)`: hue, saturation and brightness in
        /// `[0, 1]` whatever the type. Leaves alpha alone.
        pub const setNormalizedHsb_sig: Signature = .{ .name = "setNormalizedHsb", .args = &.{GlmVec3}, .this = *Self };
        pub fn setNormalizedHsb(self: *Self, hsb: Vec3) void {
            cpp.bind(setNormalizedHsb_sig)(self, .from(hsb));
        }

        // in-place edits; oF returns `*this` from each, which is dropped

        /// Clamps every channel to `[0, limit]`. Only a `FloatColor` can be
        /// outside it.
        pub const clamp_sig: Signature = .{ .name = "clamp", .ret = Ref(*Self), .this = *Self };
        pub fn clamp(self: *Self) void {
            _ = cpp.bind(clamp_sig)(self);
        }
        /// `limit - channel` for r, g and b; alpha stays.
        pub const invert_sig: Signature = .{ .name = "invert", .ret = Ref(*Self), .this = *Self };
        pub fn invert(self: *Self) void {
            _ = cpp.bind(invert_sig)(self);
        }
        /// Scales r, g and b so the brightest is `limit`; alpha stays.
        pub const normalize_sig: Signature = .{ .name = "normalize", .ret = Ref(*Self), .this = *Self };
        pub fn normalize(self: *Self) void {
            _ = cpp.bind(normalize_sig)(self);
        }
        /// Moves every channel, alpha included, `amount` of the way to
        /// `target`, with `amount` in `[0, 1]`.
        pub const lerp_sig: Signature = .{ .name = "lerp", .args = &.{ Ref(*const Self), f32 }, .ret = Ref(*Self), .this = *Self };
        pub fn lerp(self: *Self, target: Self, amount: f32) void {
            _ = cpp.bind(lerp_sig)(self, &target, amount);
        }

        // the same, as new values

        pub const getClamped_sig: Signature = .{ .name = "getClamped", .ret = Self, .this = *const Self };
        pub fn getClamped(self: *const Self) Self {
            return cpp.bind(getClamped_sig)(self);
        }
        pub const getInverted_sig: Signature = .{ .name = "getInverted", .ret = Self, .this = *const Self };
        pub fn getInverted(self: *const Self) Self {
            return cpp.bind(getInverted_sig)(self);
        }
        pub const getNormalized_sig: Signature = .{ .name = "getNormalized", .ret = Self, .this = *const Self };
        pub fn getNormalized(self: *const Self) Self {
            return cpp.bind(getNormalized_sig)(self);
        }
        pub const getLerped_sig: Signature = .{ .name = "getLerped", .args = &.{ Ref(*const Self), f32 }, .ret = Self, .this = *const Self };
        pub fn getLerped(self: *const Self, target: Self, amount: f32) Self {
            return cpp.bind(getLerped_sig)(self, &target, amount);
        }

        // getters

        /// `0xRRGGBB`, without the alpha.
        pub const getHex_sig: Signature = .{ .name = "getHex", .ret = i32, .this = *const Self };
        pub fn getHex(self: *const Self) u32 {
            return @bitCast(cpp.bind(getHex_sig)(self));
        }
        /// In `[0, limit]`.
        pub const getHue_sig: Signature = .{ .name = "getHue", .ret = f32, .this = *const Self };
        pub fn getHue(self: *const Self) f32 {
            return cpp.bind(getHue_sig)(self);
        }
        /// `getHueAngle()` in radians, `[0, 2 pi)`.
        pub const getHueAngle_sig: Signature = .{ .name = "getHueAngle", .ret = f32, .this = *const Self };
        pub fn getHueAngle(self: *const Self) f32 {
            return std.math.degreesToRadians(cpp.bind(getHueAngle_sig)(self));
        }
        /// In `[0, limit]`.
        pub const getSaturation_sig: Signature = .{ .name = "getSaturation", .ret = f32, .this = *const Self };
        pub fn getSaturation(self: *const Self) f32 {
            return cpp.bind(getSaturation_sig)(self);
        }
        /// The largest of r, g and b, in `[0, limit]`.
        pub const getBrightness_sig: Signature = .{ .name = "getBrightness", .ret = f32, .this = *const Self };
        pub fn getBrightness(self: *const Self) f32 {
            return cpp.bind(getBrightness_sig)(self);
        }
        /// The mean of r, g and b, in `[0, limit]`.
        pub const getLightness_sig: Signature = .{ .name = "getLightness", .ret = f32, .this = *const Self };
        pub fn getLightness(self: *const Self) f32 {
            return cpp.bind(getLightness_sig)(self);
        }
        /// Hue, saturation and brightness in `[0, limit]`.
        pub const getHsb_sig: Signature = .{ .name = "getHsb", .ret = GlmVec3, .this = *const Self };
        pub fn getHsb(self: *const Self) Vec3 {
            return cpp.bind(getHsb_sig)(self).to();
        }
        /// Hue, saturation and brightness in `[0, 1]` whatever the type.
        pub const getNormalizedHsb_sig: Signature = .{ .name = "getNormalizedHsb", .ret = GlmVec3, .this = *const Self };
        pub fn getNormalizedHsb(self: *const Self) Vec3 {
            return cpp.bind(getNormalizedHsb_sig)(self).to();
        }
    };
}

/// `ofColor` = `ofColor_<unsigned char>`, channels 0 to 255.
pub const Color = ColorType(u8, cpp.uchar, 255);

/// `ofFloatColor` = `ofColor_<float>`, channels 0 to 1. What a mesh and a
/// light carry, and what the renderer works in.
pub const FloatColor = ColorType(f32, f32, 1.0);

/// `ofShortColor` = `ofColor_<unsigned short>`, channels 0 to 65535.
pub const ShortColor = ColorType(u16, u16, 65535);
