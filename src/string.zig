//! `std::string`, as laid out by the MSVC STL: a 16-byte small-string
//! buffer (or a heap pointer), the size, and the capacity.
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
//! Its members are header-only, so the glue must force their definitions;
//! the public signatures below are what the glue scan picks up for that.
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
