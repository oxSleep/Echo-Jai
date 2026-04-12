f32 :: float32;

Vec2 :: struct
{
    x, y: f32;

    #place x;
    v: [2]f32 = ---;
}

operator + :: inline (a: Vec2, b: Vec2) -> Vec2
{
    return .{
        x = a.x + b.x,
        y = a.y + b.y,
    };
}

Rng2 :: struct
{
    x0, y0, x1, y1: f32;

    #place x0;
    min: Vec2 = ---;
    #place x1;
    max: Vec2 = ---;

    #place x0;
    p0: Vec2 = ---;
    #place x1;
    p1: Vec2 = ---;

    #place x0;
    v: [2]Vec2;
}

dim_2f32 :: inline (r: Rng2) -> Vec2
{
   result: Vec2;
   result.x = ifx r.max.x > r.min.x then r.max.x - r.min.x else 0;
   result.y = ifx r.max.y > r.min.y then r.max.y - r.min.y else 0;
   return result;   
}

#import "Basic";
#load "Window/window.jai";
#load "Render/render.jai";

backend : Backend : .OPENGL;

