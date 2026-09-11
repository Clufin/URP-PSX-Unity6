Shader "PostEffect/Fog"
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

        // --- RG source & depth ---
        TEXTURE2D(_BlitTexture);
        SAMPLER(sampler_BlitTexture);

        TEXTURE2D_X_FLOAT(_CameraDepthTexture);

        // --- Parameters (match C# property IDs) ---
        float   _FogDensity;      // density scale
        float   _FogDistance;     // extra distance scale (multiplier)
        float4  _FogColor;        // fog color
        float4  _AmbientColor;    // ambient multiplier

        float   _FogNear;         // near distance (eye space)
        float   _FogFar;          // far distance (eye space)
        float   _FogAltScale;     // (reserved for altitude fog; not used here)
        float   _FogThinning;     // (reserved)

        float   _NoiseScale;      // screen-space noise tiling
        float   _NoiseStrength;   // noise contribution

        struct Varyings {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0;
        };

        // Fullscreen triangle
        Varyings Vert(uint vid : SV_VertexID)
        {
            Varyings o;
            o.positionCS = GetFullScreenTriangleVertexPosition(vid);
            o.uv         = GetFullScreenTriangleTexCoord(vid);
            return o;
        }

        // Cheap hash noise in [0,1]
        float hash21(float2 p)
        {
            p = frac(p * float2(123.34, 345.45));
            p += dot(p, p + 34.345);
            return frac(p.x * p.y);
        }

        // Screen-space value noise (one-liner)
        float screenNoise(float2 uv, float scale)
        {
            float2 px = uv * _ScreenParams.xy / max(scale, 1.0);
            return hash21(floor(px));
        }

        half4 Frag(Varyings i) : SV_Target
        {
            float2 uv = i.uv;

            // Sample source color
            float3 src = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb;

            // Depth sampling
            float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_PointClamp, uv).r;

            // Identify skybox / no-geometry pixels -> skip fog on those
            bool noGeometry =
            #if defined(UNITY_REVERSED_Z)
                (rawDepth <= 1e-6);
            #else
                (rawDepth >= 1.0 - 1e-6);
            #endif

            float fogFac = 0.0;
            if (!noGeometry)
            {
                // Eye-space depth (meters-ish)
                float eyeZ = LinearEyeDepth(rawDepth, _ZBufferParams);

                // Normalize by near/far band (optional fade-in/out)
                float nearFar = max(_FogFar - _FogNear, 1e-5);
                float band    = saturate( (eyeZ - _FogNear) / nearFar );

                // Exponential fog, distance-scaled
                float dens = max(_FogDensity, 0.0) * max(_FogDistance, 0.0);
                fogFac = 1.0 - exp2(-dens * eyeZ * band);

                // Add a bit of screen noise to break banding
                float n = screenNoise(uv, max(_NoiseScale, 1.0)) - 0.5;
                fogFac = saturate(fogFac + n * _NoiseStrength);
            }

            float3 fogCol = (_FogColor.rgb * _AmbientColor.rgb);
            float3 outCol = lerp(src, fogCol, fogFac);
            return half4(outCol, 1.0);
        }

        // Pure copy (debug)
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