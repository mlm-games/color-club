shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.102, 0.102, 0.180, 1.0);
uniform vec4 color2 : source_color = vec4(0.086, 0.129, 0.243, 1.0);
uniform vec4 accent_color : source_color = vec4(0.310, 0.804, 0.769, 0.3);
uniform float wave_speed : hint_range(0.1, 2.0) = 0.5;
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.1;

void fragment() {
    vec2 uv = UV;

    // Add subtle wave animation
    uv.y += sin(uv.x * 10.0 + TIME * wave_speed) * wave_amplitude;

    // Create gradient
    float gradient = smoothstep(0.0, 1.0, uv.y);
    vec4 base_color = mix(color1, color2, gradient);

    // Add animated accent spots
    float spot1 = smoothstep(0.5, 0.0, distance(uv, vec2(0.3 + sin(TIME * 0.3) * 0.1, 0.4)));
    float spot2 = smoothstep(0.4, 0.0, distance(uv, vec2(0.7 + cos(TIME * 0.4) * 0.1, 0.6)));

    vec4 final_color = base_color + accent_color * (spot1 + spot2);

    COLOR = final_color;
}