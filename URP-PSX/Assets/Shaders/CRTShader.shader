Shader "PostEffect/CRTShader"
{
    Properties
    {
        // Placeholder only; RG will bind the source color here
        _BlitTexture("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        // ---- RG source texture ----
        TEXTURE2D(_BlitTexture);
        SAMPLER(sampler_BlitTexture);

        // ---- Parameters (match your C# property IDs) ----
        float  _ScanlinesWeight, _NoiseWeight;
        float  _ScreenBendX, _ScreenBendY;
        float  _VignetteAmount, _VignetteSize, _VignetteRounding, _VignetteSmoothing;
        float  _ScanLinesDensity, _ScanLinesSpeed, _NoiseAmount;
        float2 _ChromaticRed, _ChromaticGreen, _ChromaticBlue;

        // Grille (aperture mask) params
        float  _GrilleOpacity, _GrilleCounterOpacity;
        float  _GrilleResolution, _GrilleCounterResolution, _GrilleBrightness;
        float  _GrilleUvRotation, _GrilleUvMidPoint; // in [0,1]
        float3 _GrilleShift;

        // ---- Fullscreen triangle varyings ----
        struct Varyings {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0;
        };

        // ---- Fullscreen triangle vertex (procedural) ----
        Varyings Vert(uint vid : SV_VertexID)
        {
            Varyings o;
            o.positionCS = GetFullScreenTriangleVertexPosition(vid);
            o.uv         = GetFullScreenTriangleTexCoord(vid);
            return o;
        }

        // ---- Helpers ----
        float rand(float2 uv) {
            return frac(sin(dot(uv, float2(15.5151, 42.2561))) * 12341.14122 * sin(_TimeParameters.y * 0.03));
        }

        float noise2D(float2 uv) {
            float2 i = floor(uv);
            float2 f = frac(uv);
            float a = rand(i);
            float b = rand(i + float2(1,0));
            float c = rand(i + float2(0,1));
            float d = rand(i + float2(1,1));
            float2 u = smoothstep(0.0, 1.0, f);
            return lerp(a,b,u.x) + (c - a)*u.y*(1 - u.x) + (d - b)*u.x*u.y;
        }

        float2 rotateUV(float2 uv, float rot, float mid)
        {
            float s = sin(rot), c = cos(rot);
            float2 t = uv - mid;
            return float2(c*t.x + s*t.y, c*t.y - s*t.x) + mid;
        }

        // ---- Main CRT fragment (NO depth / NO fog) ----
        half4 Frag(Varyings i) : SV_Target
        {
            float2 uv = i.uv;

            // Screen bend (protect against division by zero)
            float2 buv = uv - 0.5;
            buv *= 2.0;
            float bx = max(_ScreenBendX, 1e-4);
            float by = max(_ScreenBendY, 1e-4);
            buv.x *= (1.0 + pow(abs(buv.y)/bx, 2.0));
            buv.y *= (1.0 + pow(abs(buv.x)/by, 2.0));
            buv = buv * 0.5 + 0.5;

            // Chromatic aberration sampling
            float3 col;
            col.r = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, buv + _ChromaticRed  ).r;
            col.g = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, buv + _ChromaticGreen).g;
            col.b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, buv + _ChromaticBlue ).b;

            // Scanlines
            float scan   = sin(buv.y * _ScanLinesDensity + _TimeParameters.y * _ScanLinesSpeed);
            float scan01 = 0.5 + 0.5 * scan;
            col = lerp(col * (1.0 - _ScanlinesWeight), col * (1.0 + _ScanlinesWeight), scan01);

            // Noise
            float n = noise2D(buv * max(_NoiseAmount, 1e-4));
            col *= (1.0 + _NoiseWeight * (n - 0.5));

            // Vignette
            float2 v = (uv - 0.5) * _VignetteSize;
            float vig = 1.0 - (pow(abs(v.x), _VignetteRounding) + pow(abs(v.y), _VignetteRounding));
            vig = smoothstep(0.0, _VignetteSmoothing, saturate(vig));
            col *= lerp(1.0, vig, saturate(_VignetteAmount));

            // Grille (aperture mask)
            float rot = radians(_GrilleUvRotation);
            float mid = _GrilleUvMidPoint; // typically 0.5
            float2 guv  = rotateUV(uv,  rot,     mid);
            float2 guvC = rotateUV(uv,  rot*2.0, mid);

            float pr  = _GrilleResolution        * 3.14159265;
            float prc = _GrilleCounterResolution * 3.14159265;

            float g_r   = smoothstep(0.85, 0.95, abs(sin(_GrilleShift.x + guv  * pr )));
            float g_r_c = smoothstep(0.85, 0.95, abs(sin(_GrilleShift.x + guvC * prc)));
            float g_g   = smoothstep(0.85, 0.95, abs(sin(_GrilleShift.y + 1.05 + guv  * pr )));
            float g_g_c = smoothstep(0.85, 0.95, abs(sin(_GrilleShift.y + 1.05 + guvC * prc)));
            float g_b   = smoothstep(0.85, 0.95, abs(sin(_GrilleShift.z + 2.10 + guv  * pr )));
            float g_b_c = smoothstep(0.85, 0.95, abs(sin(_GrilleShift.z + 2.10 + guvC * prc)));

            float3 grille = col;
            grille.r = lerp(grille.r, grille.r * g_r,    saturate(_GrilleOpacity));
            grille.r = lerp(grille.r, grille.r * g_r_c,  saturate(_GrilleCounterOpacity));
            grille.g = lerp(grille.g, grille.g * g_g,    saturate(_GrilleOpacity));
            grille.g = lerp(grille.g, grille.g * g_g_c,  saturate(_GrilleCounterOpacity));
            grille.b = lerp(grille.b, grille.b * g_b,    saturate(_GrilleOpacity));
            grille.b = lerp(grille.b, grille.b * g_b_c,  saturate(_GrilleCounterOpacity));
            grille   = saturate(grille * _GrilleBrightness);

            return half4(grille, 1.0);
        }

        // Pure copy pass (for quick A/B debugging)
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
