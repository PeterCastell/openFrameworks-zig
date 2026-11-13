//! A 3D model through ofxAssimpModelLoader, under an `EasyCam`.
//!
//! With no argument it loads a small OBJ embedded in this file, from
//! memory: two named meshes, a pyramid and a cube. Give it a file to load
//! any model assimp reads, with its textures and animations:
//!
//!     zig build run-model -Dof-root=... -- path/to/Fox.gltf
//!
//! (oF ships some in `examples/3d/assimp3DModelLoaderExample/bin/data`.)
//!
//! Keys: `1` faces, `2` wireframe, `3` points, `space` pauses the
//! animations, `t` textures, `m` materials, `c` back-face culling,
//! `r` resets the camera.
const std = @import("std");
const of = @import("of");

/// Two objects, so `getMeshNames` and the per-mesh calls have something to
/// show. No `mtllib`: from memory, assimp has no directory to find one in.
const embedded_obj =
    \\o pyramid
    \\v -1 0 -1
    \\v 1 0 -1
    \\v 1 0 1
    \\v -1 0 1
    \\v 0 1.6 0
    \\f 1 2 3
    \\f 1 3 4
    \\f 1 5 2
    \\f 2 5 3
    \\f 3 5 4
    \\f 4 5 1
    \\o cube
    \\v 1.5 0 -0.5
    \\v 2.5 0 -0.5
    \\v 2.5 0 0.5
    \\v 1.5 0 0.5
    \\v 1.5 1 -0.5
    \\v 2.5 1 -0.5
    \\v 2.5 1 0.5
    \\v 1.5 1 0.5
    \\f 6 8 7
    \\f 6 9 8
    \\f 10 11 12
    \\f 10 12 13
    \\f 6 7 11
    \\f 6 11 10
    \\f 7 8 12
    \\f 7 12 11
    \\f 8 9 13
    \\f 8 13 12
    \\f 9 6 10
    \\f 9 10 13
    \\
;

