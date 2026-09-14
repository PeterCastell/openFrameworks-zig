//! ofTrueTypeFont.h: a TrueType face, and the text it draws.
//!
//! ```zig
//! var font: of.Font = undefined;   // a field of the app struct, not a local
//! font.init();
//! defer font.deinit();
//! _ = font.load(of.font.sans, 24, .{});
//! font.drawString("hello", 20, 40);
//! ```
//!
//! `load` takes the arguments oF defaults. `Settings` is the other half of
//! the same call: it adds the face index, the writing direction, and the
//! Unicode ranges to cache, which is what a font outside Latin-1 needs.
//!
//! Either way the load builds a texture atlas, so it needs the window: call
//! it from `setup`, not before `run`.
const cpp = @import("cpp_bindgen");
const Signature = cpp.Signature;
const Ref = cpp.Ref;
const String = @import("string.zig").String;
const Path = @import("string.zig").Path;
const rectangle = @import("rectangle.zig");
const Rectangle = rectangle.Rectangle;
const OfRectangle = rectangle.OfRectangle;

/// The three names a load resolves to an installed system font rather than
/// to a file under `bin/data`. On Windows oF reads the font registry and
/// maps these to Arial, Times New Roman and Courier New.
pub const sans = "sans-serif";
pub const serif = "serif";
pub const mono = "monospace";

/// The arguments of `Font.load` that oF defaults, in the order the C++ takes
/// them.
pub const LoadOptions = struct {
    antialiased: bool = true,
    /// Latin-1 rather than plain ASCII.
    full_character_set: bool = true,
    /// Cache the vector outline of each glyph. `drawStringAsShapes` draws
    /// nothing without them, and says so through `ofLogError`.
    contours: bool = false,
    /// How far to simplify those outlines. Larger is coarser.
    simplify_amount: f32 = 0,
    /// `0` means the global dpi, which `Font.setGlobalDpi` sets and which oF
    /// starts at 96.
    dpi: u32 = 0,
};

/// `ofTrueTypeFontDirection`, which oF gives a `uint32_t` of its own.
pub const Direction = enum(u32) {
    left_to_right = 0,
    right_to_left = 1,
    pub const cpp_name = "ofTrueTypeFontDirection";
    pub const cpp_kind: cpp.Kind = .@"enum";
};

/// `ofUnicode::range`: a span of code points to cache, both ends included.
pub const UnicodeRange = extern struct {
    begin: u32,
    end: u32,

    pub const cpp_name = "ofUnicode::range";
    pub const cpp_kind: cpp.Kind = .@"struct";
    /// Trivial to copy, but it declares constructors, so it is not a plain
    /// C struct.
    pub const cpp_abi: cpp.ClassAbi = .trivial_copy;

    /// `ofUnicode::range::getNumGlyphs()`, which is Zig arithmetic here.
    pub fn glyphCount(r: UnicodeRange) u32 {
        return r.end - r.begin + 1;
    }
};

