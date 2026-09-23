//! The classic first oF sketch, in Zig: a circle that follows the mouse,
//! a rectangle you can click, and some text. Press `f` for fullscreen.
const std = @import("std");
const of = @import("of");

const App = struct {
    clicks: u32 = 0,
    box: of.Rectangle = .{ .position = .{ 40, 80 }, .size = .{ 220, 120 } },
    /// C++ constructs this in place in `setup` and destroys it in `exit`.
    /// It cannot be copied, so it lives here and is never passed by value.
    font: of.Font = undefined,
    /// A second face, loaded the long way round: `FontSettings` is what
    /// reaches the Unicode ranges, the face index and the direction.
    hud: of.Font = undefined,

    pub fn setup(self: *App) void {
        of.setWindowTitle("openFrameworks-zig");
        of.setFrameRate(60);
        of.setCircleResolution(64);
        of.background(of.Color.rgb(24, 24, 32));

        // `sans` is not a file: oF resolves it against the installed fonts,
        // which is Arial here. `contours` is what `drawStringAsShapes` needs.
        of.Font.setGlobalDpi(96);
        self.font.init();
        if (!self.font.load(of.font.sans, 18, .{ .contours = true })) {
            std.debug.print("setup: no font, falling back to the bitmap one\n", .{});
        }

        // The same load through the settings, which is the only way to say
        // which blocks to cache: ASCII and its accented Latin, nothing else.
        self.hud.init();
        var s: of.FontSettings = undefined;
        if (s.init(of.font.mono, 12)) {
            defer s.deinit();
            s.antialiased = false;
            s.direction = .left_to_right;
            s.addRange(of.font.unicode.space);
            s.addRanges(of.font.alphabet.latin);
            if (self.hud.loadSettings(&s)) {
                std.debug.print("setup: hud caches {d} latin glyphs\n", .{of.font.unicode.latin.glyphCount()});
            } else {
                std.debug.print("setup: no hud face\n", .{});
            }
        }

        std.debug.print("setup: window {d}x{d}, box area {d:.0}\n", .{ of.getWidth(), of.getHeight(), self.box.getArea() });
    }

    pub fn update(_: *App) void {}

    pub fn draw(self: *App) void {
        const t = of.getElapsedTime();

        // `Vec2` is `@Vector(2, f32)`, so the arithmetic below is Zig's own.
        const mouse: of.Vec2 = @floatFromInt(of.getMousePos());

        // A box that changes shade while the mouse is over it.
        of.setColor(if (self.box.inside(mouse)) of.Color.rgb(255, 180, 40) else of.Color.rgb(90, 90, 120));
        self.box.draw();

        // A circle that follows the mouse and pulses.
        const r = 30 + 10 * @sin(t * 3);
        of.setColor(of.Color.rgba(80, 200, 255, 200));
        of.drawCirclev(mouse, r);

        // A leader from the box to the circle's edge: subtract, normalize,
        // scale, and hand the result straight to the wrapper, which is the
        // only place a `glm::vec2` exists.
        const from = self.box.getCenter();
        const gap = mouse - from;
        if (of.length(gap) > r) {
            of.setColor(of.Color.rgba(255, 255, 255, 90));
            of.setLineWidth(1);
            of.drawLinev(from, mouse - of.normalize(gap) * @as(of.Vec2, @splat(r)));
        }

        // A spinning line around the circle.
        of.pushMatrix();
        of.translatev(.{ mouse[0], mouse[1], 0 });
        of.rotate(t * (std.math.pi / 2.0)); // a quarter turn a second
        of.setColor(of.Color.grey(255));
        of.setLineWidth(2);
        of.drawLine(-60, 0, 60, 0);
        of.popMatrix();

        var buf: [128]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "fps {d:.1}  frame {d}  clicks {d}  ({d}x{d})", .{
            of.getFrameRate(), of.getFrameNum(), self.clicks, of.getWidth(), of.getHeight(),
        }) catch "?";

        if (!self.font.isLoaded()) {
            // The 8x13 face oF has built in, which needs no file at all.
            of.setColor(of.Color.grey(220));
            of.drawBitmapString(text, 20, 30);
            return;
        }

        const line = self.font.getLineHeight();
        const base = 20 + line;

        // `getStringBoundingBox` measures what `drawString` would cover, so
        // the plate behind the text fits it.
        var plate = self.font.getStringBoundingBox(text, 20, base);
        plate.position -= @as(of.Vec2, @splat(6));
        plate.size += @as(of.Vec2, @splat(12));
        of.setColor(of.Color.rgba(0, 0, 0, 140));
        plate.draw();

        of.setColor(of.Color.grey(220));
        self.font.drawString(text, 20, base);

        const hint = "move the mouse, click the box, f for fullscreen, esc to quit";
        const hud = if (self.hud.isLoaded()) &self.hud else &self.font;
        hud.drawStringv(hint, .{ 20, base + line });

        // The same face as outlines rather than as its texture atlas, which
        // is what `noFill` and `setLineWidth` reach.
        of.noFill();
        of.setLineWidth(1);
        of.setColor(of.Color.rgba(255, 180, 40, 200));
        self.font.drawStringAsShapes("openFrameworks", 20, base + 3 * line);
        of.fill();

        // A caption above the cursor, centred on it by its own width.
        const caption = "drag me";
        const cx = of.getMouseX() - @as(i32, @intFromFloat(self.font.stringWidth(caption) / 2));
        const cy = of.getMouseY() - @as(i32, @intFromFloat(r + self.font.stringHeight(caption)));
        const label = self.font.getStringBoundingBoxi(caption, cx, cy);
        of.setColor(of.Color.rgba(0, 0, 0, 140));
        label.draw();
        of.setColor(of.Color.grey(255));
        self.font.drawStringAsShapesi(caption, cx, cy);
    }

    pub fn keyPressed(_: *App, k: of.KeyEventArgs) void {
        if (k.key == 'f') of.toggleFullscreen();
    }

    pub fn mousePressed(self: *App, m: of.MouseEventArgs) void {
        const p = m.pos();
        if (self.box.inside(p)) self.clicks += 1;
    }

    pub fn windowResized(_: *App, size: of.ResizeEventArgs) void {
        std.debug.print("resized to {d}x{d}\n", .{ size.width, size.height });
    }

    /// oF calls this once, as the main loop ends.
    pub fn exit(self: *App) void {
        self.hud.deinit();
        self.font.deinit();
    }
};

pub fn main() u8 {
    var app: App = .{};
    return @intCast(of.run(App, &app, .{ .width = 900, .height = 600 }));
}
