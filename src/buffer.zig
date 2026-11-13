//! ofFileUtils.h: `ofBuffer`, a block of bytes in memory, which oF's
//! loaders take where they read from memory rather than from a file.
//!
//! ```zig
//! var buf = of.Buffer.init(@embedFile("teapot.obj"));
//! defer buf.deinit();
//! _ = model.loadBuffer(&buf, .optimize_default, "obj");
//! ```
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;

/// The MSVC STL (Windows), or else libc++ (macOS): the storage size
/// differs between them.
const msvc = @import("builtin").target.abi == .msvc;

/// `ofBuffer`.
///
/// A `std::vector<char>` holding the bytes, and the line cursor its text
/// iteration uses; Zig reads neither directly. It owns heap, so `deinit` it.
pub const Buffer = extern struct {
    _storage: [if (msvc) 80 else 72]u8 align(8),

    pub const cpp_name = "ofBuffer";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Buffer };
    pub const ctor_bytes_sig: Signature = .{ .name = "*", .this = *Buffer, .args = &.{ [*]const u8, usize } };
    /// `ofBuffer(const char*, size_t)`: a copy of `bytes`.
    pub fn init(bytes: []const u8) Buffer {
        var b: Buffer = undefined;
        cpp.bind(ctor_bytes_sig)(&b, bytes.ptr, bytes.len);
        return b;
    }
    /// `ofBuffer()`: empty.
    pub fn initEmpty() Buffer {
        var b: Buffer = undefined;
        cpp.bind(ctor_sig)(&b);
        return b;
    }
    /// The destructor is implicit, so header-only; the glue emits it.
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Buffer };
    pub fn deinit(self: *Buffer) void {
        cpp.bind(dtor_sig)(self);
    }

    pub const getData_sig: Signature = .{ .name = "getData", .this = *const Buffer, .ret = ?[*]const u8 };
    pub const size_sig: Signature = .{ .name = "size", .this = *const Buffer, .ret = usize };
    /// The bytes, valid until the buffer changes or is freed.
    pub fn slice(self: *const Buffer) []const u8 {
        const n = cpp.bind(size_sig)(self);
        const p = cpp.bind(getData_sig)(self) orelse return &.{};
        return p[0..n];
    }
    pub fn len(self: *const Buffer) usize {
        return cpp.bind(size_sig)(self);
    }
};
