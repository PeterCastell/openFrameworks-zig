//! ofLight.h: a light source, which is an `ofNode`, and the global lighting
//! switches.
//!
//! ```zig
//! var light: of.Light = undefined;   // a field of the app struct
//! light.init();                      // in setup
//! light.setPointLight();
//! light.node().setPosition(.{ 200, 300, 200 });
//!
//! of.enableLighting();               // in draw, inside a camera
//! light.enable();
//! box.draw();
//! light.disable();
//! of.disableLighting();
//! ```
//!
//! Lighting only shades meshes that carry normals, which the primitives do
//! and the immediate-mode solids in `graphics3d.zig` do too.
const std = @import("std");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const FloatColor = @import("color.zig").FloatColor;
const Node = @import("node.zig").Node;

/// `ofLightType`
pub const LightType = enum(i32) {
    point = 0,
    directional = 1,
    spot = 2,
    /// Programmable renderer only.
    area = 3,
    pub const cpp_name = "ofLightType";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

// global state

pub const ofEnableLighting_sig: Signature = .{ .name = "ofEnableLighting" };
pub fn enableLighting() void {
    cpp.bind(ofEnableLighting_sig)();
}
pub const ofDisableLighting_sig: Signature = .{ .name = "ofDisableLighting" };
pub fn disableLighting() void {
    cpp.bind(ofDisableLighting_sig)();
}
pub const ofGetLightingEnabled_sig: Signature = .{ .name = "ofGetLightingEnabled", .ret = bool };
pub fn getLightingEnabled() bool {
    return cpp.bind(ofGetLightingEnabled_sig)();
}
pub const ofEnableSeparateSpecularLight_sig: Signature = .{ .name = "ofEnableSeparateSpecularLight" };
pub fn enableSeparateSpecularLight() void {
    cpp.bind(ofEnableSeparateSpecularLight_sig)();
}
pub const ofDisableSeparateSpecularLight_sig: Signature = .{ .name = "ofDisableSeparateSpecularLight" };
pub fn disableSeparateSpecularLight() void {
    cpp.bind(ofDisableSeparateSpecularLight_sig)();
}
/// Gouraud (smooth) against flat shading.
pub const ofSetSmoothLighting_sig: Signature = .{ .name = "ofSetSmoothLighting", .args = &.{bool} };
pub fn setSmoothLighting(smooth: bool) void {
    cpp.bind(ofSetSmoothLighting_sig)(smooth);
}
/// The ambient term every lit surface gets, whatever lights are on.
pub const ofSetGlobalAmbientColor_sig: Signature = .{ .name = "ofSetGlobalAmbientColor", .args = &.{Ref(*const FloatColor)} };
pub fn setGlobalAmbientColor(c: FloatColor) void {
    cpp.bind(ofSetGlobalAmbientColor_sig)(&c);
}
pub const ofGetGlobalAmbientColor_sig: Signature = .{ .name = "ofGetGlobalAmbientColor", .ret = Ref(*const FloatColor) };
pub fn getGlobalAmbientColor() FloatColor {
    return cpp.bind(ofGetGlobalAmbientColor_sig)().*;
}

/// `ofLight`. Its position and direction are its node's; the light shines
/// down the node's -z axis, so `lookAt` aims it.
///
/// The renderer allows a fixed number of lights (eight in the fixed
/// pipeline). `init` claims a slot and `deinit` frees it, so a `Light` is
/// constructed in place like every other class here.
pub const Light = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [272]u8 align(8),

    pub const cpp_name = "ofLight";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{Node};
    pub const cpp_virtual_dtor = true;

    pub fn node(self: *Light) *Node {
        return cpp.basePtr(Node, self);
    }
    pub fn nodeConst(self: *const Light) *const Node {
        return cpp.basePtr(Node, self);
    }

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Light };
    /// Runs `ofLight()` on the storage of `self`: a white point light at the
    /// origin, disabled. Needs the window, so call it from `setup`.
    pub fn init(self: *Light) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Light };
    pub fn deinit(self: *Light) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `setup()`: claims a renderer slot if the constructor could not, which
    /// happens when the light is constructed before the window exists.
    pub const setup_sig: Signature = .{ .name = "setup", .this = *Light };
    pub fn setup(self: *Light) void {
        cpp.bind(setup_sig)(self);
    }

    /// Turns the light on for what is drawn next. Lighting as a whole must
    /// also be on: see `enableLighting`.
    pub const enable_sig: Signature = .{ .name = "enable", .this = *Light };
    pub fn enable(self: *Light) void {
        cpp.bind(enable_sig)(self);
    }
    pub const disable_sig: Signature = .{ .name = "disable", .this = *Light };
    pub fn disable(self: *Light) void {
        cpp.bind(disable_sig)(self);
    }
    pub const getIsEnabled_sig: Signature = .{ .name = "getIsEnabled", .this = *const Light, .ret = bool };
    pub fn getIsEnabled(self: *const Light) bool {
        return cpp.bind(getIsEnabled_sig)(self);
    }

    // kind

    /// Parallel light along the node's -z axis; position does not matter.
    pub const setDirectional_sig: Signature = .{ .name = "setDirectional", .this = *Light };
    pub fn setDirectional(self: *Light) void {
        cpp.bind(setDirectional_sig)(self);
    }
    pub const getIsDirectional_sig: Signature = .{ .name = "getIsDirectional", .this = *const Light, .ret = bool };
    pub fn getIsDirectional(self: *const Light) bool {
        return cpp.bind(getIsDirectional_sig)(self);
    }

    /// `setSpotlight(spotCutOff, exponent)`, with the cone's half-angle in
    /// radians rather than oF's degrees. `concentration` is how sharply the
    /// light falls off toward the edge; 0 is even.
    pub const setSpotlight_sig: Signature = .{ .name = "setSpotlight", .this = *Light, .args = &.{ f32, f32 } };
    pub fn setSpotlight(self: *Light, cutoff: f32, concentration: f32) void {
        cpp.bind(setSpotlight_sig)(self, std.math.radiansToDegrees(cutoff), concentration);
    }
    pub const getIsSpotlight_sig: Signature = .{ .name = "getIsSpotlight", .this = *const Light, .ret = bool };
    pub fn getIsSpotlight(self: *const Light) bool {
        return cpp.bind(getIsSpotlight_sig)(self);
    }
    /// The cone's half-angle, radians.
    pub const setSpotlightCutOff_sig: Signature = .{ .name = "setSpotlightCutOff", .this = *Light, .args = &.{f32} };
    pub fn setSpotlightCutOff(self: *Light, cutoff: f32) void {
        cpp.bind(setSpotlightCutOff_sig)(self, std.math.radiansToDegrees(cutoff));
    }
    pub const getSpotlightCutOff_sig: Signature = .{ .name = "getSpotlightCutOff", .this = *const Light, .ret = f32 };
    pub fn getSpotlightCutOff(self: *const Light) f32 {
        return std.math.degreesToRadians(cpp.bind(getSpotlightCutOff_sig)(self));
    }
    pub const setSpotConcentration_sig: Signature = .{ .name = "setSpotConcentration", .this = *Light, .args = &.{f32} };
    pub fn setSpotConcentration(self: *Light, exponent: f32) void {
        cpp.bind(setSpotConcentration_sig)(self, exponent);
    }
    pub const getSpotConcentration_sig: Signature = .{ .name = "getSpotConcentration", .this = *const Light, .ret = f32 };
    pub fn getSpotConcentration(self: *const Light) f32 {
        return cpp.bind(getSpotConcentration_sig)(self);
    }

    /// Radiates from the node's position in every direction. The default.
    pub const setPointLight_sig: Signature = .{ .name = "setPointLight", .this = *Light };
    pub fn setPointLight(self: *Light) void {
        cpp.bind(setPointLight_sig)(self);
    }
    pub const getIsPointLight_sig: Signature = .{ .name = "getIsPointLight", .this = *const Light, .ret = bool };
    pub fn getIsPointLight(self: *const Light) bool {
        return cpp.bind(getIsPointLight_sig)(self);
    }

    /// `setAttenuation(constant, linear, quadratic)`: how a point or spot
    /// light fades with distance `d`, as `1 / (c + l*d + q*d*d)`. oF starts
    /// at `1, 0, 0`, which is no fade.
    pub const setAttenuation_sig: Signature = .{ .name = "setAttenuation", .this = *Light, .args = &.{ f32, f32, f32 } };
    pub fn setAttenuation(self: *Light, constant: f32, linear: f32, quadratic: f32) void {
        cpp.bind(setAttenuation_sig)(self, constant, linear, quadratic);
    }
    pub const getAttenuationConstant_sig: Signature = .{ .name = "getAttenuationConstant", .this = *const Light, .ret = f32 };
    pub fn getAttenuationConstant(self: *const Light) f32 {
        return cpp.bind(getAttenuationConstant_sig)(self);
    }
    pub const getAttenuationLinear_sig: Signature = .{ .name = "getAttenuationLinear", .this = *const Light, .ret = f32 };
    pub fn getAttenuationLinear(self: *const Light) f32 {
        return cpp.bind(getAttenuationLinear_sig)(self);
    }
    pub const getAttenuationQuadratic_sig: Signature = .{ .name = "getAttenuationQuadratic", .this = *const Light, .ret = f32 };
    pub fn getAttenuationQuadratic(self: *const Light) f32 {
        return cpp.bind(getAttenuationQuadratic_sig)(self);
    }

    /// A rectangle of light `width` by `height`, facing down -z. Programmable
    /// renderer only.
    pub const setAreaLight_sig: Signature = .{ .name = "setAreaLight", .this = *Light, .args = &.{ f32, f32 } };
    pub fn setAreaLight(self: *Light, width: f32, height: f32) void {
        cpp.bind(setAreaLight_sig)(self, width, height);
    }
    pub const getIsAreaLight_sig: Signature = .{ .name = "getIsAreaLight", .this = *const Light, .ret = bool };
    pub fn getIsAreaLight(self: *const Light) bool {
        return cpp.bind(getIsAreaLight_sig)(self);
    }

    pub const getType_sig: Signature = .{ .name = "getType", .this = *const Light, .ret = i32 };
    pub fn getType(self: *const Light) LightType {
        return @fromBackingInt(cpp.bind(getType_sig)(self));
    }

    // colors

    pub const setAmbientColor_sig: Signature = .{ .name = "setAmbientColor", .this = *Light, .args = &.{Ref(*const FloatColor)} };
    pub fn setAmbientColor(self: *Light, c: FloatColor) void {
        cpp.bind(setAmbientColor_sig)(self, &c);
    }
    pub const setDiffuseColor_sig: Signature = .{ .name = "setDiffuseColor", .this = *Light, .args = &.{Ref(*const FloatColor)} };
    pub fn setDiffuseColor(self: *Light, c: FloatColor) void {
        cpp.bind(setDiffuseColor_sig)(self, &c);
    }
    pub const setSpecularColor_sig: Signature = .{ .name = "setSpecularColor", .this = *Light, .args = &.{Ref(*const FloatColor)} };
    pub fn setSpecularColor(self: *Light, c: FloatColor) void {
        cpp.bind(setSpecularColor_sig)(self, &c);
    }
    pub const getAmbientColor_sig: Signature = .{ .name = "getAmbientColor", .this = *const Light, .ret = FloatColor };
    pub fn getAmbientColor(self: *const Light) FloatColor {
        return cpp.bind(getAmbientColor_sig)(self);
    }
    pub const getDiffuseColor_sig: Signature = .{ .name = "getDiffuseColor", .this = *const Light, .ret = FloatColor };
    pub fn getDiffuseColor(self: *const Light) FloatColor {
        return cpp.bind(getDiffuseColor_sig)(self);
    }
    pub const getSpecularColor_sig: Signature = .{ .name = "getSpecularColor", .this = *const Light, .ret = FloatColor };
    pub fn getSpecularColor(self: *const Light) FloatColor {
        return cpp.bind(getSpecularColor_sig)(self);
    }

    /// The renderer slot this light holds, or -1 for none.
    pub const getLightID_sig: Signature = .{ .name = "getLightID", .this = *const Light, .ret = i32 };
    pub fn getLightID(self: *const Light) i32 {
        return cpp.bind(getLightID_sig)(self);
    }
};
