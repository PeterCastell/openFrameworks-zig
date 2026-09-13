//! glm matrices and quaternions, and the `Transform` that composes them.
//!
//! Unlike the vectors, these have one spelling each, not two. The vector
//! split exists because `@Vector` hands you `+` and `*` for free; a matrix
//! product is not element-wise, so Zig has no builtin to gain and a second
//! type would buy nothing but a conversion. `Mat4` therefore *is* the ABI
//! type: its field is glm's own `value` array, and `&m` goes straight to a
//! bound function.
//!
//! Storage is glm's: column-major, so `value[1]` is the second column and
//! `m.mul(n)` applies `n` first. The arithmetic is written here over
//! `@Vector` columns rather than bound from glm — a 4x4 product is about
//! sixteen vector instructions, which is cheaper than the call would be.
//!
//! Euler angles are **degrees**, as yaw/pitch/roll:
//!
//! | component | name | axis | |
//! |---|---|---|---|
//! | `rotation[0]` | pitch | X | right |
//! | `rotation[1]` | yaw | Y | up |
//! | `rotation[2]` | roll | Z | toward the viewer |
//!
//! composed `Ry(yaw) * Rx(pitch) * Rz(roll)` — roll is applied first, then
//! pitch, then yaw. That is the usual convention for a Y-up renderer, and
//! the one Unity and Godot take.
//!
//! It is *not* the one `glm::quat(vec3)` builds, which is `Rz * Ry * Rx`,
//! and so not the one `ofNode::setOrientation(const glm::vec3&)` takes. A
//! quaternion carries no convention, so `Quat` is the currency to interop
//! through: bind `ofNode`'s `const glm::quat&` overload rather than its
//! euler one and the question does not arise.
const std = @import("std");
const cpp = @import("cpp_bindgen");
const math = @import("math.zig");

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const GlmVec3 = math.GlmVec3;
const GlmVec4 = math.GlmVec4;
const GlmQualifier = math.GlmQualifier;

const deg_to_rad: f32 = std.math.pi / 180.0;
const rad_to_deg: f32 = 180.0 / std.math.pi;

fn glmMat(comptime c: comptime_int, comptime r: comptime_int, comptime E: type) cpp.Template {
    return .{ .name = "glm::mat", .args = &.{
        .{ .int = c },
        .{ .int = r },
        .{ .type = E },
        .{ .value = .{ .type = GlmQualifier, .int = 0 } },
    } };
}

