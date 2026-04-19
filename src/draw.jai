draw_begin_frame :: ()
{
    for batchs array_reset(*it.rects);
    arena_array_rewind(*batchs);

    xform_stack_storage[0] = Matrix3_Identity;
    xform_stack = array_view(xform_stack_storage, 0, 1);

    clip_stack_storage[0] = .{};
    clip_stack = array_view(clip_stack_storage, 0, 1);

    transparency_stack_storage[0] = 0.0;
    transparency_stack = array_view(transparency_stack_storage, 0, 1);

    state_gen = 0;
    last_cmd_state_gen = -1;
}

draw_init :: ()
{
    arena_array_init(*batchs);
}

draw_rect :: (dst: Rng2f, color: Vec4f, corner_radius := 0.0, border_thickness := 0.0, edge_softness := 0.0)
{
    group: *Rect_Group;

    if batchs.count > 0 && state_gen == last_cmd_state_gen
    {
        group = peek_pointer(batchs);
    }

    if group == null
    {
        group = array_add(*batchs);
        group.rects.allocator = batchs.allocator;
        group.xform = top_xform();
        group.clip = top_clip();
        group.transparency = top_transparency();
        group.texture = 0;
        group.texture_sample_kind = .Nearest;
    }

    inst := array_add(*group.rects);
    inst.dst   = dst;
    inst.src   = .{0, 0, 1, 1};
    inst.color = color;
    inst.style.x = border_thickness;
    inst.style.y = edge_softness;
    inst.style.z = 1.0; // white_texture_overide

    last_cmd_state_gen = state_gen;
}

push_xform :: (xform: Matrix3) -> Matrix3
{
    old := top_xform();
    assert(xform_stack.count < DRAW_STACK_CAPACITY, "Xform stack overflow.");
    xform_stack[xform_stack.count] = xform;
    xform_stack.count += 1;
    state_gen += 1;
    return old;
}

pop_xform :: () -> Matrix3
{
    assert(xform_stack.count > 1, "Tried to pop the default xform state.");
    popped := pop(*xform_stack);
    state_gen += 1;
    return popped;
}

top_xform :: () -> Matrix3 { return peek(xform_stack); }

push_clip :: (clip: Rng2f) -> Rng2f
{
    old := top_clip();
    assert(clip_stack.count < DRAW_STACK_CAPACITY, "Clip stack overflow.");
    clip_stack[clip_stack.count] = clip;
    clip_stack.count += 1;
    state_gen += 1;
    return old;
}

pop_clip :: () -> Rng2f
{
    assert(clip_stack.count > 1, "Tried to pop the default clip state.");
    popped := pop(*clip_stack);
    state_gen += 1;
    return popped;
}

top_clip :: () -> Rng2f { return peek(clip_stack); }

push_transparency :: (transparency: f32) -> f32
{
    old := top_transparency();
    assert(transparency_stack.count < DRAW_STACK_CAPACITY, "Transparency stack overflow.");
    transparency_stack[transparency_stack.count] = transparency;
    transparency_stack.count += 1;
    state_gen += 1;
    return old;
}

pop_transparency :: () -> f32
{
    assert(transparency_stack.count > 1, "Tried to pop the default transparency state.");
    popped := pop(*transparency_stack);
    state_gen += 1;
    return popped;
}

top_transparency :: () -> f32 { return peek(transparency_stack); }


batchs: [..]Rect_Group;
xform_stack_storage: [DRAW_STACK_CAPACITY]Matrix3;
xform_stack: []Matrix3;

clip_stack_storage: [DRAW_STACK_CAPACITY]Rng2f;
clip_stack: []Rng2f;

transparency_stack_storage: [DRAW_STACK_CAPACITY]f32;
transparency_stack: []f32;

state_gen: s64;
last_cmd_state_gen: s64;

DRAW_STACK_CAPACITY :: 16;
