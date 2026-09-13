//! The classic first oF sketch, in Zig: a circle that follows the mouse,
//! a rectangle you can click, and some text. Press `f` for fullscreen.
const std = @import("std");
const of = @import("of");

const App = struct {
    clicks: u32 = 0,
    box: of.Rectangle = undefined,

    pub fn setup(self: *App) void {
        of.setWindowTitle("openFrameworks-zig");
        of.setFrameRate(60);
        of.setCircleResolution(64);
        of.background(of.Color.rgb(24, 24, 32));
        self.box.init(40, 80, 220, 120);
        std.debug.print("setup: window {d}x{d}, box area {d:.0}\n", .{ of.getWidth(), of.getHeight(), self.box.getArea() });
    }

    pub fn update(_: *App) void {}

    pub fn draw(self: *App) void {
        const t = of.getElapsedTimef();

        // `Vec2` is `@Vector(2, f32)`, so the arithmetic below is Zig's own.
        const mouse: of.Vec2 = .{ @floatFromInt(of.getMouseX()), @floatFromInt(of.getMouseY()) };

        // A box that changes shade while the mouse is over it.
        of.setColor(if (self.box.inside(mouse[0], mouse[1])) of.Color.rgb(255, 180, 40) else of.Color.rgb(90, 90, 120));
        self.box.draw();

        // A circle that follows the mouse and pulses.
        const r = 30 + 10 * @sin(t * 3);
        of.setColor(of.Color.rgba(80, 200, 255, 200));
        of.drawCircleAt(mouse, r);

        // A leader from the box to the circle's edge: subtract, normalize,
        // scale, and hand the result straight to the wrapper, which is the
        // only place a `glm::vec2` exists.
        const centre = self.box.getCenter();
        const from: of.Vec2 = .{ centre[0], centre[1] };
        const gap = mouse - from;
        if (of.length(gap) > r) {
            of.setColor(of.Color.rgba(255, 255, 255, 90));
            of.setLineWidth(1);
            of.drawLineBetween(from, mouse - of.normalize(gap) * @as(of.Vec2, @splat(r)));
        }

        // A spinning line around the circle.
        of.pushMatrix();
        of.translate(mouse[0], mouse[1], 0);
        of.rotateDeg(t * 90);
        of.setColor(of.Color.grey(255));
        of.setLineWidth(2);
        of.drawLine(-60, 0, 60, 0);
        of.popMatrix();

        var buf: [128]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "fps {d:.1}  frame {d}  clicks {d}  ({d}x{d})", .{
            of.getFrameRate(), of.getFrameNum(), self.clicks, of.getWidth(), of.getHeight(),
        }) catch "?";
        of.setColor(of.Color.grey(220));
        of.drawBitmapString(text, 20, 30);
        of.drawBitmapString("move the mouse, click the box, press f for fullscreen, esc to quit", 20, 50);
    }

    pub fn exit(self: *App) void {
        self.box.deinit();
    }

    pub fn keyPressed(_: *App, k: of.KeyEventArgs) void {
        if (k.key == 'f') of.toggleFullscreen();
    }

    pub fn mousePressed(self: *App, m: of.MouseEventArgs) void {
        const p = m.pos();
        if (self.box.inside(p[0], p[1])) self.clicks += 1;
    }

    pub fn windowResized(_: *App, size: of.ResizeEventArgs) void {
        std.debug.print("resized to {d}x{d}\n", .{ size.width, size.height });
    }
};

pub fn main() u8 {
    var app: App = .{};
    return @intCast(of.run(App, &app, .{ .width = 900, .height = 600 }));
}
