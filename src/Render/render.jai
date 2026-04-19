Backend :: enum { OPENGL; }

Resource_Kind :: enum
{
    Static;
    Dynamic;
    Stream;
}

Texture_Format :: enum
{
    R8;
    RG8;
    RGBA8;
    BGRA8;
    R16;
    RGBA16;
    R32;
    RG32;
    RGBA32;
    D32;
}

Texture_Sample_Kind :: enum
{
    Nearest;
    Linear;
}

Rect_Instance :: struct
{
    dst:   Rng2f;
    src:   Rng2f;
    color: Vec4f;
    style: Vec4f;
}


Rect_Group :: struct
{
    rects: [..]Rect_Instance;

    texture: u32; // Make a true texture handle in the future
    texture_sample_kind: Texture_Sample_Kind;
    xform: Matrix3;
    clip: Rng2f;
    transparency: f32;
}

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
