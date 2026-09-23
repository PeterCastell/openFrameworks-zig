//! `ofRectangle`, as a Zig value type.
//!
//! `Rectangle` is a plain struct of two `Vec2`s. Copy it, store it in an
//! array, return it from a function — it is just four floats. Its methods
//! are Zig, not calls into C++, and they reproduce `ofRectangle`'s exact
//! semantics, quirks included (see `getArea` and `inside`).
//!
//! ```zig
//! const box: of.Rectangle = .{ .position = .{ 40, 80 }, .size = .{ 220, 120 } };
//! box.draw();
//! ```
//!
//! `OfRectangle` below is the ABI type, the layout the C++ class actually
//! has. It appears only in a `Signature`, and a `Rectangle` is staged into
//! one at the boundary. That split is not a style choice: `ofRectangle`
//! declares `float& x` and `float& y` bound to its own `position`, so an
//! instance cannot be copied or moved once constructed. Keeping it out of
//! the public API is what makes `Rectangle` an ordinary value.
//!
//! oF's `position` is a `glm::vec3`, but the z is a fossil of the days when
//! `ofPoint` was `ofVec3f`: the class has no `getZ`/`setZ`, `getCenter`
//! returns z as `0.f`, and `ofDrawRectangle(const ofRectangle&)` passes a
//! hardcoded `0.0f`. Nothing in oF reads it except a stream operator that
//! does not match its own writer. So `Rectangle` is 2D.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const math = @import("math.zig");
const graphics = @import("graphics.zig");
const Vec2 = math.Vec2;
const GlmVec3 = math.GlmVec3;

pub const Rectangle = struct {
    position: Vec2 = @splat(0),
    size: Vec2 = @splat(0),

    pub fn init(x: f32, y: f32, w: f32, h: f32) Rectangle {
        return .{ .position = .{ x, y }, .size = .{ w, h } };
    }

    pub fn width(r: Rectangle) f32 {
        return r.size[0];
    }
    pub fn height(r: Rectangle) f32 {
        return r.size[1];
    }

    /// The lower corner, which is not `position` when a side is negative.
    pub fn getMin(r: Rectangle) Vec2 {
        return @min(r.position, r.position + r.size);
    }
    /// The upper corner.
    pub fn getMax(r: Rectangle) Vec2 {
        return @max(r.position, r.position + r.size);
    }

    /// The same rectangle with both sides positive, which is what oF calls
    /// standardized.
    pub fn standardized(r: Rectangle) Rectangle {
        return .{ .position = r.getMin(), .size = @abs(r.size) };
    }

    pub fn getCenter(r: Rectangle) Vec2 {
        return r.position + r.size * @as(Vec2, @splat(0.5));
    }

    /// `abs(width) * abs(height)`, as oF defines it: a rectangle with a
    /// negative side still has a positive area.
    pub fn getArea(r: Rectangle) f32 {
        const a = @abs(r.size);
        return a[0] * a[1];
    }

    /// oF's test, strictly: a point exactly on an edge is *outside*. Sides
    /// may be negative; the comparison is against the standardized corners.
    pub fn inside(r: Rectangle, p: Vec2) bool {
        const lo = r.getMin();
        const hi = r.getMax();
        return @reduce(.And, p > lo) and @reduce(.And, p < hi);
    }

    /// Whether `other` lies wholly inside `r`, corners included in the same
    /// strict sense.
    pub fn insideRect(r: Rectangle, other: Rectangle) bool {
        return r.inside(other.getMin()) and r.inside(other.getMax());
    }

    /// The signature lives in `graphics.zig` with the rest of `ofGraphics.h`;
    /// the glue scan walks namespaces and C++ classes, and `Rectangle` is
    /// neither, so a `Signature` declared here would go unseen.
    pub fn draw(r: Rectangle) void {
        graphics.drawRectanglev(r.position, r.size[0], r.size[1]);
    }

    /// Runs the C++ constructor on `storage` and hands back the pointer a
    /// bound function wants. The constructor binds `OfRectangle`'s two
    /// reference members into `storage` itself, so the result is only valid
    /// while `storage` lives and does not move — keep it a local:
    ///
    /// ```zig
    /// var tmp: of.OfRectangle = undefined;
    /// const p = rect.stage(&tmp);
    /// defer tmp.deinit();
    /// cpp.bind(some_sig)(p);
    /// ```
    pub fn stage(r: Rectangle, storage: *OfRectangle) *OfRectangle {
        storage.init(r.position[0], r.position[1], r.size[0], r.size[1]);
        return storage;
    }

    /// The four numbers of a C++ rectangle, dropping the vestigial z.
    pub fn fromOf(o: OfRectangle) Rectangle {
        return .{ .position = .{ o.position.x, o.position.y }, .size = .{ o.width, o.height } };
    }
};

/// `ofRectangle` itself: the layout the C++ class has, for signatures and
/// for staging. It has a virtual destructor and two reference members
/// aliasing its own `position`, so it is neither copyable nor movable —
/// construct it in place with `init` and let it die where it was born.
pub const OfRectangle = extern struct {
    _vptr: *const anyopaque,
    /// `glm::vec3`, so the ABI spelling.
    position: GlmVec3,
    /// `float& x` and `float& y`, bound to `position.x` and `position.y`.
    _x: *f32,
    _y: *f32,
    width: f32,
    height: f32,

    pub const cpp_name = "ofRectangle";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    /// `ofRectangle(x, y, w, h)`, run on `self`'s storage.
    pub const ctor_sig: Signature = .{ .name = "*", .args = &.{ f32, f32, f32, f32 }, .this = *OfRectangle };
    pub fn init(self: *OfRectangle, x: f32, y: f32, w: f32, h: f32) void {
        cpp.bind(ctor_sig)(self, x, y, w, h);
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *OfRectangle };
    pub fn deinit(self: *OfRectangle) void {
        cpp.bind(dtor_sig)(self);
    }

    pub fn toRect(self: *const OfRectangle) Rectangle {
        return .fromOf(self.*);
    }
};
