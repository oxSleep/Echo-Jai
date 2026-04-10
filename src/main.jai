#import "Basic";
#import "Window";

main :: ()
{
    window := open_window(1280, 720);
    quit := false;

    while !quit
    {
        reset_temporary_storage();
        for get_events()
        {
            if it.kind == .Press log("%\n", it);
            if it.kind == .Text  log("%\n", it);
            if it.key == .K || it.kind == .Quit then quit = true;
        }
        sleep_milliseconds(16);
    }
}

