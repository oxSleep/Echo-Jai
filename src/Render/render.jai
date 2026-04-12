Backend :: enum
{
    OPENGL;
}

#scope_module

#if OS == .WINDOWS #import "Windows";

#if backend == .OPENGL
{
    #import "GL";
    #load "opengl/opengl.jai";
}

#import "Basic";
#import "Math";
#import "String";
