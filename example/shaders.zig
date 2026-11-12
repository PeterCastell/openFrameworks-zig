//! Two GLSL programs, compiled from source in this file. A fragment shader
//! paints the background a slow gradient of rings around the mouse; a
//! vertex shader ripples a sphere along its normals, and its fragment
//! shader lights it from the camera. Drag to orbit; the mouse's x sets the
//! ripple's height. `r` resets the camera, `p` prints the sphere program's
//! uniforms, `f` is fullscreen.
//!
//! `of.run` opens an OpenGL 2.1 context, so both programs are GLSL 1.20 and
//! read oF's geometry through the compatibility built-ins.
const std = @import("std");
const of = @import("of");

const background_vert =
    \\#version 120
    \\void main() {
    \\    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    \\}
;
const background_frag =
    \\#version 120
    \\uniform vec2 resolution;
    \\uniform vec2 mouse;
    \\uniform float time;
    \\uniform vec4 colors[2];
    \\void main() {
    \\    vec2 p = gl_FragCoord.xy / resolution.y;
    \\    vec2 m = vec2(mouse.x, resolution.y - mouse.y) / resolution.y;
    \\    float rings = 0.5 + 0.5 * sin(distance(p, m) * 40.0 - time * 3.0);
    \\    gl_FragColor = mix(colors[0], colors[1], rings * gl_FragCoord.y / resolution.y);
    \\}
;

const ripple_vert =
    \\#version 120
    \\uniform float time;
    \\uniform float amplitude;
    \\varying vec3 normal;
    \\void main() {
    \\    float wave = sin(gl_Vertex.y * 0.08 + time * 4.0) * sin(gl_Vertex.x * 0.05 + time * 2.0);
    \\    vec4 p = gl_Vertex + vec4(gl_Normal * wave * amplitude, 0.0);
    \\    normal = gl_NormalMatrix * gl_Normal;
    \\    gl_Position = gl_ModelViewProjectionMatrix * p;
    \\}
;
const ripple_frag =
    \\#version 120
    \\uniform vec4 tint;
    \\varying vec3 normal;
    \\void main() {
    \\    float facing = max(dot(normalize(normal), vec3(0.0, 0.0, 1.0)), 0.0);
    \\    gl_FragColor = vec4(tint.rgb * (0.25 + 0.75 * facing), tint.a);
    \\}
;

const App = struct {
    cam: of.EasyCam = undefined,
    sphere: of.SpherePrimitive = undefined,
    background: of.Shader = undefined,
    ripple: of.Shader = undefined,

    pub fn setup(self: *App) void {
        of.setWindowTitle("Shaders");
        of.setFrameRate(60);

        self.cam.init();
        self.sphere.init();
        self.sphere.setRadius(150);
        self.sphere.setResolution(64);

        self.background.init();
        build(&self.background, background_vert, background_frag);
        self.ripple.init();
        build(&self.ripple, ripple_vert, ripple_frag);

        std.debug.print("shaders: background program {d}, ripple program {d}, ripple vertex stage {d}, amplitude at location {d}\n", .{
            self.background.getProgram(),
            self.ripple.getProgram(),
            self.ripple.getShader(.vertex),
            self.ripple.getUniformLocation("amplitude"),
        });
    }

    /// Compiles both stages and links them, saying which step failed.
    fn build(shader: *of.Shader, vert: []const u8, frag: []const u8) void {
        if (!shader.setupShaderFromSource(.vertex, vert)) std.debug.print("vertex stage did not compile\n", .{});
        if (!shader.setupShaderFromSource(.fragment, frag)) std.debug.print("fragment stage did not compile\n", .{});
        if (!shader.linkProgram()) std.debug.print("program did not link\n", .{});
    }

    pub fn draw(self: *App) void {
        const t = of.getElapsedTime();
        const w: f32 = @floatFromInt(of.getWidth());
        const h: f32 = @floatFromInt(of.getHeight());

        of.disableDepthTest();
        self.background.begin();
        self.background.setUniform2f("resolution", .{ w, h });
        self.background.setUniform2f("mouse", .{ @floatFromInt(of.getMouseX()), @floatFromInt(of.getMouseY()) });
        self.background.setUniform1f("time", t);
        self.background.setUniform4fv("colors", &.{
            .{ .x = 0.08, .y = 0.08, .z = 0.14, .w = 1 },
            .{ .x = 0.35, .y = 0.2, .z = 0.45, .w = 1 },
        });
        of.drawRectangle(0, 0, w, h);
        self.background.end();

        of.enableDepthTest();
        self.cam.begin();
        defer self.cam.end();
        self.ripple.begin();
        defer self.ripple.end();
        self.ripple.setUniform1f("time", t);
        self.ripple.setUniform1f("amplitude", of.map(@floatFromInt(of.getMouseX()), 0, w, 0, 40, true));
        self.ripple.setUniformColor("tint", of.FloatColor.fromHsb(@mod(t * 0.05, 1), 0.6, 1, 1));
        self.sphere.draw();
    }

    pub fn keyPressed(self: *App, k: of.KeyEventArgs) void {
        switch (k.key) {
            'f' => of.toggleFullscreen(),
            'r' => self.cam.reset(),
            'p' => self.ripple.printActiveUniforms(),
            else => {},
        }
    }

    pub fn exit(self: *App) void {
        self.ripple.deinit();
        self.background.deinit();
        self.sphere.deinit();
        self.cam.deinit();
    }
};

pub fn main() u8 {
    var app: App = .{};
    return @intCast(of.run(App, &app, .{ .width = 1024, .height = 768 }));
}
