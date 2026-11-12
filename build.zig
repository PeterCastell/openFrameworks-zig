//! openFrameworks bindings for Zig, built on cpp-bindgen.
//!
//! This package owns the compilation of the openFrameworks core, but not the
//! source: point it at an existing 0.12 release with `-Dof-root=<path>` or the
//! `OF_ROOT` environment variable. Two platforms are supported, each against
//! its own release:
//!
//! - Windows, x86_64, MSVC ABI: `of_v0.12.x_vs_64_release`. It is the default
//!   target on a Windows host.
//! - macOS, aarch64 or x86_64: `of_v0.12.x_osx_release`. It is the default
//!   target on a Mac, which builds natively.
//!
//! It exports two things:
//!
//! - module `of`: the Zig side, built on cpp-bindgen.
//! - artifact `openFrameworks`: a static library holding the oF core compiled
//!   for the platform's C++ ABI, the C++ glue cpp-bindgen generates for the
//!   bindings, and the link lines for every third-party and system library oF
//!   needs. There is no hand-written C++: an app is a Zig subclass of
//!   `ofBaseApp`.
//!
//! An end project does this:
//!
//! ```zig
//! const of_dep = b.dependency("openframeworks_zig", .{ .target = target, .optimize = optimize, .@"of-root" = of_root });
//! exe_mod.addImport("of", of_dep.module("of")); // the module carries the library and its link line
//! // and the executable must link dynamically: on Windows that is the dynamic
//! // CRT, like every oF build there; on macOS it is the only kind there is.
//! const exe = b.addExecutable(.{ .name = "app", .root_module = exe_mod, .linkage = .dynamic });
//! ```
const std = @import("std");
const builtin = @import("builtin");
const cpp_bindgen = @import("cpp_bindgen");

