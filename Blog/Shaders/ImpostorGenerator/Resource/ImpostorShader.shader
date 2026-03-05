Shader "Impostor/ImpostorShader"
{
    Properties
    {
        _ImpostorAtlas ("Impostor Atlas", 2D) = "white" {}
        _GridSize ("Grid Size", Float) = 12
        _AlphaCutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
        _Tint ("Tint", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
        }

        Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _ImpostorAtlas_ST;
            float  _GridSize;
            float  _AlphaCutoff;
            half4  _Tint;
        CBUFFER_END

        TEXTURE2D(_ImpostorAtlas);
        SAMPLER(sampler_ImpostorAtlas);

        float2 OctEncode(float3 n)
        {
            n /= (abs(n.x) + abs(n.y) + abs(n.z));
            if (n.y < 0.0)
            {
                float2 s = float2(n.x >= 0.0 ? 1.0 : -1.0, n.z >= 0.0 ? 1.0 : -1.0);
                n.xz = (1.0 - abs(n.zx)) * s;
            }
            return float2(n.x, n.z);
        }

        float2 FrameUV(float2 frameIdx, float2 localUV)
        {
            return (frameIdx + saturate(localUV)) / _GridSize;
        }

        void Billboard(float4 posOS, out float3 worldPos, out float3 worldCenter)
        {
            worldCenter = TransformObjectToWorld(float3(0, 0, 0));
            float3 camRight = UNITY_MATRIX_V[0].xyz;
            float3 camUp    = UNITY_MATRIX_V[1].xyz;

            float3 scale = float3(
                length(GetObjectToWorldMatrix()[0].xyz),
                length(GetObjectToWorldMatrix()[1].xyz),
                length(GetObjectToWorldMatrix()[2].xyz));

            worldPos = worldCenter
                + camRight * posOS.x * scale.x
                + camUp    * posOS.y * scale.y;
        }

        float2 ViewOct()
        {
            float3 worldCenter = TransformObjectToWorld(float3(0, 0, 0));
            float3 worldDir = normalize(_WorldSpaceCameraPos - worldCenter);
            float3 localDir = normalize(mul((float3x3)GetWorldToObjectMatrix(), worldDir));
            return OctEncode(localDir);
        }
        ENDHLSL

        // ──────────────────────────────────────────────
        // Forward Lit — bilinear frame blending
        // ──────────────────────────────────────────────
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fog

            struct Attributes
            {
                float4 posOS : POSITION;
                float2 uv    : TEXCOORD0;
            };

            struct Varyings
            {
                float4 posCS    : SV_POSITION;
                float2 uv       : TEXCOORD0;
                float  fogCoord : TEXCOORD1;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings o;
                float3 wp, wc;
                Billboard(IN.posOS, wp, wc);
                o.posCS    = TransformWorldToHClip(wp);
                o.uv       = IN.uv;
                o.fogCoord = ComputeFogFactor(o.posCS.z);
                return o;
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                float2 oct = ViewOct();
                float2 gridPos = (oct * 0.5 + 0.5) * _GridSize - 0.5;
                float2 base = floor(gridPos);

                // Narrow smoothstep transition zone at frame boundaries
                float2 blend = smoothstep(0.45, 0.55, frac(gridPos));

                float2 f00 = clamp(base,                0, _GridSize - 1);
                float2 f10 = clamp(base + float2(1, 0), 0, _GridSize - 1);
                float2 f01 = clamp(base + float2(0, 1), 0, _GridSize - 1);
                float2 f11 = clamp(base + float2(1, 1), 0, _GridSize - 1);

                half4 c00 = SAMPLE_TEXTURE2D(_ImpostorAtlas, sampler_ImpostorAtlas, FrameUV(f00, IN.uv));
                half4 c10 = SAMPLE_TEXTURE2D(_ImpostorAtlas, sampler_ImpostorAtlas, FrameUV(f10, IN.uv));
                half4 c01 = SAMPLE_TEXTURE2D(_ImpostorAtlas, sampler_ImpostorAtlas, FrameUV(f01, IN.uv));
                half4 c11 = SAMPLE_TEXTURE2D(_ImpostorAtlas, sampler_ImpostorAtlas, FrameUV(f11, IN.uv));

                half4 col = lerp(lerp(c00, c10, blend.x),
                                 lerp(c01, c11, blend.x), blend.y);

                clip(col.a - _AlphaCutoff);

                half3 rgb = col.rgb * _Tint.rgb;
                rgb = MixFog(rgb, IN.fogCoord);

                return half4(rgb, 1.0);
            }
            ENDHLSL
        }

        // ──────────────────────────────────────────────
        // Shadow Caster
        // ──────────────────────────────────────────────
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag

            struct Attributes
            {
                float4 posOS : POSITION;
                float2 uv    : TEXCOORD0;
            };

            struct Varyings
            {
                float4 posCS : SV_POSITION;
                float2 uv    : TEXCOORD0;
            };

            Varyings ShadowVert(Attributes IN)
            {
                Varyings o;
                float3 wp, wc;
                Billboard(IN.posOS, wp, wc);
                o.posCS = TransformWorldToHClip(wp);
                o.uv    = IN.uv;
                return o;
            }

            half4 ShadowFrag(Varyings IN) : SV_Target
            {
                float2 oct = ViewOct();
                float2 gridUV = (oct * 0.5 + 0.5) * _GridSize;
                float2 idx = clamp(floor(gridUV), 0, _GridSize - 1);
                half4 col = SAMPLE_TEXTURE2D(_ImpostorAtlas, sampler_ImpostorAtlas, FrameUV(idx, IN.uv));
                clip(col.a - _AlphaCutoff);
                return 0;
            }
            ENDHLSL
        }

        // ──────────────────────────────────────────────
        // Depth Only
        // ──────────────────────────────────────────────
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Off

            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag

            struct Attributes
            {
                float4 posOS : POSITION;
                float2 uv    : TEXCOORD0;
            };

            struct Varyings
            {
                float4 posCS : SV_POSITION;
                float2 uv    : TEXCOORD0;
            };

            Varyings DepthVert(Attributes IN)
            {
                Varyings o;
                float3 wp, wc;
                Billboard(IN.posOS, wp, wc);
                o.posCS = TransformWorldToHClip(wp);
                o.uv    = IN.uv;
                return o;
            }

            half4 DepthFrag(Varyings IN) : SV_Target
            {
                float2 oct = ViewOct();
                float2 gridUV = (oct * 0.5 + 0.5) * _GridSize;
                float2 idx = clamp(floor(gridUV), 0, _GridSize - 1);
                half4 col = SAMPLE_TEXTURE2D(_ImpostorAtlas, sampler_ImpostorAtlas, FrameUV(idx, IN.uv));
                clip(col.a - _AlphaCutoff);
                return 0;
            }
            ENDHLSL
        }
    }

    Fallback Off
}