/// `glm::mat3`, three columns of three. 36 bytes, alignment 4.
pub const Mat3 = extern struct {
    /// glm's own member name. Unlike `vec`'s `x`/`y`/`z`, `mat` declares it
    /// private and reaches it through `operator[]`, so the glue cannot
    /// `offsetof` it — hence `cpp_no_offsets`. The size and alignment checks
    /// still run, and with one member of a known type they pin the layout.
    value: [3]GlmVec3,

    pub const cpp_template = glmMat(3, 3, f32);
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;
    pub const cpp_no_offsets = true;

    pub const identity: Mat3 = .{ .value = .{
        .{ .x = 1, .y = 0, .z = 0 },
        .{ .x = 0, .y = 1, .z = 0 },
        .{ .x = 0, .y = 0, .z = 1 },
    } };

    pub fn fromCols(c0: Vec3, c1: Vec3, c2: Vec3) Mat3 {
        return .{ .value = .{ GlmVec3.from(c0), GlmVec3.from(c1), GlmVec3.from(c2) } };
    }

    pub fn col(m: Mat3, i: usize) Vec3 {
        return m.value[i].to();
    }

    /// `a.mul(b)` is `A * B`: `b` is applied to a vector first.
    pub fn mul(a: Mat3, b: Mat3) Mat3 {
        var out: Mat3 = undefined;
        inline for (0..3) |j| out.value[j] = GlmVec3.from(a.transform(b.col(j)));
        return out;
    }

    pub fn transform(m: Mat3, v: Vec3) Vec3 {
        return m.col(0) * @as(Vec3, @splat(v[0])) +
            m.col(1) * @as(Vec3, @splat(v[1])) +
            m.col(2) * @as(Vec3, @splat(v[2]));
    }

    pub fn transpose(m: Mat3) Mat3 {
        const a = m.col(0);
        const b = m.col(1);
        const c = m.col(2);
        return fromCols(.{ a[0], b[0], c[0] }, .{ a[1], b[1], c[1] }, .{ a[2], b[2], c[2] });
    }

    pub fn determinant(m: Mat3) f32 {
        return math.dot(m.col(0), math.cross(m.col(1), m.col(2)));
    }

    /// A singular matrix inverts to itself rather than to infinities.
    pub fn inverse(m: Mat3) Mat3 {
        const a = m.col(0);
        const b = m.col(1);
        const c = m.col(2);
        const r0 = math.cross(b, c);
        const r1 = math.cross(c, a);
        const r2 = math.cross(a, b);
        const det = math.dot(a, r0);
        if (det == 0) return m;
        const inv: Vec3 = @splat(1.0 / det);
        // The cofactor vectors are the inverse's rows, so they transpose in.
        const x = r0 * inv;
        const y = r1 * inv;
        const z = r2 * inv;
        return fromCols(.{ x[0], y[0], z[0] }, .{ x[1], y[1], z[1] }, .{ x[2], y[2], z[2] });
    }

    /// Yaw/pitch/roll in degrees — `.{ pitch, yaw, roll }` about X, Y, Z —
    /// composed `Ry(yaw) * Rx(pitch) * Rz(roll)`.
    pub fn fromEuler(degrees: Vec3) Mat3 {
        const r = degrees * @as(Vec3, @splat(deg_to_rad));
        const c: Vec3 = .{ @cos(r[0]), @cos(r[1]), @cos(r[2]) };
        const s: Vec3 = .{ @sin(r[0]), @sin(r[1]), @sin(r[2]) };
        return fromCols(
            .{ c[1] * c[2] + s[1] * s[0] * s[2], c[0] * s[2], -s[1] * c[2] + c[1] * s[0] * s[2] },
            .{ -c[1] * s[2] + s[1] * s[0] * c[2], c[0] * c[2], s[1] * s[2] + c[1] * s[0] * c[2] },
            .{ s[1] * c[0], -s[0], c[1] * c[0] },
        );
    }

    /// The inverse of `fromEuler`, for a matrix that is a pure rotation.
    /// Straight up or down (`|pitch| = 90`) yaw and roll turn about the same
    /// axis and are not separable, so roll comes back zero and yaw carries
    /// the whole rotation.
    pub fn toEuler(m: Mat3) Vec3 {
        const sx = -m.value[2].y;
        const x = std.math.asin(std.math.clamp(sx, -1.0, 1.0));
        const cx = @cos(x);
        if (@abs(cx) > 1e-6) {
            return Vec3{
                x,
                std.math.atan2(m.value[2].x, m.value[2].z),
                std.math.atan2(m.value[0].y, m.value[1].y),
            } * @as(Vec3, @splat(rad_to_deg));
        }
        const signed = if (sx > 0) m.value[1].x else -m.value[1].x;
        return Vec3{ x, std.math.atan2(signed, m.value[0].x), 0 } * @as(Vec3, @splat(rad_to_deg));
    }
};

/// `glm::mat4`, four columns of four. 64 bytes, alignment 4.
pub const Mat4 = extern struct {
    /// glm's own member name, private on `mat` as it is on `Mat3`.
    value: [4]GlmVec4,

    pub const cpp_template = glmMat(4, 4, f32);
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;
    pub const cpp_no_offsets = true;

    pub const identity: Mat4 = .{ .value = .{
        .{ .x = 1, .y = 0, .z = 0, .w = 0 },
        .{ .x = 0, .y = 1, .z = 0, .w = 0 },
        .{ .x = 0, .y = 0, .z = 1, .w = 0 },
        .{ .x = 0, .y = 0, .z = 0, .w = 1 },
    } };

    pub fn fromCols(c0: Vec4, c1: Vec4, c2: Vec4, c3: Vec4) Mat4 {
        return .{ .value = .{ GlmVec4.from(c0), GlmVec4.from(c1), GlmVec4.from(c2), GlmVec4.from(c3) } };
    }

    pub fn col(m: Mat4, i: usize) Vec4 {
        return m.value[i].to();
    }

    /// `a.mul(b)` is `A * B`: `b` is applied to a vector first.
    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var out: Mat4 = undefined;
        inline for (0..4) |j| out.value[j] = GlmVec4.from(a.transform(b.col(j)));
        return out;
    }

    pub fn transform(m: Mat4, v: Vec4) Vec4 {
        return m.col(0) * @as(Vec4, @splat(v[0])) +
            m.col(1) * @as(Vec4, @splat(v[1])) +
            m.col(2) * @as(Vec4, @splat(v[2])) +
            m.col(3) * @as(Vec4, @splat(v[3]));
    }

    /// Transforms a position: `w` is 1, so the translation applies.
    pub fn transformPoint(m: Mat4, v: Vec3) Vec3 {
        const r = m.transform(.{ v[0], v[1], v[2], 1 });
        return .{ r[0], r[1], r[2] };
    }

    /// Transforms a direction: `w` is 0, so the translation does not.
    pub fn transformDir(m: Mat4, v: Vec3) Vec3 {
        const r = m.transform(.{ v[0], v[1], v[2], 0 });
        return .{ r[0], r[1], r[2] };
    }

    pub fn transpose(m: Mat4) Mat4 {
        const a = m.col(0);
        const b = m.col(1);
        const c = m.col(2);
        const d = m.col(3);
        return fromCols(
            .{ a[0], b[0], c[0], d[0] },
            .{ a[1], b[1], c[1], d[1] },
            .{ a[2], b[2], c[2], d[2] },
            .{ a[3], b[3], c[3], d[3] },
        );
    }

    /// The upper-left 3x3: rotation and scale, without the translation.
    pub fn basis(m: Mat4) Mat3 {
        return .fromCols(
            .{ m.value[0].x, m.value[0].y, m.value[0].z },
            .{ m.value[1].x, m.value[1].y, m.value[1].z },
            .{ m.value[2].x, m.value[2].y, m.value[2].z },
        );
    }

    /// The translation, which is the fourth column.
    pub fn origin(m: Mat4) Vec3 {
        return .{ m.value[3].x, m.value[3].y, m.value[3].z };
    }

    pub fn fromBasisOrigin(b: Mat3, o: Vec3) Mat4 {
        const c0 = b.col(0);
        const c1 = b.col(1);
        const c2 = b.col(2);
        return fromCols(
            .{ c0[0], c0[1], c0[2], 0 },
            .{ c1[0], c1[1], c1[2], 0 },
            .{ c2[0], c2[1], c2[2], 0 },
            .{ o[0], o[1], o[2], 1 },
        );
    }

    /// The inverse of an affine matrix — one whose last row is `0 0 0 1`,
    /// which everything built from a `Transform` is. A projection matrix is
    /// not affine and needs a general inverse this does not provide.
    pub fn affineInverse(m: Mat4) Mat4 {
        const b = m.basis().inverse();
        return fromBasisOrigin(b, -b.transform(m.origin()));
    }
};

