//! ofxAssimpModelLoader, the addon every oF release ships for loading 3D
//! models -- `.obj`, `.dae`, `.fbx`, `.gltf`/`.glb`, `.3ds`, `.ply`,
//! `.stl` and the rest of what assimp reads -- with their materials,
//! textures and skeletal animations.
//!
//! ```zig
//! model: of.assimp.ModelLoader,        // a field of the app struct
//!
//! // setup
//! self.model.init();                   // deinit in exit
//! if (!self.model.load("astroBoy_walk.dae", .optimize_default)) return;
//! self.model.setRotation(0, std.math.pi, .{ 0, 0, 1 }); // most files are y-up
//! self.model.playAllAnimations();
//!
//! // update
//! self.model.update();                 // advances the animations
//!
//! // draw, with depth testing on
//! self.model.drawFaces();
//! ```
//!
//! A relative file name resolves against `bin/data`, as every oF loader
//! does. The model is scaled to fit the window unless
//! `setScaleNormalization(false)`; it is drawn with its own transform
//! (`setPosition`, `setScale`, `setRotation`) applied on top of the
//! current matrix.
//!
//! The four classes here are the addon's public API. `ModelLoader` is the
//! one a sketch uses; it owns the `Animation`s and `MeshHelper`s it hands
//! out, which live until the next `load` or `clear`. The deprecated calls
//! (`loadModel`, the `bool optimize` overloads of `load`, and
//! `setAnimation`/`setTime`/`setNormalizedTime`/`getDuration`) are not
//! bound; `load` and `Animation` replace them.
//!
//! Angles are radians, as everywhere in this package: `setRotation` and
//! `getRotationAngle` convert to and from the degrees the addon stores.
const std = @import("std");
const cpp = @import("cpp_bindgen");
/// The MSVC ABI and STL (Windows), or else Itanium with libc++ (macOS):
/// the opaque storage sizes below differ between them.
const msvc = @import("builtin").target.abi == .msvc;
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const math = @import("math.zig");
const matrix = @import("matrix.zig");
const string = @import("string.zig");
const graphics = @import("graphics.zig");
const mesh_zig = @import("mesh.zig");
const Material = @import("material.zig").Material;
const Texture = @import("texture.zig").Texture;
const Buffer = @import("buffer.zig").Buffer;
const PolyRenderMode = @import("primitives.zig").PolyRenderMode;

const Vec3 = math.Vec3;
const GlmVec3 = math.GlmVec3;
const Mat4 = matrix.Mat4;
const String = string.String;
const StringVector = string.StringVector;
const Path = string.Path;
const Mesh = mesh_zig.Mesh;
const BlendMode = graphics.BlendMode;
const LoopType = graphics.LoopType;

/// `cpp.bind` with a larger comptime budget, as in `mesh.zig`: the mangled
/// names that carry `ofMesh_`'s four template arguments, or a vector of
/// shared pointers, are past what the default quota computes.
inline fn bind(comptime sig: Signature) Bound(sig) {
    @setEvalBranchQuota(1 << 16);
    return cpp.bind(sig);
}
fn Bound(comptime sig: Signature) type {
    @setEvalBranchQuota(1 << 16);
    return *const cpp.FnType(cpp.default_mangling, sig);
}

// assimp's own types: the scene graph the addon reads its meshes and
// animations from. They are plain C structs from assimp's headers; this
// package passes them through as pointers for code that wants to read the
// raw scene, and reads none of them itself.

/// `aiScene`: the whole imported file.
pub const AiScene = opaque {
    pub const cpp_name = "aiScene";
    pub const cpp_kind: cpp.Kind = .@"struct";
};
/// `aiMesh`: one mesh of the scene, before the addon converts it.
pub const AiMesh = opaque {
    pub const cpp_name = "aiMesh";
    pub const cpp_kind: cpp.Kind = .@"struct";
};
/// `aiAnimation`: one animation's channels and keyframes.
pub const AiAnimation = opaque {
    pub const cpp_name = "aiAnimation";
    pub const cpp_kind: cpp.Kind = .@"struct";
};

/// `aiVector3D`, which is `aiVector3t<float>`: assimp's three floats, as
/// `MeshHelper` keeps the animated positions and normals.
pub const AiVector3D = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub const cpp_template: cpp.Template = .{ .name = "aiVector3t", .args = &.{.{ .type = f32 }}, .kind = .class };
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;
    /// assimp defines the members; only the layout is needed here.
    pub const cpp_no_instantiate = true;

    pub fn to(v: AiVector3D) Vec3 {
        return .{ v.x, v.y, v.z };
    }
};

