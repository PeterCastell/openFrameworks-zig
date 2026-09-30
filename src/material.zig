//! ofMaterial.h: the surface properties -- diffuse, ambient, specular and
//! emissive reflectance, and the specular exponent -- that lighting shades
//! a mesh with. What a light emits meets what a material reflects.
//!
//! ```zig
//! var material: of.Material = undefined;   // a field of the app struct
//! material.init();                         // in setup; deinit in exit
//! material.setDiffuseColor(of.FloatColor.steelBlue);
//! material.setShininess(120);
//!
//! material.begin();                        // in draw, with lighting on
//! mesh.draw();
//! material.end();
//! ```
//!
//! Between `begin` and `end` the material replaces the current color for
//! everything drawn, so `setColor` has no effect there. The colors are
//! `FloatColor`s, as a light's are; `.from(of.Color.wheat)` converts a
//! `Color`, and every named constant exists on `FloatColor` directly.
//!
//! The PBR properties -- metallic, roughness, reflectance, clear coat --
//! apply only under the programmable renderer, which `of.run` does not
//! select; they are bound so a sketch that does can reach them. Textures
//! and custom shaders are not bound, since `ofTexture` and `ofShader` are
//! not.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const matrix = @import("matrix.zig");
const FloatColor = @import("color.zig").FloatColor;
const String = @import("string.zig").String;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec2I = math.Vec2I;
const Vec3I = math.Vec3I;
const Vec4I = math.Vec4I;
const GlmVec2 = math.GlmVec2;
const GlmVec3 = math.GlmVec3;
const GlmVec4 = math.GlmVec4;
const GlmVec2I = math.GlmVec2I;
const GlmVec3I = math.GlmVec3I;
const GlmVec4I = math.GlmVec4I;
const Mat3 = matrix.Mat3;
const Mat4 = matrix.Mat4;

/// `ofBaseMaterial`, the interface `ofMaterial` implements: a vtable
/// pointer and a `bound` flag. Abstract, so never constructed; it is here
/// as the base `Material` declares, so the glue can check the relation.
pub const BaseMaterial = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [8]u8 align(8),

    pub const cpp_name = "ofBaseMaterial";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;
};