/// The blocks `ofUnicode` names, with oF's own numbers.
///
/// cpp-bindgen binds functions, not data, so these are written out here
/// rather than read from the `ofUnicode` statics that hold them. They are
/// Unicode block bounds, and oF has not moved them.
pub const unicode = struct {
    pub const space: UnicodeRange = .{ .begin = 32, .end = 32 };
    pub const ideographic_space: UnicodeRange = .{ .begin = 0x3000, .end = 0x3000 };
    pub const latin: UnicodeRange = .{ .begin = 32, .end = 0x007F };
    pub const latin1_supplement: UnicodeRange = .{ .begin = 32, .end = 0x00FF };
    pub const latin_a: UnicodeRange = .{ .begin = 0x0100, .end = 0x017F };
    pub const greek: UnicodeRange = .{ .begin = 0x0370, .end = 0x03FF };
    pub const cyrillic: UnicodeRange = .{ .begin = 0x0400, .end = 0x04FF };
    pub const arabic: UnicodeRange = .{ .begin = 0x0600, .end = 0x077F };
    pub const arabic_supplement: UnicodeRange = .{ .begin = 0x0750, .end = 0x077F };
    pub const arabic_extended_a: UnicodeRange = .{ .begin = 0x08A0, .end = 0x08FF };
    pub const devanagari: UnicodeRange = .{ .begin = 0x0900, .end = 0x097F };
    pub const hangul_jamo: UnicodeRange = .{ .begin = 0x1100, .end = 0x11FF };
    pub const vedic_extensions: UnicodeRange = .{ .begin = 0x1CD0, .end = 0x1CFF };
    pub const latin_extended_additional: UnicodeRange = .{ .begin = 0x1E00, .end = 0x1EFF };
    pub const greek_extended: UnicodeRange = .{ .begin = 0x1F00, .end = 0x1FFF };
    pub const general_punctuation: UnicodeRange = .{ .begin = 0x2000, .end = 0x206F };
    pub const super_and_subscripts: UnicodeRange = .{ .begin = 0x2070, .end = 0x209F };
    pub const currency_symbols: UnicodeRange = .{ .begin = 0x20A0, .end = 0x20CF };
    pub const letter_like_symbols: UnicodeRange = .{ .begin = 0x2100, .end = 0x214F };
    pub const number_forms: UnicodeRange = .{ .begin = 0x2150, .end = 0x218F };
    pub const arrows: UnicodeRange = .{ .begin = 0x2190, .end = 0x21FF };
    pub const math_operators: UnicodeRange = .{ .begin = 0x2200, .end = 0x22FF };
    pub const misc_technical: UnicodeRange = .{ .begin = 0x2300, .end = 0x23FF };
    pub const box_drawing: UnicodeRange = .{ .begin = 0x2500, .end = 0x257F };
    pub const block_element: UnicodeRange = .{ .begin = 0x2580, .end = 0x259F };
    pub const geometric_shapes: UnicodeRange = .{ .begin = 0x25A0, .end = 0x25FF };
    pub const misc_symbols: UnicodeRange = .{ .begin = 0x2600, .end = 0x26FF };
    pub const dingbats: UnicodeRange = .{ .begin = 0x2700, .end = 0x27BF };
    pub const cjk_symbol_and_punctuation: UnicodeRange = .{ .begin = 0x3001, .end = 0x303F };
    pub const hiragana: UnicodeRange = .{ .begin = 0x3040, .end = 0x309F };
    pub const katakana: UnicodeRange = .{ .begin = 0x30A0, .end = 0x30FF };
    pub const hangul_compat_jamo: UnicodeRange = .{ .begin = 0x3130, .end = 0x318F };
    pub const katakana_phonetic_extensions: UnicodeRange = .{ .begin = 0x31F0, .end = 0x31FF };
    pub const cjk_letters_and_months: UnicodeRange = .{ .begin = 0x3200, .end = 0x32FF };
    pub const cjk_unified: UnicodeRange = .{ .begin = 0x4E00, .end = 0x9FD5 };
    pub const devanagari_extended: UnicodeRange = .{ .begin = 0xA8E0, .end = 0xA8FF };
    pub const hangul_extended_a: UnicodeRange = .{ .begin = 0xA960, .end = 0xA97F };
    pub const hangul_syllables: UnicodeRange = .{ .begin = 0xAC00, .end = 0xD7AF };
    pub const hangul_extended_b: UnicodeRange = .{ .begin = 0xD7B0, .end = 0xD7FF };
    pub const alphabetic_presentation_forms: UnicodeRange = .{ .begin = 0xFB00, .end = 0xFB4F };
    pub const arabic_pres_forms_a: UnicodeRange = .{ .begin = 0xFB50, .end = 0xFDFF };
    pub const arabic_pres_forms_b: UnicodeRange = .{ .begin = 0xFE70, .end = 0xFEFF };
    pub const katakana_half_and_fullwidth_forms: UnicodeRange = .{ .begin = 0xFF00, .end = 0xFFEF };
    pub const kana_supplement: UnicodeRange = .{ .begin = 0x1B000, .end = 0x1B0FF };
    pub const rumi_numerical_symbols: UnicodeRange = .{ .begin = 0x10E60, .end = 0x10E7F };
    pub const arabic_math: UnicodeRange = .{ .begin = 0x1EE00, .end = 0x1EEFF };
    pub const misc_symbols_and_pictographs: UnicodeRange = .{ .begin = 0x1F300, .end = 0x1F5FF };
    pub const emoticons: UnicodeRange = .{ .begin = 0x1F601, .end = 0x1F64F };
    pub const transport_and_map: UnicodeRange = .{ .begin = 0x1F680, .end = 0x1F6FF };
    pub const enclosed_characters: UnicodeRange = .{ .begin = 0x24C2, .end = 0x1F251 };
    pub const uncategorized: UnicodeRange = .{ .begin = 0x00A9, .end = 0x1F5FF };
    pub const additional_emoticons: UnicodeRange = .{ .begin = 0x1F600, .end = 0x1F636 };
    pub const additional_transport_and_map: UnicodeRange = .{ .begin = 0x1F681, .end = 0x1F6C5 };
    pub const other_additional_symbols: UnicodeRange = .{ .begin = 0x1F30D, .end = 0x1F567 };
    pub const uppercase_latin: UnicodeRange = .{ .begin = 65, .end = 90 };
    pub const lowercase_latin: UnicodeRange = .{ .begin = 97, .end = 122 };
    pub const braces: UnicodeRange = .{ .begin = 123, .end = 127 };
    pub const numbers: UnicodeRange = .{ .begin = 48, .end = 57 };
    pub const symbols: UnicodeRange = .{ .begin = 33, .end = 47 };
    pub const generic_symbols: UnicodeRange = .{ .begin = 58, .end = 64 };
};