pub fn build(b: *std.Build) void {
    // On a Windows host, the MSVC ABI that oF's Visual Studio libraries use;
    // anywhere else, the machine itself.
    const default_target: std.Target.Query = if (builtin.os.tag == .windows)
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .msvc }
    else
        .{};
    const target = b.standardTargetOptions(.{ .default_target = default_target });
    const optimize = b.standardOptimizeOption(.{});

    const of_root = b.option([]const u8, "of-root", "Path to an openFrameworks 0.12 release (vs_64 or osx layout). Defaults to $OF_ROOT.") orelse
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

    // The C++ side: oF core + glue, as one static library.
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
        lib.step.dependOn(&b.addFail("openframeworks_zig: pass -Dof-root=<path to of_v0.12.x_vs_64_release or of_v0.12.x_osx_release> or set OF_ROOT").step);
    } else {
        configureOf(b, of_mod, lib_mod, target, of_root, winrt_include, glue);
    }
    b.installArtifact(lib);
    of_mod.linkLibrary(lib);

    // Example apps, also the smoke tests of the whole chain: `main.zig` is
    // the 2D one, `3d.zig` the camera, primitives and light.
    addExample(b, of_mod, target, optimize, "example", "example/main.zig", "example", "run", "the 2D example app");
    addExample(b, of_mod, target, optimize, "example-3d", "example/3d.zig", "example-3d", "run-3d", "the 3D example app");
    addExample(b, of_mod, target, optimize, "example-transforms", "example/transforms.zig", "example-transforms", "run-transforms", "the matrix and material example app");
    addExample(b, of_mod, target, optimize, "example-shaders", "example/shaders.zig", "example-shaders", "run-shaders", "the shader example app");

    // Tests of the bindings against the oF build itself: the vtable layouts
    // they claim, and a Zig subclass of `ofBaseApp`. Linked like an example,
    // with the dynamic CRT, but needing no window.
    const tests_mod = b.createModule(.{
        .root_source_file = b.path("test/vtables.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    tests_mod.addImport("of", of_mod);
    tests_mod.addImport("cpp_bindgen", dep.module("cpp_bindgen"));
    const tests = b.addTest(.{ .name = "vtables", .root_module = tests_mod });
    tests.linkage = .dynamic;
    b.step("test", "Run the binding tests (needs -Dof-root)").dependOn(&b.addRunArtifact(tests).step);

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

/// The platforms there is an oF release for and a link line here.
const Platform = enum {
    windows,
    macos,

    fn of(t: std.Target) ?Platform {
        if (t.os.tag == .windows and t.abi == .msvc and t.cpu.arch == .x86_64) return .windows;
        if (t.os.tag == .macos and (t.cpu.arch == .aarch64 or t.cpu.arch == .x86_64)) return .macos;
        return null;
    }
};

/// Everything the oF compile needs from one platform's release.
fn configureOf(
    b: *std.Build,
    of_mod: *std.Build.Module,
    lib_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    of_root: []const u8,
    winrt_include: ?[]const u8,
    glue: std.Build.LazyPath,
) void {
    const platform = Platform.of(target.result) orelse {
        lib_mod.owner.getInstallStep().dependOn(&b.addFail("openframeworks_zig: the supported targets are x86_64-windows-msvc (oF's vs_64 release) and aarch64-macos or x86_64-macos (oF's osx release)").step);
        return;
    };

    const of: std.Build.LazyPath = .{ .cwd_relative = of_root };
    const libs = of.path(b, "libs");
    for (include_dirs) |d| lib_mod.addIncludePath(libs.path(b, d));

    const cxx_flags = switch (platform) {
        .windows => configureWindows(b, of_mod, lib_mod, libs, winrt_include),
        .macos => configureMacos(b, of_mod, lib_mod, libs, of_root),
    };

    // The glue cpp-bindgen generated from the bindings: it instantiates every
    // header-only entity the bindings name and static_asserts every layout
    // fact they claim, against the real headers. Compiling it here gives it
    // the include paths added above and the same flags as the rest of the oF
    // build: the facts it checks are only the facts that will be linked if it
    // sees the same declarations. The glue needs no flags of its own -- it
    // carries what it needs in its own source. It is C++ on every platform:
    // what the core's Objective-C++ adds on macOS is in no class it binds.
    lib_mod.addCSourceFile(.{ .file = glue, .flags = cxx_flags, .language = .cpp });
}

/// The compile and link lines of oF's own `openframeworksLib.vcxproj` and
/// `openFrameworksRelease.props`, reproduced for the zig toolchain. Returns
/// the C++ flags, for the glue.
fn configureWindows(
    b: *std.Build,
    of_mod: *std.Build.Module,
    lib_mod: *std.Build.Module,
    libs: std.Build.LazyPath,
    winrt_include: ?[]const u8,
) []const []const u8 {
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

    if (winrt_include orelse findWinrtInclude(b)) |dir| {
        lib_mod.addIncludePath(.{ .cwd_relative = dir });
    } else {
        lib_mod.owner.getInstallStep().dependOn(&b.addFail("openframeworks_zig: could not find the Windows SDK 'winrt' include directory; pass -Dwinrt-include=<...\\Windows Kits\\10\\Include\\<version>\\winrt>").step);
    }

    const root = libs.path(b, "openFrameworks");
    lib_mod.addCSourceFiles(.{ .root = root, .files = core_sources, .flags = cxx_flags });
    lib_mod.addCSourceFiles(.{ .root = root, .files = windows_sources, .flags = cxx_flags });

    // Link inputs go on the `of` module, not on the static library's own
    // module: a static library's library paths do not reach the executable
    // that links it, but everything attached to an imported module does. So
    // importing `of` is all an executable has to do.
    for (prebuilt_libs) |l| {
        of_mod.addLibraryPath(libs.path(b, b.fmt("{s}/lib/vs/x64", .{l.dir})));
        of_mod.linkSystemLibrary(l.file, .{ .preferred_link_mode = .static });
    }
    for (system_libs) |name| of_mod.linkSystemLibrary(name, .{});
    return cxx_flags;
}

/// The compile and link lines of oF's `config.osx.default.mk`, the makefile
/// build of the osx release, reproduced for the zig toolchain. Returns the
/// C++ flags, for the glue.
///
/// The makefile compiles the whole core as Objective-C++ with ARC, and so does
/// this: `ofAppGLFWWindow.cpp` talks to Cocoa directly. It links the
/// release's static libraries by finding them, every `libs/*/lib/osx/*.a`,
/// and so does this too, since their names (`glfw3.a`, `freeimage.a`) are not
/// ones `linkSystemLibrary` would look for.
fn configureMacos(
    b: *std.Build,
    of_mod: *std.Build.Module,
    lib_mod: *std.Build.Module,
    libs: std.Build.LazyPath,
    of_root: []const u8,
) []const []const u8 {
    const cxx_flags: []const []const u8 = &.{
        "-std=c++20",                 "-DNDEBUG",
        "-DOF_NO_FMOD",               "-DGLM_FORCE_CTOR_INIT",
        "-DGLM_ENABLE_EXPERIMENTAL",  "-DGL_SILENCE_DEPRECATION",
        "-DGLES_SILENCE_DEPRECATION", "-DCOREVIDEO_SILENCE_GL_DEPRECATION",
        "-Wno-everything",
    };
    const objc_flags: []const []const u8 = cxx_flags ++ &[_][]const u8{"-fobjc-arc"};
    const c_objc_flags: []const []const u8 = &.{
        "-DNDEBUG",                 "-DOF_NO_FMOD",
        "-DGL_SILENCE_DEPRECATION", "-DCOREVIDEO_SILENCE_GL_DEPRECATION",
        "-fobjc-arc",               "-Wno-everything",
    };

    // libc++ is not part of the C runtime on macOS, as the MSVC STL is on
    // Windows: the library needs it to compile, and the executable to link.
    lib_mod.link_libcpp = true;
    of_mod.link_libcpp = true;

    const root = libs.path(b, "openFrameworks");
    lib_mod.addCSourceFiles(.{ .root = root, .files = core_sources, .flags = objc_flags, .language = .objective_cpp });
    lib_mod.addCSourceFiles(.{ .root = root, .files = macos_objcpp_sources, .flags = objc_flags, .language = .objective_cpp });
    lib_mod.addCSourceFiles(.{ .root = root, .files = macos_objc_sources, .flags = c_objc_flags, .language = .objective_c });

    // See `configureWindows` for why link inputs go on the `of` module.
    for (findMacosLibs(b, b.pathJoin(&.{ of_root, "libs" }))) |lib| of_mod.addObjectFile(.{ .cwd_relative = lib });
    for (macos_frameworks) |name| of_mod.linkFramework(name, .{});
    for (macos_system_libs) |name| of_mod.linkSystemLibrary(name, .{});
    return cxx_flags;
}

/// Every `libs/<name>/lib/osx/*.a` of the release, as oF's makefiles find
/// them, but for the core's own (`openFrameworksCompiled`), which this
/// package compiles itself. A library missing from a release is then simply
/// not linked, and one a release adds is linked without a change here.
fn findMacosLibs(b: *std.Build, libs_dir: []const u8) []const []const u8 {
    const io = b.graph.io;
    var found: std.ArrayList([]const u8) = .empty;

    var dir = std.Io.Dir.cwd().openDir(io, libs_dir, .{ .iterate = true }) catch |err|
        std.debug.panic("openframeworks_zig: cannot open {s}: {t}", .{ libs_dir, err });
    defer dir.close(io);
    var it = dir.iterate();
    while (it.next(io) catch |err| std.debug.panic("openframeworks_zig: cannot list {s}: {t}", .{ libs_dir, err })) |lib| {
        if (lib.kind != .directory or std.mem.eql(u8, lib.name, "openFrameworksCompiled")) continue;
        const sub = b.pathJoin(&.{ lib.name, "lib", "osx" });
        var osx = dir.openDir(io, sub, .{ .iterate = true }) catch continue;
        defer osx.close(io);
        var files = osx.iterate();
        while (files.next(io) catch null) |file| {
            if (file.kind != .file or !std.mem.endsWith(u8, file.name, ".a")) continue;
            found.append(b.allocator, b.pathJoin(&.{ libs_dir, sub, file.name })) catch @panic("OOM");
        }
    }
    // Directory order is the file system's; sorting keeps the link line, and
    // with it the cache key, the same from one machine to the next.
    std.mem.sort([]const u8, found.items, {}, struct {
        fn lessThan(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.lessThan(u8, x, y);
        }
    }.lessThan);
    return found.items;
}

/// `libs/<...>` include directories, from openFrameworksRelease.props and
/// CoreOF.xcconfig. Each release lacks a few of the other's; a directory that
/// does not exist is simply not searched.
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
    "brotli/include",
};

/// The translation units every platform compiles, relative to
/// libs/openFrameworks: openframeworksLib.vcxproj less its Windows-only
/// players, which is also the makefile's list less its exclusions.
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
    "video/ofVideoGrabber.cpp",
    "video/ofVideoPlayer.cpp",
};

/// The rest of openframeworksLib.vcxproj: DirectShow and Media Foundation,
/// and the fmod player, which `OF_NO_FMOD` compiles to nothing.
const windows_sources = &[_][]const u8{
    "sound/ofFmodSoundPlayer.cpp",
    "sound/ofMediaFoundationSoundPlayer.cpp",
    "video/ofDirectShowGrabber.cpp",
    "video/ofDirectShowPlayer.cpp",
    "video/ofMediaFoundationPlayer.cpp",
};

/// AVFoundation, macOS's video and sound backends.
const macos_objcpp_sources = &[_][]const u8{
    "sound/ofAVEngineSoundPlayer.mm",
    "video/ofAVFoundationGrabber.mm",
    "video/ofAVFoundationPlayer.mm",
};
const macos_objc_sources = &[_][]const u8{
    "video/ofAVFoundationVideoPlayer.m",
};

/// `OF_CORE_FRAMEWORKS` of CoreOF.xcconfig, less AGL: nothing here uses it,
/// and recent SDKs no longer carry it.
const macos_frameworks = [_][]const u8{
    "Accelerate",   "AppKit",              "ApplicationServices", "AudioToolbox",
    "AVFoundation", "Cocoa",               "CoreAudio",           "CoreFoundation",
    "CoreMedia",    "CoreServices",        "CoreVideo",           "Foundation",
    "IOKit",        "Metal",               "OpenGL",              "QuartzCore",
    "Security",     "SystemConfiguration",
};

/// `PLATFORM_LIBRARIES` of config.osx.default.mk, and the system zlib, which
/// the release's png, freetype, cairo and curl expect.
const macos_system_libs = [_][]const u8{ "objc", "z" };

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
