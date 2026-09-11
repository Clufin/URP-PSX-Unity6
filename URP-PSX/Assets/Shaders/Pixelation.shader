Shader "PostEffect/Pixelation"
{
    Properties
    {
        // RG will bind the source color here
        _BlitTexture("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_BlitTexture);
        SAMPLER(sampler_BlitTexture);

        // params
        float _WidthPixelation;   // columns  (>=1)
        float _HeightPixelation;  // rows     (>=1)
        float _ColorPrecision;    // color steps (>=1)

        struct Varyings {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0;
        };

        Varyings Vert(uint vid : SV_VertexID)
        {
            Varyings o;
            o.positionCS = GetFullScreenTriangleVertexPosition(vid);
            o.uv         = GetFullScreenTriangleTexCoord(vid);
            return o;
        }

        // clamp to avoid div-by-zero and keep sensible ranges
        float2 QuantizeUV(float2 uv, float2 grid)
        {
            grid = max(grid, float2(1.0, 1.0));
            return floor(uv * grid) / grid;
        }

        half4 Frag(Varyings i) : SV_Target
        {
            float2 grid = float2(_WidthPixelation, _HeightPixelation);
            float2 uvQ  = QuantizeUV(i.uv, grid);

            float3 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uvQ).rgb;

            // color precision quantization
            float steps = max(_ColorPrecision, 1.0);
            col = floor(col * steps) / steps;

            return half4(col, 1.0);
        }

        // pure copy
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