/// `aiTextureType`: the role a texture plays in a material. A C enum, so an
/// `int` underneath; the addon keeps the diffuse one apart and the others in
/// `MeshHelper.getAllMeshTextures`.
pub const TextureType = enum(i32) {
    none = 0,
    diffuse = 1,
    specular = 2,
    ambient = 3,
    emissive = 4,
    height = 5,
    normals = 6,
    shininess = 7,
    opacity = 8,
    displacement = 9,
    lightmap = 10,
    reflection = 11,
    base_color = 12,
    normal_camera = 13,
    emission_color = 14,
    metalness = 15,
    diffuse_roughness = 16,
    ambient_occlusion = 17,
    unknown = 18,
    sheen = 19,
    clearcoat = 20,
    transmission = 21,
    maya_base = 22,
    maya_specular = 23,
    maya_specular_color = 24,
    maya_specular_roughness = 25,
    _,

    pub const cpp_name = "aiTextureType";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

/// `aiPostProcessSteps`: the processing assimp applies to a scene as it
/// loads it, one bit each, as `postprocess.h` documents them. Pass a set to
/// `load` through `LoadFlags.steps`.
pub const PostProcess = packed struct(u32) {
    calc_tangent_space: bool = false,
    join_identical_vertices: bool = false,
    make_left_handed: bool = false,
    triangulate: bool = false,
    remove_component: bool = false,
    gen_normals: bool = false,
    gen_smooth_normals: bool = false,
    split_large_meshes: bool = false,
    pre_transform_vertices: bool = false,
    limit_bone_weights: bool = false,
    validate_data_structure: bool = false,
    improve_cache_locality: bool = false,
    remove_redundant_materials: bool = false,
    fix_infacing_normals: bool = false,
    populate_armature_data: bool = false,
    sort_by_p_type: bool = false,
    find_degenerates: bool = false,
    find_invalid_data: bool = false,
    gen_uv_coords: bool = false,
    transform_uv_coords: bool = false,
    find_instances: bool = false,
    optimize_meshes: bool = false,
    optimize_graph: bool = false,
    flip_uvs: bool = false,
    flip_winding_order: bool = false,
    split_by_bone_count: bool = false,
    debone: bool = false,
    global_scale: bool = false,
    embed_textures: bool = false,
    force_gen_normals: bool = false,
    drop_normals: bool = false,
    gen_bounding_boxes: bool = false,

    /// `aiProcess_ConvertToLeftHanded`, which the presets add and which a
    /// set of your own usually wants too: oF's texture coordinates and
    /// winding, rather than assimp's.
    pub const convert_to_left_handed: PostProcess = .{ .make_left_handed = true, .flip_uvs = true, .flip_winding_order = true };

    /// The union of two sets.
    pub fn with(a: PostProcess, b: PostProcess) PostProcess {
        return @bitCast(@as(u32, @bitCast(a)) | @as(u32, @bitCast(b)));
    }
};

/// What `load` does to the scene: one of the addon's three presets
/// (`ofxAssimpModelLoader::Flags`), or exactly the assimp steps given.
///
/// - `optimize_none`: nothing but `convert_to_left_handed`.
/// - `optimize_default`: triangulated, smooth normals and tangents, shared
///   vertices joined, degenerate faces and duplicate materials removed,
///   large meshes split and small ones merged. What oF's examples use.
/// - `optimize_high`: the default, plus `optimize_graph` (the node
///   hierarchy collapsed where it can be) and validation.
/// - `.steps(set)`: the set as given, with nothing added. Leave
///   `gen_bounding_boxes` out: it is the sign bit of the `int` the addon
///   takes, which sends the set down the presets' path, and that adds
///   `convert_to_left_handed`.
pub const LoadFlags = enum(i32) {
    optimize_none = -3,
    optimize_default = -2,
    optimize_high = -1,
    _,

    pub fn steps(set: PostProcess) LoadFlags {
        return @enumFromInt(@as(i32, @bitCast(set)));
    }
};

/// `enableCulling`'s argument, the `GLenum` that oF passes to
/// `glFrontFace`: which winding faces the camera. Back faces are culled.
pub const FrontFace = enum(i32) {
    clockwise = 0x0900, // GL_CW
    counter_clockwise = 0x0901, // GL_CCW
};

pub const SharedPtr = @import("memory.zig").SharedPtr;

/// `ofxAssimpTexture`: one texture of a mesh's material, with the file it
/// came from and the role it plays.
///
/// The members are private; the binding gives the storage and the glue
/// checks the size. Every one a sketch sees belongs to a `MeshHelper`. One
/// of its own -- for `MeshHelper.addTexture` -- is `init`ed and `deinit`ed
/// like any other.
pub const AssimpTexture = extern struct {
    _storage: [if (msvc) 256 else 240]u8 align(8),

    pub const cpp_name = "ofxAssimpTexture";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    /// The constructor and destructor are implicit, so header-only; the
    /// glue emits them.
    pub const ctor_sig: Signature = .{ .name = "*", .this = *AssimpTexture };
    /// No texture, no path, and type `none`.
    pub fn init(self: *AssimpTexture) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *AssimpTexture };
    pub fn deinit(self: *AssimpTexture) void {
        cpp.bind(dtor_sig)(self);
    }

    /// `setup(texture, path, bTexRepeat)`: shares `texture`'s GL texture
    /// (see `Texture`), records the file it came from, and sets the wrap to
    /// `GL_REPEAT`, or `GL_CLAMP_TO_EDGE` when `repeat` is false.
    pub const setup_sig: Signature = .{ .name = "setup", .this = *AssimpTexture, .args = &.{ Ref(*const Texture), Ref(*const Path), bool } };
    pub fn setup(self: *AssimpTexture, texture: *const Texture, path: []const u8, repeat: bool) bool {
        var p = Path.init(path) orelse return false;
        defer p.deinit();
        cpp.bind(setup_sig)(self, texture, &p, repeat);
        return true;
    }
    /// The texture itself, owned by this object.
    pub const getTextureRef_sig: Signature = .{ .name = "getTextureRef", .this = *AssimpTexture, .ret = Ref(*Texture) };
    pub fn getTextureRef(self: *AssimpTexture) *Texture {
        return cpp.bind(getTextureRef_sig)(self);
    }
    /// The file the texture was loaded from, as the model names it (or, for
    /// an embedded one, assimp's `*0`-style name). The caller owns the
    /// string and must `deinit` it.
    pub const getTexturePath_sig: Signature = .{ .name = "getTexturePath", .this = *AssimpTexture, .ret = Path };
    pub fn getTexturePath(self: *AssimpTexture) String {
        var p: Path = undefined;
        cpp.bind(getTexturePath_sig)(&p, self);
        defer p.deinit();
        return p.toString();
    }
    /// Whether the texture is allocated.
    pub const hasTexture_sig: Signature = .{ .name = "hasTexture", .this = *AssimpTexture, .ret = bool };
    pub fn hasTexture(self: *AssimpTexture) bool {
        return cpp.bind(hasTexture_sig)(self);
    }
    pub const setTextureType_sig: Signature = .{ .name = "setTextureType", .this = *AssimpTexture, .args = &.{TextureType} };
    pub fn setTextureType(self: *AssimpTexture, kind: TextureType) void {
        cpp.bind(setTextureType_sig)(self, kind);
    }
    pub const getTextureType_sig: Signature = .{ .name = "getTextureType", .this = *const AssimpTexture, .ret = TextureType };
    pub fn getTextureType(self: *const AssimpTexture) TextureType {
        return cpp.bind(getTextureType_sig)(self);
    }
    /// assimp's name for the type, `"DIFFUSE"` or `"NORMALS"`, say. The
    /// caller owns the string and must `deinit` it.
    pub const getTextureTypeAsString_sig: Signature = .{ .name = "getTextureTypeAsString", .this = *const AssimpTexture, .ret = String };
    pub fn getTextureTypeAsString(self: *const AssimpTexture) String {
        var s: String = undefined;
        cpp.bind(getTextureTypeAsString_sig)(&s, self);
        return s;
    }
};