const App = struct {
    /// C++ constructs these in place in `setup` and destroys them in `exit`.
    model: of.assimp.ModelLoader = undefined,
    cam: of.EasyCam = undefined,
    light: of.Light = undefined,
    file: ?[]const u8 = null,
    loaded: bool = false,
    mode: of.PolyRenderMode = .fill,
    paused: bool = false,
    textures: bool = true,
    materials: bool = true,
    culling: bool = false,

    pub fn setup(self: *App) void {
        of.setWindowTitle("Model");
        of.setFrameRate(60);
        of.background(of.Color.rgb(40, 40, 48));

        self.cam.init();
        self.light.init();
        self.light.node().setPosition(.{ 300, 500, 600 });

        self.model.init();
        self.loaded = if (self.file) |f|
            self.model.load(f, .optimize_default)
        else
            self.model.loadMemory(embedded_obj, .optimize_default, "obj");
        if (!self.loaded) {
            std.debug.print("could not load {s}\n", .{self.file orelse "the embedded model"});
            return;
        }
        // `load` centers the model in the window, for the 2D camera; under
        // an EasyCam the origin is the middle of the view.
        self.model.setPosition(.{ 0, 0, 0 });
        self.model.setLoopStateForAllAnimations(.normal);
        self.model.playAllAnimations();

        self.describe();
    }

    /// Prints what the loader found, through the read-only half of the API.
    fn describe(self: *App) void {
        const m = &self.model;
        std.debug.print("model: {d} meshes, {d} animations, normalized scale {d:.3}\n", .{
            m.getMeshCount(), m.getAnimationCount(), m.getNormalizedScale(),
        });
        std.debug.print("model: scene {d:.2} to {d:.2}, center {d:.2}\n", .{
            m.getSceneMin(false), m.getSceneMax(false), m.getSceneCenter(),
        });

        var names = m.getMeshNames();
        defer names.deinit();
        for (names.items(), 0..) |*name, i| {
            const index: u32 = @intCast(i);
            const helper = m.getMeshHelper(index).?;

            var mesh: of.Mesh = undefined;
            m.getMesh(index, &mesh);
            defer mesh.deinit();

            // A second handle on the diffuse texture. Ask first: oF logs an
            // error for a mesh with none.
            var tex: of.Texture = undefined;
            if (helper.hasTexture(.diffuse)) m.getTextureForMesh(index, &tex) else tex.init();
            defer tex.deinit();

            std.debug.print("  mesh {d} \"{s}\": {d} vertices, {d} indices, diffuse {d:.2}, texture {s} {d}x{d}, {d} textures in all\n", .{
                i,
                name.slice(),
                mesh.getNumVertices(),
                helper.indices.constItems().len,
                helper.material.getDiffuseColor().r,
                if (tex.isAllocated()) "yes" else "no",
                tex.getWidth(),
                tex.getHeight(),
                helper.getAllMeshTextures().len,
            });
            for (helper.getAllMeshTextures()) |shared| {
                const t = shared.get() orelse continue;
                var kind = t.getTextureTypeAsString();
                defer kind.deinit();
                var path = t.getTexturePath();
                defer path.deinit();
                std.debug.print("    {s}: {s}\n", .{ kind.slice(), path.slice() });
            }
        }
        var i: u32 = 0;
        while (m.getAnimation(i)) |anim| : (i += 1) {
            std.debug.print("  animation {d}: {d:.0} ticks\n", .{ i, anim.getDurationInSeconds() });
        }
    }

    pub fn update(self: *App) void {
        if (self.loaded) self.model.update();    }

    pub fn draw(self: *App) void {
        if (!self.loaded) {
            of.drawBitmapString("no model: see the console", 20, 30);
            return;
        }
        {
            self.cam.begin();
            defer self.cam.end();
            of.enableDepthTest();
            defer of.disableDepthTest();
            of.enableLighting();
            self.light.enable();
            defer {
                self.light.disable();
                of.disableLighting();
            }

            of.setColor(of.Color.white);
            self.model.draw(self.mode);
        }

        var buf: [128]u8 = undefined;
        const anim = self.model.getAnimation(0);
        const line = std.fmt.bufPrint(&buf, "{d:.0} fps   animation {d:.2}   1/2/3 mode, space pause, t/m/c toggles", .{
            of.getFrameRate(),
            if (anim) |a| a.getPosition() else 0,
        }) catch return;
        of.drawBitmapString(line, 20, 30);
    }

    pub fn keyPressed(self: *App, k: of.KeyEventArgs) void {
        switch (k.key) {
            '1' => self.mode = .fill,
            '2' => self.mode = .wireframe,
            '3' => self.mode = .points,
            ' ' => {
                self.paused = !self.paused;
                self.model.setPausedForAllAnimations(self.paused);
            },
            't' => {
                self.textures = !self.textures;
                if (self.textures) self.model.enableTextures() else self.model.disableTextures();
            },
            'm' => {
                self.materials = !self.materials;
                if (self.materials) self.model.enableMaterials() else self.model.disableMaterials();
            },
            'c' => {
                self.culling = !self.culling;
                if (self.culling) self.model.enableCulling(.counter_clockwise) else self.model.disableCulling();
            },
            'r' => self.cam.reset(),
            else => {},
        }
    }

    pub fn exit(self: *App) void {
        if (self.model.getAnimation(0)) |anim|
            std.debug.print("exit: animation 0 at {d:.3} of the way, playing {}\n", .{ anim.getPosition(), anim.isPlaying() });
        self.model.deinit();
        self.light.deinit();
        self.cam.deinit();
    }
};

pub fn main(init: std.process.Init.Minimal) u8 {
    var app: App = .{};
    const args = init.args.toSlice(std.heap.page_allocator) catch &.{};
    if (args.len > 1) app.file = args[1];
    return @intCast(of.run(App, &app, .{ .width = 800, .height = 600 }));
}
