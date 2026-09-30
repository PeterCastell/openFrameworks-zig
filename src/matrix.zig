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
//! Euler angles are **radians**, as yaw/pitch/roll:
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
//! and so not the one `ofNode::setOrientation(const glm::vec3&)` takes --
//! which is degrees on top of that. A quaternion carries neither a unit nor
//! a composition order, so `Quat` is the currency to interop through: bind
//! `ofNode`'s `const glm::quat&` overload rather than its euler one and
//! both questions go away.
const std = @import("std");
const cpp = @import("cpp_bindgen");
const math = @import("math.zig");

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const GlmVec3 = math.GlmVec3;
const GlmVec4 = math.GlmVec4;
const GlmQualifier = math.GlmQualifier;

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

    /// A rotation of `radians` about `axis`, right-handed; `axis` need not
    /// be normalized. What `glm::rotate(mat4(1), angle, axis)` builds, as
    /// its upper-left 3x3.
    pub fn fromAxisAngle(radians: f32, axis: Vec3) Mat3 {
        const a = math.normalize(axis);
        const c = @cos(radians);
        const s = @sin(radians);
        const t = 1 - c;
        return fromCols(
            .{ t * a[0] * a[0] + c, t * a[0] * a[1] + s * a[2], t * a[0] * a[2] - s * a[1] },
            .{ t * a[0] * a[1] - s * a[2], t * a[1] * a[1] + c, t * a[1] * a[2] + s * a[0] },
            .{ t * a[0] * a[2] + s * a[1], t * a[1] * a[2] - s * a[0], t * a[2] * a[2] + c },
        );
    }

    /// The columns of `m` each scaled by the matching component of `s`:
    /// `m * S`, a scale applied before `m`.
    pub fn scaled(m: Mat3, s: Vec3) Mat3 {
        return fromCols(
            m.col(0) * @as(Vec3, @splat(s[0])),
            m.col(1) * @as(Vec3, @splat(s[1])),
            m.col(2) * @as(Vec3, @splat(s[2])),
        );
    }

    /// Yaw/pitch/roll in radians — `.{ pitch, yaw, roll }` about X, Y, Z —
    /// composed `Ry(yaw) * Rx(pitch) * Rz(roll)`.
    pub fn fromEuler(r: Vec3) Mat3 {
        const c: Vec3 = .{ @cos(r[0]), @cos(r[1]), @cos(r[2]) };
        const s: Vec3 = .{ @sin(r[0]), @sin(r[1]), @sin(r[2]) };
        return fromCols(
            .{ c[1] * c[2] + s[1] * s[0] * s[2], c[0] * s[2], -s[1] * c[2] + c[1] * s[0] * s[2] },
            .{ -c[1] * s[2] + s[1] * s[0] * c[2], c[0] * c[2], s[1] * s[2] + c[1] * s[0] * c[2] },
            .{ s[1] * c[0], -s[0], c[1] * c[0] },
        );
    }

    /// The inverse of `fromEuler`, for a matrix that is a pure rotation.
    /// Straight up or down (`|pitch| = pi/2`) yaw and roll turn about the
    /// same axis and are not separable, so roll comes back zero and yaw
    /// carries the whole rotation.
    pub fn toEuler(m: Mat3) Vec3 {
        const sx = -m.value[2].y;
        const x = std.math.asin(std.math.clamp(sx, -1.0, 1.0));
        const cx = @cos(x);
        if (@abs(cx) > 1e-6) {
            return Vec3{
                x,
                std.math.atan2(m.value[2].x, m.value[2].z),
                std.math.atan2(m.value[0].y, m.value[1].y),
            };
        }
        const signed = if (sx > 0) m.value[1].x else -m.value[1].x;
        return Vec3{ x, std.math.atan2(signed, m.value[0].x), 0 };
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

    /// `b` as a 4x4 with no translation.
    pub fn fromMat3(b: Mat3) Mat4 {
        return fromBasisOrigin(b, @splat(0));
    }

    /// The rotation `q` as a 4x4.
    pub fn fromQuat(q: Quat) Mat4 {
        return fromMat3(q.toMat3());
    }

    // The elementary matrices, as glm spells them. Each has two forms: a
    // static that builds the matrix on its own (`Mat4.translation(v)` is
    // `glm::translate(glm::mat4(1), v)`) and a method that post-multiplies
    // it onto an existing one (`m.translate(v)` is `glm::translate(m, v)`,
    // which is `m * T`: the translation is applied first). So `T * R * S`
    // is either `Mat4.translation(t).mul(.rotation(a, axis)).mul(.scaling(s))`
    // or `Mat4.identity.translate(t).rotate(a, axis).scale(s)`.

    pub fn translation(v: Vec3) Mat4 {
        return fromBasisOrigin(.identity, v);
    }

    /// `radians` about `axis`, right-handed; `axis` need not be normalized.
    pub fn rotation(radians: f32, axis: Vec3) Mat4 {
        return fromMat3(.fromAxisAngle(radians, axis));
    }

    pub fn scaling(s: Vec3) Mat4 {
        return fromCols(.{ s[0], 0, 0, 0 }, .{ 0, s[1], 0, 0 }, .{ 0, 0, s[2], 0 }, .{ 0, 0, 0, 1 });
    }

    /// `m * translation(v)`.
    pub fn translate(m: Mat4, v: Vec3) Mat4 {
        return m.mul(translation(v));
    }

    /// `m * rotation(radians, axis)`.
    pub fn rotate(m: Mat4, radians: f32, axis: Vec3) Mat4 {
        return m.mul(rotation(radians, axis));
    }

    /// `m * scaling(s)`.
    pub fn scale(m: Mat4, s: Vec3) Mat4 {
        return m.mul(scaling(s));
    }

    /// Transforms a position through a projective matrix: `w` is 1 going
    /// in, and the result is divided by the `w` that comes out. For an
    /// affine matrix that `w` is 1 and this is `transformPoint`.
    pub fn projectPoint(m: Mat4, v: Vec3) Vec3 {
        const r = m.transform(.{ v[0], v[1], v[2], 1 });
        return Vec3{ r[0], r[1], r[2] } / @as(Vec3, @splat(r[3]));
    }

    pub fn determinant(m: Mat4) f32 {
        return m.eliminate().det;
    }

    /// The general inverse, for a projection or anything else whose last
    /// row is not `0 0 0 1`; `affineInverse` is cheaper when it is. A
    /// singular matrix inverts to itself rather than to infinities.
    pub fn inverse(m: Mat4) Mat4 {
        const e = m.eliminate();
        return if (e.det == 0) m else e.inv;
    }

    /// Gauss-Jordan with partial pivoting over the rows of `m`, which are
    /// the columns of its transpose. Yields the inverse and, from the
    /// pivots, the determinant.
    fn eliminate(m: Mat4) struct { inv: Mat4, det: f32 } {
        const t = m.transpose();
        var a: [4]Vec4 = .{ t.col(0), t.col(1), t.col(2), t.col(3) };
        var b: [4]Vec4 = .{ .{ 1, 0, 0, 0 }, .{ 0, 1, 0, 0 }, .{ 0, 0, 1, 0 }, .{ 0, 0, 0, 1 } };
        var det: f32 = 1;
        // `inline`: a vector index must be comptime-known, and `c` is one.
        inline for (0..4) |c| {
            var p: usize = c;
            for (c + 1..4) |r| {
                if (@abs(a[r][c]) > @abs(a[p][c])) p = r;
            }
            const pivot = a[p][c];
            if (pivot == 0) return .{ .inv = m, .det = 0 };
            if (p != c) {
                std.mem.swap(Vec4, &a[p], &a[c]);
                std.mem.swap(Vec4, &b[p], &b[c]);
                det = -det;
            }
            det *= pivot;
            const inv_pivot: Vec4 = @splat(1.0 / pivot);
            a[c] *= inv_pivot;
            b[c] *= inv_pivot;
            for (0..4) |r| {
                if (r == c) continue;
                const f: Vec4 = @splat(a[r][c]);
                a[r] -= a[c] * f;
                b[r] -= b[c] * f;
            }
        }
        // `b` holds the inverse's rows; transposing them in makes columns.
        return .{ .inv = fromCols(b[0], b[1], b[2], b[3]).transpose(), .det = det };
    }

    // Projections and views, as glm builds them for OpenGL: right-handed,
    // with clip depth in `[-1, 1]`. These are what `ofCamera` hands back
    // from `getProjectionMatrix` and `getModelViewMatrix`.

    /// `glm::perspective`: `fovy` is the vertical field of view in radians,
    /// `aspect` is width over height, and the two planes are positive
    /// distances in front of the eye.
    pub fn perspective(fovy: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fovy * 0.5);
        return fromCols(
            .{ f / aspect, 0, 0, 0 },
            .{ 0, f, 0, 0 },
            .{ 0, 0, -(far + near) / (far - near), -1 },
            .{ 0, 0, -(2 * far * near) / (far - near), 0 },
        );
    }

    /// `glm::ortho`
    pub fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        return fromCols(
            .{ 2 / (right - left), 0, 0, 0 },
            .{ 0, 2 / (top - bottom), 0, 0 },
            .{ 0, 0, -2 / (far - near), 0 },
            .{ -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1 },
        );
    }

    /// `glm::lookAt`: the view matrix of an eye at `eye` looking at `center`
    /// with `up` roughly upward. `up` need not be normalized or exactly
    /// perpendicular to the view direction.
    pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = math.normalize(center - eye);
        const s = math.normalize(math.cross(f, up));
        const u = math.cross(s, f);
        return fromCols(
            .{ s[0], u[0], -f[0], 0 },
            .{ s[1], u[1], -f[1], 0 },
            .{ s[2], u[2], -f[2], 0 },
            .{ -math.dot(s, eye), -math.dot(u, eye), math.dot(f, eye), 1 },
        );
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

    /// Yaw/pitch/roll in radians, the same convention as `Mat3.fromEuler`:
    /// `qy * qx * qz`. Note this is *not* what `glm::quat(vec3)` builds —
    /// see the module comment.
    pub fn fromEuler(radians: Vec3) Quat {
        const h = radians * @as(Vec3, @splat(0.5));
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

    /// `axis` need not be normalized; `radians` turns about it right-handed.
    pub fn fromAxisAngle(axis: Vec3, radians: f32) Quat {
        const h = radians * 0.5;
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

    /// The rotation as a 4x4 with no translation.
    pub fn toMat4(q: Quat) Mat4 {
        return .fromQuat(q);
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

/// A position, an xyz euler rotation in radians, and a per-axis scale, kept
/// as the three things a sketch actually edits rather than as the matrix
/// they multiply out to. It is a plain Zig struct, not a C++ class, so its
/// fields are `@Vector`s you can do arithmetic on directly.
///
/// `basis` and `matrix` compose the three; `setBasis` and `setMatrix` take
/// them apart again. A decomposition is not always exact: shear cannot be
/// represented at all, and at `rotation[0] = +-pi/2` the y and z angles trade
/// off against each other, so a round trip preserves the *matrix* but need
/// not preserve the *numbers*.
pub const Transform = struct {
    origin: Vec3 = @splat(0),
    /// Radians: `.{ pitch, yaw, roll }` about X, Y and Z, composed
    /// `Ry(yaw) * Rx(pitch) * Rz(roll)`.
    rotation: Vec3 = @splat(0),
    scale: Vec3 = @splat(1),

    pub const identity: Transform = .{};

    pub fn pitch(t: Transform) f32 {
        return t.rotation[0];
    }
    pub fn yaw(t: Transform) f32 {
        return t.rotation[1];
    }
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