/// The `std::shared_ptr<ofxAssimpTexture>` a mesh keeps for each texture.
pub const SharedAssimpTexture = SharedPtr(AssimpTexture);
/// `std::vector<std::shared_ptr<ofxAssimpTexture>>`.
pub const SharedAssimpTextureVector = mesh_zig.Vector(SharedAssimpTexture);
/// `std::vector<aiVector3D>`.
pub const AiVector3DVector = mesh_zig.Vector(AiVector3D);

/// `ofxAssimpMeshHelper`: one mesh of a loaded model, as the loader draws
/// it -- its VBO, material, textures and transform.
///
/// The public members are fields here, under their C++ names, and the
/// glue checks every offset; the VBO and the texture list are opaque.
/// Write `material`, `blendMode` or `twoSided` to change how `ModelLoader`
/// draws this mesh. A helper belongs to its `ModelLoader`; never `init` or
/// copy one.
pub const MeshHelper = extern struct {
    /// The assimp mesh this one was built from.
    mesh: ?*AiMesh,
    /// `ofVbo vbo`: the vertex buffer `ModelLoader` draws.
    _vbo: [if (msvc) 296 else 272]u8 align(8),
    /// The triangle indices, three per face.
    indices: mesh_zig.IndexVector,
    /// The material from the model file, applied while drawing unless
    /// `ModelLoader.disableMaterials`.
    material: Material,
    /// How the mesh blends; `.alpha` unless the material is additive.
    blendMode: BlendMode,
    /// Whether the material is two-sided, which exempts it from
    /// `enableCulling`.
    twoSided: bool,
    /// Set when an animation moved the vertices this frame.
    hasChanged: bool,
    /// The skinned positions and normals of the current animation frame.
    animatedPos: AiVector3DVector,
    animatedNorm: AiVector3DVector,
    /// The diffuse texture. Every other one is in `getAllMeshTextures`.
    assimpTexture: AssimpTexture,
    /// What `ModelLoader.getCurrentAnimatedMesh` rebuilds and copies;
    /// valid while `validCache`.
    cachedMesh: Mesh,
    validCache: bool,
    /// The mesh's transform within the model: its node's, and its parents'.
    matrix: Mat4,
    /// `std::vector<std::shared_ptr<ofxAssimpTexture>> meshTextures`,
    /// protected; `getAllMeshTextures` reaches it.
    _meshTextures: [3]usize,

    pub const cpp_name = "ofxAssimpMeshHelper";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    /// `addTexture(ofxAssimpTexture&)`: a diffuse texture replaces
    /// `assimpTexture`, unless the mesh already has one; any other type is
    /// copied into the list, and the material is told to use it.
    pub const addTexture_sig: Signature = .{ .name = "addTexture", .this = *MeshHelper, .args = &.{Ref(*AssimpTexture)} };
    pub fn addTexture(self: *MeshHelper, texture: *AssimpTexture) void {
        cpp.bind(addTexture_sig)(self, texture);
    }
    /// Whether the mesh has an allocated texture of the type.
    pub const hasTexture_sig: Signature = .{ .name = "hasTexture", .this = *MeshHelper, .args = &.{TextureType}, .ret = bool };
    pub fn hasTexture(self: *MeshHelper, kind: TextureType) bool {
        return cpp.bind(hasTexture_sig)(self, kind);
    }
    /// The texture of the type; the diffuse one, allocated or not, when the
    /// mesh has none of that type. Check `hasTexture` first.
    pub const getTextureRef_sig: Signature = .{ .name = "getTextureRef", .this = *MeshHelper, .args = &.{TextureType}, .ret = Ref(*Texture) };
    pub fn getTextureRef(self: *MeshHelper, kind: TextureType) *Texture {
        return cpp.bind(getTextureRef_sig)(self, kind);
    }
    /// Every texture of the mesh, the diffuse one included, as the shared
    /// pointers the mesh holds. Header-only; the glue emits it.
    pub const getAllMeshTextures_sig: Signature = .{ .name = "getAllMeshTextures", .this = *MeshHelper, .ret = Ref(*SharedAssimpTextureVector) };
    pub fn getAllMeshTextures(self: *MeshHelper) []SharedAssimpTexture {
        return bind(getAllMeshTextures_sig)(self).items();
    }
};

