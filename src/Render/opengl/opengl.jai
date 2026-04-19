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

        // fallback checkerboard texture
        checkerboard_pixels: [16]u8 = u8.[255, 0, 255, 255,
                                          0,   0,   0, 255,
                                          0,   0,   0, 255,
                                          255, 0, 255, 255];
        glGenTextures(1, *debug_texture);
        glBindTexture(GL_TEXTURE_2D, debug_texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 2, 2, 0, GL_RGBA, GL_UNSIGNED_BYTE, checkerboard_pixels.data);
        // glEnable(GL_FRAMEBUFFER_SRGB);

        bind_instance_attributes(Rect_Instance, RECT_INSTANCE_ATTRIBUTE_BINDINGS);

    }

    swap_buffer  :: () { SwapBuffers(hdc); }
}

make_texture :: (kind: Resource_Kind, size: Vec2u, format: Texture_Format, data: *void) -> u32
{
    // init texture array
    if textures.allocator.proc == null arena.array_init(*textures);

    texture := array_add(*textures);
    gl_format := ogl_format_from_texture_format(format);

    glGenTextures(1, *texture.id);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexImage2D(GL_TEXTURE_2D, 0, gl_format.internal_format, size.x, size.y, 0, gl_format.format, gl_format.base_type, data);
    glBindTexture(GL_TEXTURE_2D, 0);

    texture.kind = kind;
    texture.format = format;
    texture.size = size;

    return cast(u32)textures.count;
}

fill_region_texture :: (texture: u32, region: Rng2s, data: *void)
{
    assert(texture != 0, "Invalid texture handle.");

    slot_index := cast(s64)texture - 1;
    assert(slot_index >= 0 && slot_index < textures.count, "Texture handle % is out of range.", texture);

    tex := textures[slot_index];
    rect_dim := dim2(region);

    assert(rect_dim.x >= 0 && rect_dim.y >= 0, "Texture region must have non-negative size.");
    assert(region.x0 >= 0 && region.y0 >= 0, "Texture region origin must be non-negative.");
    assert(region.x1 <= cast(s32)tex.size.x && region.y1 <= cast(s32)tex.size.y, "Texture region exceeds texture bounds.");

    gl_format := ogl_format_from_texture_format(tex.format);

    glBindTexture(GL_TEXTURE_2D, tex.id);
    glTexSubImage2D(GL_TEXTURE_2D,
                    0,
                    cast(GLint)region.x0,
                    cast(GLint)region.y0,
                    cast(GLsizei)rect_dim.x,
                    cast(GLsizei)rect_dim.y,
                    gl_format.format,
                    gl_format.base_type,
                    data);
    glBindTexture(GL_TEXTURE_2D, 0);
}

release_texture :: (texture: u32)
{
    assert(texture != 0, "Invalid texture handle.");

    slot_index := cast(s64)texture - 1;
    assert(slot_index >= 0 && slot_index < textures.count, "Texture handle % is out of range.", texture);

    tex := *textures[slot_index];
    assert(tex.id != 0, "Texture handle % was already released.", texture);

    glDeleteTextures(1, *tex.id);

    tex.id = 0;
    tex.kind = .Static;
    tex.format = .RGBA8;
    tex.size = .{0, 0};
}

begin_frame :: (window: Window_Handle)
{
    viewport_rect := rect_from_window(window);
    viewport_dim := dim2(viewport_rect);

    glViewport(0, 0, viewport_dim.x, viewport_dim.y);
    glClearColor(.18, .18, .18, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
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

    texture_loc := glGetUniformLocation(shader, "color_texture");
    glUniform1i(texture_loc, 0);

    for batchs if it.rects.count > 0
    {

        // unpack texture
        texture_format : Texture_Format = .RGBA8;
        texture_id := debug_texture;
        if it.texture != 0
        {
            slot_index := cast(s64)it.texture - 1;
            tex := textures[slot_index];
            texture_id = tex.id;
            texture_format = tex.format;
        }

        // bind texture
        {
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, texture_id);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

            if it.texture_sample_kind == .Linear
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            }
            else
            {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            }

            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
        }

        glBufferSubData(GL_ARRAY_BUFFER, 0, it.rects.count * size_of(Rect_Instance), it.rects.data);

        if it.clip != 0
        {
            scissor_x0 := cast(GLint)clamp(0, cast(int)floor(it.clip.x0), viewport_dim.x);
            scissor_x1 := cast(GLint)clamp(0, cast(int)floor(it.clip.x1), viewport_dim.x);
            scissor_y0 := cast(GLint)clamp(0, cast(int)floor(it.clip.y0), viewport_dim.y);
            scissor_y1 := cast(GLint)clamp(0, cast(int)floor(it.clip.y1), viewport_dim.y);
            scissor_w := cast(GLsizei)max(0, scissor_x1 - scissor_x0);
            scissor_h := cast(GLsizei)max(0, scissor_y1 - scissor_y0);
            glScissor(scissor_x0, cast(GLint)viewport_dim.y - scissor_y1, scissor_w, scissor_h);
            glEnable(GL_SCISSOR_TEST);
        }

        glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, cast(u32)it.rects.count);
        glDisable(GL_SCISSOR_TEST);
    }

    swap_buffer();
}

#scope_file

