//! glm vectors and ofMath.h.
//!
//! Vectors come in two spellings, and they are not interchangeable.
//!
//! - `Vec2`, `Vec3`, `Vec4` and their `I` (`i32`) and `U` (`u32`) variants
//!   are Zig's builtin `@Vector`. They are what user code and every wrapper
//!   here deal in, and they carry the arithmetic: `a + b`, `a * @as(Vec3,
//!   @splat(k))`, `@reduce(.Add, a * b)`. Components are `v[0]`, `v[1]`,
//!   `v[2]`, not `v.x`. `vecCast` converts between element types.
//! - `GlmVec2`, `GlmVec3I`, `GlmVec4U` and the rest are the ABI types, laid
//!   out exactly like `glm::vec<N, T>`. They appear only in a `Signature` and
//!   in the fields of another bound class.
//!
//! The split is forced rather than chosen. A `@Vector` has no guaranteed
//! in-memory representation, so Zig refuses one as an `extern struct` field,
//! and `@Vector(3, f32)` is 16 bytes against `glm::vec3`'s 12 — an array of
//! them strides wrong as well. So the conversion happens inside the wrapper,
//! `GlmVec3.from` going out to C++ and `.to()` coming back; neither survives
//! the optimizer.
//!
//! A type here stands for a C++ class: its `cpp_template`/`cpp_name` and
//! `cpp_abi` describe the class to cpp-bindgen, and its field names are the
//! C++ member names because the generated glue checks each one with
//! `offsetof` against the real header.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;

/// `glm::qualifier`, only ever `packed_highp` (= `defaultp`) in oF. glm also
/// spells it `glm::precision`, which is a typedef of the same enum.
pub const GlmQualifier = enum(i32) {
    packed_highp = 0,
    _,
    pub const cpp_name = "glm::qualifier";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

/// The ABI spelling of `glm::vec<n, E, defaultp>`: an `extern struct` whose
/// field names are glm's own member names, because the generated glue checks
/// each one with `offsetof`. `from` and `to` convert to and from the
/// `@Vector` spelling, and neither survives the optimizer.
fn GlmVec(comptime n: comptime_int, comptime E: type) type {
    const template: cpp.Template = .{
        .name = "glm::vec",
        .args = &.{ .{ .int = n }, .{ .type = E }, .{ .value = .{ .type = GlmQualifier, .int = 0 } } },
    };
    return switch (n) {
        2 => extern struct {
            x: E = 0,
            y: E = 0,

            const V = @Vector(2, E);
            pub const cpp_template = template;
            pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

            pub inline fn from(v: V) @This() {
                return .{ .x = v[0], .y = v[1] };
            }
            pub inline fn to(g: @This()) V {
                return .{ g.x, g.y };
            }
        },
        3 => extern struct {
            x: E = 0,
            y: E = 0,
            z: E = 0,

            const V = @Vector(3, E);
            pub const cpp_template = template;
            pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

            pub inline fn from(v: V) @This() {
                return .{ .x = v[0], .y = v[1], .z = v[2] };
            }
            pub inline fn to(g: @This()) V {
                return .{ g.x, g.y, g.z };
            }
        },
        4 => extern struct {
            x: E = 0,
            y: E = 0,
            z: E = 0,
            w: E = 0,

            const V = @Vector(4, E);
            pub const cpp_template = template;
            pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

            pub inline fn from(v: V) @This() {
                return .{ .x = v[0], .y = v[1], .z = v[2], .w = v[3] };
            }
            pub inline fn to(g: @This()) V {
                return .{ g.x, g.y, g.z, g.w };
            }
        },
        else => @compileError("glm::vec has 2, 3 or 4 components"),
    };
}

/// `glm::vec2`, `glm::vec3`, `glm::vec4`.
pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);
pub const GlmVec2 = GlmVec(2, f32);
pub const GlmVec3 = GlmVec(3, f32);
pub const GlmVec4 = GlmVec(4, f32);

/// `glm::ivec2`, `glm::ivec3`, `glm::ivec4`. oF spells these out long-hand as
/// `glm::vec<N, int, glm::precision::defaultp>`; `ofMaterial`'s
/// `setCustomUniform2i` and friends are the only place it uses them.
pub const Vec2I = @Vector(2, i32);
pub const Vec3I = @Vector(3, i32);
pub const Vec4I = @Vector(4, i32);
pub const GlmVec2I = GlmVec(2, i32);
pub const GlmVec3I = GlmVec(3, i32);
pub const GlmVec4I = GlmVec(4, i32);

/// `glm::uvec2`, `glm::uvec3`, `glm::uvec4`. Nothing in oF 0.12 takes one;
/// they are here so a binding that needs one does not have to invent it.
pub const Vec2U = @Vector(2, u32);
pub const Vec3U = @Vector(3, u32);
pub const Vec4U = @Vector(4, u32);
pub const GlmVec2U = GlmVec(2, u32);
pub const GlmVec3U = GlmVec(3, u32);
pub const GlmVec4U = GlmVec(4, u32);

/// Element-wise conversion between any two vector types of the same length:
/// `vecCast(Vec2I, v)`. Float to int truncates toward zero, as C does; wrap
/// the argument in `@floor` or `@round` for another rounding mode. In a
/// safety-checked build a value the destination cannot hold is a panic, so a
/// negative float does not belong in a `*U` cast.
pub fn vecCast(comptime To: type, v: anytype) To {
    const to = @typeInfo(To).vector;
    const from = @typeInfo(@TypeOf(v)).vector;
    if (to.len != from.len)
        @compileError(@typeName(@TypeOf(v)) ++ " and " ++ @typeName(To) ++ " have different lengths");
    return switch (@typeInfo(to.child)) {
        .float => switch (@typeInfo(from.child)) {
            .float => @floatCast(v),
            .int => @floatFromInt(v),
            else => @compileError(@typeName(from.child) ++ " is not a number"),
        },
        .int => switch (@typeInfo(from.child)) {
            .float => @intFromFloat(v),
            .int => @intCast(v),
            else => @compileError(@typeName(from.child) ++ " is not a number"),
        },
        else => @compileError(@typeName(to.child) ++ " is not a number"),
    };
}

