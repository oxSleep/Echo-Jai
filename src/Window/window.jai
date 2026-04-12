#if OS == .WINDOWS
{
    #load "win32.jai";
    Window_Handle :: HWND;
}

#scope_module;

#import "Basic";
#import "Flat_Pool";

Modifiers :: enum_flags u8
{
    None  :: 0;
    Ctrl  :: 1 << 0;
    Shift :: 1 << 1;
    Alt   :: 1 << 2;
}

Key :: enum u8
{
    Null;

    // special key
    Esc;
    Tab;
    Return;
    Backspace;
    Space;

    // function key
    F1; F2; F3; F4; F5;
    F6; F7; F8; F9; F10;
    F11; F12;

    // number row
    Tick;
    Num_0; Num_1; Num_2; Num_3; Num_4;
    Num_5; Num_6; Num_7; Num_8; Num_9;
    Minus; Equal;

    // letter
    Q; W; E; R; T; Y; U; I; O; P;
    A; S; D; F; G; H; J; K; L;
    Z; X; C; V; B; N; M;
    Left_Bracket; Right_Bracket; Back_Slash;
    Semicolon; Quote;
    Comma; Period;

    // modifier keys
    Caps_Lock; Shift; Ctrl; Alt;

    // navigation keys
    Insert;  Home;
    Page_Up; Delete;
    End;     Page_Down;
    Up;      Left;
    Down;    Right;

    // mouse button
    Left_Mouse;
    Middle_Mouse;
    Right_Mouse;
}

Event_Kind :: enum 
{
    Null;
    Press;
    Release;
    Text;
    Scroll;
    Quit;
    Drop;
}

Event :: struct
{
    kind := Event_Kind.Null;

    key := Key.Null;
    modifiers: Modifiers;

    character: u64;
    is_repeat: bool;
    right_sided: bool;
    mouse_position: [2]int;
}

Event_Pool :: struct
{
    pool: Flat_Pool;
    events: [..] Event;
}

