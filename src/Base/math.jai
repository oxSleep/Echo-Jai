Vec2 :: struct(T: Type)
{
    x, y: T;
    #place x; v: [2]T = ---;
}

operator + :: inline (a: Vec2($T), b: Vec2(T)) -> Vec2(T)
{
    return .{
        x = a.x + b.x,
        y = a.y + b.y,
    };
}

Vec2f :: Vec2(f32);
Vec2s :: Vec2(s32);
Vec2u :: Vec2(u32);

Vec3 :: struct(T: Type)
{
    x, y, z: f32;
    #place x; xy: Vec2(T) = ---;
    #place y; yz: Vec2(T) = ---;
    #place x; v:  [3]f32  = ---;
}

Vec3f :: Vec3(f32);
Vec3s :: Vec3(s32);
Vec3u :: Vec3(u32);

Vec4 :: struct(T: Type)
{
    x, y, z, w: T;

    #place x; xy:  Vec2(T) = ---;
    #place y; yz:  Vec2(T) = ---;
    #place z; zw:  Vec2(T) = ---;
    #place x; xyz: Vec3(T) = ---;
    #place y; yzw: Vec3(T) = ---;
    #place x; v:   [4]T    = ---;
}

Vec4f :: Vec4(f32);
Vec4s :: Vec4(s32);
Vec4u :: Vec4(u32);

operator == :: (a: Vec4($T), b: Vec4(T)) -> bool {
    return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;
}

Rng2 :: struct(T: Type)
{
    x0, y0, x1, y1: T;

    #place x0; min: Vec2(T) = ---;
    #place x1; max: Vec2(T) = ---;
    #place x0; p0:  Vec2(T) = ---;
    #place x1; p1:  Vec2(T) = ---;
    #place x0; v:   [2]Vec2(T);
}

dim2 :: inline (r: Rng2($T)) -> Vec2(T)
{
    result: Vec2(T);
    result.x = ifx r.max.x > r.min.x then r.max.x - r.min.x else 0;
    result.y = ifx r.max.y > r.min.y then r.max.y - r.min.y else 0;
    return result;
}

Rng2f :: Rng2(f32);
Rng2s :: Rng2(s32);
Rng2u :: Rng2(u32);
