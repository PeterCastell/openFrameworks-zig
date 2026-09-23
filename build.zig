//! openFrameworks bindings for Zig, built on cpp-bindgen.
//!
//! This package owns the compilation of the openFrameworks core, but not the
//! source: point it at an existing 0.12 release (the `of_v0.12.x_vs_64_release`
//! layout) with `-Dof-root=<path>` or the `OF_ROOT` environment variable.
//!
//! It exports two things:
//!
//! - module `of`: the Zig side, built on cpp-bindgen.
//! - artifact `openFrameworks`: a static library holding the oF core compiled
//!   for the MSVC ABI, the C++ glue cpp-bindgen generates for the bindings,
//!   the app trampoline, and the link lines for every third-party and system
//!   library oF needs.
//!
//! An end project does this:
//!
//! ```zig
//! const of_dep = b.dependency("openframeworks_zig", .{ .target = target, .optimize = optimize, .@"of-root" = of_root });
//! exe_mod.addImport("of", of_dep.module("of")); // the module carries the library and its link line
//! // and the executable must use the dynamic CRT, like every oF build on Windows:
//! const exe = b.addExecutable(.{ .name = "app", .root_module = exe_mod, .linkage = .dynamic });
//! ```
const std = @import("std");
const cpp_bindgen = @import("cpp_bindgen");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .msvc } });
    const optimize = b.standardOptimizeOption(.{});

    const of_root = b.option([]const u8, "of-root", "Path to an openFrameworks 0.12 release (vs_64 layout). Defaults to $OF_ROOT.") orelse
        b.graph.environ_map.get("OF_ROOT") orelse
        "";
    const winrt_include = b.option([]const u8, "winrt-include", "Windows SDK 'winrt' include directory (auto-detected when omitted)");

    const dep = b.dependency("cpp_bindgen", .{ .target = target, .optimize = optimize });

    // The Zig side. `src/of.zig` is also the root of the glue scan; what the
    // glue needs beyond the bindings themselves is in `generateCppGlue` below.
    const of_mod = b.addModule("of", .{
        .root_source_file = b.path("src/of.zig"),
        .target = target,
    });
    of_mod.addImport("cpp_bindgen", dep.module("cpp_bindgen"));

    // The C++ side: oF core + glue + trampoline, as one static library.
    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // oF and its third-party code are not written to survive UBSan traps.
        .sanitize_c = .off,
    });

    const lib = b.addLibrary(.{ .name = "openFrameworks", .root_module = lib_mod, .linkage = .static });

    // Generated here rather than inside `configureOf` so that one generator
    // run feeds both the `glue` step and the compile below: the file installed
    // for inspection is then the file that was compiled, not a second copy of
    // it. Generating needs no oF headers -- only compiling does -- so the
    // `glue` step still works without `-Dof-root`.
    const glue = cpp_bindgen.generateCppGlue(b, dep, .{
        .binding_module = bindingsModule(b, dep, target),
        .headers = glue_headers,
        .target = target,
        .name = "of-glue",
    });

    if (of_root.len == 0) {
        lib.step.dependOn(&b.addFail("openframeworks_zig: pass -Dof-root=<path to of_v0.12.x_vs_64_release> or set OF_ROOT").step);
    } else {
        configureOf(b, of_mod, lib_mod, target, of_root, winrt_include, glue);
    }
    b.installArtifact(lib);
    of_mod.linkLibrary(lib);

    // Example apps, also the smoke tests of the whole chain: `main.zig` is
    // the 2D one, `3d.zig` the camera, primitives and light.
    addExample(b, of_mod, target, optimize, "example", "example/main.zig", "example", "run", "the 2D example app");
    addExample(b, of_mod, target, optimize, "example-3d", "example/3d.zig", "example-3d", "run-3d", "the 3D example app");

    const glue_step = b.step("glue", "Write the generated C++ glue to zig-out/glue for inspection");
    glue_step.dependOn(&b.addInstallFile(glue, "glue/of_glue.cpp").step);
}

