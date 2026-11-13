//! The vtable layouts the bindings claim, and Zig subclasses built on them.
//!
//! Every class with a `cpp_virtuals` list is checked against the vtables the
//! C++ compiler emitted (`cpp.verifyVtable`): each method slot must hold the
//! definition the computed layout says. That check cannot see an entry
//! missing from the very end of a table, so the layouts are also compared
//! with clang's `-fdump-vtable-layouts` for oF 0.12.1, read from a
//! translation unit that constructs one of each: slot for slot for the
//! classes with one table, by length for `ofBaseApp`'s two.
//!
//! The dumps differ by ABI, and so do the expectations. MSVC gives a class
//! one destructor slot and reverses each group of overloads; Itanium (macOS)
//! gives it two, complete then deleting, and keeps the header's order.
const std = @import("std");
const builtin = @import("builtin");
const cpp = @import("cpp_bindgen");
const of = @import("of");
/// Which addons the build has, for the tests that need one.
const options = @import("of_options");

const msvc = builtin.target.abi == .msvc;

const Node = of.Node;
const Camera = of.Camera;
const EasyCam = of.EasyCam;
const Light = of.Light;
const Primitive = of.primitives.Primitive;
const BoxPrimitive = of.primitives.BoxPrimitive;

// computed layouts, against clang's

const Want = struct { kind: cpp.vtable.SlotKind, name: []const u8, args: usize, owner: type };

/// The destructor's slots: MSVC's one deleting destructor, or Itanium's
/// complete destructor and deleting destructor.
fn d(comptime owner: type) []const Want {
    const deleting: Want = .{ .kind = .dtor_deleting, .name = "~", .args = 0, .owner = owner };
    if (msvc) return &.{deleting};
    return &.{ .{ .kind = .dtor_complete, .name = "~", .args = 0, .owner = owner }, deleting };
}
fn m(comptime name: []const u8, comptime args: usize, comptime owner: type) Want {
    return .{ .kind = .method, .name = name, .args = args, .owner = owner };
}

/// Two overloads as the header declares them, in their slot order: MSVC
/// reverses a group of overloads, Itanium keeps it.
fn overloads(comptime first: Want, comptime second: Want) []const Want {
    return if (msvc) &.{ second, first } else &.{ first, second };
}

fn expectLayout(comptime T: type, comptime want: []const Want) !void {
    const tables = comptime cpp.vtable.tables(T);
    try std.testing.expectEqual(1, tables.len);
    const slots = tables[0].slots;
    try std.testing.expectEqual(want.len, slots.len);
    inline for (want, slots, 0..) |w, s, i| {
        errdefer std.debug.print("{s}: slot {d}\n", .{ @typeName(T), i });
        try std.testing.expectEqual(w.kind, s.kind);
        try std.testing.expectEqualStrings(w.name, s.sig.name);
        try std.testing.expectEqual(w.args, s.sig.args.len);
        try std.testing.expectEqual(w.owner, s.owner);
    }
}

/// `ofNode`'s slots. The header declares `customDraw(renderer)` before
/// `customDraw()`.
fn nodeSlots(comptime dtor: type, comptime draw_r: type, comptime draw: type, comptime pos: type, comptime ori: type) []const Want {
    return d(dtor) ++ overloads(m("customDraw", 1, draw_r), m("customDraw", 0, Node)) ++ &[_]Want{
        m("draw", 0, draw),
        m("onPositionChanged", 0, pos),
        m("onOrientationChanged", 0, ori),
        m("onScaleChanged", 0, Node),
    };
}

test "node layouts match clang's" {
    try expectLayout(Node, nodeSlots(Node, Node, Node, Node, Node));
    try expectLayout(Primitive, nodeSlots(Primitive, Node, Primitive, Node, Node));
    try expectLayout(BoxPrimitive, nodeSlots(BoxPrimitive, Node, Primitive, Node, Node));
    try expectLayout(Light, nodeSlots(Light, Light, Node, Light, Light));
    // The header declares `begin()` before `begin(viewport)`.
    try expectLayout(Camera, nodeSlots(Camera, Node, Node, Node, Node) ++
        overloads(m("begin", 0, Camera), m("begin", 1, Camera)) ++ &[_]Want{m("end", 0, Camera)});
    try expectLayout(EasyCam, nodeSlots(EasyCam, Node, Node, EasyCam, Node) ++
        overloads(m("begin", 0, EasyCam), m("begin", 1, EasyCam)) ++ &[_]Want{m("end", 0, Camera)});
}

