//! `ofRectangle`.
//!
//! It has a virtual destructor and two reference members (`x` and `y` alias
//! `position.x` and `position.y`), so it is constructed by the C++
//! constructor and is not movable: construct it in place with `init` and
//! never copy it.
//!
//! ```zig
//! var r: of.Rectangle = undefined;
//! r.init(10, 10, 200, 100);
//! defer r.deinit();
//! ```
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const math = @import("math.zig");
const Vec3 = math.Vec3;
const GlmVec3 = math.GlmVec3;

pub const Rectangle = extern struct {
    _vptr: *const anyopaque,
    /// `glm::vec3`, so the ABI spelling; `getPosition` hands back a `Vec3`.
    position: GlmVec3,
    _x: *f32,
    _y: *f32,
    width: f32,
    height: f32,

    pub const cpp_name = "ofRectangle";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    /// `ofRectangle(x, y, w, h)`, run on `self`'s storage.
    pub const ctor_sig: Signature = .{ .name = "*", .args = &.{ f32, f32, f32, f32 }, .this = *Rectangle };
    pub fn init(self: *Rectangle, x: f32, y: f32, w: f32, h: f32) void {
        cpp.bind(ctor_sig)(self, x, y, w, h);
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *Rectangle };
    pub fn deinit(self: *Rectangle) void {
        cpp.bind(dtor_sig)(self);
    }

    pub const set_sig: Signature = .{ .name = "set", .args = &.{ f32, f32, f32, f32 }, .this = *Rectangle };
    pub fn set(self: *Rectangle, x: f32, y: f32, w: f32, h: f32) void {
        cpp.bind(set_sig)(self, x, y, w, h);
    }

    pub const inside_sig: Signature = .{ .name = "inside", .args = &.{ f32, f32 }, .ret = bool, .this = *const Rectangle };
    pub fn inside(self: *const Rectangle, x: f32, y: f32) bool {
        return cpp.bind(inside_sig)(self, x, y);
    }

    /// The top-left corner, as a `Vec3` you can do arithmetic on.
    pub fn getPosition(self: *const Rectangle) Vec3 {
        return self.position.to();
    }

    pub const getCenter_sig: Signature = .{ .name = "getCenter", .ret = GlmVec3, .this = *const Rectangle };
    pub fn getCenter(self: *const Rectangle) Vec3 {
        return cpp.bind(getCenter_sig)(self).to();
    }

    pub const getArea_sig: Signature = .{ .name = "getArea", .ret = f32, .this = *const Rectangle };
    pub fn getArea(self: *const Rectangle) f32 {
        return cpp.bind(getArea_sig)(self);
    }

    /// `ofDrawRectangle(rect)`. The corner is `position.x`/`position.y`.
    pub const ofDrawRectangle_sig: Signature = .{ .name = "ofDrawRectangle", .args = &.{cpp.Ref(*const Rectangle)} };
    pub fn draw(self: *const Rectangle) void {
        cpp.bind(ofDrawRectangle_sig)(self);
    }
};