/// One example executable, with a build step and a run step. The run step
/// runs from `example/`, which is where a sketch's `bin/data` would be.
fn addExample(
    b: *std.Build,
    of_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    source: []const u8,
    build_step: []const u8,
    run_step: []const u8,
    what: []const u8,
) void {
    const mod = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport("of", of_mod);
    const exe = b.addExecutable(.{ .name = name, .root_module = mod, .linkage = .dynamic });
    b.step(build_step, b.fmt("Build {s}", .{what})).dependOn(&b.addInstallArtifact(exe, .{}).step);

    const run = b.addRunArtifact(exe);
    run.setCwd(b.path("example"));
    b.step(run_step, b.fmt("Run {s}", .{what})).dependOn(&run.step);
}

/// The compile and link lines of oF's own `openframeworksLib.vcxproj` and
/// `openFrameworksRelease.props`, reproduced for the zig toolchain.
fn configureOf(
    b: *std.Build,
    of_mod: *std.Build.Module,
    lib_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    of_root: []const u8,
    winrt_include: ?[]const u8,
    glue: std.Build.LazyPath,
) void {
    if (target.result.abi != .msvc) {
        lib_mod.owner.getInstallStep().dependOn(&b.addFail("openframeworks_zig: only the x86_64-windows-msvc target is supported (it links oF's Visual Studio prebuilt libraries)").step);
    }

    const of: std.Build.LazyPath = .{ .cwd_relative = of_root };
    const libs = of.path(b, "libs");

    // Always the Release configuration of oF, whatever the Zig optimize mode:
    // the prebuilt third-party libraries and the dynamic CRT are release
    // builds, and the MSVC STL changes its container layouts in debug mode.
    const cxx_flags: []const []const u8 = &.{
        "-std=c++20",
        "-D_DLL",                        "-D_MT", // MultiThreadedDLL (/MD), matching the prebuilt libs
        "-D_ITERATOR_DEBUG_LEVEL=0",     "-DNDEBUG",
        "-DWIN32",                       "-D_CONSOLE",
        "-DUNICODE",                     "-D_UNICODE",
        "-DCURL_STATICLIB",              "-DFREEIMAGE_LIB",
        "-DURI_STATIC_BUILD",            "-D_HAS_STREAM_INSERTION_OPERATORS_DELETED_IN_CXX20",
        "-DPOCO_STATIC",                 "-DCAIRO_WIN32_STATIC_BUILD",
        "-DDISABLE_SOME_FLOATING_POINT", "-DOF_NO_FMOD",
        "-DGLM_FORCE_CTOR_INIT",         "-DGLM_ENABLE_EXPERIMENTAL",
        "-Wno-everything",
    };

    for (include_dirs) |d| lib_mod.addIncludePath(libs.path(b, d));
    if (winrt_include orelse findWinrtInclude(b)) |dir| {
        lib_mod.addIncludePath(.{ .cwd_relative = dir });
    } else {
        lib_mod.owner.getInstallStep().dependOn(&b.addFail("openframeworks_zig: could not find the Windows SDK 'winrt' include directory; pass -Dwinrt-include=<...\\Windows Kits\\10\\Include\\<version>\\winrt>").step);
    }

    lib_mod.addCSourceFiles(.{
        .root = libs.path(b, "openFrameworks"),
        .files = core_sources,
        .flags = cxx_flags,
    });

    // The trampoline that turns ofBaseApp's virtual calls into C callbacks.
    lib_mod.addCSourceFile(.{ .file = b.path("src/cpp/ofzig_app.cpp"), .flags = cxx_flags });

    // The glue cpp-bindgen generated from the bindings: it instantiates every
    // header-only entity the bindings name and static_asserts every layout
    // fact they claim, against the real headers. Compiling it here gives it
    // the include paths added above and the same flags as the rest of the oF
    // build: the facts it checks are only the facts that will be linked if it
    // sees the same declarations. The glue needs no flags of its own -- it
    // carries what it needs in its own source.
    lib_mod.addCSourceFile(.{ .file = glue, .flags = cxx_flags });

    // Link inputs go on the `of` module, not on the static library's own
    // module: a static library's library paths do not reach the executable
    // that links it, but everything attached to an imported module does. So
    // importing `of` is all an executable has to do.
    for (prebuilt_libs) |l| {
        of_mod.addLibraryPath(libs.path(b, b.fmt("{s}/lib/vs/x64", .{l.dir})));
        of_mod.linkSystemLibrary(l.file, .{ .preferred_link_mode = .static });
    }
    for (system_libs) |name| of_mod.linkSystemLibrary(name, .{});
}

