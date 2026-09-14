//! The MSVC STL types that cross the boundary: `std::string`, `std::wstring`,
//! and the `std::filesystem::path` that every oF call naming a file takes.
//!
//! A `std::string` is a 16-byte small-string buffer (or a heap pointer), the
//! size, and the capacity.
//!
//! ```zig
//! var s = of.String.init("hello");
//! defer s.deinit();
//! std.debug.print("{s}\n", .{s.slice()});
//! ```
//!
//! A `String` passed *by value* to a bound C++ function (for example
//! `ofSetWindowTitle(std::string)`) is consumed by that call: do not `deinit`
//! it afterwards. One passed by reference (`const std::string&`) is not.
//!
//! The members of all three types are header-only, so the glue must force
//! their definitions; the public signatures below are what the glue scan
//! picks up for that.
const std = @import("std");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;

pub const String = extern struct {
    _bx: [16]u8,
    _size: usize,
    _res: usize,

    pub const cpp_template = cpp.Template{
        .name = "std::basic_string",
        .args = &.{
            .{ .type = u8 },
            .{ .template = .{ .name = "std::char_traits", .args = &.{.{ .type = u8 }} } },
            .{ .template = .{ .name = "std::allocator", .args = &.{.{ .type = u8 }}, .kind = .class } },
        },
        .kind = .class,
    };
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    /// The MSVC STL already instantiates this; a second explicit
    /// instantiation is ill-formed.
    pub const cpp_no_instantiate = true;
    pub const cpp_no_offsets = true;

    // The MSVC STL declares its `const char*` constructors with a top-level
    // const on the pointer (`const char* const`), which MSVC mangles as
    // `QEBD` rather than `PEBD`; `ConstPtr` spells that.
    pub const ctor_sig: Signature = .{ .name = "*", .args = &.{ cpp.ConstPtr([*]const u8), usize }, .this = *String };
    pub const dtor_sig: Signature = .{ .name = "~", .this = *String };
    pub const c_str_sig: Signature = .{ .name = "c_str", .ret = [*:0]const u8, .this = *const String };
    pub const size_sig: Signature = .{ .name = "size", .ret = usize, .this = *const String };

    pub fn init(bytes: []const u8) String {
        var s: String = undefined;
        cpp.bind(ctor_sig)(&s, bytes.ptr, bytes.len);
        return s;
    }

    pub fn deinit(self: *String) void {
        cpp.bind(dtor_sig)(self);
    }

    pub fn len(self: *const String) usize {
        return cpp.bind(size_sig)(self);
    }

    pub fn cStr(self: *const String) [*:0]const u8 {
        return cpp.bind(c_str_sig)(self);
    }

    pub fn slice(self: *const String) []const u8 {
        return self.cStr()[0..self.len()];
    }
};

/// `std::wstring`: the same class template with `wchar_t`, which is 16 bits
/// on Windows. It exists for `Path`, whose one non-template constructor
/// takes it.
pub const WString = extern struct {
    _bx: [16]u8,
    _size: usize,
    _res: usize,

    pub const cpp_template = cpp.Template{
        .name = "std::basic_string",
        .args = &.{
            .{ .type = cpp.wchar_t },
            .{ .template = .{ .name = "std::char_traits", .args = &.{.{ .type = cpp.wchar_t }} } },
            .{ .template = .{ .name = "std::allocator", .args = &.{.{ .type = cpp.wchar_t }}, .kind = .class } },
        },
        .kind = .class,
    };
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    /// See `String.cpp_no_instantiate`.
    pub const cpp_no_instantiate = true;
    pub const cpp_no_offsets = true;

    pub const ctor_sig: Signature = .{ .name = "*", .args = &.{ cpp.ConstPtr([*]const cpp.wchar_t), usize }, .this = *WString };
    pub const dtor_sig: Signature = .{ .name = "~", .this = *WString };

    /// Takes UTF-16 code units, which is what `wchar_t` holds on Windows.
    pub fn init(units: []const u16) WString {
        var s: WString = undefined;
        cpp.bind(ctor_sig)(&s, @ptrCast(units.ptr), units.len);
        return s;
    }

    pub fn deinit(self: *WString) void {
        cpp.bind(dtor_sig)(self);
    }
};

/// `std::filesystem::path`, which `ofConstants.h` renames `of::filesystem::path`:
/// the type of every oF parameter that names a file. On Windows it holds one
/// `std::wstring` and nothing else.
///
/// C++ never writes one of these out, because `path` converts from a string
/// literal on its own. A Zig caller has to build it:
///
/// ```zig
/// var p = of.string.Path.init("fonts/verdana.ttf") orelse return false;
/// defer p.deinit();
/// ```
pub const Path = extern struct {
    /// MSVC calls this member `_Text`. The leading underscore is what tells
    /// the glue to check the size of the class and not this offset.
    _text: WString,

    pub const cpp_name = "std::filesystem::path";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    /// `path(string_type&&)`. Every other constructor is a template over the
    /// source type, which is how a literal or a `std::string` converts.
    pub const ctor_sig: Signature = .{ .name = "*", .args = &.{cpp.RRef(*WString)}, .this = *Path };
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Path };

    /// The longest path `init` converts, in UTF-16 code units.
    pub const max_units = 512;

    /// `null` when `utf8` is not valid UTF-8, or is longer than `max_units`.
    /// oF resolves a relative path against `bin/data` itself, so this has to
    /// hold what the sketch writes, not the absolute path it becomes.
    pub fn init(utf8: []const u8) ?Path {
        var units: [max_units]u16 = undefined;
        // One UTF-8 byte yields at most one UTF-16 unit, so this is the
        // bound that keeps `utf8ToUtf16Le`, which checks nothing, in range.
        if (utf8.len > units.len) return null;
        const n = std.unicode.utf8ToUtf16Le(&units, utf8) catch return null;

        // The constructor moves the string in, which leaves an empty husk
        // that still has to be destroyed.
        var w: WString = .init(units[0..n]);
        defer w.deinit();
        var p: Path = undefined;
        cpp.bind(ctor_sig)(&p, &w);
        return p;
    }

    pub fn deinit(self: *Path) void {
        cpp.bind(dtor_sig)(self);
    }
};