/// `ofAlphabet`: the range sets oF groups by script, for `Settings.addRanges`.
pub const alphabet = struct {
    pub const emoji: []const UnicodeRange = &.{
        unicode.space,
        unicode.emoticons,
        unicode.dingbats,
        unicode.uncategorized,
        unicode.transport_and_map,
        unicode.enclosed_characters,
        unicode.other_additional_symbols,
    };
    pub const japanese: []const UnicodeRange = &.{
        unicode.space,
        unicode.ideographic_space,
        unicode.cjk_symbol_and_punctuation,
        unicode.hiragana,
        unicode.katakana,
        unicode.katakana_phonetic_extensions,
        unicode.cjk_letters_and_months,
        unicode.cjk_unified,
    };
    pub const chinese: []const UnicodeRange = &.{
        unicode.space,
        unicode.ideographic_space,
        unicode.cjk_symbol_and_punctuation,
        unicode.cjk_letters_and_months,
        unicode.cjk_unified,
    };
    pub const korean: []const UnicodeRange = &.{
        unicode.space,
        unicode.ideographic_space,
        unicode.cjk_symbol_and_punctuation,
        unicode.hangul_jamo,
        unicode.hangul_compat_jamo,
        unicode.hangul_extended_a,
        unicode.hangul_extended_b,
        unicode.hangul_syllables,
    };
    pub const arabic: []const UnicodeRange = &.{
        unicode.space,
        unicode.arabic,
        unicode.arabic_extended_a,
        unicode.arabic_math,
        unicode.arabic_pres_forms_a,
        unicode.arabic_pres_forms_b,
    };
    pub const devanagari: []const UnicodeRange = &.{
        unicode.devanagari,
        unicode.devanagari_extended,
        unicode.vedic_extensions,
    };
    pub const latin: []const UnicodeRange = &.{
        unicode.latin1_supplement,
        unicode.latin_extended_additional,
        unicode.latin,
        unicode.latin_a,
    };
    pub const greek: []const UnicodeRange = &.{
        unicode.space,
        unicode.greek,
        unicode.greek_extended,
    };
    pub const cyrillic: []const UnicodeRange = &.{
        unicode.space,
        unicode.cyrillic,
    };
};

/// `std::vector<ofUnicode::range>`, as the three pointers MSVC gives it.
/// Zig never reads them: `Settings.init` builds the vector, `addRange` grows
/// it, and `Settings.deinit` frees it, all in C++.
const RangeVector = extern struct {
    _first: ?*UnicodeRange,
    _last: ?*UnicodeRange,
    _end: ?*UnicodeRange,
};