/// `libs/<...>` include directories, from openFrameworksRelease.props.
const include_dirs = [_][]const u8{
    "openFrameworks",
    "openFrameworks/graphics",
    "openFrameworks/app",
    "openFrameworks/sound",
    "openFrameworks/utils",
    "openFrameworks/communication",
    "openFrameworks/video",
    "openFrameworks/types",
    "openFrameworks/math",
    "openFrameworks/3d",
    "openFrameworks/gl",
    "openFrameworks/events",
    "glm/include",
    "rtAudio/include",
    "freetype/include",
    "freetype/include/freetype2",
    "FreeImage/include",
    "videoInput/include",
    "glew/include",
    "tess2/include",
    "cairo/include",
    "pixman/include/pixman",
    "libpng/include",
    "zlib/include",
    "glfw/include",
    "openssl/include",
    "utf8/include",
    "json/include",
    "curl/include",
    "uriparser/include",
    "pugixml/include",
};

/// Every translation unit of openframeworksLib.vcxproj, relative to libs/openFrameworks.
const core_sources = &[_][]const u8{
    "3d/of3dPrimitives.cpp",
    "3d/of3dUtils.cpp",
    "3d/ofCamera.cpp",
    "3d/ofEasyCam.cpp",
    "3d/ofNode.cpp",
    "app/ofAppGLFWWindow.cpp",
    "app/ofAppNoWindow.cpp",
    "app/ofAppRunner.cpp",
    "app/ofBaseApp.cpp",
    "app/ofMainLoop.cpp",
    "communication/ofArduino.cpp",
    "communication/ofSerial.cpp",
    "events/ofEvents.cpp",
    "gl/ofBufferObject.cpp",
    "gl/ofCubeMap.cpp",
    "gl/ofFbo.cpp",
    "gl/ofGLProgrammableRenderer.cpp",
    "gl/ofGLRenderer.cpp",
    "gl/ofGLUtils.cpp",
    "gl/ofLight.cpp",
    "gl/ofMaterial.cpp",
    "gl/ofShader.cpp",
    "gl/ofShadow.cpp",
    "gl/ofTexture.cpp",
    "gl/ofVbo.cpp",
    "gl/ofVboMesh.cpp",
    "graphics/of3dGraphics.cpp",
    "graphics/ofBitmapFont.cpp",
    "graphics/ofCairoRenderer.cpp",
    "graphics/ofGraphics.cpp",
    "graphics/ofGraphicsBaseTypes.cpp",
    "graphics/ofGraphicsCairo.cpp",
    "graphics/ofImage.cpp",
    "graphics/ofPath.cpp",
    "graphics/ofPixels.cpp",
    "graphics/ofRendererCollection.cpp",
    "graphics/ofTessellator.cpp",
    "graphics/ofTrueTypeFont.cpp",
    "math/ofMath.cpp",
    "math/ofMatrix3x3.cpp",
    "math/ofMatrix4x4.cpp",
    "math/ofQuaternion.cpp",
    "math/ofVec2f.cpp",
    "math/ofVec4f.cpp",
    "sound/ofFmodSoundPlayer.cpp",
    "sound/ofMediaFoundationSoundPlayer.cpp",
    "sound/ofRtAudioSoundStream.cpp",
    "sound/ofSoundBaseTypes.cpp",
    "sound/ofSoundBuffer.cpp",
    "sound/ofSoundPlayer.cpp",
    "sound/ofSoundStream.cpp",
    "types/ofBaseTypes.cpp",
    "types/ofColor.cpp",
    "types/ofParameter.cpp",
    "types/ofParameterGroup.cpp",
    "types/ofRectangle.cpp",
    "utils/ofFileUtils.cpp",
    "utils/ofFpsCounter.cpp",
    "utils/ofLog.cpp",
    "utils/ofMatrixStack.cpp",
    "utils/ofSystemUtils.cpp",
    "utils/ofThread.cpp",
    "utils/ofTimer.cpp",
    "utils/ofTimerFps.cpp",
    "utils/ofURLFileLoader.cpp",
    "utils/ofUtils.cpp",
    "utils/ofXml.cpp",
    "video/ofDirectShowGrabber.cpp",
    "video/ofDirectShowPlayer.cpp",
    "video/ofMediaFoundationPlayer.cpp",
    "video/ofVideoGrabber.cpp",
    "video/ofVideoPlayer.cpp",
};

