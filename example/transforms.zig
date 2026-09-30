//! Two copies of one cylinder, transformed vertex by vertex through the
//! same three elementary matrices in two orders: `T * R * S`, which turns
//! the cylinder in place and then lifts it, and `R * T * S`, which lifts it
//! and then turns the lifted position about the origin. Drag to orbit, and
//! move the mouse to move the light in and out.
//!
//! A port of a COMP 3501 transform sandbox. The matrices are built the way
//! glm builds them (`translation`, `rotation`, `scaling`, or `translate`,
//! `rotate`, `scale` chained off `identity`) and applied with
//! `transformPoint`, which is `M * vec4(v, 1)`.
const std = @import("std");
const of = @import("of");

const radius = 30;
const height = 180;
const lift: of.Vec3 = .{ 0, 200, 0 };
const spin_axis: of.Vec3 = .{ 0, 0, 1 };

const App = struct {
    cam: of.EasyCam = undefined,
    /// The cylinder as `Mesh.initCylinder` built it, and a copy whose
    /// vertices are rewritten every frame.
    original: of.Mesh = undefined,
    transformed: of.Mesh = undefined,
    sun: of.Light = undefined,
    material: of.Material = undefined,
    /// Time, in frames of a hundredth.
    t: f32 = 0,

    pub fn setup(self: *App) void {
        of.setWindowTitle("Transforms");
        of.background(of.Color.wheat);

        self.cam.init();

        // `ofMesh::cylinder(radius, height)` with its default segment counts.
        self.original.initCylinder(radius, height, 12, 6, 2, true, .triangle_strip);
        self.original.clearColors();
        self.transformed.initCopy(&self.original);

        self.sun.init();
        self.sun.setPointLight();
        self.sun.setAmbientColor(of.FloatColor.ghostWhite);
        self.sun.setDiffuseColor(.grey(0.7));
        self.sun.setSpecularColor(.grey(1));
        self.sun.setSpotConcentration(30);
        self.sun.node().setGlobalPosition(.{ 0, 0, 1000 });
        of.enableSeparateSpecularLight();
        self.sun.enable();

        self.material.init();
        self.material.setShininess(120);
        self.material.setSpecularColor(.black);
        self.material.setEmissiveColor(.black);
        self.material.setDiffuseColor(.white);
        self.material.setAmbientColor(.black);

        of.enableLighting();
        of.enableDepthTest();
    }

    pub fn update(self: *App) void {
        self.t += 0.01;
    }

    pub fn draw(self: *App) void {
        self.cam.begin();
        defer self.cam.end();

        const w: f32 = @floatFromInt(of.getWidth());
        const h: f32 = @floatFromInt(of.getHeight());
        self.sun.node().setPosition(.{ w * 0.2, h * 0.1, @floatFromInt(of.getMouseX()) });

        const angle = std.math.degreesToRadians(self.t * 10);

        // The elementary matrices, then the composite in the regular order.
        const T: of.Mat4 = .translation(lift);
        const R: of.Mat4 = .rotation(angle, spin_axis);
        const S: of.Mat4 = .scaling(@splat(1));
        self.apply(T.mul(R).mul(S));
        self.material.setDiffuseColor(of.FloatColor.blueSteel);
        self.material.begin();
        self.transformed.draw();
        self.material.end();

        // The confused order, spelled the other way: each call
        // post-multiplies, so this is `I * R * T * S`.
        self.apply(of.Mat4.identity.rotate(angle, spin_axis).translate(lift).scale(@splat(1)));
        self.material.setDiffuseColor(of.FloatColor.indianRed);
        self.material.begin();
        self.transformed.draw();
        self.material.end();
    }

    /// Every vertex of the original through `m`, into the transformed copy.
    fn apply(self: *App, m: of.Mat4) void {
        for (0..self.original.getNumVertices()) |i| {
            const index: u32 = @intCast(i);
            self.transformed.setVertex(index, m.transformPoint(self.original.getVertex(index)));
        }
    }

    pub fn keyPressed(self: *App, k: of.KeyEventArgs) void {
        switch (k.key) {
            'f' => of.toggleFullscreen(),
            'r' => self.cam.reset(),
            else => {},
        }
    }

    pub fn exit(self: *App) void {
        self.material.deinit();
        self.sun.deinit();
        self.transformed.deinit();
        self.original.deinit();
        self.cam.deinit();
    }
};

pub fn main() u8 {
    var app: App = .{};
    return @intCast(of.run(App, &app, .{ .width = 1024, .height = 768 }));
}
