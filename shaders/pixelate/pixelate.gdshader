shader_type canvas_item;

// Size of one pixelation block in *screen pixels* (1 = off, 2 = 2×2, 4 = 4×4, …)
uniform int pixel_size = 4;  // adjust as needed

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    // SCREEN_PIXEL_SIZE is the size of one screen pixel in UV space.
    // Multiply by the desired block size to get the block’s UV footprint.
    vec2 block_uv = SCREEN_PIXEL_SIZE * float(pixel_size);

    // Snap the screen UV to the nearest block centre.
    vec2 coord = (floor(SCREEN_UV / block_uv) + 0.5) * block_uv;

    // Instead of a single center sample, take a few samples and average them.
vec4 color = vec4(0.0);
int samples = 4; // 4 gives a good stability/quality balance
for (int x = 0; x < samples; x++) {
    for (int y = 0; y < samples; y++) {
        vec2 offset = (vec2(float(x), float(y)) / float(samples)) - 0.5;
        vec2 sample_coord = coord + offset * block_uv;
        color += textureLod(SCREEN_TEXTURE, sample_coord, 0.0);
    }
}
color /= float(samples * samples);
COLOR = color;
}