const PrebuiltLib = struct { dir: []const u8, file: []const u8 };

/// Release link line of openFrameworksRelease.props, x64.
const prebuilt_libs = [_]PrebuiltLib{
    .{ .dir = "cairo", .file = "libcairo" },
    .{ .dir = "pixman", .file = "libpixman-1" },
    .{ .dir = "libpng", .file = "libpng" },
    .{ .dir = "zlib", .file = "zlib" },
    .{ .dir = "brotli", .file = "brotlicommon" },
    .{ .dir = "brotli", .file = "brotlidec" },
    .{ .dir = "brotli", .file = "brotlienc" },
    .{ .dir = "rtAudio", .file = "rtAudio" },
    .{ .dir = "videoInput", .file = "videoInput" },
    .{ .dir = "freetype", .file = "freetype" },
    .{ .dir = "FreeImage", .file = "FreeImage" },
    .{ .dir = "glew", .file = "libglew32" },
    .{ .dir = "openssl", .file = "libssl" },
    .{ .dir = "openssl", .file = "libcrypto" },
    .{ .dir = "curl", .file = "libcurl" },
    .{ .dir = "uriparser", .file = "uriparser" },
    .{ .dir = "pugixml", .file = "pugixml" },
    .{ .dir = "tess2", .file = "tess2" },
    .{ .dir = "glfw", .file = "glfw3" },
};

/// Windows SDK libraries from both property sheets.
const system_libs = [_][]const u8{
    "msimg32", "opengl32", "glu32",    "kernel32",    "setupapi", "vfw32",    "comctl32", "dsound",
    "user32",  "gdi32",    "winspool", "comdlg32",    "advapi32", "shell32",  "ole32",    "oleaut32",
    "uuid",    "crypt32",  "ws2_32",   "winmm",       "odbc32",   "odbccp32", "wldap32",  "mf",
    "mfplat",  "mfuuid",   "d3d11",    "mfreadwrite", "xaudio2",
};

/// `ofMain.h` includes every oF header, so the glue needs no other.
const glue_headers: []const []const u8 = &.{"ofMain.h"};

/// The root of the glue scan. The generator is its own compilation, so it
/// gets its own module object for `src/of.zig` rather than the public `of`
/// module: that one links the library the glue is compiled into, which would
/// be a dependency loop.
fn bindingsModule(b: *std.Build, dep: *std.Build.Dependency, target: std.Build.ResolvedTarget) *std.Build.Module {
    const bindings = b.createModule(.{ .root_source_file = b.path("src/of.zig"), .target = target });
    bindings.addImport("cpp_bindgen", dep.module("cpp_bindgen"));
    return bindings;
}

/// `<Windows Kits>/10/Include/<version>/winrt`, which oF's Media Foundation
/// code needs (`wrl.h`) and which zig does not add on its own.
fn findWinrtInclude(b: *std.Build) ?[]const u8 {
    const sdk = std.zig.WindowsSdk.find(b.allocator, b.graph.io, .x86_64, &b.graph.environ_map) catch return null;
    const w10 = sdk.windows10sdk orelse return null;
    return b.pathJoin(&.{ w10.path, "Include", w10.version, "winrt" });
}