/// `ofTrueTypeFontSettings`: everything `Font.loadSettings` reads.
///
/// The fields carry the C++ names, because the glue checks each one with
/// `offsetof`. They are yours to set between `init` and the load:
///
/// ```zig
/// var s: of.FontSettings = undefined;
/// if (!s.init("NotoSansJP.ttf", 18)) return;
/// defer s.deinit();
/// s.contours = true;
/// s.addRanges(of.font.alphabet.japanese);
/// _ = font.loadSettings(&s);
/// ```
///
/// `fontName` and `ranges` own heap, so a `Settings` is no more copyable
/// than a `Font` is: construct it where it will live.
pub const Settings = extern struct {
    fontName: Path,
    fontSize: u32,
    antialiased: bool,
    contours: bool,
    simplifyAmt: f32,
    /// `0` means the global dpi. See `Font.setGlobalDpi`.
    dpi: u32,
    /// Which face to take from a file that holds more than one.
    index: u32,
    direction: Direction,
    /// The blocks to cache. The constructor leaves this empty and a load
    /// caches nothing, so add at least one range -- or call `Font.load`,
    /// which fills the field in with Latin-1 for you.
    ranges: RangeVector,

    pub const cpp_name = "ofTrueTypeFontSettings";
    pub const cpp_kind: cpp.Kind = .@"struct";
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;

    /// `ofTrueTypeFontSettings(const of::filesystem::path&, int)`.
    pub const ctor_sig: Signature = .{ .name = "*", .args = &.{ Ref(*const Path), i32 }, .this = *Settings };
    /// Runs that constructor on the storage of `self`, and reports whether
    /// it ran: a `file` that is not valid UTF-8, or that is longer than
    /// `string.Path.max_units`, builds nothing and must not be `deinit`ed.
    ///
    /// The fields the constructor does not take start at oF's defaults:
    /// antialiased, no contours, no simplification, the global dpi, face
    /// zero, left to right, and no ranges.
    pub fn init(self: *Settings, file: []const u8, size: u32) bool {
        var path = Path.init(file) orelse return false;
        defer path.deinit();
        cpp.bind(ctor_sig)(self, &path, @bitCast(size));
        return true;
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *Settings };
    pub fn deinit(self: *Settings) void {
        cpp.bind(dtor_sig)(self);
    }

    pub const addRange_sig: Signature = .{ .name = "addRange", .this = *Settings, .args = &.{Ref(*const UnicodeRange)} };
    pub fn addRange(self: *Settings, range: UnicodeRange) void {
        cpp.bind(addRange_sig)(self, &range);
    }

    /// oF spells this `addRanges(std::initializer_list<ofUnicode::range>)`.
    /// A Zig slice is the same list, and appending it one range at a time
    /// leaves the same vector, so this needs no second binding.
    pub fn addRanges(self: *Settings, to_add: []const UnicodeRange) void {
        for (to_add) |range| self.addRange(range);
    }
};

