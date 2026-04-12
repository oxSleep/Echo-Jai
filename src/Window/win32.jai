open_window :: (width: int, height: int, title := "Jai") -> Window_Handle
{
    error     := GetLastError();
    hinstance := GetModuleHandleW(null);

    // register window class
    {
        wc: WNDCLASSEXW;
        wc.cbSize        = size_of(WNDCLASSEXW);
        wc.lpfnWndProc   = xx WndProc;
        wc.hInstance     = hinstance;
        wc.lpszClassName = utf8_to_wide(WINDOW_CLASS_NAME,, temp);
        wc.lpszMenuName  = null;
        wc.style         = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
        RegisterClassExW(*wc);
    }

    // create window
    {
        state.hwnd = CreateWindowExW(WS_EX_APPWINDOW,
        utf8_to_wide(WINDOW_CLASS_NAME,, temp),
        utf8_to_wide(title,, temp),
        WINDOWED_STYLE,
        30, 30,
        xx width, xx height,
        null, null,
        hinstance,
        null);
    }

    UpdateWindow(state.hwnd);
    ShowWindow(state.hwnd, SW_SHOW);

    return state.hwnd;
}

get_events :: () -> [] Event
{
    if state.events.allocator.proc == null state.events.allocator = Allocator.{flat_pool_allocator_proc, *state.pool};
    array_reset_keeping_memory(*state.events);
    reset(*state.pool);
    while true
    {
        message: MSG;
        result := PeekMessageW(*message, null, 0, 0, PM_REMOVE);
        if !result break;
        TranslateMessage(*message);
        DispatchMessageW(*message);
    }
    return state.events;
}

rect_from_window :: (window: Window_Handle) -> Rng2
{
    result: Rng2;
    {
        rect: RECT;
        GetClientRect(window, *rect);
        result.x0 = cast(f32)rect.left;
        result.x1 = cast(f32)rect.right;
        result.y0 = cast(f32)rect.top;
        result.y1 = cast(f32)rect.bottom;
    }
    return result;
}

#scope_file

WINDOW_CLASS_NAME :: "Jai-Window-Class";
WINDOWED_STYLE : u32 : WS_OVERLAPPEDWINDOW;

key_from_vkey :: (wParam: WPARAM) -> Key
{
    return Key_Table[cast(int)(wParam & 0xFF)];
}

WndProc :: (hWnd: HWND, message: u32, wParam: WPARAM, lParam: LPARAM) -> s64 #c_call
{
    result := 0;
    release := false;
    push_context
    {
        if message == 
        {
            case; return DefWindowProcW(hWnd, message, wParam, lParam);
            case WM_CLOSE; #through;
            case WM_QUIT;  #through;
            case WM_DESTROY;
                event: Event;
                event.kind = .Quit;
                array_add(*state.events, event);

            case WM_LBUTTONUP; #through;
            case WM_MBUTTONUP; #through;
            case WM_RBUTTONUP; release = true; #through;
            case WM_LBUTTONDOWN; #through;
            case WM_MBUTTONDOWN; #through;
            case WM_RBUTTONDOWN;
            {
                event: Event;
                event.kind = ifx release then .Release else .Press;
                if message == 
                {
                    case WM_LBUTTONUP;case WM_LBUTTONDOWN; event.key = .Left_Mouse;
                    case WM_MBUTTONUP;case WM_MBUTTONDOWN; event.key = .Middle_Mouse;
                    case WM_RBUTTONUP;case WM_RBUTTONDOWN; event.key = .Right_Mouse;
                }
                event.mouse_position[0] = (lParam & 0xffff);
                event.mouse_position[1] = (lParam >> 16) & 0xffff;
                array_add(*state.events, event);
                if release then ReleaseCapture(); else SetCapture(state.hwnd);
            }
            case WM_SYSKEYDOWN; #through;
            case WM_SYSKEYUP;
            {
                if wParam != VK_MENU && (wParam < VK_F1 || VK_F24 < wParam || wParam == VK_F4)
                {
                    result = DefWindowProcW(hWnd, message, wParam, lParam);
                }
            } #through;
            case WM_KEYDOWN; #through;
            case WM_KEYUP;
            {
                was_down := (lParam & 0x40000000) != 0;
                is_down  := (lParam & 0x80000000) == 0;
                is_repeat := false;
                if !is_down release = true; else if was_down is_repeat = true;

                event: Event;
                event.kind = ifx release then .Release else .Press;
                event.key = key_from_vkey(wParam);
                event.is_repeat = is_repeat;
                event.modifiers = modifiers_from_win32();
                if event.key == .Alt   && (event.modifiers & .Alt)   event.modifiers &= ~.Alt;
                if event.key == .Ctrl  && (event.modifiers & .Ctrl)  event.modifiers &= ~.Ctrl;
                if event.key == .Shift && (event.modifiers & .Shift) event.modifiers &= ~.Shift;
                array_add(*state.events, event);
            }
            case WM_SYSCHAR;
            case WM_CHAR;
            {
                character := wParam;
                if(character >= 32 && character != 127)
                {
                    event: Event;
                    event.kind = .Text;
                    if (lParam & (1 << 29))
                    {
                        event.modifiers |= .Alt;
                    }
                    event.character = character;
                    array_add(*state.events, event);
                }
            }
        }
    }
    return result;
}

