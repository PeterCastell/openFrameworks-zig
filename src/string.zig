//! The standard-library types that cross the boundary: `std::string`, and the
//! `std::filesystem::path` that every oF call naming a file takes. Windows
//! adds `std::wstring`, which a path is made of there.
//!
//! The layouts are the target's standard library: the MSVC STL on Windows,
//! libc++ on macOS. A `std::string` is 32 bytes in the first (a 16-byte
//! small-string buffer or a heap pointer, the size, and the capacity) and 24
//! in the second. Zig reads neither: every member is called.
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
const builtin = @import("builtin");
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;

/// The MSVC STL (Windows), or else libc++ (macOS).
const msvc = builtin.target.abi == .msvc;

pub const String = extern struct {
    _rep: [if (msvc) 32 else 24]u8 align(8),

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
    /// The standard library already instantiates this; a second explicit
    /// instantiation is ill-formed.
    pub const cpp_no_instantiate = true;
    pub const cpp_no_offsets = true;

    // The MSVC STL declares its `const char*` constructors with a top-level
    // const on the pointer (`const char* const`), which MSVC mangles as
    // `QEBD` rather than `PEBD`; `ConstPtr` spells that. Itanium drops a
    // top-level const, so libc++ is unaffected.
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
/// takes it there. Elsewhere a path holds a `std::string`, and this is an
/// empty namespace.
pub const WString = if (msvc) extern struct {
    _rep: [32]u8 align(8),

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

    pub const ctor_sig: Signature = .{ .name = "*", .args = &.{ cpp.ConstPtr([*]const cpp.wchar_t), usize }, .this = *@This() };
    pub const dtor_sig: Signature = .{ .name = "~", .this = *@This() };

    /// Takes UTF-16 code units, which is what `wchar_t` holds on Windows.
    pub fn init(units: []const u16) @This() {
        var s: @This() = undefined;
        cpp.bind(ctor_sig)(&s, @ptrCast(units.ptr), units.len);
        return s;
    }

    pub fn deinit(self: *@This()) void {
        cpp.bind(dtor_sig)(self);
    }
} else struct {};

/// `std::filesystem::path`, which `ofConstants.h` renames `of::filesystem::path`:
/// the type of every oF parameter that names a file. It holds one string and
/// nothing else: a `std::wstring` of UTF-16 on Windows, a `std::string` of
/// UTF-8 on macOS.
///
/// C++ never writes one of these out, because `path` converts from a string
/// literal on its own. A Zig caller has to build it:
///
/// ```zig
/// var p = of.string.Path.init("fonts/verdana.ttf") orelse return false;
/// defer p.deinit();
/// ```
pub const Path = extern struct {
    /// MSVC calls this member `_Text`, libc++ `__pn_`. The leading underscore
    /// is what tells the glue to check the size of the class and not this
    /// offset.
    _text: if (msvc) WString else String,

    /// libc++'s `std::filesystem` is an alias for `std::__fs::filesystem`,
    /// and a mangled name carries the real namespace.
    pub const cpp_name = if (msvc) "std::filesystem::path" else "std::__fs::filesystem::path";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    /// `path::format`, which libc++'s string constructor takes as well.
    pub const Format = enum(u8) {
        auto_format = 0,
        native_format = 1,
        generic_format = 2,
        pub const cpp_name = Path.cpp_name ++ "::format";
        pub const cpp_kind: cpp.Kind = .@"enum";
    };

    /// `path(string_type&&)` on MSVC, `path(string_type&&, format)` in
    /// libc++. Every other constructor is a template over the source type,
    /// which is how a literal or a `std::string` converts.
    pub const ctor_sig: Signature = if (msvc)
        .{ .name = "*", .args = &.{cpp.RRef(*WString)}, .this = *Path }
    else
        .{ .name = "*", .args = &.{ cpp.RRef(*String), Format }, .this = *Path };
    pub const dtor_sig: Signature = .{ .name = "~", .this = *Path };

    /// The longest path `init` converts: in UTF-16 code units on Windows, in
    /// bytes elsewhere.
    pub const max_units = 512;

    /// `null` when `utf8` is not valid UTF-8, or is longer than `max_units`.
    /// oF resolves a relative path against `bin/data` itself, so this has to
    /// hold what the sketch writes, not the absolute path it becomes.
    pub fn init(utf8: []const u8) ?Path {
        return if (msvc) initUtf16(utf8) else initUtf8(utf8);
    }

    fn initUtf16(utf8: []const u8) ?Path {
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

    fn initUtf8(utf8: []const u8) ?Path {
        if (utf8.len > max_units or !std.unicode.utf8ValidateSlice(utf8)) return null;
        // As above: the moved-from string still has to be destroyed.
        var s: String = .init(utf8);
        defer s.deinit();
        var p: Path = undefined;
        cpp.bind(ctor_sig)(&p, &s, .auto_format);
        return p;
    }

    pub fn deinit(self: *Path) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `ofPathToString(const of::filesystem::path&)`, which converts as
    /// oF's own code does when it prints or compares a path.
    pub const ofPathToString_sig: Signature = .{ .name = "ofPathToString", .args = &.{cpp.Ref(*const Path)}, .ret = String };
    /// The path as a `String`, which the caller owns and must `deinit`.
    pub fn toString(self: *const Path) String {
        var s: String = undefined;
        cpp.bind(ofPathToString_sig)(&s, self);
        return s;
    }
};

/// `std::vector<std::string>`, as oF returns one by value: a list of names
/// the caller owns. `deinit` frees the strings and the array together.
///
/// ```zig
/// var names = model.getMeshNames();
/// defer names.deinit();
/// for (names.items()) |*n| std.debug.print("{s}\n", .{n.slice()});
/// ```
pub const StringVector = extern struct {
    /// Begin, end, and the end of the allocation: the same three pointers
    /// in the MSVC STL and in libc++.
    _first: ?[*]String,
    _last: ?[*]String,
    _end: ?[*]String,

    pub const cpp_template: cpp.Template = .{
        .name = "std::vector",
        .args = &.{
            .{ .type = String },
            .{ .template = .{ .name = "std::allocator", .args = &.{.{ .type = String }}, .kind = .class } },
        },
        .kind = .class,
    };
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    /// See `String.cpp_no_instantiate`; the one member called is the
    /// destructor, which the glue forces on its own.
    pub const cpp_no_instantiate = true;
    pub const cpp_no_offsets = true;

    pub const dtor_sig: Signature = .{ .name = "~", .this = *StringVector };
    pub fn deinit(self: *StringVector) void {
        cpp.bind(dtor_sig)(self);
    }

    pub fn items(self: *const StringVector) []const String {
        const first = self._first orelse return &.{};
        return first[0 .. self._last.? - first];
    }
};
