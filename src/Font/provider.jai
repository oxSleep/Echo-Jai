Metrics :: struct {
    ascent: s32;
    descent: s32;
    line_gap: s32;
    design_units_per_em: s32;
}

Raster_Flags :: enum_flags u8 {
    None   :: 0;
    Smooth :: 1 << 0;
    Hinted :: 1 << 1;
}

Raster_Result :: struct {
    atlas_dim: Vec2u;
    atlas: *void;
    advance: f32;
}

Font :: struct {
    face: FT_Face;
}

Font_State :: struct {
    allocator: Allocator;
    library: FT_Library;
}

font_state: *Font_State;


font_init :: ()
{
    allocator := create_heap(arena_allocator);
    font_state = New(Font_State,, allocator);
    font_state.allocator = allocator;
    FT_Init_FreeType(*font_state.library);
    cache_init();
}

font_open :: (path: string) -> *Font
{
    font := New(Font,, font_state.allocator);
    FT_New_Face(font_state.library, temp_c_string(path), 0, *font.face);
    assert(font.face != null, tprint("Failed to open the font file %", path));
    return font;
}

font_close :: (font: *Font)
{
    assert(font.face != null, "Trying to release a null font");
    FT_Done_Face(font.face);
}

font_metrics_from_font :: (font: *Font) -> Metrics
{
    result: Metrics;
    if font.face != null
    {
        result.design_units_per_em = (font.face.units_per_EM);
        result.ascent              = font.face.ascender;
        result.descent             = font.face.descender;
        result.line_gap            = (font.face.height - font.face.ascender + font.face.descender);
    }
    return result;
}

raster :: (allocator: Allocator, font: Font, size: f32, flags: Raster_Flags, text: string) -> Raster_Result
{
    result: Raster_Result;
    assert(font.face != null, "Trying to to raster something with a null font");

    face := font.face;

    load_flags: FT_Int32 = FT_LOAD_RENDER;
    if (flags & .Hinted) == 0 load_flags |= FT_LOAD_NO_HINTING;

    load_next_glyph :: (face: FT_Face, load_flags: FT_Int32, remaining: *string) -> bool, s32
    {
        if remaining.count == 0 return false, 0;

        codepoint, unicode_result := utf8_next_character(remaining);
        assert(unicode_result == .CONVERSION_OK);

        error := FT_Load_Char(face, cast(FT_ULong)codepoint, load_flags);
        assert(!error, "FT_Load_Char failed.");

        advance := cast(s32)(face.glyph.advance.x >> 6);
        return true, advance;
    }

    blit_current_glyph :: (face: FT_Face, atlas: *u8, atlas_write_x: s32, baseline: s32, dim_x: s32, dim_y: s32)
    {
        bmp := face.glyph.bitmap;
        top := cast(s32)face.glyph.bitmap_top;
        left := cast(s32)face.glyph.bitmap_left;

        row_count := cast(s32)bmp.rows;
        col_count := cast(s32)bmp.width;

        row := 0;
        while row < row_count
        {
            y := baseline - top + row;
            col := 0;
            while col < col_count
            {
                x := atlas_write_x + left + col;
                if x >= 0 && y >= 0 && x < dim_x && y < dim_y
                {
                    off := cast(s64)(y * dim_x + x) * 4;
                    alpha := bmp.buffer[row * cast(s32)bmp.pitch + col];
                    atlas[off + 0] = 255;
                    atlas[off + 1] = 255;
                    atlas[off + 2] = 255;
                    atlas[off + 3] = alpha;
                }
                col += 1;
            }
            row += 1;
        }
    }

    error := FT_Set_Pixel_Sizes(face, 0, cast(FT_UInt)((96.0/72.0) * size));
    assert(!error, "FT_Set_Pixel_Sizes failed.");

    ascent := cast(s32)(face.size.metrics.ascender >> 6);
    height := cast(s32)(face.size.metrics.height >> 6);

    total_width: s32;
    remaining := text;
    while true
    {
        ok, advance := load_next_glyph(face, load_flags, *remaining);
        if !ok break;
        total_width += advance;
    }

    dim_x := total_width + 1;
    dim_y := height + 1;
    if dim_x <= 0 || dim_y <= 0
    {
        result.atlas_dim = .{0, 0};
        result.atlas = null;
        result.advance = 0;
        return result;
    }

    atlas_size := dim_x * dim_y * 4;
    atlas := cast(*u8) alloc(atlas_size,, allocator=allocator);
    assert(atlas != null, "Failed to allocate raster atlas.");
    memset(atlas, 0, atlas_size);

    baseline: s32 = ascent;
    atlas_write_x: s32 = 0;

    remaining = text;
    while true
    {
        ok, advance := load_next_glyph(face, load_flags, *remaining);
        if !ok break;

        blit_current_glyph(face, atlas, atlas_write_x, baseline, dim_x, dim_y);
        atlas_write_x += advance;
    }
    result.atlas_dim = .{cast(u32)dim_x, cast(u32)dim_y};
    result.atlas     = atlas;
    result.advance   = cast(f32)total_width;
    return result;
}

#scope_file

#import "freetype-2.12.1";
#import "Unicode";
