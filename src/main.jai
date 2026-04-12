main :: ()
{
    window := open_window(1280, 720);
    window_equip(window);
    quit := false;

    while !quit
    {
        reset_temporary_storage();
        for get_events()
        {
            if it.kind == .Quit then quit = true;
        }

        begin_frame(window);
        end_frame();

        sleep_milliseconds(16);
    }
}

#import "Base";
#import "Arena";

#load "Window/window.jai";
#load "Render/render.jai";

backend : Backend : .OPENGL;