/// `ofMaterial`.
///
/// The class holds an `ofMaterialSettings` (the colors and PBR scalars,
/// with a dozen `std::string`s for shader overrides) and a set of
/// `std::unordered_map`s for custom uniforms and cached shaders; none of it
/// is read from Zig, so the binding gives the storage and the glue checks
/// the size. It owns heap, so `deinit` it, and construct it where it will
/// live rather than copying it.
pub const Material = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [1600]u8 align(8),

    pub const cpp_name = "ofMaterial";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{BaseMaterial};
    pub const cpp_virtual_dtor = true;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Material };
    /// Runs `ofMaterial()` on the storage of `self`: diffuse `0.8` grey,
    /// ambient `0.2` grey, black specular and emissive, shininess `0.2`.
    pub fn init(self: *Material) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Material };
    pub fn deinit(self: *Material) void {
        cpp.bind(dtor_sig)(self);
    }

    // rendering

    /// Applies the material to everything drawn until `end`.
    pub const begin_sig: Signature = .{ .name = "begin", .this = *const Material, .virtual = true };
    pub fn begin(self: *const Material) void {
        cpp.bind(begin_sig)(self);
    }
    pub const end_sig: Signature = .{ .name = "end", .this = *const Material, .virtual = true };
    pub fn end(self: *const Material) void {
        cpp.bind(end_sig)(self);
    }

    // Phong colors

    /// All four at once: diffuse, ambient, specular, emissive.
    pub const setColors_sig: Signature = .{ .name = "setColors", .this = *Material, .args = &.{ FloatColor, FloatColor, FloatColor, FloatColor } };
    pub fn setColors(self: *Material, diffuse: FloatColor, ambient: FloatColor, specular: FloatColor, emissive: FloatColor) void {
        cpp.bind(setColors_sig)(self, diffuse, ambient, specular, emissive);
    }
    /// The color of the surface under direct light; the albedo, in PBR.
    pub const setDiffuseColor_sig: Signature = .{ .name = "setDiffuseColor", .this = *Material, .args = &.{FloatColor} };
    pub fn setDiffuseColor(self: *Material, c: FloatColor) void {
        cpp.bind(setDiffuseColor_sig)(self, c);
    }
    /// The color of the surface in shadow, lit by the ambient term.
    pub const setAmbientColor_sig: Signature = .{ .name = "setAmbientColor", .this = *Material, .args = &.{FloatColor} };
    pub fn setAmbientColor(self: *Material, c: FloatColor) void {
        cpp.bind(setAmbientColor_sig)(self, c);
    }
    /// The color of the highlight; its size is `setShininess`.
    pub const setSpecularColor_sig: Signature = .{ .name = "setSpecularColor", .this = *Material, .args = &.{FloatColor} };
    pub fn setSpecularColor(self: *Material, c: FloatColor) void {
        cpp.bind(setSpecularColor_sig)(self, c);
    }
    /// Light the surface gives off on its own, unlit.
    pub const setEmissiveColor_sig: Signature = .{ .name = "setEmissiveColor", .this = *Material, .args = &.{FloatColor} };
    pub fn setEmissiveColor(self: *Material, c: FloatColor) void {
        cpp.bind(setEmissiveColor_sig)(self, c);
    }
    /// The specular exponent: higher is a smaller, sharper highlight. The
    /// fixed pipeline clamps it to `[0, 128]`.
    pub const setShininess_sig: Signature = .{ .name = "setShininess", .this = *Material, .args = &.{f32} };
    pub fn setShininess(self: *Material, shininess: f32) void {
        cpp.bind(setShininess_sig)(self, shininess);
    }
    /// Scales the texture coordinates the material's shader samples with.
    pub const setTexCoordScale_sig: Signature = .{ .name = "setTexCoordScale", .this = *Material, .args = &.{ f32, f32 } };
    pub fn setTexCoordScale(self: *Material, scale: Vec2) void {
        cpp.bind(setTexCoordScale_sig)(self, scale[0], scale[1]);
    }

    pub const getDiffuseColor_sig: Signature = .{ .name = "getDiffuseColor", .this = *const Material, .ret = FloatColor, .virtual = true };
    pub fn getDiffuseColor(self: *const Material) FloatColor {
        return cpp.bind(getDiffuseColor_sig)(self);
    }
    pub const getAmbientColor_sig: Signature = .{ .name = "getAmbientColor", .this = *const Material, .ret = FloatColor, .virtual = true };
    pub fn getAmbientColor(self: *const Material) FloatColor {
        return cpp.bind(getAmbientColor_sig)(self);
    }
    pub const getSpecularColor_sig: Signature = .{ .name = "getSpecularColor", .this = *const Material, .ret = FloatColor, .virtual = true };
    pub fn getSpecularColor(self: *const Material) FloatColor {
        return cpp.bind(getSpecularColor_sig)(self);
    }
    pub const getEmissiveColor_sig: Signature = .{ .name = "getEmissiveColor", .this = *const Material, .ret = FloatColor, .virtual = true };
    pub fn getEmissiveColor(self: *const Material) FloatColor {
        return cpp.bind(getEmissiveColor_sig)(self);
    }
    pub const getShininess_sig: Signature = .{ .name = "getShininess", .this = *const Material, .ret = f32, .virtual = true };
    pub fn getShininess(self: *const Material) f32 {
        return cpp.bind(getShininess_sig)(self);
    }

    // PBR

    /// Whether the renderer in use can shade a PBR material.
    pub const isPBRSupported_sig: Signature = .{ .name = "isPBRSupported", .class = Material, .ret = bool };
    pub fn isPBRSupported() bool {
        return cpp.bind(isPBRSupported_sig)();
    }
    /// Switches the material between the Phong model and the PBR one.
    /// Setting any PBR property switches it on as well.
    pub const setPBR_sig: Signature = .{ .name = "setPBR", .this = *Material, .args = &.{bool} };
    pub fn setPBR(self: *Material, on: bool) void {
        cpp.bind(setPBR_sig)(self, on);
    }
    pub const isPBR_sig: Signature = .{ .name = "isPBR", .this = *const Material, .ret = bool };
    pub fn isPBR(self: *const Material) bool {
        return cpp.bind(isPBR_sig)(self);
    }
    /// `0` is a dielectric, `1` a metal.
    pub const setMetallic_sig: Signature = .{ .name = "setMetallic", .this = *Material, .args = &.{Ref(*const f32)} };
    pub fn setMetallic(self: *Material, metallic: f32) void {
        cpp.bind(setMetallic_sig)(self, &metallic);
    }
    pub const getMetallic_sig: Signature = .{ .name = "getMetallic", .this = *const Material, .ret = f32 };
    pub fn getMetallic(self: *const Material) f32 {
        return cpp.bind(getMetallic_sig)(self);
    }
    /// `0` is a mirror, `1` fully diffuse.
    pub const setRoughness_sig: Signature = .{ .name = "setRoughness", .this = *Material, .args = &.{Ref(*const f32)} };
    pub fn setRoughness(self: *Material, roughness: f32) void {
        cpp.bind(setRoughness_sig)(self, &roughness);
    }
    pub const getRoughness_sig: Signature = .{ .name = "getRoughness", .this = *const Material, .ret = f32 };
    pub fn getRoughness(self: *const Material) f32 {
        return cpp.bind(getRoughness_sig)(self);
    }
    /// How much a dielectric reflects head-on; ignored for a metal.
    pub const setReflectance_sig: Signature = .{ .name = "setReflectance", .this = *Material, .args = &.{Ref(*const f32)} };
    pub fn setReflectance(self: *Material, reflectance: f32) void {
        cpp.bind(setReflectance_sig)(self, &reflectance);
    }
    pub const getReflectance_sig: Signature = .{ .name = "getReflectance", .this = *const Material, .ret = f32 };
    pub fn getReflectance(self: *const Material) f32 {
        return cpp.bind(getReflectance_sig)(self);
    }
    /// A second, glossy layer over the surface; off by default.
    pub const setClearCoatEnabled_sig: Signature = .{ .name = "setClearCoatEnabled", .this = *Material, .args = &.{bool} };
    pub fn setClearCoatEnabled(self: *Material, on: bool) void {
        cpp.bind(setClearCoatEnabled_sig)(self, on);
    }
    pub const isClearCoatEnabled_sig: Signature = .{ .name = "isClearCoatEnabled", .this = *const Material, .ret = bool };
    pub fn isClearCoatEnabled(self: *const Material) bool {
        return cpp.bind(isClearCoatEnabled_sig)(self);
    }
    pub const setClearCoatStrength_sig: Signature = .{ .name = "setClearCoatStrength", .this = *Material, .args = &.{Ref(*const f32)} };
    pub fn setClearCoatStrength(self: *Material, strength: f32) void {
        cpp.bind(setClearCoatStrength_sig)(self, &strength);
    }
    pub const getClearCoatStrength_sig: Signature = .{ .name = "getClearCoatStrength", .this = *const Material, .ret = f32 };
    pub fn getClearCoatStrength(self: *const Material) f32 {
        return cpp.bind(getClearCoatStrength_sig)(self);
    }
    pub const setClearCoatRoughness_sig: Signature = .{ .name = "setClearCoatRoughness", .this = *Material, .args = &.{Ref(*const f32)} };
    pub fn setClearCoatRoughness(self: *Material, roughness: f32) void {
        cpp.bind(setClearCoatRoughness_sig)(self, &roughness);
    }
    pub const getClearCoatRoughness_sig: Signature = .{ .name = "getClearCoatRoughness", .this = *const Material, .ret = f32 };
    pub fn getClearCoatRoughness(self: *const Material) f32 {
        return cpp.bind(getClearCoatRoughness_sig)(self);
    }

    // Custom uniforms: values the material's shader can read by `name`.
    // Programmable renderer only; the fixed pipeline has no shader to read
    // them. Each `std::string` is built for the call and freed after it.

    pub const setCustomUniform1f_sig: Signature = .{ .name = "setCustomUniform1f", .this = *Material, .args = &.{ Ref(*const String), f32 } };
    pub fn setCustomUniform1f(self: *Material, name: []const u8, value: f32) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform1f_sig)(self, &s, value);
    }
    pub const setCustomUniform2f_sig: Signature = .{ .name = "setCustomUniform2f", .this = *Material, .args = &.{ Ref(*const String), GlmVec2 } };
    pub fn setCustomUniform2f(self: *Material, name: []const u8, value: Vec2) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform2f_sig)(self, &s, .from(value));
    }
    pub const setCustomUniform3f_sig: Signature = .{ .name = "setCustomUniform3f", .this = *Material, .args = &.{ Ref(*const String), GlmVec3 } };
    pub fn setCustomUniform3f(self: *Material, name: []const u8, value: Vec3) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform3f_sig)(self, &s, .from(value));
    }
    pub const setCustomUniform4f_sig: Signature = .{ .name = "setCustomUniform4f", .this = *Material, .args = &.{ Ref(*const String), GlmVec4 } };
    pub fn setCustomUniform4f(self: *Material, name: []const u8, value: Vec4) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform4f_sig)(self, &s, .from(value));
    }
    pub const setCustomUniformMatrix4f_sig: Signature = .{ .name = "setCustomUniformMatrix4f", .this = *Material, .args = &.{ Ref(*const String), Mat4 } };
    pub fn setCustomUniformMatrix4f(self: *Material, name: []const u8, value: Mat4) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniformMatrix4f_sig)(self, &s, value);
    }
    pub const setCustomUniformMatrix3f_sig: Signature = .{ .name = "setCustomUniformMatrix3f", .this = *Material, .args = &.{ Ref(*const String), Mat3 } };
    pub fn setCustomUniformMatrix3f(self: *Material, name: []const u8, value: Mat3) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniformMatrix3f_sig)(self, &s, value);
    }
    pub const setCustomUniform1i_sig: Signature = .{ .name = "setCustomUniform1i", .this = *Material, .args = &.{ Ref(*const String), i32 } };
    pub fn setCustomUniform1i(self: *Material, name: []const u8, value: i32) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform1i_sig)(self, &s, value);
    }
    pub const setCustomUniform2i_sig: Signature = .{ .name = "setCustomUniform2i", .this = *Material, .args = &.{ Ref(*const String), GlmVec2I } };
    pub fn setCustomUniform2i(self: *Material, name: []const u8, value: Vec2I) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform2i_sig)(self, &s, .from(value));
    }
    pub const setCustomUniform3i_sig: Signature = .{ .name = "setCustomUniform3i", .this = *Material, .args = &.{ Ref(*const String), GlmVec3I } };
    pub fn setCustomUniform3i(self: *Material, name: []const u8, value: Vec3I) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform3i_sig)(self, &s, .from(value));
    }
    pub const setCustomUniform4i_sig: Signature = .{ .name = "setCustomUniform4i", .this = *Material, .args = &.{ Ref(*const String), GlmVec4I } };
    pub fn setCustomUniform4i(self: *Material, name: []const u8, value: Vec4I) void {
        var s = String.init(name);
        defer s.deinit();
        cpp.bind(setCustomUniform4i_sig)(self, &s, .from(value));
    }
};
