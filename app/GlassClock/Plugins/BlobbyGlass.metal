// Blobby Pip's glass (Aaron, 1 Nov 2026): his silhouette goes in, glass comes out. Used by PipBlobbyLook.swift.
// The layer it reads is a soft silhouette: red = body (head + tail), green = front wing, blue = back wing.
// From it: how round he is at each point (the slope of the soft edge; his head is an exact ball), then glass:
// a light tint, a rim of light, a highlight from the top left (never moves), a warm bounce underneath, the tail
// fading out (his shadow). See for comparison app/design/pip-vector.html (the WebGL version of the same thing).
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float3 slopeAt(SwiftUI::Layer layer, float2 p, float k, float3 ch) {
    float hx = dot(float3(layer.sample(p + float2(k, 0)).rgb - layer.sample(p - float2(k, 0)).rgb), ch);
    float hy = dot(float3(layer.sample(p + float2(0, k)).rgb - layer.sample(p - float2(0, k)).rgb), ch);
    return normalize(float3(-hx * 2.5, -hy * 2.5, 1.0));
}

// t: Aaron's sliders (Tune Blobby): x glassiness, y inner glow (rim), z shine, w warm bounce.
static half4 glassAt(float3 n, float a, bool body, float4 t, float edge) {
    float fr = pow(1.0 - n.z, 2.2);
    // his glass colour, darker blue towards the edge, so he reads on light backgrounds too (Apple: never light on light)
    float3 col = mix(float3(0.87, 0.86, 0.95), float3(0.30, 0.40, 0.58), fr * edge);
    float tint = ((body ? 0.16 : 0.22) + 0.3 * (1.0 - n.z)) * t.x;                  // clear in the middle, thicker at the edge
    float3 rim = float3(0.8, 0.93, 1.0) * fr * t.y;                           // rim light (the inner glow)
    float3 L = normalize(float3(-0.55, -0.6, 0.6));                           // light from the top left (y down)
    float spec = pow(max(dot(reflect(-L, n), float3(0, 0, 1)), 0.0), 22.0) * t.z;   // soft (Aaron)
    float3 warm = float3(1.0, 0.93, 0.75) * max(n.y, 0.0) * fr * t.w;       // warm bounce underneath
    float3 light = rim + warm + spec;
    float alpha = clamp(tint + fr * edge * 0.35 + max(max(light.r, light.g), light.b) * 0.8, 0.0, 1.0);
    float3 outc = col * (tint + fr * edge * 0.35) + light;                     // premultiplied
    return half4(half3(outc * a), half(alpha * a));
}

[[ stitchable ]] half4 blobbyGlass(float2 p, SwiftUI::Layer layer, float2 head, float r, float2 tip, float k, float4 t, float edge) {
    half4 s = layer.sample(p);
    float body = smoothstep(0.36, 0.60, float(s.r));
    float fw = smoothstep(0.22, 0.50, float(s.g));
    float bw = smoothstep(0.22, 0.50, float(s.b));
    if (body + fw + bw < 0.001) return half4(0);
    float3 n = slopeAt(layer, p, k, float3(1, 0, 0));
    float2 d = (p - head) / r;
    float dd = dot(d, d);
    if (dd < 1.0) n = normalize(mix(n, float3(d, sqrt(1.0 - dd)), smoothstep(1.0, 0.75, sqrt(dd))));   // his head is a ball
    float2 ht = tip - head;
    float along = dot(p - head, ht) / max(dot(ht, ht), 1e-4);
    float fade = 1.0 - smoothstep(0.3, 1.0, along);                           // the tail fades (his shadow)
    fade = max(fade, smoothstep(1.08, 0.96, sqrt(dd)));                       // never into his head
    half4 outc = half4(0);
    if (bw > 0.001) outc = glassAt(slopeAt(layer, p, k * 0.5, float3(0, 0, 1)), bw * 0.5 * (1.0 - body), false, t, edge);
    if (body > 0.001) { half4 b = glassAt(n, body * fade, true, t, edge); outc = b + outc * (1.0h - b.a); }
    if (fw > 0.001) { half4 w = glassAt(slopeAt(layer, p, k * 0.5, float3(0, 1, 0)), fw * 0.75, false, t, edge); outc = w + outc * (1.0h - w.a); }
    return outc;
}

/// The emoji, seen through his ball: magnified in the middle, bent towards the edge.
[[ stitchable ]] float2 blobbyLens(float2 p, float2 c, float r, float strength) {
    float2 d = (p - c) / r;
    float dd = dot(d, d);
    if (dd >= 1.0) return p;
    return c + d * r * (1.0 - strength * (1.0 - dd));
}
