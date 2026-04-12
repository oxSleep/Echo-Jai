#if OS == .WINDOWS
{
    hdc: HDC;
    hglrc: HGLRC;
    window_equip :: (window: Window_Handle)
    {
        hglrc, hdc, _ = wgl_create_context(window, null, 3, 3);
    }

    swap_buffer :: ()
    {
        SwapBuffers(hdc);
    }
}

begin_frame :: (window: Window_Handle)
{
    viewport_rect := rect_from_window(window);
    viewport_dim := dim_2f32(viewport_rect);

    glViewport(0, 0, xx viewport_dim.x, xx viewport_dim.y);
    glClearColor(.18, .18, .18, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
}

end_frame :: ()
{
    swap_buffer();
}

#scope_module