modifiers_from_win32 :: () -> Modifiers
{
    modifiers := Modifiers.None;
    if (GetKeyState(VK_CONTROL) & 0x8000) != 0 modifiers |= .Ctrl;
    if (GetKeyState(VK_SHIFT)   & 0x8000) != 0 modifiers |= .Shift;
    if (GetKeyState(VK_MENU)    & 0x8000) != 0 modifiers |= .Alt;
    return modifiers;
}

Key_Table :: #run -> [256]Key
{
    table: [256]Key;
    for table it = .Null;

    // letters
    table[#char "A"] = .A;
    table[#char "B"] = .B;
    table[#char "C"] = .C;
    table[#char "D"] = .D;
    table[#char "E"] = .E;
    table[#char "F"] = .F;
    table[#char "G"] = .G;
    table[#char "H"] = .H;
    table[#char "I"] = .I;
    table[#char "J"] = .J;
    table[#char "K"] = .K;
    table[#char "L"] = .L;
    table[#char "M"] = .M;
    table[#char "N"] = .N;
    table[#char "O"] = .O;
    table[#char "P"] = .P;
    table[#char "Q"] = .Q;
    table[#char "R"] = .R;
    table[#char "S"] = .S;
    table[#char "T"] = .T;
    table[#char "U"] = .U;
    table[#char "V"] = .V;
    table[#char "W"] = .W;
    table[#char "X"] = .X;
    table[#char "Y"] = .Y;
    table[#char "Z"] = .Z;

    // number row
    table[#char "0"] = .Num_0;
    table[#char "1"] = .Num_1;
    table[#char "2"] = .Num_2;
    table[#char "3"] = .Num_3;
    table[#char "4"] = .Num_4;
    table[#char "5"] = .Num_5;
    table[#char "6"] = .Num_6;
    table[#char "7"] = .Num_7;
    table[#char "8"] = .Num_8;
    table[#char "9"] = .Num_9;
    table[VK_OEM_3]     = .Tick;
    table[VK_OEM_MINUS] = .Minus;
    table[VK_OEM_PLUS]  = .Equal;

    // punctuation
    table[VK_OEM_1]      = .Semicolon;
    table[VK_OEM_4]      = .Left_Bracket;
    table[VK_OEM_5]      = .Back_Slash;
    table[VK_OEM_6]      = .Right_Bracket;
    table[VK_OEM_7]      = .Quote;
    table[VK_OEM_COMMA]  = .Comma;
    table[VK_OEM_PERIOD] = .Period;

    // special keys
    table[VK_ESCAPE] = .Esc;
    table[VK_TAB]    = .Tab;
    table[VK_RETURN] = .Return;
    table[VK_BACK]   = .Backspace;
    table[VK_SPACE]  = .Space;

    // function keys
    table[VK_F1]  = .F1;
    table[VK_F2]  = .F2;
    table[VK_F3]  = .F3;
    table[VK_F4]  = .F4;
    table[VK_F5]  = .F5;
    table[VK_F6]  = .F6;
    table[VK_F7]  = .F7;
    table[VK_F8]  = .F8;
    table[VK_F9]  = .F9;
    table[VK_F10] = .F10;
    table[VK_F11] = .F11;
    table[VK_F12] = .F12;

    // modifier keys
    table[VK_CAPITAL]  = .Caps_Lock;
    table[VK_SHIFT]    = .Shift;
    table[VK_LSHIFT]   = .Shift;
    table[VK_RSHIFT]   = .Shift;
    table[VK_CONTROL]  = .Ctrl;
    table[VK_LCONTROL] = .Ctrl;
    table[VK_RCONTROL] = .Ctrl;
    table[VK_MENU]     = .Alt;
    table[VK_LMENU]    = .Alt;
    table[VK_RMENU]    = .Alt;

    // navigation keys
    table[VK_INSERT] = .Insert;
    table[VK_HOME]   = .Home;
    table[VK_PRIOR]  = .Page_Up;
    table[VK_DELETE] = .Delete;
    table[VK_END]    = .End;
    table[VK_NEXT]   = .Page_Down;
    table[VK_UP]     = .Up;
    table[VK_LEFT]   = .Left;
    table[VK_DOWN]   = .Down;
    table[VK_RIGHT]  = .Right;

    // mouse buttons
    table[VK_LBUTTON] = .Left_Mouse;
    table[VK_MBUTTON] = .Middle_Mouse;
    table[VK_RBUTTON] = .Right_Mouse;

    return table;
}

State :: struct
{
    hwnd: HWND;
    hdc: HDC;
    using event_list: Event_Pool;
}
state: State;

#import "Windows";
#import "Windows_Utf8";