/// `ofxAssimpAnimation`: one animation of a model, which plays like a
/// video: `play`, `stop`, `setPaused`, `setPosition`, `setLoopState`,
/// `setSpeed`.
///
/// The members are protected; the binding gives the storage and the glue
/// checks the size. Every animation belongs to its `ModelLoader`, which
/// advances it in its own `update`: a sketch calls that, not this one's.
pub const Animation = extern struct {
    _storage: [64]u8 align(8),

    pub const cpp_name = "ofxAssimpAnimation";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    /// The assimp animation this one plays.
    pub const getAnimation_sig: Signature = .{ .name = "getAnimation", .this = *Animation, .ret = ?*AiAnimation };
    pub fn getAnimation(self: *Animation) ?*AiAnimation {
        return cpp.bind(getAnimation_sig)(self);
    }
    /// Advances the clock and the position. `ModelLoader.update` calls this
    /// for every animation; the skinning that follows is the loader's.
    pub const update_sig: Signature = .{ .name = "update", .this = *Animation };
    pub fn update(self: *Animation) void {
        cpp.bind(update_sig)(self);
    }
    pub const play_sig: Signature = .{ .name = "play", .this = *Animation };
    pub fn play(self: *Animation) void {
        cpp.bind(play_sig)(self);
    }
    /// Stops, and rewinds to the start.
    pub const stop_sig: Signature = .{ .name = "stop", .this = *Animation };
    pub fn stop(self: *Animation) void {
        cpp.bind(stop_sig)(self);
    }
    /// Back to the start, playing or not.
    pub const reset_sig: Signature = .{ .name = "reset", .this = *Animation };
    pub fn reset(self: *Animation) void {
        cpp.bind(reset_sig)(self);
    }
    /// Whether it is playing and not paused: the addon counts every such
    /// frame as new.
    pub const isFrameNew_sig: Signature = .{ .name = "isFrameNew", .this = *Animation, .ret = bool };
    pub fn isFrameNew(self: *Animation) bool {
        return cpp.bind(isFrameNew_sig)(self);
    }
    pub const isPaused_sig: Signature = .{ .name = "isPaused", .this = *Animation, .ret = bool };
    pub fn isPaused(self: *Animation) bool {
        return cpp.bind(isPaused_sig)(self);
    }
    pub const isPlaying_sig: Signature = .{ .name = "isPlaying", .this = *Animation, .ret = bool };
    pub fn isPlaying(self: *Animation) bool {
        return cpp.bind(isPlaying_sig)(self);
    }
    /// Whether a non-looping animation reached its end.
    pub const isFinished_sig: Signature = .{ .name = "isFinished", .this = *Animation, .ret = bool };
    pub fn isFinished(self: *Animation) bool {
        return cpp.bind(isFinished_sig)(self);
    }
    /// How far through it is, from 0 to 1.
    pub const getPosition_sig: Signature = .{ .name = "getPosition", .this = *Animation, .ret = f32 };
    pub fn getPosition(self: *Animation) f32 {
        return cpp.bind(getPosition_sig)(self);
    }
    pub const getPositionInSeconds_sig: Signature = .{ .name = "getPositionInSeconds", .this = *Animation, .ret = f32 };
    pub fn getPositionInSeconds(self: *Animation) f32 {
        return cpp.bind(getPositionInSeconds_sig)(self);
    }
    pub const getPositionInMilliSeconds_sig: Signature = .{ .name = "getPositionInMilliSeconds", .this = *Animation, .ret = i32 };
    pub fn getPositionInMilliSeconds(self: *Animation) u32 {
        return @bitCast(cpp.bind(getPositionInMilliSeconds_sig)(self));
    }
    pub const getSpeed_sig: Signature = .{ .name = "getSpeed", .this = *Animation, .ret = f32 };
    pub fn getSpeed(self: *Animation) f32 {
        return cpp.bind(getSpeed_sig)(self);
    }
    /// What oF 0.12 returns here is assimp's `mDuration`, which is in the
    /// file's ticks, not seconds: the same number only for a file that
    /// ticks once a second. `getPosition` is the reliable measure of
    /// progress; the milliseconds below are this times 1000.
    pub const getDurationInSeconds_sig: Signature = .{ .name = "getDurationInSeconds", .this = *Animation, .ret = f32 };
    pub fn getDurationInSeconds(self: *Animation) f32 {
        return cpp.bind(getDurationInSeconds_sig)(self);
    }
    pub const getDurationInMilliSeconds_sig: Signature = .{ .name = "getDurationInMilliSeconds", .this = *Animation, .ret = i32 };
    pub fn getDurationInMilliSeconds(self: *Animation) u32 {
        return @bitCast(cpp.bind(getDurationInMilliSeconds_sig)(self));
    }
    pub const setPaused_sig: Signature = .{ .name = "setPaused", .this = *Animation, .args = &.{bool} };
    pub fn setPaused(self: *Animation, paused: bool) void {
        cpp.bind(setPaused_sig)(self, paused);
    }
    /// Jumps to `position`, from 0 to 1; clamped.
    pub const setPosition_sig: Signature = .{ .name = "setPosition", .this = *Animation, .args = &.{f32} };
    pub fn setPosition(self: *Animation, position: f32) void {
        cpp.bind(setPosition_sig)(self, position);
    }
    pub const setLoopState_sig: Signature = .{ .name = "setLoopState", .this = *Animation, .args = &.{LoopType} };
    pub fn setLoopState(self: *Animation, state: LoopType) void {
        cpp.bind(setLoopState_sig)(self, state);
    }
    /// A multiple of the file's own speed; negative plays it backwards.
    pub const setSpeed_sig: Signature = .{ .name = "setSpeed", .this = *Animation, .args = &.{f32} };
    pub fn setSpeed(self: *Animation, speed: f32) void {
        cpp.bind(setSpeed_sig)(self, speed);
    }
};

