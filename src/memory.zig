//! <memory>: the smart pointers oF hands out.
const cpp = @import("cpp_bindgen");

/// `std::shared_ptr<T>`: the object, and the control block that counts
/// references to it. Zig reads the first and never copies one.
pub fn SharedPtr(comptime T: type) type {
    return extern struct {
        ptr: ?*T,
        _ctrl: ?*anyopaque,

        pub const cpp_template: cpp.Template = .{ .name = "std::shared_ptr", .args = &.{.{ .type = T }}, .kind = .class };
        pub const cpp_abi: cpp.ClassAbi = .managed_copy;
        pub const cpp_no_instantiate = true;
        pub const cpp_no_offsets = true;

        pub fn get(self: @This()) ?*T {
            return self.ptr;
        }
    };
}