vao:    GLuint;
vbo:    GLuint;
shader: GLuint;
debug_texture: GLuint;
textures: [..]Texture;

Texture :: struct
{
    id: GLuint;
    kind: Resource_Kind;
    format: Texture_Format;
    size: Vec2u;
}

OGL_Format_Info :: struct
{
    internal_format: GLint;
    format: GLenum;
    base_type: GLenum;
}

Attribute_Binding :: struct
{
    location: GLuint;
    field_name: string;
    component_count: GLint;
    gl_type: GLenum;
    normalized: GLboolean;
    divisor: GLuint;
}


RECT_INSTANCE_ATTRIBUTE_BINDINGS :: Attribute_Binding.[
    .{0, "dst",   4, GL_FLOAT, GL_FALSE, 1},
    .{1, "src",   4, GL_FLOAT, GL_FALSE, 1},
    .{2, "color", 4, GL_FLOAT, GL_FALSE, 1},
    .{3, "style", 4, GL_FLOAT, GL_FALSE, 1},
];

bind_instance_attributes :: ($T: Type, bindings: []Attribute_Binding)
{
    info := cast(*Type_Info_Struct)type_info(T);
    stride := cast(GLsizei)size_of(T);

    for bindings
    {
        member, offset := get_field(info, it.field_name);
        assert(member != null, "Missing attribute field '%'.", it.field_name);

        glEnableVertexAttribArray(it.location);
        glVertexAttribPointer(it.location,
                              it.component_count,
                              it.gl_type,
                              it.normalized,
                              stride,
                              cast(*void)offset);
        glVertexAttribDivisor(it.location, it.divisor);
    }
}

ogl_format_from_texture_format :: (fmt: Texture_Format) -> OGL_Format_Info
{
    result: OGL_Format_Info;

    if fmt == {
        case .R8;
            result.internal_format = GL_R8;
            result.format = GL_RED;
            result.base_type = GL_UNSIGNED_BYTE;

        case .RG8;
            result.internal_format = GL_RG8;
            result.format = GL_RG;
            result.base_type = GL_UNSIGNED_BYTE;

        case .RGBA8;
            result.internal_format = GL_RGBA8;
            result.format = GL_RGBA;
            result.base_type = GL_UNSIGNED_BYTE;

        case .BGRA8;
            result.internal_format = GL_RGBA8;
            result.format = GL_BGRA;
            result.base_type = GL_UNSIGNED_BYTE;

        case .R16;
            result.internal_format = GL_R16;
            result.format = GL_RED;
            result.base_type = GL_UNSIGNED_SHORT;

        case .RGBA16;
            result.internal_format = GL_RGBA16;
            result.format = GL_RGBA;
            result.base_type = GL_UNSIGNED_SHORT;

        case .R32;
            result.internal_format = GL_R32F;
            result.format = GL_RED;
            result.base_type = GL_FLOAT;

        case .RG32;
            result.internal_format = GL_RG32F;
            result.format = GL_RG;
            result.base_type = GL_FLOAT;

        case .RGBA32;
            result.internal_format = GL_RGBA32F;
            result.format = GL_RGBA;
            result.base_type = GL_FLOAT;

        case .D32;
            result.internal_format = GL_DEPTH_COMPONENT32F;
            result.format = GL_DEPTH_COMPONENT;
            result.base_type = GL_FLOAT;

        case;
            result.internal_format = GL_RGBA8;
            result.format = GL_RGBA;
            result.base_type = GL_UNSIGNED_BYTE;
    }

    return result;
}

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
OUT_IN vec2 out_uv;
OUT_IN float out_omit_texture;
uniform sampler2D color_texture;

#ifdef VERTEX_SHADER

layout(location = 0) in vec4 screen_rect;
layout(location = 1) in vec4 texture_rect;
layout(location = 2) in vec4 color;
layout(location = 3) in vec4 style;

uniform vec2 viewport;

void main(void)
{
    vec2 vertices[] = vec2[](vec2(-1, -1), vec2(-1, +1), vec2(+1, -1), vec2(+1, +1));

    vec2 screen_half_size = (screen_rect.zw - screen_rect.xy) / 2.0;
    vec2 screen_center    = (screen_rect.zw + screen_rect.xy) / 2.0;
    vec2 screen_position  = vertices[gl_VertexID] * screen_half_size + screen_center;

    vec2 texture_half_size = (texture_rect.zw - texture_rect.xy) / 2.0;
    vec2 texture_center    = (texture_rect.zw + texture_rect.xy) / 2.0;
    vec2 texture_position  = vertices[gl_VertexID] * texture_half_size + texture_center;

    vec2 ndc = (screen_position / viewport) * 2.0 - 1.0;
    ndc.y = -ndc.y; 
    gl_Position = vec4(ndc, 0.0, 1.0);

    out_color = color;
    out_uv = texture_position;
    out_omit_texture = style.z;
}

#endif // VERTERX_SHADER

#ifdef FRAGMENT_SHADER

uniform float time;
out vec4 frag_color;

void main(void)
{
    vec3 color = 0.5 + 0.5 * cos(time + vec3(0.0, 2.0, 4.0));
    vec4 albedo = (out_omit_texture < 1.0) ? texture(color_texture, out_uv) : vec4(1.0);
    frag_color = albedo * out_color;
}

#endif // FRAGMENT_SHADER
END
