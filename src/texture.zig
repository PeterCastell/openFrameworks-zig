//! ofTexture.h: an OpenGL texture, and `ofBaseDraws`, the interface every
//! drawable oF object with a size implements.
//!
//! ```zig
//! var tex: of.Texture = undefined;   // a field of the app struct
//! tex.init();                        // in setup; deinit in exit
//! tex.allocate(256, 256, of.texture.gl_rgba);
//!
//! tex.draw(10, 10);                  // in draw: at its own size
//! tex.drawSized(10, 10, 64, 64);     // scaled to a box
//! ```
//!
//! A texture is usually not allocated by hand: a model's
//! (`of.assimp.ModelLoader.getTextureForMesh`) or a mesh's
//! (`of.assimp.MeshHelper.getTextureRef`) comes back ready. Images and
//! pixel uploads are not bound in this package yet, so neither are the
//! `ofPixels` overloads of `allocate` and `loadData`; their signatures are
//! here only because `ofTexture`'s vtable holds them.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const rectangle = @import("rectangle.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const GlmVec2 = math.GlmVec2;
const GlmVec3 = math.GlmVec3;
const OfRectangle = rectangle.OfRectangle;

/// `GL_RGB`, `GL_RGBA` and the other unsized internal formats oF's own
/// sketches pass to `allocate`. Any `GLint` internal format will do.
pub const gl_luminance: u32 = 0x1909;
pub const gl_rgb: u32 = 0x1907;
pub const gl_rgba: u32 = 0x1908;
pub const gl_rgb32f: u32 = 0x8815;
pub const gl_rgba32f: u32 = 0x8814;

/// `ofPixels_<T>`: `ofPixels`, `ofShortPixels` and `ofFloatPixels`. Opaque:
/// they appear here only as the parameters of `ofTexture`'s virtual
/// `allocate` overloads.
fn Pixels(comptime T: type) type {
    return opaque {
        pub const cpp_template: cpp.Template = .{ .name = "ofPixels_", .args = &.{.{ .type = T }}, .kind = .class };
    };
}
/// `unsigned char`, which Zig's `u8` (C++ `char`) is not.
pub const BytePixels = Pixels(cpp.uchar);
pub const ShortPixels = Pixels(u16);
pub const FloatPixels = Pixels(f32);

/// `ofTextureData`: the GL texture's id, target, format and size, which
/// `ofTexture` keeps by value. Opaque, like `Pixels`.
pub const TextureData = opaque {
    pub const cpp_name = "ofTextureData";
    pub const cpp_kind: cpp.Kind = .class;
};

/// `ofBaseDraws`: something drawn at a position, at its own size or
/// scaled, with an anchor. An abstract class, nothing but a vtable pointer;
/// `Texture` is the one here that implements it.
pub const BaseDraws = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),

    pub const cpp_name = "ofBaseDraws";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    pub const dtor_sig: Signature = .{ .name = "~", .this = *BaseDraws };
    pub const draw_sig: Signature = .{ .name = "draw", .this = *const BaseDraws, .args = &.{ f32, f32 }, .virtual = true };
    pub const draw_size_sig: Signature = .{ .name = "draw", .this = *const BaseDraws, .args = &.{ f32, f32, f32, f32 }, .pure = true };
    pub const draw_point_sig: Signature = .{ .name = "draw", .this = *const BaseDraws, .args = &.{Ref(*const GlmVec2)}, .virtual = true };
    pub const draw_rect_sig: Signature = .{ .name = "draw", .this = *const BaseDraws, .args = &.{Ref(*const OfRectangle)}, .virtual = true };
    pub const draw_point_size_sig: Signature = .{ .name = "draw", .this = *const BaseDraws, .args = &.{ Ref(*const GlmVec2), f32, f32 }, .virtual = true };
    pub const getHeight_sig: Signature = .{ .name = "getHeight", .this = *const BaseDraws, .ret = f32, .pure = true };
    pub const getWidth_sig: Signature = .{ .name = "getWidth", .this = *const BaseDraws, .ret = f32, .pure = true };
    /// Not `const` in oF, unlike the two getters it calls.
    pub const getSize_sig: Signature = .{ .name = "getSize", .this = *BaseDraws, .ret = GlmVec2, .virtual = true };
    pub const setAnchorPercent_sig: Signature = .{ .name = "setAnchorPercent", .this = *BaseDraws, .args = &.{ f32, f32 }, .virtual = true };
    pub const setAnchorPoint_sig: Signature = .{ .name = "setAnchorPoint", .this = *BaseDraws, .args = &.{ f32, f32 }, .virtual = true };
    pub const resetAnchor_sig: Signature = .{ .name = "resetAnchor", .this = *BaseDraws, .virtual = true };

    /// Every virtual function `ofBaseDraws` declares, in header order.
    pub const cpp_virtuals: []const Signature = &.{
        dtor_sig,
        draw_sig,
        draw_size_sig,
        draw_point_sig,
        draw_rect_sig,
        draw_point_size_sig,
        getHeight_sig,
        getWidth_sig,
        getSize_sig,
        setAnchorPercent_sig,
        setAnchorPoint_sig,
        resetAnchor_sig,
    };

    /// Draws at `(x, y)`, at the object's own size. A virtual call.
    pub fn draw(self: *const BaseDraws, x: f32, y: f32) void {
        cpp.bindVirtual(draw_sig)(self, x, y);
    }
    /// Draws scaled into the `w` by `h` box at `(x, y)`. A virtual call.
    pub fn drawSized(self: *const BaseDraws, x: f32, y: f32, w: f32, h: f32) void {
        cpp.bindVirtual(draw_size_sig)(self, x, y, w, h);
    }
    pub fn getWidth(self: *const BaseDraws) f32 {
        return cpp.bindVirtual(getWidth_sig)(self);
    }
    pub fn getHeight(self: *const BaseDraws) f32 {
        return cpp.bindVirtual(getHeight_sig)(self);
    }
    pub fn getSize(self: *BaseDraws) Vec2 {
        return cpp.bindVirtual(getSize_sig)(self).to();
    }
};

