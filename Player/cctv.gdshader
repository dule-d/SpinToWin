shader_type canvas_item;

// Outline Controls
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Red outline
uniform float outline_width : hint_range(0.0, 5.0) = 1.0;

// CCTV Fine Grain Controls
uniform float grain_intensity : hint_range(0.0, 0.3) = 0.08;

// High-Frequency Glitch Controls (Ported from your favorite filter!)
uniform float glitch_frequency : hint_range(0.0, 10.0) = 4.0;  // How often it breaks
uniform float glitch_amplitude : hint_range(0.0, 0.1) = 0.03;  // How far it tears horizontally

// Pseudo-random number generator for grain and tearing
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;

    // 1. Generate high-frequency timing windows (Ported from favorite filter)
    float time_snap = floor(TIME * 25.0); // Creates sharp, blocky, stepped time intervals
    float glitch_chance = step(1.0 - (glitch_frequency * 0.1), random(vec2(time_snap, 123.45)));

    // 2. If the random chance hits, slice and distort the UV coordinates
    if (glitch_chance > 0.0) {
        // Create horizontal slicing lines based on the vertical position
        float slice_y = floor(uv.y * 12.0); // Determines how many blocky strips the bar slices into
        float line_noise = random(vec2(slice_y, time_snap));
        
        // Push strips left or right randomly
        uv.x += (line_noise * 2.0 - 1.0) * glitch_amplitude;
    }

    // 3. Sample the texture using our modified, glitched UV coordinates
    vec4 base_color = texture(TEXTURE, uv);
    
    // 4. Pixel Outline Logic using the exact same glitched coordinates
    vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;
    float max_alpha = 0.0;
    max_alpha = max(max_alpha, texture(TEXTURE, uv + vec2(0.0, pixel_size.y)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, uv - vec2(0.0, pixel_size.y)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, uv + vec2(pixel_size.x, 0.0)).a);
    max_alpha = max(max_alpha, texture(TEXTURE, uv - vec2(pixel_size.x, 0.0)).a);
    
    // 5. Final output blending (Merging CCTV grain with the glitch flashes)
    vec4 final_color = base_color;
    
    if (base_color.a == 0.0 && max_alpha > 0.0) {
        // Draw the red outline
        final_color = outline_color;
        
        // Make the outline color color-flash white during severe glitches
        if (glitch_chance > 0.0 && random(vec2(time_snap)) > 0.5) {
            final_color = vec4(1.0, 1.0, 1.0, 1.0);
        }
    } else if (base_color.a > 0.0) {
        // CCTV Effect: Apply fine analog grain over the visible bar area
        float grain = random(uv + vec2(TIME, TIME)) * grain_intensity;
        final_color.rgb += vec3(grain);
        
        // Give the bar fill a brief static flash overlay when actively glitching
        if (glitch_chance > 0.0) {
            final_color.rgb += vec3(random(uv + TIME) * 0.2);
            
            // Randomly turn the whole bar chunk solid white for total diagnostic blowout look
            if (random(vec2(time_snap, 99.9)) > 0.7) {
                final_color.rgb = vec3(1.0);
            }
        }
    }
    
    COLOR = final_color;
}