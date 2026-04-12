main :: ()
{
    window := open_window(1280, 720);
    window_equip(window);
    quit := false;

    a := Vec2.{30, 30};
    b := Vec2.{30, 30};
    print("%\n", a + b);

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

#load "base.jai";
