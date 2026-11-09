#version 300 es
// Grayscale screen shader, toggled by ~/.local/bin/omarchy-toggle-monochrome
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 color = texture(tex, v_texcoord);
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(luma), color.a);
}
