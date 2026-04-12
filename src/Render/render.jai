Backend :: enum { OPENGL; }

draw_init :: ()
{
    draw_arena = arena_make(); 
    allocator := Allocator.{arena_allocator_proc, draw_arena};
    batchs.allocator = allocator;
    xform_stack.allocator = allocator;
    clip_stack.allocator = allocator;
    transparency_stack.allocator = allocator;
    draw_frame_mark = arena_mark(draw_arena);
}

draw_rect :: (dst: Rng2f, color: Vec4f)
{
    group: *Rect_Group;

    if batchs.count > 0 && state_gen == last_cmd_state_gen
    {
        group = peek_pointer(batchs);
    }

    if group == null
    {
        group = array_add(*batchs);
        group.rects.allocator = Allocator.{arena_allocator_proc, draw_arena};
        group.xform = top_xform();
        group.clip = top_clip();
        group.transparency = top_transparency();
    }

    inst := array_add(*group.rects);
    inst.dst   = dst;
    inst.color = color;

    last_cmd_state_gen = state_gen;
}

push_xform :: (xform: Matrix3) -> Matrix3
{
    old := top_xform();
    array_add(*xform_stack, xform);
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
    array_add(*clip_stack, clip);
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
    array_add(*transparency_stack, transparency);
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

reset_draw_state :: ()
{
    array_reset(*batchs);
    array_reset(*xform_stack);
    array_reset(*clip_stack);
    array_reset(*transparency_stack);

    array_add(*xform_stack, Matrix3_Identity);
    array_add(*clip_stack, .{});
    array_add(*transparency_stack, 0.0);

    state_gen = 0;
    last_cmd_state_gen = -1;
}

Rect_Instance :: struct
{
    dst:   Rng2f;
    color: Vec4f;
}

Rect_Group :: struct
{
    rects: [..]Rect_Instance;

    // texture: u32; // Make a true texture handle in the future
    // texture_sample_kind: u8; // Make a enum in the future (Nearest, Linear)
    xform: Matrix3;
    clip: Rng2f;
    transparency: f32;
}

batchs: [..]Rect_Group;
xform_stack: [..]Matrix3;
clip_stack: [..]Rng2f;
transparency_stack: [..]f32;

draw_arena: *Arena;
draw_frame_mark: s64;
state_gen: s64;
last_cmd_state_gen: s64;

#scope_module

#if OS == .WINDOWS #import "Windows";

#if backend == .OPENGL
{
    #import "GL";
    #load "opengl/opengl.jai";
}

#import "Basic";
#import "String";
#import "Math";