/// `ofTexture`.
///
/// It holds an `ofTextureData` (the GL id, target, formats and sizes, and
/// a texture matrix), the anchor and two flags; none of it is read from
/// Zig, so the binding gives the storage and the glue checks the size.
/// The GL texture behind it is shared by reference count between copies:
/// `initCopy` and every texture returned by value are a second handle on
/// the same GL texture, not a copy of its pixels. `deinit` every one.
pub const Texture = extern struct {
    _bases: cpp.BaseSpan(@This()) align(cpp.baseAlign(@This())),
    _storage: [176]u8 align(8),

    pub const cpp_name = "ofTexture";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_bases: []const type = &.{BaseDraws};
    pub const cpp_virtual_dtor = true;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Texture };
    /// Runs `ofTexture()` on the storage of `self`: no GL texture yet.
    pub fn init(self: *Texture) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const copy_ctor_sig: Signature = .{ .name = "*", .this = *Texture, .args = &.{Ref(*const Texture)} };
    /// `ofTexture(const ofTexture&)`, on the uninitialized storage of
    /// `self`: a second handle on `other`'s GL texture. Takes the place of
    /// `init`.
    pub fn initCopy(self: *Texture, other: *const Texture) void {
        cpp.bind(copy_ctor_sig)(self, other);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Texture };
    /// Drops this handle; the last one deletes the GL texture.
    pub fn deinit(self: *Texture) void {
        cpp.bind(dtor_sig)(self);
    }

    /// The `ofBaseDraws` interface. `Texture`'s own wrappers cover it, so
    /// this is for code that takes any drawable.
    pub fn baseDraws(self: *Texture) *BaseDraws {
        return cpp.basePtr(BaseDraws, self);
    }

    // allocation. The twelve overloads are all virtual; the GL work needs
    // the window, so call them from `setup` or later.

    const Data = Ref(*const TextureData);
    pub const allocate_data_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{Data}, .virtual = true };
    pub const allocate_data_format_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ Data, i32, i32 }, .virtual = true };
    pub const allocate_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ i32, i32, i32 }, .virtual = true };
    pub const allocate_format_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ i32, i32, i32, i32, i32 }, .virtual = true };
    pub const allocate_arb_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ i32, i32, i32, bool }, .virtual = true };
    pub const allocate_arb_format_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ i32, i32, i32, bool, i32, i32 }, .virtual = true };
    pub const allocate_pixels_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{Ref(*const BytePixels)}, .virtual = true };
    pub const allocate_pixels_arb_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ Ref(*const BytePixels), bool }, .virtual = true };
    pub const allocate_short_pixels_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{Ref(*const ShortPixels)}, .virtual = true };
    pub const allocate_short_pixels_arb_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ Ref(*const ShortPixels), bool }, .virtual = true };
    pub const allocate_float_pixels_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{Ref(*const FloatPixels)}, .virtual = true };
    pub const allocate_float_pixels_arb_sig: Signature = .{ .name = "allocate", .this = *Texture, .args = &.{ Ref(*const FloatPixels), bool }, .virtual = true };

    /// `allocate(w, h, glInternalFormat)`: an empty `width` by `height`
    /// texture of `internal_format` (`gl_rgba`, say), rectangular or
    /// power-of-two as oF's texture settings choose. Reallocating frees the
    /// old one.
    pub fn allocate(self: *Texture, width: u32, height: u32, internal_format: u32) void {
        cpp.bindVirtual(allocate_sig)(self, @bitCast(width), @bitCast(height), @bitCast(internal_format));
    }
    /// `allocate(w, h, glInternalFormat, bUseARBExtension)`: as `allocate`,
    /// with `arb` choosing a `GL_TEXTURE_RECTANGLE` (pixel texture
    /// coordinates) over a `GL_TEXTURE_2D` (normalized ones).
    pub fn allocateArb(self: *Texture, width: u32, height: u32, internal_format: u32, arb: bool) void {
        cpp.bindVirtual(allocate_arb_sig)(self, @bitCast(width), @bitCast(height), @bitCast(internal_format), arb);
    }
    pub const isAllocated_sig: Signature = .{ .name = "isAllocated", .this = *const Texture, .ret = bool };
    /// Whether there is a GL texture behind this handle.
    pub fn isAllocated(self: *const Texture) bool {
        return cpp.bind(isAllocated_sig)(self);
    }
    pub const clear_sig: Signature = .{ .name = "clear", .this = *Texture };
    /// Drops this handle's GL texture, as `deinit` does, leaving the
    /// texture unallocated and usable again.
    pub fn clear(self: *Texture) void {
        cpp.bind(clear_sig)(self);
    }

    // drawing. Each draws a textured quad, anchored as `setAnchor*` says.

    /// `draw(x, y)`, at the texture's own size. Overrides `ofBaseDraws`'s;
    /// the call is virtual.
    pub const draw_sig: Signature = .{ .name = "draw", .this = *const Texture, .args = &.{ f32, f32 }, .virtual = true };
    pub fn draw(self: *const Texture, x: f32, y: f32) void {
        cpp.bindVirtual(draw_sig)(self, x, y);
    }
    pub fn drawv(self: *const Texture, pos: Vec2) void {
        self.draw(pos[0], pos[1]);
    }
    /// `draw(x, y, w, h)`, scaled into the box. Virtual, too.
    pub const draw_size_sig: Signature = .{ .name = "draw", .this = *const Texture, .args = &.{ f32, f32, f32, f32 }, .virtual = true };
    pub fn drawSized(self: *const Texture, x: f32, y: f32, w: f32, h: f32) void {
        cpp.bindVirtual(draw_size_sig)(self, x, y, w, h);
    }
    pub fn drawSizedv(self: *const Texture, pos: Vec2, size: Vec2) void {
        self.drawSized(pos[0], pos[1], size[0], size[1]);
    }
    /// `draw(const glm::vec3&)`: at a point in 3D, at the texture's size.
    pub const draw_pos3_sig: Signature = .{ .name = "draw", .this = *const Texture, .args = &.{Ref(*const GlmVec3)} };
    pub fn draw3(self: *const Texture, pos: Vec3) void {
        cpp.bind(draw_pos3_sig)(self, &GlmVec3.from(pos));
    }
    /// `draw(const glm::vec3&, float w, float h)`.
    pub const draw_pos3_size_sig: Signature = .{ .name = "draw", .this = *const Texture, .args = &.{ Ref(*const GlmVec3), f32, f32 } };
    pub fn drawSized3(self: *const Texture, pos: Vec3, size: Vec2) void {
        cpp.bind(draw_pos3_size_sig)(self, &GlmVec3.from(pos), size[0], size[1]);
    }
    /// `draw(p1, p2, p3, p4)`: onto any quad, its corners in the order
    /// top-left, top-right, bottom-right, bottom-left.
    pub const draw_quad_sig: Signature = .{
        .name = "draw",
        .this = *const Texture,
        .args = &.{ Ref(*const GlmVec3), Ref(*const GlmVec3), Ref(*const GlmVec3), Ref(*const GlmVec3) },
    };
    pub fn drawQuad(self: *const Texture, p1: Vec3, p2: Vec3, p3: Vec3, p4: Vec3) void {
        cpp.bind(draw_quad_sig)(self, &GlmVec3.from(p1), &GlmVec3.from(p2), &GlmVec3.from(p3), &GlmVec3.from(p4));
    }
    /// `drawSubsection(x, y, w, h, sx, sy, sw, sh)`: the `sw` by `sh`
    /// region at `(sx, sy)` of the texture, in its pixels, into the `w` by
    /// `h` box at `(x, y)`.
    pub const drawSubsection_sig: Signature = .{
        .name = "drawSubsection",
        .this = *const Texture,
        .args = &.{ f32, f32, f32, f32, f32, f32, f32, f32 },
    };
    pub fn drawSubsection(self: *const Texture, pos: Vec2, size: Vec2, src_pos: Vec2, src_size: Vec2) void {
        cpp.bind(drawSubsection_sig)(self, pos[0], pos[1], size[0], size[1], src_pos[0], src_pos[1], src_size[0], src_size[1]);
    }

    // binding, for a mesh drawn with its texture coordinates

    /// `bind(textureLocation)`: makes this the texture of texture unit
    /// `unit` for what is drawn until `unbind`. A mesh drawn in between
    /// samples it through its own texture coordinates.
    pub const bind_sig: Signature = .{ .name = "bind", .this = *const Texture, .args = &.{i32} };
    pub fn bind(self: *const Texture, unit: u32) void {
        cpp.bind(bind_sig)(self, @bitCast(unit));
    }
    pub const unbind_sig: Signature = .{ .name = "unbind", .this = *const Texture, .args = &.{i32} };
    pub fn unbind(self: *const Texture, unit: u32) void {
        cpp.bind(unbind_sig)(self, @bitCast(unit));
    }

    // size and anchor

    pub const getWidth_sig: Signature = .{ .name = "getWidth", .this = *const Texture, .ret = f32, .virtual = true };
    pub fn getWidth(self: *const Texture) f32 {
        return cpp.bindVirtual(getWidth_sig)(self);
    }
    pub const getHeight_sig: Signature = .{ .name = "getHeight", .this = *const Texture, .ret = f32, .virtual = true };
    pub fn getHeight(self: *const Texture) f32 {
        return cpp.bindVirtual(getHeight_sig)(self);
    }
    pub fn getSize(self: *const Texture) Vec2 {
        return .{ self.getWidth(), self.getHeight() };
    }
    /// The point of the texture that `draw` puts at its position, as a
    /// fraction of its size: `.{ 0.5, 0.5 }` centers it.
    pub const setAnchorPercent_sig: Signature = .{ .name = "setAnchorPercent", .this = *Texture, .args = &.{ f32, f32 }, .virtual = true };
    pub fn setAnchorPercent(self: *Texture, pct: Vec2) void {
        cpp.bindVirtual(setAnchorPercent_sig)(self, pct[0], pct[1]);
    }
    /// The same point, in pixels.
    pub const setAnchorPoint_sig: Signature = .{ .name = "setAnchorPoint", .this = *Texture, .args = &.{ f32, f32 }, .virtual = true };
    pub fn setAnchorPoint(self: *Texture, point: Vec2) void {
        cpp.bindVirtual(setAnchorPoint_sig)(self, point[0], point[1]);
    }
    /// Back to the top-left corner.
    pub const resetAnchor_sig: Signature = .{ .name = "resetAnchor", .this = *Texture, .virtual = true };
    pub fn resetAnchor(self: *Texture) void {
        cpp.bindVirtual(resetAnchor_sig)(self);
    }

    /// Every virtual function `ofTexture.h` declares, in header order.
    /// `using ofBaseDraws::draw;` is the first declaration of `draw` here,
    /// ahead of the two overrides.
    pub const cpp_virtuals: []const Signature = &.{
        allocate_data_sig,
        allocate_data_format_sig,
        allocate_sig,
        allocate_format_sig,
        allocate_arb_sig,
        allocate_arb_format_sig,
        allocate_pixels_sig,
        allocate_pixels_arb_sig,
        allocate_short_pixels_sig,
        allocate_short_pixels_arb_sig,
        allocate_float_pixels_sig,
        allocate_float_pixels_arb_sig,
        dtor_sig,
        cpp.firstNamed("draw"),
        draw_sig,
        draw_size_sig,
        getHeight_sig,
        getWidth_sig,
        setAnchorPercent_sig,
        setAnchorPoint_sig,
        resetAnchor_sig,
    };

    // texture coordinates

    /// `getCoordFromPoint(x, y)`: the texture coordinate of the pixel at
    /// `(x, y)`, normalized or in pixels as the texture's target wants.
    pub const getCoordFromPoint_sig: Signature = .{ .name = "getCoordFromPoint", .this = *const Texture, .args = &.{ f32, f32 }, .ret = GlmVec2 };
    pub fn getCoordFromPoint(self: *const Texture, point: Vec2) Vec2 {
        return cpp.bind(getCoordFromPoint_sig)(self, point[0], point[1]).to();
    }
    /// `getCoordFromPercent(x, y)`: the same for a fraction of its size.
    pub const getCoordFromPercent_sig: Signature = .{ .name = "getCoordFromPercent", .this = *const Texture, .args = &.{ f32, f32 }, .ret = GlmVec2 };
    pub fn getCoordFromPercent(self: *const Texture, pct: Vec2) Vec2 {
        return cpp.bind(getCoordFromPercent_sig)(self, pct[0], pct[1]).to();
    }
};
