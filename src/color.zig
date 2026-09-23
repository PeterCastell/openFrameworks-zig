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
//! The arithmetic operators and the 140 named constants are not bound: the
//! operators are per-channel with saturation, which Zig spells as plainly,
//! and cpp-bindgen binds functions, not data.
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

        pub const white: Self = .{ .r = max, .g = max, .b = max };
        pub const black: Self = .{ .r = 0, .g = 0, .b = 0 };
        pub const red: Self = .{ .r = max, .g = 0, .b = 0 };
        pub const green: Self = .{ .r = 0, .g = max, .b = 0 };
        pub const blue: Self = .{ .r = 0, .g = 0, .b = max };

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