/// `glm::quat`, stored `x, y, z, w` as glm lays it out.
pub const Quat = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub const cpp_template: cpp.Template = .{
        .name = "glm::qua",
        .args = &.{ .{ .type = f32 }, .{ .value = .{ .type = GlmQualifier, .int = 0 } } },
    };
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

    pub const identity: Quat = .{ .x = 0, .y = 0, .z = 0, .w = 1 };

    /// Yaw/pitch/roll in degrees, the same convention as `Mat3.fromEuler`:
    /// `qy * qx * qz`. Note this is *not* what `glm::quat(vec3)` builds —
    /// see the module comment.
    pub fn fromEuler(degrees: Vec3) Quat {
        const h = degrees * @as(Vec3, @splat(deg_to_rad * 0.5));
        const c: Vec3 = .{ @cos(h[0]), @cos(h[1]), @cos(h[2]) };
        const s: Vec3 = .{ @sin(h[0]), @sin(h[1]), @sin(h[2]) };
        return .{
            .x = s[0] * c[1] * c[2] + c[0] * s[1] * s[2],
            .y = c[0] * s[1] * c[2] - s[0] * c[1] * s[2],
            .z = c[0] * c[1] * s[2] - s[0] * s[1] * c[2],
            .w = c[0] * c[1] * c[2] + s[0] * s[1] * s[2],
        };
    }

    pub fn toEuler(q: Quat) Vec3 {
        return q.toMat3().toEuler();
    }

    pub fn fromAxisAngle(axis: Vec3, degrees: f32) Quat {
        const h = degrees * deg_to_rad * 0.5;
        const a = math.normalize(axis) * @as(Vec3, @splat(@sin(h)));
        return .{ .x = a[0], .y = a[1], .z = a[2], .w = @cos(h) };
    }

    /// `a.mul(b)` applies `b` first, like the matrix product it stands for.
    pub fn mul(a: Quat, b: Quat) Quat {
        return .{
            .x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            .y = a.w * b.y + a.y * b.w + a.z * b.x - a.x * b.z,
            .z = a.w * b.z + a.z * b.w + a.x * b.y - a.y * b.x,
            .w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
        };
    }

    pub fn rotate(q: Quat, v: Vec3) Vec3 {
        return q.toMat3().transform(v);
    }

    pub fn normalize(q: Quat) Quat {
        const len = @sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
        if (len == 0) return identity;
        return .{ .x = q.x / len, .y = q.y / len, .z = q.z / len, .w = q.w / len };
    }

    pub fn toMat3(q: Quat) Mat3 {
        const xx = q.x * q.x;
        const yy = q.y * q.y;
        const zz = q.z * q.z;
        const xy = q.x * q.y;
        const xz = q.x * q.z;
        const yz = q.y * q.z;
        const wx = q.w * q.x;
        const wy = q.w * q.y;
        const wz = q.w * q.z;
        return .fromCols(
            .{ 1 - 2 * (yy + zz), 2 * (xy + wz), 2 * (xz - wy) },
            .{ 2 * (xy - wz), 1 - 2 * (xx + zz), 2 * (yz + wx) },
            .{ 2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (xx + yy) },
        );
    }

    /// Shepperd's method: pick the largest diagonal term so the divisor is
    /// never near zero. `m` must be a pure rotation.
    pub fn fromMat3(m: Mat3) Quat {
        const a = m.value[0];
        const b = m.value[1];
        const c = m.value[2];
        const trace = a.x + b.y + c.z;
        if (trace > 0) {
            const s = @sqrt(trace + 1.0) * 2;
            return .{ .x = (b.z - c.y) / s, .y = (c.x - a.z) / s, .z = (a.y - b.x) / s, .w = 0.25 * s };
        }
        if (a.x > b.y and a.x > c.z) {
            const s = @sqrt(1.0 + a.x - b.y - c.z) * 2;
            return .{ .x = 0.25 * s, .y = (b.x + a.y) / s, .z = (c.x + a.z) / s, .w = (b.z - c.y) / s };
        }
        if (b.y > c.z) {
            const s = @sqrt(1.0 + b.y - a.x - c.z) * 2;
            return .{ .x = (b.x + a.y) / s, .y = 0.25 * s, .z = (c.y + b.z) / s, .w = (c.x - a.z) / s };
        }
        const s = @sqrt(1.0 + c.z - a.x - b.y) * 2;
        return .{ .x = (c.x + a.z) / s, .y = (c.y + b.z) / s, .z = 0.25 * s, .w = (a.y - b.x) / s };
    }
};

