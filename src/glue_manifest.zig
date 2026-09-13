//! The manifest cpp-bindgen's `addCppGlue` writes for itself, written out
//! once so the `glue` step can hand one to the generator directly. Nothing
//! imports this but `build.zig`, and the bindings never see it.
//!
//! `headers` has to match the list `build.zig` passes to `addCppGlue`, or the
//! file the `glue` step installs is not the file that gets compiled.
const cpp = @import("cpp_bindgen");

pub const cpp_manifest: cpp.emit.Manifest = .{
    .headers = &.{"ofMain.h"},
    .modules = &.{@import("bindings")},
};