/// The material interface, in header order: no virtual function of either
/// class is overloaded, so MSVC keeps the order. `T` defines the getters
/// through `updateEnvironmentMaps`; `isBound`, `bind` and `unbind` follow.
fn materialSlots(comptime T: type, comptime unbind: type) []const Want {
    return d(T) ++ &[_]Want{
        m("getDiffuseColor", 0, T),
        m("getAmbientColor", 0, T),
        m("getSpecularColor", 0, T),
        m("getEmissiveColor", 0, T),
        m("getShininess", 0, T),
        m("begin", 0, T),
        m("end", 0, T),
        m("hasDepthShader", 0, T),
        m("getShadowDepthShader", 2, T),
        m("getShader", 3, T),
        m("setCustomShader", 1, T),
        m("uploadMatrices", 2, T),
        m("updateMaterial", 2, T),
        m("updateLights", 2, T),
        m("updateShadows", 2, T),
        m("updateEnvironmentMaps", 2, T),
        m("isBound", 0, of.material.BaseMaterial),
        m("bind", 1, of.material.BaseMaterial),
        m("unbind", 1, unbind),
    };
}

test "ofBaseApp's two tables have clang's lengths" {
    // MSVC: 48 and 6 entries in clang's dump, each counting the RTTI word.
    // Itanium: 50 and 8, each counting `offset_to_top` and the RTTI word,
    // with the extra destructor slot in both.
    const tables = comptime cpp.vtable.tables(of.BaseApp);
    try std.testing.expectEqual(2, tables.len);
    try std.testing.expectEqual(if (msvc) 47 else 48, tables[0].slots.len);
    try std.testing.expectEqual(if (msvc) 5 else 6, tables[1].slots.len);
    try std.testing.expectEqual(8, tables[1].offset);
}

test "mesh, material, font and rectangle layouts match clang's" {
    const Mesh = of.Mesh;
    try expectLayout(Mesh, d(Mesh) ++ &[_]Want{
        m("enableNormals", 0, Mesh),
        m("disableNormals", 0, Mesh),
        m("usingNormals", 0, Mesh),
        m("enableColors", 0, Mesh),
        m("disableColors", 0, Mesh),
        m("usingColors", 0, Mesh),
        m("enableTextures", 0, Mesh),
        m("disableTextures", 0, Mesh),
        m("usingTextures", 0, Mesh),
        m("enableIndices", 0, Mesh),
        m("disableIndices", 0, Mesh),
        m("usingIndices", 0, Mesh),
        m("draw", 1, Mesh),
    });
    const BaseMaterial = of.material.BaseMaterial;
    try expectLayout(BaseMaterial, materialSlots(BaseMaterial, BaseMaterial));
    try expectLayout(of.Material, materialSlots(of.Material, of.Material));
    try expectLayout(of.Font, d(of.Font));
    try expectLayout(of.OfRectangle, d(of.OfRectangle));
}

/// A group of overloads as the header declares them, in their slot order:
/// MSVC reverses the whole group, Itanium keeps it.
fn group(comptime ws: []const Want) []const Want {
    if (!msvc) return ws;
    return comptime blk: {
        var r: [ws.len]Want = undefined;
        for (ws, 0..) |w, i| r[ws.len - 1 - i] = w;
        const out = r;
        break :blk &out;
    };
}

test "texture layouts match clang's" {
    const BaseDraws = of.BaseDraws;
    const Texture = of.Texture;
    // `ofBaseDraws` declares five `draw`s, the two `ofTexture` overrides
    // first; then the size and anchor functions, most overridden.
    const tail = comptime &[_]Want{
        m("getHeight", 0, Texture),
        m("getWidth", 0, Texture),
        m("getSize", 0, BaseDraws),
        m("setAnchorPercent", 2, Texture),
        m("setAnchorPoint", 2, Texture),
        m("resetAnchor", 0, Texture),
    };
    const draws = comptime group(&.{
        m("draw", 2, Texture),
        m("draw", 4, Texture),
        m("draw", 1, BaseDraws),
        m("draw", 1, BaseDraws),
        m("draw", 3, BaseDraws),
    });
    // `ofTexture`'s twelve `allocate` overloads, a new group of its own.
    const allocates = comptime group(&.{
        m("allocate", 1, Texture), m("allocate", 3, Texture),
        m("allocate", 3, Texture), m("allocate", 5, Texture),
        m("allocate", 4, Texture), m("allocate", 6, Texture),
        m("allocate", 1, Texture), m("allocate", 2, Texture),
        m("allocate", 1, Texture), m("allocate", 2, Texture),
        m("allocate", 1, Texture), m("allocate", 2, Texture),
    });
    try expectLayout(Texture, d(Texture) ++ draws ++ tail ++ allocates);
}

