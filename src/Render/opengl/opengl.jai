#if OS == .WINDOWS
{
    hdc: HDC;
    hglrc: HGLRC;
    window_equip :: (window: Window_Handle)
    {
        hglrc, hdc, _ = wgl_create_context(window, null, 3, 3, wanted_msaa = 8); 
        gl_load(*gl);

        shader = load_shader(MY_SHADER);
        glGenVertexArrays(1, *vao);
        glBindVertexArray(vao);

        glGenBuffers(1, *vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, kilobytes(64), null, GL_DYNAMIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, size_of(Rect_Instance), null);
        glVertexAttribDivisor(0, 1);

        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, size_of(Rect_Instance), cast(*void)16);
        glVertexAttribDivisor(1, 1); 

    }

    swap_buffer  :: () { SwapBuffers(hdc); }
}

begin_frame :: (window: Window_Handle)
{
    viewport_rect := rect_from_window(window);
    viewport_dim := dim2(viewport_rect);

    glViewport(0, 0, viewport_dim.x, viewport_dim.y);
    glClearColor(.18, .18, .18, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    arena_pop_to(draw_arena, draw_frame_mark);
    reset_draw_state();
}

end_frame :: (window: Window_Handle)
{
    viewport_rect := rect_from_window(window);
    viewport_dim := dim2(viewport_rect);

    glUseProgram(shader);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);

    time_loc := glGetUniformLocation(shader, "time");
    glUniform1f(time_loc, context.time);

    viewport_loc := glGetUniformLocation(shader, "viewport");
    glUniform2f(viewport_loc, cast(f32)viewport_dim.x, cast(f32)viewport_dim.y);

for batchs if it.rects.count > 0
    {
        glBufferSubData(GL_ARRAY_BUFFER, 0, it.rects.count * size_of(Rect_Instance), it.rects.data);
        glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, cast(u32)it.rects.count);
    }

swap_buffer();
}

#scope_file

vao:    GLuint;
vbo:    GLuint;
shader: GLuint;

load_shader :: (shader_source: string) -> GLuint
{
    make_shader_object :: (shader: string, prefix: string, shader_type: GLenum) -> GLuint
    {
        shader_object := glCreateShader(shader_type);

        shaders: [2]*u8;
        lengths: [2]s32;

        shaders[0] = prefix.data;
        shaders[1] = shader.data;
        lengths[0] = cast(s32)prefix.count;
        lengths[1] = cast(s32)shader.count;

        glShaderSource(shader_object, 2, shaders.data, lengths.data);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success 
        {
            log_data: [1024] u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            log("%", to_string(log_data.data), flags=.ERROR);
            exit(1);
        }
        return shader_object;
    }

    PREFIX_V :: #string END
    #version 330 core
    #define VERTEX_SHADER
    #define OUT_IN out
    END

    PREFIX_F :: #string END
    #version 330 core
    #define FRAGMENT_SHADER
    #define OUT_IN in
    END

    shader_v := make_shader_object(shader_source, PREFIX_V, GL_VERTEX_SHADER);
    shader_f := make_shader_object(shader_source, PREFIX_F, GL_FRAGMENT_SHADER);
    shader_p := glCreateProgram();

    glAttachShader(shader_p, shader_v);
    glAttachShader(shader_p, shader_f);
    glLinkProgram(shader_p);

    success : GLint = 0;
    glGetProgramiv(shader_p, GL_LINK_STATUS, *success);

    if !success
    {
        log_data: [1024] u8;
        glGetProgramInfoLog(shader_p, log_data.count, null, log_data.data);
        log_error("%", to_string(log_data.data));
        return 0;
    }

    glDeleteShader(shader_v);
    glDeleteShader(shader_f);

    return shader_p;
}

MY_SHADER :: #string END
OUT_IN vec4 out_color;

#ifdef VERTEX_SHADER

layout(location = 0) in vec4 screen_rect;
layout(location = 1) in vec4 color;
uniform vec2 viewport;

void main(void)
{
    vec2 vertices[] = vec2[](vec2(-1, -1), vec2(-1, +1), vec2(+1, -1), vec2(+1, +1));

    vec2 screen_half_size = (screen_rect.zw - screen_rect.xy) / 2.0;
    vec2 screen_center    = (screen_rect.zw + screen_rect.xy) / 2.0;
    vec2 screen_position  = vertices[gl_VertexID] * screen_half_size + screen_center;

    vec2 ndc = (screen_position / viewport) * 2.0 - 1.0;
    ndc.y = -ndc.y; 
    gl_Position = vec4(ndc, 0.0, 1.0);

    out_color = color;
}

#endif // VERTERX_SHADER

#ifdef FRAGMENT_SHADER

uniform float time;
out vec4 frag_color;

void main(void)
{
    vec3 color = 0.5 + 0.5 * cos(time + vec3(0.0, 2.0, 4.0));
    frag_color = out_color;
}

#endif // FRAGMENT_SHADER
END