/// `ofxAssimpModelLoader`.
///
/// It holds the assimp importer and scene, the meshes and animations built
/// from them, the textures they share, and the model's transform; none of
/// it is read from Zig, so the binding gives the storage and the glue
/// checks the size. It owns heap, GL buffers and textures, and C++
/// containers that point into the object itself, so construct it where it
/// will live with `init`, `deinit` it, and never copy or move it.
pub const ModelLoader = extern struct {
    _storage: [360]u8 align(8),

    pub const cpp_name = "ofxAssimpModelLoader";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *ModelLoader };
    /// Runs `ofxAssimpModelLoader()` on the storage of `self`: no model,
    /// with textures, normals, colors and materials enabled and scale
    /// normalization on.
    pub fn init(self: *ModelLoader) void {
        cpp.bind(ctor_sig)(self);
    }
    pub const dtor_sig: Signature = .{ .name = "~", .this = *ModelLoader };
    /// Frees the model and its GL resources.
    pub fn deinit(self: *ModelLoader) void {
        cpp.bind(dtor_sig)(self);
    }

    // loading

    /// `load(const of::filesystem::path&, int)`: imports the file, builds
    /// a VBO per mesh, loads the textures it names (relative to the file),
    /// and positions the model in the middle of the window, scaled to fit
    /// unless `setScaleNormalization(false)` came first. Replaces any model
    /// already loaded. Reports whether it loaded; assimp says why not
    /// through `ofLogError`. Needs the window, so call it from `setup`.
    pub const load_sig: Signature = .{ .name = "load", .this = *ModelLoader, .args = &.{ Ref(*const Path), i32 }, .ret = bool };
    pub fn load(self: *ModelLoader, file: []const u8, flags: LoadFlags) bool {
        var path = Path.init(file) orelse return false;
        defer path.deinit();
        return cpp.bind(load_sig)(self, &path, @intFromEnum(flags));
    }
    /// `load(ofBuffer&, int, const char* extension)`: the same, from bytes
    /// in memory. `extension` (`"obj"`, `"glb"`) tells assimp the format;
    /// textures that are not embedded resolve against `bin/data`.
    pub const load_buffer_sig: Signature = .{ .name = "load", .this = *ModelLoader, .args = &.{ Ref(*Buffer), i32, [*:0]const u8 }, .ret = bool };
    pub fn loadBuffer(self: *ModelLoader, buffer: *Buffer, flags: LoadFlags, extension: [*:0]const u8) bool {
        return cpp.bind(load_buffer_sig)(self, buffer, @intFromEnum(flags), extension);
    }
    /// `loadBuffer` from a slice, which it copies into an `ofBuffer` for
    /// the call: `model.loadMemory(@embedFile("teapot.obj"), .optimize_default, "obj")`.
    pub fn loadMemory(self: *ModelLoader, bytes: []const u8, flags: LoadFlags, extension: [*:0]const u8) bool {
        var buffer = Buffer.init(bytes);
        defer buffer.deinit();
        return self.loadBuffer(&buffer, flags, extension);
    }
    /// Drops the model, as `clear` does, leaving no scene.
    pub const createEmptyModel_sig: Signature = .{ .name = "createEmptyModel", .this = *ModelLoader };
    pub fn createEmptyModel(self: *ModelLoader) void {
        cpp.bind(createEmptyModel_sig)(self);
    }
    /// Makes an enabled `ofLight` for each light in the file, which the
    /// loader keeps. Needs a loaded model.
    pub const createLightsFromAiModel_sig: Signature = .{ .name = "createLightsFromAiModel", .this = *ModelLoader };
    pub fn createLightsFromAiModel(self: *ModelLoader) void {
        cpp.bind(createLightsFromAiModel_sig)(self);
    }
    /// Runs assimp's optimizations over the loaded scene again: cache
    /// locality, graph and mesh merging, shared vertices, duplicate
    /// materials. The meshes already built are not rebuilt.
    pub const optimizeScene_sig: Signature = .{ .name = "optimizeScene", .this = *ModelLoader };
    pub fn optimizeScene(self: *ModelLoader) void {
        cpp.bind(optimizeScene_sig)(self);
    }
    /// Frees the model and its GL resources, and forgets the transform.
    pub const clear_sig: Signature = .{ .name = "clear", .this = *ModelLoader };
    pub fn clear(self: *ModelLoader) void {
        cpp.bind(clear_sig)(self);
    }
    /// The imported scene, for reading what the addon does not expose;
    /// null with no model loaded. Owned by the loader.
    pub const getAssimpScene_sig: Signature = .{ .name = "getAssimpScene", .this = *ModelLoader, .ret = ?*const AiScene };
    pub fn getAssimpScene(self: *ModelLoader) ?*const AiScene {
        return cpp.bind(getAssimpScene_sig)(self);
    }

    // per frame

    /// Advances every animation, poses the skeleton and re-uploads the
    /// skinned vertices. Call it once per frame, from `update`.
    pub const update_sig: Signature = .{ .name = "update", .this = *ModelLoader };
    pub fn update(self: *ModelLoader) void {
        cpp.bind(update_sig)(self);
    }

    // drawing: each draws every mesh, under the model's transform

    /// `draw(ofPolyRenderMode)`.
    pub const draw_sig: Signature = .{ .name = "draw", .this = *ModelLoader, .args = &.{PolyRenderMode} };
    pub fn draw(self: *ModelLoader, mode: PolyRenderMode) void {
        cpp.bind(draw_sig)(self, mode);
    }
    /// `draw(.fill)`, with materials and textures as enabled.
    pub const drawFaces_sig: Signature = .{ .name = "drawFaces", .this = *ModelLoader };
    pub fn drawFaces(self: *ModelLoader) void {
        cpp.bind(drawFaces_sig)(self);
    }
    /// `draw(.wireframe)`.
    pub const drawWireframe_sig: Signature = .{ .name = "drawWireframe", .this = *ModelLoader };
    pub fn drawWireframe(self: *ModelLoader) void {
        cpp.bind(drawWireframe_sig)(self);
    }
    /// `draw(.points)`.
    pub const drawVertices_sig: Signature = .{ .name = "drawVertices", .this = *ModelLoader };
    pub fn drawVertices(self: *ModelLoader) void {
        cpp.bind(drawVertices_sig)(self);
    }
    /// Culls back faces of every mesh that is not two-sided, `front` saying
    /// which winding is the front. Off by default.
    pub const enableCulling_sig: Signature = .{ .name = "enableCulling", .this = *ModelLoader, .args = &.{i32} };
    pub fn enableCulling(self: *ModelLoader, front: FrontFace) void {
        cpp.bind(enableCulling_sig)(self, @intFromEnum(front));
    }
    pub const disableCulling_sig: Signature = .{ .name = "disableCulling", .this = *ModelLoader };
    pub fn disableCulling(self: *ModelLoader) void {
        cpp.bind(disableCulling_sig)(self);
    }

    // what the draws use; all on by default

    pub const enableTextures_sig: Signature = .{ .name = "enableTextures", .this = *ModelLoader };
    pub fn enableTextures(self: *ModelLoader) void {
        cpp.bind(enableTextures_sig)(self);
    }
    pub const disableTextures_sig: Signature = .{ .name = "disableTextures", .this = *ModelLoader };
    pub fn disableTextures(self: *ModelLoader) void {
        cpp.bind(disableTextures_sig)(self);
    }
    pub const enableNormals_sig: Signature = .{ .name = "enableNormals", .this = *ModelLoader };
    pub fn enableNormals(self: *ModelLoader) void {
        cpp.bind(enableNormals_sig)(self);
    }
    pub const disableNormals_sig: Signature = .{ .name = "disableNormals", .this = *ModelLoader };
    pub fn disableNormals(self: *ModelLoader) void {
        cpp.bind(disableNormals_sig)(self);
    }
    pub const enableColors_sig: Signature = .{ .name = "enableColors", .this = *ModelLoader };
    pub fn enableColors(self: *ModelLoader) void {
        cpp.bind(enableColors_sig)(self);
    }
    pub const disableColors_sig: Signature = .{ .name = "disableColors", .this = *ModelLoader };
    pub fn disableColors(self: *ModelLoader) void {
        cpp.bind(disableColors_sig)(self);
    }
    pub const enableMaterials_sig: Signature = .{ .name = "enableMaterials", .this = *ModelLoader };
    pub fn enableMaterials(self: *ModelLoader) void {
        cpp.bind(enableMaterials_sig)(self);
    }
    pub const disableMaterials_sig: Signature = .{ .name = "disableMaterials", .this = *ModelLoader };
    pub fn disableMaterials(self: *ModelLoader) void {
        cpp.bind(disableMaterials_sig)(self);
    }

    // animations

    pub const hasAnimations_sig: Signature = .{ .name = "hasAnimations", .this = *ModelLoader, .ret = bool };
    pub fn hasAnimations(self: *ModelLoader) bool {
        return cpp.bind(hasAnimations_sig)(self);
    }
    pub const getAnimationCount_sig: Signature = .{ .name = "getAnimationCount", .this = *ModelLoader, .ret = u32 };
    pub fn getAnimationCount(self: *ModelLoader) u32 {
        return cpp.bind(getAnimationCount_sig)(self);
    }
    /// `getAnimation(int)`, or null when `index` is past the last one. oF
    /// clamps the index instead, which is undefined with no animations.
    pub const getAnimation_sig: Signature = .{ .name = "getAnimation", .this = *ModelLoader, .args = &.{i32}, .ret = Ref(*Animation) };
    pub fn getAnimation(self: *ModelLoader, index: u32) ?*Animation {
        if (index >= self.getAnimationCount()) return null;
        return cpp.bind(getAnimation_sig)(self, @bitCast(index));
    }
    pub const playAllAnimations_sig: Signature = .{ .name = "playAllAnimations", .this = *ModelLoader };
    pub fn playAllAnimations(self: *ModelLoader) void {
        cpp.bind(playAllAnimations_sig)(self);
    }
    pub const stopAllAnimations_sig: Signature = .{ .name = "stopAllAnimations", .this = *ModelLoader };
    pub fn stopAllAnimations(self: *ModelLoader) void {
        cpp.bind(stopAllAnimations_sig)(self);
    }
    pub const resetAllAnimations_sig: Signature = .{ .name = "resetAllAnimations", .this = *ModelLoader };
    pub fn resetAllAnimations(self: *ModelLoader) void {
        cpp.bind(resetAllAnimations_sig)(self);
    }
    pub const setPausedForAllAnimations_sig: Signature = .{ .name = "setPausedForAllAnimations", .this = *ModelLoader, .args = &.{bool} };
    pub fn setPausedForAllAnimations(self: *ModelLoader, paused: bool) void {
        cpp.bind(setPausedForAllAnimations_sig)(self, paused);
    }
    pub const setLoopStateForAllAnimations_sig: Signature = .{ .name = "setLoopStateForAllAnimations", .this = *ModelLoader, .args = &.{LoopType} };
    pub fn setLoopStateForAllAnimations(self: *ModelLoader, state: LoopType) void {
        cpp.bind(setLoopStateForAllAnimations_sig)(self, state);
    }
    /// Every animation to `position`, from 0 to 1.
    pub const setPositionForAllAnimations_sig: Signature = .{ .name = "setPositionForAllAnimations", .this = *ModelLoader, .args = &.{f32} };
    pub fn setPositionForAllAnimations(self: *ModelLoader, position: f32) void {
        cpp.bind(setPositionForAllAnimations_sig)(self, position);
    }
    pub const setSpeedForAllAnimations_sig: Signature = .{ .name = "setSpeedForAllAnimations", .this = *ModelLoader, .args = &.{f32} };
    pub fn setSpeedForAllAnimations(self: *ModelLoader, speed: f32) void {
        cpp.bind(setSpeedForAllAnimations_sig)(self, speed);
    }

    // meshes. The loader builds one `MeshHelper` per assimp mesh, in the
    // scene's order; `getMeshCount` counts those, `getNumMeshes` the
    // scene's, which is the same number once a model is loaded.

    pub const hasMeshes_sig: Signature = .{ .name = "hasMeshes", .this = *ModelLoader, .ret = bool };
    pub fn hasMeshes(self: *ModelLoader) bool {
        return cpp.bind(hasMeshes_sig)(self);
    }
    pub const getMeshCount_sig: Signature = .{ .name = "getMeshCount", .this = *ModelLoader, .ret = u32 };
    pub fn getMeshCount(self: *ModelLoader) u32 {
        return cpp.bind(getMeshCount_sig)(self);
    }
    pub const getNumMeshes_sig: Signature = .{ .name = "getNumMeshes", .this = *ModelLoader, .ret = u32 };
    pub fn getNumMeshes(self: *ModelLoader) u32 {
        return cpp.bind(getNumMeshes_sig)(self);
    }
    /// `getMeshHelper(int)`, or null when `index` is past the last one, as
    /// for `getAnimation`.
    pub const getMeshHelper_sig: Signature = .{ .name = "getMeshHelper", .this = *ModelLoader, .args = &.{i32}, .ret = Ref(*MeshHelper) };
    pub fn getMeshHelper(self: *ModelLoader, index: u32) ?*MeshHelper {
        if (index >= self.getMeshCount()) return null;
        return cpp.bind(getMeshHelper_sig)(self, @bitCast(index));
    }
    /// The name of every mesh, in order, as the file gives them (often
    /// empty). The caller owns the list and must `deinit` it.
    pub const getMeshNames_sig: Signature = .{ .name = "getMeshNames", .this = *ModelLoader, .ret = StringVector };
    pub fn getMeshNames(self: *ModelLoader) StringVector {
        var out: StringVector = undefined;
        bind(getMeshNames_sig)(&out, self);
        return out;
    }

    // Copies out of the model. Each runs a constructor on `out`, which must
    // be uninitialized storage where the copy will live; `deinit` it after.
    // An index or name with no mesh logs an error and gives an empty one.

    /// `getMesh(unsigned)`: the mesh as the file has it, before any
    /// animation, untransformed, as an `ofMesh` of triangles.
    pub const getMesh_sig: Signature = .{ .name = "getMesh", .this = *ModelLoader, .args = &.{u32}, .ret = Mesh };
    pub fn getMesh(self: *ModelLoader, index: u32, out: *Mesh) void {
        bind(getMesh_sig)(out, self, index);
    }
    /// `getMesh(std::string)`: the first mesh of that name.
    pub const getMesh_name_sig: Signature = .{ .name = "getMesh", .this = *ModelLoader, .args = &.{String}, .ret = Mesh };
    pub fn getMeshNamed(self: *ModelLoader, name: []const u8, out: *Mesh) void {
        // By value: the call consumes it.
        var s = String.init(name);
        bind(getMesh_name_sig)(out, self, &s);
    }
    /// `getCurrentAnimatedMesh(unsigned)`: the mesh as the current frame of
    /// its animation poses it, positions and normals only.
    pub const getCurrentAnimatedMesh_sig: Signature = .{ .name = "getCurrentAnimatedMesh", .this = *ModelLoader, .args = &.{u32}, .ret = Mesh };
    pub fn getCurrentAnimatedMesh(self: *ModelLoader, index: u32, out: *Mesh) void {
        bind(getCurrentAnimatedMesh_sig)(out, self, index);
    }
    pub const getCurrentAnimatedMesh_name_sig: Signature = .{ .name = "getCurrentAnimatedMesh", .this = *ModelLoader, .args = &.{String}, .ret = Mesh };
    pub fn getCurrentAnimatedMeshNamed(self: *ModelLoader, name: []const u8, out: *Mesh) void {
        var s = String.init(name);
        bind(getCurrentAnimatedMesh_name_sig)(out, self, &s);
    }
    /// `getMaterialForMesh(unsigned)`: a copy of the mesh's material.
    pub const getMaterialForMesh_sig: Signature = .{ .name = "getMaterialForMesh", .this = *ModelLoader, .args = &.{u32}, .ret = Material };
    pub fn getMaterialForMesh(self: *ModelLoader, index: u32, out: *Material) void {
        cpp.bind(getMaterialForMesh_sig)(out, self, index);
    }
    pub const getMaterialForMesh_name_sig: Signature = .{ .name = "getMaterialForMesh", .this = *ModelLoader, .args = &.{String}, .ret = Material };
    pub fn getMaterialForMeshNamed(self: *ModelLoader, name: []const u8, out: *Material) void {
        var s = String.init(name);
        cpp.bind(getMaterialForMesh_name_sig)(out, self, &s);
    }
    /// `getTextureForMesh(unsigned)`: a second handle on the mesh's diffuse
    /// texture (see `Texture`), or an unallocated one if it has none -- for
    /// which oF also logs an "out of range" error, so ask
    /// `MeshHelper.hasTexture(.diffuse)` first.
    pub const getTextureForMesh_sig: Signature = .{ .name = "getTextureForMesh", .this = *ModelLoader, .args = &.{u32}, .ret = Texture };
    pub fn getTextureForMesh(self: *ModelLoader, index: u32, out: *Texture) void {
        cpp.bind(getTextureForMesh_sig)(out, self, index);
    }
    pub const getTextureForMesh_name_sig: Signature = .{ .name = "getTextureForMesh", .this = *ModelLoader, .args = &.{String}, .ret = Texture };
    pub fn getTextureForMeshNamed(self: *ModelLoader, name: []const u8, out: *Texture) void {
        var s = String.init(name);
        cpp.bind(getTextureForMesh_name_sig)(out, self, &s);
    }

    // the model's transform: translate, then each rotation in turn, then
    // scale, then the normalization scale, about the scene's center

    /// Where the model's center goes. `load` puts it in the middle of the
    /// window.
    pub const setPosition_sig: Signature = .{ .name = "setPosition", .this = *ModelLoader, .args = &.{ f32, f32, f32 } };
    pub fn setPosition(self: *ModelLoader, pos: Vec3) void {
        cpp.bind(setPosition_sig)(self, pos[0], pos[1], pos[2]);
    }
    pub const getPosition_sig: Signature = .{ .name = "getPosition", .this = *ModelLoader, .ret = GlmVec3 };
    pub fn getPosition(self: *ModelLoader) Vec3 {
        return cpp.bind(getPosition_sig)(self).to();
    }
    /// A scale per axis, on top of the normalization.
    pub const setScale_sig: Signature = .{ .name = "setScale", .this = *ModelLoader, .args = &.{ f32, f32, f32 } };
    pub fn setScale(self: *ModelLoader, scale: Vec3) void {
        cpp.bind(setScale_sig)(self, scale[0], scale[1], scale[2]);
    }
    pub const getScale_sig: Signature = .{ .name = "getScale", .this = *ModelLoader, .ret = GlmVec3 };
    pub fn getScale(self: *ModelLoader) Vec3 {
        return cpp.bind(getScale_sig)(self).to();
    }
    /// `setRotation(which, angle, x, y, z)`: rotation number `which` of the
    /// model's list, by `angle` radians about `axis`. The rotations apply
    /// in order; setting one past the end adds zero rotations up to it.
    pub const setRotation_sig: Signature = .{ .name = "setRotation", .this = *ModelLoader, .args = &.{ i32, f32, f32, f32, f32 } };
    pub fn setRotation(self: *ModelLoader, which: u32, angle: f32, axis: Vec3) void {
        cpp.bind(setRotation_sig)(self, @bitCast(which), math.radToDeg(angle), axis[0], axis[1], axis[2]);
    }
    pub const getNumRotations_sig: Signature = .{ .name = "getNumRotations", .this = *ModelLoader, .ret = i32 };
    pub fn getNumRotations(self: *ModelLoader) u32 {
        return @bitCast(cpp.bind(getNumRotations_sig)(self));
    }
    /// Rotation `which`'s axis; zero past the end.
    pub const getRotationAxis_sig: Signature = .{ .name = "getRotationAxis", .this = *ModelLoader, .args = &.{i32}, .ret = GlmVec3 };
    pub fn getRotationAxis(self: *ModelLoader, which: u32) Vec3 {
        return cpp.bind(getRotationAxis_sig)(self, @bitCast(which)).to();
    }
    /// Rotation `which`'s angle, in radians; zero past the end.
    pub const getRotationAngle_sig: Signature = .{ .name = "getRotationAngle", .this = *ModelLoader, .args = &.{i32}, .ret = f32 };
    pub fn getRotationAngle(self: *ModelLoader, which: u32) f32 {
        return math.degToRad(cpp.bind(getRotationAngle_sig)(self, @bitCast(which)));
    }
    /// Whether `load` scales the model to fit `setNormalizationFactor`. On
    /// by default; set it before `load`.
    pub const setScaleNormalization_sig: Signature = .{ .name = "setScaleNormalization", .this = *ModelLoader, .args = &.{bool} };
    pub fn setScaleNormalization(self: *ModelLoader, normalize: bool) void {
        cpp.bind(setScaleNormalization_sig)(self, normalize);
    }
    /// The size the normalization fits the model's largest extent to. `load`
    /// sets it to half the window's width, so set it after `load` and then
    /// `calculateDimensions`.
    pub const setNormalizationFactor_sig: Signature = .{ .name = "setNormalizationFactor", .this = *ModelLoader, .args = &.{f32} };
    pub fn setNormalizationFactor(self: *ModelLoader, factor: f32) void {
        cpp.bind(setNormalizationFactor_sig)(self, factor);
    }
    /// The scale the normalization chose; 1 when it is off.
    pub const getNormalizedScale_sig: Signature = .{ .name = "getNormalizedScale", .this = *ModelLoader, .ret = f32 };
    pub fn getNormalizedScale(self: *ModelLoader) f32 {
        return cpp.bind(getNormalizedScale_sig)(self);
    }
    /// The whole transform `draw` applies.
    pub const getModelMatrix_sig: Signature = .{ .name = "getModelMatrix", .this = *ModelLoader, .ret = Mat4 };
    pub fn getModelMatrix(self: *ModelLoader) Mat4 {
        return cpp.bind(getModelMatrix_sig)(self);
    }

    // bounds

    /// Measures the scene's bounding box again, and with it the center and
    /// the normalization scale. `load` does this; call it after changing
    /// the normalization factor.
    pub const calculateDimensions_sig: Signature = .{ .name = "calculateDimensions", .this = *ModelLoader };
    pub fn calculateDimensions(self: *ModelLoader) void {
        cpp.bind(calculateDimensions_sig)(self);
    }
    /// The center of the scene's bounding box, in the file's units.
    pub const getSceneCenter_sig: Signature = .{ .name = "getSceneCenter", .this = *ModelLoader, .ret = GlmVec3 };
    pub fn getSceneCenter(self: *ModelLoader) Vec3 {
        return cpp.bind(getSceneCenter_sig)(self).to();
    }
    /// The bounding box's corners in the file's units, times `setScale`'s
    /// scale when `scaled`, but without the normalization or position.
    pub const getSceneMin_sig: Signature = .{ .name = "getSceneMin", .this = *ModelLoader, .args = &.{bool}, .ret = GlmVec3 };
    pub fn getSceneMin(self: *ModelLoader, scaled: bool) Vec3 {
        return cpp.bind(getSceneMin_sig)(self, scaled).to();
    }
    pub const getSceneMax_sig: Signature = .{ .name = "getSceneMax", .this = *ModelLoader, .args = &.{bool}, .ret = GlmVec3 };
    pub fn getSceneMax(self: *ModelLoader, scaled: bool) Vec3 {
        return cpp.bind(getSceneMax_sig)(self, scaled).to();
    }
    /// The bounding box in the space `drawFaces` draws in: inside the model
    /// matrix, so a box drawn with `pushMatrix`, `multMatrix(getModelMatrix())`
    /// and these corners encloses the model.
    pub const getSceneMinModelSpace_sig: Signature = .{ .name = "getSceneMinModelSpace", .this = *ModelLoader, .ret = GlmVec3 };
    pub fn getSceneMinModelSpace(self: *ModelLoader) Vec3 {
        return cpp.bind(getSceneMinModelSpace_sig)(self).to();
    }
    pub const getSceneMaxModelSpace_sig: Signature = .{ .name = "getSceneMaxModelSpace", .this = *ModelLoader, .ret = GlmVec3 };
    pub fn getSceneMaxModelSpace(self: *ModelLoader) Vec3 {
        return cpp.bind(getSceneMaxModelSpace_sig)(self).to();
    }
    pub const getSceneCenterModelSpace_sig: Signature = .{ .name = "getSceneCenterModelSpace", .this = *ModelLoader, .ret = GlmVec3 };
    pub fn getSceneCenterModelSpace(self: *ModelLoader) Vec3 {
        return cpp.bind(getSceneCenterModelSpace_sig)(self).to();
    }
};

comptime {
    // The layouts the dumps of oF 0.12.1 give, on the three targets; the
    // glue checks the same against the headers of the build.
    std.debug.assert(@sizeOf(ModelLoader) == 360);
    std.debug.assert(@sizeOf(Animation) == 64);
    std.debug.assert(@sizeOf(AssimpTexture) == if (msvc) 256 else 240);
    std.debug.assert(@sizeOf(MeshHelper) == if (msvc) 2520 else 1976);
}