// the new value types, which need no window

test "buffer, path and texture handles" {
    var buf = of.Buffer.init("v 0 0 0\n");
    defer buf.deinit();
    try std.testing.expectEqualStrings("v 0 0 0\n", buf.slice());
    var empty = of.Buffer.initEmpty();
    defer empty.deinit();
    try std.testing.expectEqual(0, empty.len());

    var p = of.string.Path.init("models/teapot.obj").?;
    defer p.deinit();
    var s = p.toString();
    defer s.deinit();
    try std.testing.expectEqualStrings("models/teapot.obj", s.slice());

    // No GL texture until `allocate`, which needs a window.
    var tex: of.Texture = undefined;
    tex.init();
    defer tex.deinit();
    try std.testing.expect(!tex.isAllocated());
    try std.testing.expectEqual(0, tex.getWidth());
    try std.testing.expectEqual(0, tex.baseDraws().getWidth()); // the same call, through ofBaseDraws's vtable
}

test "assimp: a loader with no model" {
    if (!options.assimp) return error.SkipZigTest;
    const assimp = of.assimp;

    var model: assimp.ModelLoader = undefined;
    model.init();
    defer model.deinit();
    try std.testing.expect(!model.hasMeshes());
    try std.testing.expect(!model.hasAnimations());
    try std.testing.expectEqual(0, model.getMeshCount());
    try std.testing.expectEqual(null, model.getMeshHelper(0));
    try std.testing.expectEqual(null, model.getAnimation(0));
    try std.testing.expectEqual(null, model.getAssimpScene());
    var names = model.getMeshNames();
    defer names.deinit();
    try std.testing.expectEqual(0, names.items().len);

    // The transform is plain data until a draw uses it.
    model.setPosition(.{ 1, 2, 3 });
    try std.testing.expectEqual(of.Vec3{ 1, 2, 3 }, model.getPosition());
    model.setScale(.{ 2, 2, 2 });
    try std.testing.expectEqual(of.Vec3{ 2, 2, 2 }, model.getScale());
    // Radians in, radians out; the addon stores degrees between.
    model.setRotation(1, std.math.pi / 2.0, .{ 0, 1, 0 });
    try std.testing.expectEqual(2, model.getNumRotations());
    try std.testing.expectApproxEqAbs(std.math.pi / 2.0, model.getRotationAngle(1), 1e-6);
    try std.testing.expectEqual(of.Vec3{ 0, 1, 0 }, model.getRotationAxis(1));
    try std.testing.expectEqual(0, model.getRotationAngle(0));

    // A texture of a model's own, as `MeshHelper.addTexture` takes.
    var t: assimp.AssimpTexture = undefined;
    t.init();
    defer t.deinit();
    try std.testing.expect(!t.hasTexture());
    t.setTextureType(.normals);
    try std.testing.expectEqual(assimp.TextureType.normals, t.getTextureType());
    try std.testing.expect(!t.getTextureRef().isAllocated());

    try std.testing.expectEqual(@as(i32, 0x800008), @intFromEnum(assimp.LoadFlags.steps(.{ .triangulate = true, .flip_uvs = true })));
}

// layouts against the real vtables

test "the vtables match every cpp_virtuals" {
    inline for (.{
        of.app.BaseSoundInput, of.app.BaseSoundOutput,   of.BaseApp,
        Node,                  Camera,                   EasyCam,
        Light,                 Primitive,                BoxPrimitive,
        of.Mesh,               of.material.BaseMaterial, of.Material,
        of.Font,               of.OfRectangle,           of.BaseDraws,
        of.Texture,
    }) |T| {
        errdefer std.debug.print("{s}\n", .{@typeName(T)});
        try cpp.verifyVtable(T);
    }
}

// subclassing ofNode: protected virtual functions overridden from Zig

const Tracker = struct {
    cpp: of.Subclass(Node, Tracker, "cpp"),
    moves: std.ArrayList(of.Vec3) = .empty,
    scaled: u32 = 0,

    pub const cpp_overrides = .{
        .{ Node.onPositionChanged_sig, positionChanged },
        .{ Node.onScaleChanged_sig, scaleChanged },
    };

    fn positionChanged(self: *Tracker) void {
        self.moves.append(std.testing.allocator, self.cpp.base.getPosition()) catch @panic("oom");
    }

    fn scaleChanged(self: *Tracker) void {
        self.scaled += 1;
        // "super": ofNode's own protected onScaleChanged, by its mangled name.
        of.bind(Node.onScaleChanged_sig)(&self.cpp.base);
    }

    pub fn cpp_destroy(self: *Tracker) void {
        self.moves.deinit(std.testing.allocator);
    }
};

