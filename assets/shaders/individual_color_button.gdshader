shader_type canvas_item;

// Circle transition parameters
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool circle_in = true; // true = circle in, false = circle out
uniform vec2 circle_center = vec2(0.5, 0.5); // Center position
uniform float max_radius : hint_range(0.1, 2.0) = 1.5; // Maximum radius

// Color mode and selection
uniform bool use_color_mode = false; // true = use color, false = use texture
uniform vec4 selected_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // User selected color

void fragment() {
    // Original texture color
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Distance from current pixel to circle center
    float dist = distance(UV, circle_center);
    
    // Calculate the current radius based on progress
    float current_radius = circle_in ? progress * max_radius : (1.0 - progress) * max_radius;
    
    // Check if this pixel is inside the circle
    bool inside_circle = dist < current_radius;
    
    // Decide what to show based on mode and whether inside circle
    if (use_color_mode) {
        // In color mode
        if (circle_in) {
            // Circle in: show color inside circle, texture outside
            COLOR = inside_circle ? selected_color : tex_color;
        } else {
            // Circle out: show texture inside circle, color outside
            COLOR = inside_circle ? tex_color : selected_color;
        }
    } else {
        // In texture mode (checkboard transition)
        if (circle_in) {
            // Circle in: show texture inside circle, transparent outside
            COLOR = inside_circle ? tex_color : vec4(0.0, 0.0, 0.0, 0.0);
        } else {
            // Circle out: show transparent inside circle, texture outside
            COLOR = inside_circle ? vec4(0.0, 0.0, 0.0, 0.0) : tex_color;
        }
    }
}