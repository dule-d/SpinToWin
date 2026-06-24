shader_type canvas_item;

// Outline Controls
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

// Glitch Controls
uniform float glitch_frequency : hint_range(0.0, 10.0) = 4.0;  // How often it breaks
uniform float glitch_amplitude : hint_range(0.0, 0.1) = 0.03;  // How far it tears horizontally

// Pseudo-random number generator
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;

    // 1. Generate high-frequency timing windows
    // Changing the multiplier inside sin() modifies the speed/frequency of the glitch beats
    float time_snap = floor(TIME * 25.0); // Creates sharp, blocky, stepped time intervals
    float glitch_chance = step(1.0 - (glitch_frequency * 0.1), random(vec2(time_snap, 123.45)));

    // 2. If the random chance hits, distort the UV coordinates
    if (glitch_chance > 0.0) {
        // Create horizontal slicing lines based on the vertical screen position
        float slice_y = floor(uv.y * 12.0); // Determines how many blocky strips the icon slices into
        float line_noise = random(vec2(slice_y, time_snap));
        
        // Push strips left or right randomly
        uv.x += (line_noise * 2.0 - 1.0) * glitch_amplitude;
    }

    // 3. Sample the texture using our modified (potentially glitched) UV coordinates
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    vec4 current_color = texture(TEXTURE, uv);
    float alpha = current_color.a;
    
    // 4. Calculate outline using the exact same glitched coordinates
    float max_alpha = 0.0;
    max_alpha = max(max_alpha, texture(TEXTURE, uv + vec2(0.0, size.y)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, uv - vec2(0.0, size.y)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, uv + vec2(size.x, 0.0)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, uv - vec2(size.x, 0.0)).a);
    
    // 5. Final output blending
    if (alpha == 0.0 && max_alpha > 0.0) {
        COLOR = outline_color;
        
        // Make the outline color color-flash white during severe glitches
        if (glitch_chance > 0.0 && random(vec2(time_snap)) > 0.5) {
            COLOR = vec4(1.0, 1.0, 1.0, 1.0);
        }
    } else {
        COLOR = current_color;
        
        // Give the stickman art a brief static flash overlay when glitching
        if (alpha > 0.0 && glitch_chance > 0.0) {
            COLOR.rgb += vec3(random(uv + TIME) * 0.2);
        }
    }
}