test "a Zig ofNode: the setters reach its protected overrides" {
    var t: Tracker = .{ .cpp = undefined };
    try t.cpp.initChecked();
    defer t.cpp.deinit();

    // ofNode::setPosition calls onPositionChanged() virtually, after the
    // position is stored.
    t.cpp.base.setPosition(.{ 1, 2, 3 });
    t.cpp.base.setPosition(.{ 4, 5, 6 });
    try std.testing.expectEqual(2, t.moves.items.len);
    try std.testing.expectEqual(of.Vec3{ 4, 5, 6 }, t.moves.items[1]);

    t.cpp.base.setScaleUniform(2);
    try std.testing.expectEqual(1, t.scaled);
}

// subclassing ofBaseApp, as `of.run` does

const TestApp = struct {
    cpp: of.Subclass(of.BaseApp, TestApp, "cpp"),
    setups: u32 = 0,
    keys: std.ArrayList(i32) = .empty,
    destroyed: *bool,

    pub const cpp_overrides = .{
        .{ of.BaseApp.setup_sig, setup },
        .{ of.BaseApp.keyPressed_sig, keyPressed },
    };

    fn setup(self: *TestApp) void {
        self.setups += 1;
    }

    fn keyPressed(self: *TestApp, args: *of.KeyEventArgs) void {
        self.keys.append(std.testing.allocator, args.key) catch @panic("oom");
        // "super": ofBaseApp's own keyPressed(ofKeyEventArgs&), which calls
        // the plain keyPressed(int) virtually; that one is not overridden.
        of.bind(of.BaseApp.keyPressed_sig)(&self.cpp.base, args);
    }

    pub fn cpp_destroy(self: *TestApp) void {
        self.keys.deinit(std.testing.allocator);
        self.destroyed.* = true;
    }
};

test "a Zig ofBaseApp: C++ reaches its overrides" {
    var destroyed = false;
    {
        var app: TestApp = .{ .cpp = undefined, .destroyed = &destroyed };
        try app.cpp.initChecked();
        defer app.cpp.deinit();

        // What oF's setup event does: ofBaseApp::setup(ofEventArgs&), whose
        // definition calls setup() virtually, and so reaches the override.
        var args: u8 = 0;
        of.bind(of.BaseApp.setup_args_sig)(&app.cpp.base, @ptrCast(&args));
        try std.testing.expectEqual(1, app.setups);

        // A virtual call from Zig, through the first vtable.
        var key = std.mem.zeroes(of.KeyEventArgs);
        key.key = 'a';
        of.bindVirtual(of.BaseApp.keyPressed_sig)(&app.cpp.base, &key);
        try std.testing.expectEqualSlices(i32, &.{'a'}, app.keys.items);
        try std.testing.expectEqual(0, app.cpp.base.mouseX);
    }
    // `deinit` ran `cpp_destroy` (the list was freed, or the allocator would
    // report a leak) and then ~ofBaseApp().
    try std.testing.expect(destroyed);
}

// subclassing ofMaterial: an override that returns a class by value

const Pulse = struct {
    cpp: of.Subclass(of.Material, Pulse, "cpp"),
    level: f32 = 0.5,

    pub const cpp_overrides = .{.{ of.Material.getDiffuseColor_sig, diffuse }};

    /// MSVC returns the color through a hidden pointer, which the adapter
    /// fills from this return value; Itanium returns it in registers.
    fn diffuse(self: *const Pulse) of.FloatColor {
        return of.FloatColor.rgb(self.level, 0, 1 - self.level);
    }
};

test "a Zig ofMaterial: a virtual call reaches an override returning a color" {
    var p: Pulse = .{ .cpp = undefined };
    try p.cpp.initChecked();
    defer p.cpp.deinit();

    p.level = 0.25;
    const c = p.cpp.base.getDiffuseColor(); // a virtual call, through the vtable
    try std.testing.expectEqual(0.25, c.r);
    try std.testing.expectEqual(0.75, c.b);
    // A slot it does not override still holds ofMaterial's own definition.
    p.cpp.base.setShininess(42);
    try std.testing.expectEqual(42, p.cpp.base.getShininess());
}
