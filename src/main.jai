main :: ()
{
    fmt := *context.print_style.default_format_struct;
    fmt.draw_type_name = true;
    fmt.use_long_form_if_more_than_this_many_members = -1;
    fmt.use_newlines_if_long_form = true;
    fmt.long_form_separator_between_fields = ";";

    window := open_window(1280, 720);
    window_equip(window);

    font_init();
    roboto_mono := font_open("data/fonts/Roboto-Regular.ttf");
    font_metrics_from_font(roboto_mono);
    result := raster(arena.allocator, roboto_mono, 16.0, 0, "Hello Jai");
    log("%", result);
    font_close(roboto_mono);

    draw_init();

    quit := false;
    last_time := seconds_since_init();

    while !quit
    {
        now := seconds_since_init();
        delta := now - last_time;
        context.dt = cast(f32)delta;
        if context.dt > 0.15 context.dt = 0.15;
        last_time = now;

        events := get_events();
        for events
        {
            if it.kind == .Quit || it.key == .Esc then quit = true;
        }

        draw_begin_frame();
        begin_frame(window);
        {
            draw_rect(.{10,  20, 110, 120}, .{.1, .2, .3, 1});
            draw_rect(.{210, 20, 310, 120}, .{.9, .8, .7, 1});
        }
        end_frame(window);

        sleep_milliseconds(16);
        context.frame += 1;
        context.time += context.dt;
    }
}

#import "Basic"()(MEMORY_DEBUGGER = true);
#import "Base";
arena :: #import "Arena";

#load "Window/window.jai";
#load "Render/render.jai";
#load "draw.jai";
#load "Font/font.jai";

backend : Backend : .OPENGL;

#add_context frame : u64 = 0;
#add_context dt    : f32 = 0;
#add_context time  : f32 = 0;
