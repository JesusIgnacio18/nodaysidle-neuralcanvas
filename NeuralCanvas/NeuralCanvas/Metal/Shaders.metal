#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Structures

struct StrokeVertex {
    float2 position [[attribute(0)]];
    float2 normal [[attribute(1)]];
    float width [[attribute(2)]];
    float4 color [[attribute(3)]];
};

struct StrokeVertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
    float width;
};

struct ShapeVertex {
    float2 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct ShapeVertexOut {
    float4 position [[position]];
    float4 color;
};

// MARK: - Uniforms

struct Uniforms {
    float4x4 viewProjectionMatrix;
    float2 viewportSize;
    float time;
    float scale;
};

// MARK: - Stroke Rendering

vertex StrokeVertexOut stroke_vertex(
    StrokeVertex in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    StrokeVertexOut out;

    // Calculate screen position with width offset
    float2 offset = in.normal * in.width * 0.5;
    float2 pos = in.position + offset;

    // Apply view-projection matrix
    float4 worldPos = float4(pos, 0.0, 1.0);
    out.position = uniforms.viewProjectionMatrix * worldPos;

    out.color = in.color;
    out.width = in.width;
    out.texCoord = float2(dot(in.normal, float2(1, 0)) * 0.5 + 0.5, 0.5);

    return out;
}

fragment float4 stroke_fragment(
    StrokeVertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    // Anti-aliased stroke with smooth edges
    float2 center = float2(0.5, 0.5);
    float dist = abs(in.texCoord.x - center.x) * 2.0;

    // Smooth falloff at edges for anti-aliasing
    float alpha = smoothstep(1.0, 0.8, dist) * in.color.a;

    return float4(in.color.rgb, alpha);
}

// MARK: - Shape Rendering

vertex ShapeVertexOut shape_vertex(
    ShapeVertex in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    ShapeVertexOut out;

    float4 worldPos = float4(in.position, 0.0, 1.0);
    out.position = uniforms.viewProjectionMatrix * worldPos;
    out.color = in.color;

    return out;
}

fragment float4 shape_fragment(
    ShapeVertexOut in [[stage_in]]
) {
    return in.color;
}

// MARK: - Rounded Rectangle Shape

struct RoundedRectUniforms {
    float4x4 viewProjectionMatrix;
    float2 rectCenter;
    float2 rectSize;
    float cornerRadius;
    float4 fillColor;
    float4 strokeColor;
    float strokeWidth;
};

vertex ShapeVertexOut rounded_rect_vertex(
    uint vertexID [[vertex_id]],
    constant RoundedRectUniforms &uniforms [[buffer(0)]]
) {
    ShapeVertexOut out;

    // Create quad vertices
    float2 positions[6] = {
        float2(-0.5, -0.5),
        float2( 0.5, -0.5),
        float2( 0.5,  0.5),
        float2(-0.5, -0.5),
        float2( 0.5,  0.5),
        float2(-0.5,  0.5)
    };

    float2 pos = positions[vertexID];
    pos = pos * uniforms.rectSize + uniforms.rectCenter;

    out.position = uniforms.viewProjectionMatrix * float4(pos, 0.0, 1.0);
    out.color = uniforms.fillColor;

    return out;
}

fragment float4 rounded_rect_fragment(
    ShapeVertexOut in [[stage_in]],
    constant RoundedRectUniforms &uniforms [[buffer(0)]]
) {
    // SDF for rounded rectangle
    float2 fragPos = in.position.xy;
    float2 halfSize = uniforms.rectSize * 0.5;
    float2 dist = abs(fragPos - uniforms.rectCenter) - halfSize + uniforms.cornerRadius;
    float d = length(max(dist, 0.0)) + min(max(dist.x, dist.y), 0.0) - uniforms.cornerRadius;

    // Anti-aliased edges
    float alpha = 1.0 - smoothstep(-1.0, 1.0, d);

    // Stroke
    if (uniforms.strokeWidth > 0.0) {
        float strokeDist = abs(d) - uniforms.strokeWidth * 0.5;
        float strokeAlpha = 1.0 - smoothstep(-1.0, 1.0, strokeDist);

        float4 color = mix(uniforms.fillColor, uniforms.strokeColor, strokeAlpha);
        return float4(color.rgb, color.a * alpha);
    }

    return float4(uniforms.fillColor.rgb, uniforms.fillColor.a * alpha);
}

// MARK: - Grid Rendering

struct GridUniforms {
    float4x4 viewProjectionMatrix;
    float2 viewportSize;
    float gridSize;
    float4 gridColor;
    float4 majorGridColor;
    int majorGridInterval;
    float2 offset;
    float scale;
};

vertex ShapeVertexOut grid_vertex(
    uint vertexID [[vertex_id]],
    constant GridUniforms &uniforms [[buffer(0)]]
) {
    ShapeVertexOut out;

    // Full screen quad
    float2 positions[6] = {
        float2(-1, -1),
        float2( 1, -1),
        float2( 1,  1),
        float2(-1, -1),
        float2( 1,  1),
        float2(-1,  1)
    };

    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.color = uniforms.gridColor;

    return out;
}

fragment float4 grid_fragment(
    ShapeVertexOut in [[stage_in]],
    constant GridUniforms &uniforms [[buffer(0)]]
) {
    float2 pos = in.position.xy / uniforms.scale + uniforms.offset;
    float gridSize = uniforms.gridSize;

    // Calculate grid lines
    float2 gridPos = fract(pos / gridSize);
    float2 grid = smoothstep(0.0, 0.02, gridPos) * smoothstep(1.0, 0.98, gridPos);

    // Minor grid
    float minorAlpha = max(1.0 - grid.x, 1.0 - grid.y) * uniforms.gridColor.a * 0.3;

    // Major grid
    float2 majorGridPos = fract(pos / (gridSize * float(uniforms.majorGridInterval)));
    float2 majorGrid = smoothstep(0.0, 0.01, majorGridPos) * smoothstep(1.0, 0.99, majorGridPos);
    float majorAlpha = max(1.0 - majorGrid.x, 1.0 - majorGrid.y) * uniforms.majorGridColor.a * 0.5;

    float alpha = max(minorAlpha, majorAlpha);
    float3 color = mix(uniforms.gridColor.rgb, uniforms.majorGridColor.rgb, majorAlpha / max(alpha, 0.001));

    return float4(color, alpha);
}

// MARK: - Processing Feedback Animation

struct ProcessingUniforms {
    float4x4 viewProjectionMatrix;
    float time;
    float4 baseColor;
    float4 highlightColor;
};

fragment float4 processing_shimmer_fragment(
    ShapeVertexOut in [[stage_in]],
    constant ProcessingUniforms &uniforms [[buffer(0)]]
) {
    // Shimmer effect for processing feedback
    float shimmer = sin(in.position.x * 0.1 + uniforms.time * 3.0) * 0.5 + 0.5;
    shimmer *= sin(in.position.y * 0.05 + uniforms.time * 2.0) * 0.5 + 0.5;

    float4 color = mix(uniforms.baseColor, uniforms.highlightColor, shimmer * 0.3);
    return color;
}
