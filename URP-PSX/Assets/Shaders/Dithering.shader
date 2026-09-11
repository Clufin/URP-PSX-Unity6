Shader "PostEffect/Dithering"
{
    Properties
    {
        // Placeholder only; RG will bind the source color to _BlitTexture
        _BlitTexture("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        // RG source color
        TEXTURE2D(_BlitTexture);
        SAMPLER(sampler_BlitTexture);

        // Params (match your C# IDs)
        uint  _PatternIndex;          // 0..3
        float _DitherThreshold;       // scales brightness before compare
        float _DitherStrength;        // 0..1 blend between original & masked
        float _DitherScale;           // pixel scale factor for the pattern

        // Fullscreen triangle varyings
        struct Varyings {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0;
        };

        // Fullscreen triangle vertex (procedural)
        Varyings Vert(uint vid : SV_VertexID)
        {
            Varyings o;
            o.positionCS = GetFullScreenTriangleVertexPosition(vid);
            o.uv         = GetFullScreenTriangleTexCoord(vid);
            return o;
        }

        // ----- Helpers -----

        // 4x4 ordered patterns (values normalized to 0..1)
        // row-select helper
        float4 SelectRow(uint row, float4 r0, float4 r1, float4 r2, float4 r3)
        {
            return (row == 0) ? r0 : (row == 1) ? r1 : (row == 2) ? r2 : r3;
        }

        // Returns a normalized threshold in [0,1] for a given 4x4 cell
        float GetPatternVal4x4(uint2 cell, uint idx)
        {
            uint x = cell.x & 3;
            uint y = cell.y & 3;

            // Default = Bayer4x4 (classic)
            float4 r0 = float4( 0,  8,  2, 10) / 16.0;
            float4 r1 = float4(12,  4, 14,  6) / 16.0;
            float4 r2 = float4( 3, 11,  1,  9) / 16.0;
            float4 r3 = float4(15,  7, 13,  5) / 16.0;

            // Pattern 1 (your alt pattern, normalized)
            if (idx == 1)
            {
                r0 = float4(0.23, 0.20, 0.60, 0.20);
                r1 = float4(0.20, 0.43, 0.20, 0.77);
                r2 = float4(0.88, 0.20, 0.87, 0.20);
                r3 = float4(0.20, 0.46, 0.20, 0.00);
            }
            // Pattern 2 (your +/− matrix, remapped to 0..1)
            else if (idx == 2)
            {
                // original range [-4..+3] -> normalize to [0..1]
                float4 rr0 = float4(-4,  0, -3,  1);
                float4 rr1 = float4( 2, -2,  3, -1);
                float4 rr2 = float4(-3,  1, -4,  0);
                float4 rr3 = float4( 3, -1,  2, -2);
                r0 = (rr0 + 4.0) / 7.0;
                r1 = (rr1 + 4.0) / 7.0;
                r2 = (rr2 + 4.0) / 7.0;
                r3 = (rr3 + 4.0) / 7.0;
            }
            // Pattern 3 (cross-ish)
            else if (idx == 3)
            {
                r0 = float4(1,0,0,1);
                r1 = float4(0,1,1,0);
                r2 = float4(0,1,1,0);
                r3 = float4(1,0,0,1);
            }

            float4 row = SelectRow(y, r0, r1, r2, r3);
            return row[x];
        }

        // ----- Main dithering fragment -----
        half4 Frag(Varyings i) : SV_Target
        {
            float2 uv = i.uv;

            // Sample source color
            float3 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb;

            // Convert to pixel coords (avoid div by 0 on scale)
            float scale     = max(_DitherScale, 1.0);
            float2 pixelXY  = floor(uv * _ScreenParams.xy / scale);
            uint2 cell      = (uint2)pixelXY;

            // Luminance (perceptual weights)
            float brightness = dot(col, float3(0.2126, 0.7152, 0.0722));
            float bScaled    = saturate(brightness * _DitherThreshold);

            // 4x4 ordered threshold
            float thr = GetPatternVal4x4(cell, _PatternIndex);

            // Binary mask by comparing scaled brightness against threshold
            float mask = (bScaled > thr) ? 1.0 : 0.0;

            // Blend between original and masked color by strength
            float3 outCol = lerp(col, col * mask, saturate(_DitherStrength));
            return half4(outCol, 1.0);
        }

        // Pass 1: pure copy (debug)
        half4 FragCopy(Varyings i) : SV_Target
        {
            return SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv);
        }
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment Frag
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment FragCopy
            ENDHLSL
        }
    }
}