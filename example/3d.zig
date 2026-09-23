//! A 3D scene: a snake of cylinders slithering around a grid, a lit box
//! turning in the middle, all seen through an `EasyCam`. Drag to orbit,
//! right-drag or scroll to zoom, middle-drag (or `m` and drag) to pan.
//! `l` toggles the light, `r` resets the camera, `f` is fullscreen.
//!
//! The snake is a port of a classic first oF 3D sketch: each segment is a
//! cylinder whose local frame is built from the direction to the previous
//! segment, and pushed onto the matrix stack with `multMatrix`.
const std = @import("std");
const of = @import("of");

const snake_len = 20;
const snake_angular_resolution = 0.1;
const path_radius = 150;
const speed = 0.5;
const slither_width = 15;
const slither_frequency = 3;
const slither_wavelength = 0.25;
const color_gradient_slope = 8;
const snake_radius = 10;

/// Any vector at a right angle to `v`.
fn perpendicular(v: of.Vec3) of.Vec3 {
    if (v[0] != 0 or v[1] != 0) return .{ -v[1], v[0], 0 };
    return .{ 0, -v[2], v[1] };
}

/// Where segment `index` of the snake is at this instant.
fn snakePos(index: u32) of.Vec3 {
    const t = of.getElapsedTime();
    const len_pos: f32 = @as(f32, @floatFromInt(index)) * snake_angular_resolution;
    const angle = t * speed - len_pos;
    const slither = @sin(t * slither_frequency - len_pos / slither_wavelength) * slither_width;
    return of.Vec3{ @cos(angle), 0, @sin(angle) } * @as(of.Vec3, @splat(path_radius + slither));
}

const App = struct {
    /// C++ constructs these in place in `setup` and destroys them in `exit`.
    /// None of them can be copied, so they live here.
    cam: of.EasyCam = undefined,
    box: of.BoxPrimitive = undefined,
    light: of.Light = undefined,
    /// A hand-built mesh: a fan of triangles on the ground.
    fan: of.Mesh = undefined,
    lit: bool = true,

    pub fn setup(self: *App) void {
        of.setWindowTitle("Snake");
        of.setFrameRate(60);
        of.background(of.Color.rgb(24, 24, 32));

        self.cam.init();

        self.box.init();
        self.box.set(60, 30, 60);
        self.box.node().setPosition(.{ 0, 15, 0 });

        self.light.init();
        self.light.setPointLight();
        self.light.node().setPosition(.{ 300, 400, 300 });
        self.light.setDiffuseColor(.{ .r = 1, .g = 0.95, .b = 0.8 });

        // A mesh from slices: the bulk calls hand the slice to oF's
        // pointer-and-length overloads, so nothing is copied on the way in.
        self.fan.init();
        self.fan.setMode(.triangle_fan);
        var verts: [8]of.GlmVec3 = undefined;
        var colors: [8]of.FloatColor = undefined;
        verts[0] = .{ .x = 0, .y = 1, .z = 0 };
        colors[0] = .{ .r = 1, .g = 1, .b = 1 };
        for (1..8) |i| {
            const a = @as(f32, @floatFromInt(i - 1)) / 6.0 * std.math.tau;
            verts[i] = .{ .x = 60 * @cos(a), .y = 1, .z = 60 * @sin(a) };
            // A `FloatColor` takes its hue in `[0, 1]`; the same call on a
            // `Color` would take it in `[0, 255]`.
            colors[i] = of.FloatColor.fromHsb(@as(f32, @floatFromInt(i - 1)) / 6.0, 0.8, 1, 1);
        }
        self.fan.addVertices(&verts);
        self.fan.addColors(&colors);
        // The getters return the mesh's own arrays: edit them in place.
        for (self.fan.getVertices()) |*v| v.x *= 1.5;

        // A copy owns its own arrays: clearing it leaves the fan alone.
        var copy: of.Mesh = undefined;
        copy.initCopy(&self.fan);
        const copied = copy.getNumVertices();
        copy.clear();
        copy.deinit();

        // The same color in the three channel widths, and its hue as an angle.
        const orange = of.Color.rgb(255, 128, 0);
        const orange_f: of.FloatColor = .from(orange);
        std.debug.print("setup: fan has {d} vertices, {d} colors (copy had {d}), centroid {d:.1}, box bounds {d:.0} to {d:.0}\n", .{
            self.fan.getNumVertices(),
            self.fan.getColorsConst().len,
            copied,
            self.fan.getCentroid(),
            self.box.getBoundingBox().min.to(),
            self.box.getBoundingBox().max.to(),
        });
        std.debug.print("setup: orange hue {d:.0}/255 = {d:.3}/1 = {d:.1} deg, hex {x}, short {d}\n", .{
            orange.getHue(),
            orange_f.getHue(),
            std.math.radiansToDegrees(orange_f.getHueAngle()),
            orange.getHex(),
            of.ShortColor.from(orange).g,
        });

        // The camera is an ofNode two levels up; `node()` is the checked
        // upcast to it, and `camera()` the one to ofCamera.
        self.cam.node().setPosition(.{ 0, 250, 450 });
        self.cam.node().lookAt(.{ 0, 0, 0 });
        self.cam.camera().setNearClip(1);
        std.debug.print("setup: fov {d:.1} deg, camera at {d:.0}\n", .{
            std.math.radiansToDegrees(self.cam.camera().getFov()),
            self.cam.node().getPosition(),
        });
    }

    pub fn draw(self: *App) void {
        self.cam.begin();
        defer self.cam.end();
        of.enableDepthTest();
        defer of.disableDepthTest();

        of.setColor(of.Color.grey(90));
        of.drawGrid(50, 4, .{ .x = false, .y = true, .z = false });

        if (self.lit) {
            of.enableLighting();
            self.light.enable();
        }
        defer if (self.lit) {
            self.light.disable();
            of.disableLighting();
        };

        var last_pos = snakePos(0);
        for (1..snake_len) |i| {
            const pos = snakePos(@intCast(i));
            const vec = pos - last_pos;
            const b1 = of.normalize(vec);
            const b2 = of.normalize(perpendicular(b1));
            const b3 = of.cross(b1, b2);
            const mid = (pos + last_pos) / @as(of.Vec3, @splat(2));
            // A cylinder stands along y, so `b1` (the segment's direction)
            // is the second column of its frame.
            const frame: of.Mat4 = .fromBasisOrigin(.fromCols(b2, b1, b3), mid);

            of.pushMatrix();
            defer of.popMatrix();
            of.translate(0, snake_radius, 0);
            of.multMatrix(frame);
            of.setColor(of.Color.rgb(0, 255 - @as(u8, @intCast(i)) * color_gradient_slope, 0));
            of.drawCylinder(snake_radius, of.length(vec));
            last_pos = pos;
        }

        of.setColor(of.Color.rgb(200, 160, 60));
        self.box.draw();
        self.box.node().pan(0.01);

        // The fan carries its own colors, so the current color does not apply.
        self.fan.draw();
    }

    pub fn keyPressed(self: *App, k: of.KeyEventArgs) void {
        switch (k.key) {
            'f' => of.toggleFullscreen(),
            'l' => self.lit = !self.lit,
            'r' => self.cam.reset(),
            else => {},
        }
    }

    pub fn exit(self: *App) void {
        self.fan.deinit();
        self.light.deinit();
        self.box.deinit();
        self.cam.deinit();
    }
};

pub fn main() u8 {
    var app: App = .{};
    return @intCast(of.run(App, &app, .{ .width = 624, .height = 624 }));
}