/// `ofTrueTypeFont`.
///
/// The class has a couple of dozen members -- vectors, an `unordered_map`,
/// an `ofTexture`, an `ofMesh` -- and not one of them is part of using a
/// font, so this binding gives the storage of the class rather than its
/// fields. The glue still checks that size and that alignment against the
/// real class, which is all any call here depends on: C++ constructs the
/// object into these bytes, and nothing but C++ reads them.
///
/// A `Font` therefore cannot be copied or moved. Construct it where it will
/// live -- a field of the app struct is the usual place -- and pass it on by
/// pointer.
pub const Font = extern struct {
    _storage: [728]u8 align(8),

    pub const cpp_name = "ofTrueTypeFont";
    pub const cpp_kind: cpp.Kind = .class;
    pub const cpp_abi: cpp.ClassAbi = .managed_copy;
    pub const cpp_virtual_dtor = true;

    pub const ctor_sig: Signature = .{ .name = "*", .this = *Font };
    /// Runs `ofTrueTypeFont()` on the storage of `self`:
    ///
    /// ```zig
    /// var font: of.Font = undefined;
    /// font.init();
    /// defer font.deinit();
    /// ```
    pub fn init(self: *Font) void {
        cpp.bind(ctor_sig)(self);
    }

    pub const dtor_sig: Signature = .{ .name = "~", .this = *Font };
    pub fn deinit(self: *Font) void {
        cpp.bind(dtor_sig)(self);
    }

    // loading

    /// `load(path, size, antialiased, fullCharacterSet, makeContours, simplifyAmt, dpi)`
    pub const load_sig: Signature = .{
        .name = "load",
        .this = *Font,
        .args = &.{ Ref(*const Path), i32, bool, bool, bool, f32, i32 },
        .ret = bool,
    };
    /// Loads `file` at `size` pixels, and reports whether it loaded.
    ///
    /// `file` is a path under `bin/data`, or an absolute path, or one of
    /// `sans`, `serif` and `mono`. oF falls back to the installed fonts for
    /// a name that is not a file, so a face name such as `"georgia"` also
    /// loads.
    ///
    /// A `file` that is not valid UTF-8, or that is longer than
    /// `string.Path.max_units`, returns `false` without a call.
    pub fn load(self: *Font, file: []const u8, size: u32, opts: LoadOptions) bool {
        var path = Path.init(file) orelse return false;
        defer path.deinit();
        return cpp.bind(load_sig)(
            self,
            &path,
            @bitCast(size),
            opts.antialiased,
            opts.full_character_set,
            opts.contours,
            opts.simplify_amount,
            @bitCast(opts.dpi),
        );
    }

    /// `load(const ofTrueTypeFontSettings&)`, the overload the other `load`
    /// ends up calling.
    pub const load_settings_sig: Signature = .{ .name = "load", .this = *Font, .args = &.{Ref(*const Settings)}, .ret = bool };
    /// The same load, from a `Settings` you filled in. That is the way to a
    /// face index, a right-to-left direction, or any Unicode range other
    /// than the Latin-1 that `load` settles for.
    pub fn loadSettings(self: *Font, settings: *const Settings) bool {
        return cpp.bind(load_settings_sig)(self, settings);
    }

    pub const isLoaded_sig: Signature = .{ .name = "isLoaded", .this = *const Font, .ret = bool };
    pub fn isLoaded(self: *const Font) bool {
        return cpp.bind(isLoaded_sig)(self);
    }

    /// `ofTrueTypeFont::setGlobalDpi(newDpi)`: the dpi every later load uses
    /// when the dpi it was given is zero. oF starts at 96.
    pub const setGlobalDpi_sig: Signature = .{ .name = "setGlobalDpi", .class = Font, .args = &.{i32} };
    pub fn setGlobalDpi(dpi: u32) void {
        cpp.bind(setGlobalDpi_sig)(@bitCast(dpi));
    }

    // measuring

    pub const getLineHeight_sig: Signature = .{ .name = "getLineHeight", .this = *const Font, .ret = f32 };
    pub fn getLineHeight(self: *const Font) f32 {
        return cpp.bind(getLineHeight_sig)(self);
    }

    pub const stringWidth_sig: Signature = .{ .name = "stringWidth", .this = *const Font, .args = &.{Ref(*const String)}, .ret = f32 };
    pub fn stringWidth(self: *const Font, text: []const u8) f32 {
        var s: String = .init(text);
        defer s.deinit();
        return cpp.bind(stringWidth_sig)(self, &s);
    }

    pub const stringHeight_sig: Signature = .{ .name = "stringHeight", .this = *const Font, .args = &.{Ref(*const String)}, .ret = f32 };
    pub fn stringHeight(self: *const Font, text: []const u8) f32 {
        var s: String = .init(text);
        defer s.deinit();
        return cpp.bind(stringHeight_sig)(self, &s);
    }

    /// `getStringBoundingBox(s, x, y, vflip)`, at oF's `vflip` default.
    pub const getStringBoundingBox_sig: Signature = .{
        .name = "getStringBoundingBox",
        .this = *const Font,
        .args = &.{ Ref(*const String), f32, f32, bool },
        .ret = OfRectangle,
    };
    /// The box the string would cover if it were drawn at `x, y`, which is
    /// where `drawString` puts its baseline.
    pub fn getStringBoundingBox(self: *const Font, text: []const u8, x: f32, y: f32) Rectangle {
        var s: String = .init(text);
        defer s.deinit();
        var box: OfRectangle = undefined;
        cpp.bind(getStringBoundingBox_sig)(&box, self, &s, x, y, true);
        defer box.deinit();
        return .fromOf(box);
    }
    pub fn getStringBoundingBoxi(self: *const Font, text: []const u8, x: i32, y: i32) Rectangle {
        return self.getStringBoundingBox(text, @floatFromInt(x), @floatFromInt(y));
    }

    // drawing

    pub const drawString_sig: Signature = .{ .name = "drawString", .this = *const Font, .args = &.{ Ref(*const String), f32, f32 } };
    /// Draws `text` with its baseline at `x, y`, in the current color.
    pub fn drawString(self: *const Font, text: []const u8, x: f32, y: f32) void {
        var s: String = .init(text);
        defer s.deinit();
        cpp.bind(drawString_sig)(self, &s, x, y);
    }
    pub fn drawStringi(self: *const Font, text: []const u8, x: i32, y: i32) void {
        self.drawString(text, @floatFromInt(x), @floatFromInt(y));
    }

    pub const drawStringAsShapes_sig: Signature = .{ .name = "drawStringAsShapes", .this = *const Font, .args = &.{ Ref(*const String), f32, f32 } };
    /// The same text as filled outlines rather than as the texture atlas,
    /// which is what `ofNoFill` and `ofSetLineWidth` reach. The font must
    /// have been loaded with contours.
    pub fn drawStringAsShapes(self: *const Font, text: []const u8, x: f32, y: f32) void {
        var s: String = .init(text);
        defer s.deinit();
        cpp.bind(drawStringAsShapes_sig)(self, &s, x, y);
    }
    pub fn drawStringAsShapesi(self: *const Font, text: []const u8, x: i32, y: i32) void {
        self.drawStringAsShapes(text, @floatFromInt(x), @floatFromInt(y));
    }
};