/// `@reduce(.Add, a * b)`, named. Returns the vector's element type.
pub fn dot(a: anytype, b: @TypeOf(a)) @typeInfo(@TypeOf(a)).vector.child {
    return @reduce(.Add, a * b);
}

/// Euclidean length. Float vectors only; `vecCast` an integer one first.
pub fn length(v: anytype) @typeInfo(@TypeOf(v)).vector.child {
    return @sqrt(dot(v, v));
}

/// The zero vector normalizes to itself rather than to NaN.
pub fn normalize(v: anytype) @TypeOf(v) {
    const len = length(v);
    return if (len == 0) v else v / @as(@TypeOf(v), @splat(len));
}

pub fn cross(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    const E = @typeInfo(@TypeOf(a)).vector.child;
    const a1 = @shuffle(E, a, undefined, [3]i32{ 1, 2, 0 });
    const a2 = @shuffle(E, a, undefined, [3]i32{ 2, 0, 1 });
    const b1 = @shuffle(E, b, undefined, [3]i32{ 2, 0, 1 });
    const b2 = @shuffle(E, b, undefined, [3]i32{ 1, 2, 0 });
    return a1 * b1 - a2 * b2;
}

// ofMath.h

/// `ofRandom(max)`: a random float in `[0, max)`.
pub const ofRandom_sig: Signature = .{ .name = "ofRandom", .args = &.{f32}, .ret = f32 };
pub fn random(max: f32) f32 {
    return cpp.bind(ofRandom_sig)(max);
}

/// `ofRandom(min, max)`
pub const ofRandom_range_sig: Signature = .{ .name = "ofRandom", .args = &.{ f32, f32 }, .ret = f32 };
pub fn randomRange(min: f32, max: f32) f32 {
    return cpp.bind(ofRandom_range_sig)(min, max);
}

/// `ofSeedRandom(seed)`
pub const ofSeedRandom_sig: Signature = .{ .name = "ofSeedRandom", .args = &.{i32} };
pub fn seedRandom(seed: i32) void {
    cpp.bind(ofSeedRandom_sig)(seed);
}

/// `ofMap`
pub const ofMap_sig: Signature = .{ .name = "ofMap", .args = &.{ f32, f32, f32, f32, f32, bool }, .ret = f32 };
pub fn map(value: f32, in_min: f32, in_max: f32, out_min: f32, out_max: f32, clamp_result: bool) f32 {
    return cpp.bind(ofMap_sig)(value, in_min, in_max, out_min, out_max, clamp_result);
}

/// `ofClamp`
pub const ofClamp_sig: Signature = .{ .name = "ofClamp", .args = &.{ f32, f32, f32 }, .ret = f32 };
pub fn clamp(value: f32, min: f32, max: f32) f32 {
    return cpp.bind(ofClamp_sig)(value, min, max);
}

/// `ofLerp`
pub const ofLerp_sig: Signature = .{ .name = "ofLerp", .args = &.{ f32, f32, f32 }, .ret = f32 };
pub fn lerp(start: f32, stop: f32, amount: f32) f32 {
    return cpp.bind(ofLerp_sig)(start, stop, amount);
}

/// `ofNoise(x)`: Perlin noise in `[0, 1]`.
pub const ofNoise_1_sig: Signature = .{ .name = "ofNoise", .args = &.{f32}, .ret = f32 };
pub fn noise1(x: f32) f32 {
    return cpp.bind(ofNoise_1_sig)(x);
}

/// `ofNoise(x, y)`
pub const ofNoise_2_sig: Signature = .{ .name = "ofNoise", .args = &.{ f32, f32 }, .ret = f32 };
pub fn noise(x: f32, y: f32) f32 {
    return cpp.bind(ofNoise_2_sig)(x, y);
}

/// `ofNoise(x, y, z)`
pub const ofNoise_3_sig: Signature = .{ .name = "ofNoise", .args = &.{ f32, f32, f32 }, .ret = f32 };
pub fn noise3(x: f32, y: f32, z: f32) f32 {
    return cpp.bind(ofNoise_3_sig)(x, y, z);
}

/// `ofSignedNoise(x, y)`: Perlin noise in `[-1, 1]`.
pub const ofSignedNoise_sig: Signature = .{ .name = "ofSignedNoise", .args = &.{ f32, f32 }, .ret = f32 };
pub fn signedNoise(x: f32, y: f32) f32 {
    return cpp.bind(ofSignedNoise_sig)(x, y);
}

/// `ofDegToRad`
pub const ofDegToRad_sig: Signature = .{ .name = "ofDegToRad", .args = &.{f32}, .ret = f32 };
pub fn degToRad(degrees: f32) f32 {
    return cpp.bind(ofDegToRad_sig)(degrees);
}

/// `ofRadToDeg`
pub const ofRadToDeg_sig: Signature = .{ .name = "ofRadToDeg", .args = &.{f32}, .ret = f32 };
pub fn radToDeg(radians: f32) f32 {
    return cpp.bind(ofRadToDeg_sig)(radians);
}
