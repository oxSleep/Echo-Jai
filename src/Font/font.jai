

Tag :: #type,distinct u64;

Style_Key :: struct
{
    tag: Tag;
    size_bits: u32;
}

Piece :: struct
{
    texture: u32;
    subrect: Rng2s16;
    offset:  Vec2s16;
    advance: f32;
    decode_size: u64;
}

Run :: struct
{
    pieces: []Piece;
    dimension: Vec2f;
    ascent:  f32;
    descent: f32;
}

Raster_Info :: struct
{
    subrect: Rng2u16;
    raster_dimension: Vec2u16;
    advance: f32;
}

Font_Node :: struct
{
    tag: Tag;
    font: Font;
    metrics: Metrics;
    path: string;
}

Style_Node :: struct
{
    ascii_direct_map: [256]Raster_Info;
    ascii_direct_mask: [4]u64;

    unicode_glyphs: Table(u64, Raster_Info);
    run_cache:      Table(u64, Run);
    run_frame_index: u64;

    ascent: f32;
    descent: f32;
    line_height: f32;
}

Atlas :: struct
{
    texture: u32;
    dimension: Vec2s16;
    cursor_x: u16;
    cursor_y: u16;
    row_height: u16;
}

Cache_State :: struct
{
    frame_arena:     *Arena;
    raster_arena:    *Arena;
    permanent_arena: *Arena;

    frame_index: u64;

    font_table: Table(Tag, *Font_Node);
    style_table: Table(Style_Key, *Style_Node, given_hash_function = style_key_hash, given_compare_function = style_key_match);

    atlas: Atlas;
}

Scaled_Metrics :: struct
{
    ascent: f32;
    descent: f32;
    line_height: f32;
}

cache_state: *Cache_State;

cache_init :: ()
{
    perm_allocator := create_heap(arena_allocator); 
    cache_state = New(Cache_State,, perm_allocator);
    cache_state.permanent_arena = cast(*Arena)perm_allocator.data;
    cache_state.raster_arena = arena_make();
    cache_state.frame_arena = arena_make();

    cache_state.font_table.allocator = Allocator.{arena_allocator_proc, cache_state.permanent_arena};
    init(*cache_state.font_table, 1);

    cache_reset();
}

cache_reset :: ()
{
    if cache_state.atlas.texture != 0 release_texture(cache_state.atlas.texture);
    cache_state.atlas = .{};
    arena_pop_to(cache_state.raster_arena);

    cache_state.style_table.allocator = Allocator.{arena_allocator_proc, cache_state.raster_arena};
    init(*cache_state.style_table, 2);
}

cache_frame :: ()
{
    cache_state.frame_index += 1;
    arena_pop_to(cache_state.frame_arena);
}

tag_from_path :: (path: string) -> Tag
{
    assert(cache_state != null, "cache_init must be called before tag_from_path.");

    tag := cast(Tag) fnv1a_hash(path.data, path.count);
    node, found := table_find(*cache_state.font_table, tag);
    if found return node.tag;

    allocator := Allocator.{arena_allocator_proc, cache_state.permanent_arena};
    node = New(Font_Node,, allocator);
    node.tag = tag;

    font := font_open(path);
    assert(font != null && font.face != null, tprint("Failed to open font for path %", path));

    node.font = font.*;
    node.metrics = font_metrics_from_font(font);
    node.path = copy_string(path,, allocator=allocator);

    table_add(*cache_state.font_table, tag, node);
    return tag;
}

font_from_tag :: (tag: Tag) -> *Font_Node
{
    assert(cache_state != null, "cache_init must be called before font_from_tag.");

    node, found := table_find(*cache_state.font_table, tag);
    if found return node;
    return null;
}

metrics_from_tag :: (tag: Tag) -> Metrics
{
    result: Metrics;
    node := font_from_tag(tag);
    if node != null result = node.metrics;
    return result;
}

metrics_from_tag_size :: (tag: Tag, size: f32) -> Scaled_Metrics
{
    result: Scaled_Metrics;
    metrics := metrics_from_tag(tag);
    if metrics.design_units_per_em == 0 return result;

    scaled_size := cast(f32) floor(size);
    em := cast(f32) metrics.design_units_per_em;
    result.ascent = scaled_size * cast(f32) metrics.ascent / em;
    result.descent = scaled_size * cast(f32) metrics.descent / em;
    result.line_height = scaled_size * cast(f32) metrics.line_gap / em;
    return result;
}

style_from_tag_size :: (tag: Tag, size: f32) -> *Style_Node
{
    assert(cache_state != null, "cache_init must be called before style_from_tag_size.");

    size_bits: union { value: f32; bits: u32; };
    size_bits.value = size;

    key := Style_Key.{tag, size_bits.bits};
    style, found := table_find(*cache_state.style_table, key);
    if found return style;

    allocator := Allocator.{arena_allocator_proc, cache_state.raster_arena};
    style = New(Style_Node,, allocator);
    style.unicode_glyphs.allocator = allocator;
    init(*style.unicode_glyphs, 256);

    metrics := metrics_from_tag_size(tag, size);
    style.ascent = metrics.ascent;
    style.descent = metrics.descent;
    style.line_height = metrics.line_height;

    table_add(*cache_state.style_table, key, style);
    return style;
}

#load "provider.jai";

#scope_file

style_key_hash :: (key: Style_Key) -> u32
{
    return sdbm_hash(*key, size_of(Style_Key));
}

style_key_match :: (a: Style_Key, b: Style_Key) -> bool
{
    return a.tag == b.tag && a.size_bits == b.size_bits;
}

#import "Hash_Table";
#import "Hash";
#import "Basic";