/// A position, an xyz euler rotation in degrees, and a per-axis scale, kept
/// as the three things a sketch actually edits rather than as the matrix
/// they multiply out to. It is a plain Zig struct, not a C++ class, so its
/// fields are `@Vector`s you can do arithmetic on directly.
///
/// `basis` and `matrix` compose the three; `setBasis` and `setMatrix` take
/// them apart again. A decomposition is not always exact: shear cannot be
/// represented at all, and at `rotation[1] = +-90` the x and z angles trade
/// off against each other, so a round trip preserves the *matrix* but need
/// not preserve the *numbers*.
pub const Transform = struct {
    origin: Vec3 = @splat(0),
    /// Degrees: `.{ pitch, yaw, roll }` about X, Y and Z, composed
    /// `Ry(yaw) * Rx(pitch) * Rz(roll)`.
    rotation: Vec3 = @splat(0),
    scale: Vec3 = @splat(1),

    pub const identity: Transform = .{};

    /// Nose up or down, about X.
    pub fn pitch(t: Transform) f32 {
        return t.rotation[0];
    }
    /// Turn left or right, about Y.
    pub fn yaw(t: Transform) f32 {
        return t.rotation[1];
    }
    /// Bank, about Z.
    pub fn roll(t: Transform) f32 {
        return t.rotation[2];
    }

    /// Rotation and scale together, as `R * S`: the rotation's columns each
    /// scaled by the matching component.
    pub fn basis(t: Transform) Mat3 {
        const r = Mat3.fromEuler(t.rotation);
        return .fromCols(
            r.col(0) * @as(Vec3, @splat(t.scale[0])),
            r.col(1) * @as(Vec3, @splat(t.scale[1])),
            r.col(2) * @as(Vec3, @splat(t.scale[2])),
        );
    }

    /// Splits `b` into a rotation and a scale, leaving `origin` alone. A
    /// mirrored basis (negative determinant) puts the sign on `scale[0]`,
    /// and an axis of zero length keeps the rotation it had.
    pub fn setBasis(t: *Transform, b: Mat3) void {
        var s: Vec3 = .{ math.length(b.col(0)), math.length(b.col(1)), math.length(b.col(2)) };
        if (b.determinant() < 0) s[0] = -s[0];
        t.scale = s;
        if (s[0] == 0 or s[1] == 0 or s[2] == 0) return;
        t.rotation = Mat3.fromCols(
            b.col(0) / @as(Vec3, @splat(s[0])),
            b.col(1) / @as(Vec3, @splat(s[1])),
            b.col(2) / @as(Vec3, @splat(s[2])),
        ).toEuler();
    }

    /// The whole thing, `T * R * S`, ready for `ofMultMatrix`.
    pub fn matrix(t: Transform) Mat4 {
        return .fromBasisOrigin(t.basis(), t.origin);
    }

    pub fn setMatrix(t: *Transform, m: Mat4) void {
        t.origin = m.origin();
        t.setBasis(m.basis());
    }

    /// The orientation on its own, without the scale.
    pub fn quat(t: Transform) Quat {
        return .fromEuler(t.rotation);
    }

    pub fn setQuat(t: *Transform, q: Quat) void {
        t.rotation = q.toEuler();
    }
};
