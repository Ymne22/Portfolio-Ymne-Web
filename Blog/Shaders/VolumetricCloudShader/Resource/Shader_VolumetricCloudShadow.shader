Shader "YmneShader/VolumetricCloudShadow"
{
    Properties
    {
        _ShadowColor ("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
        _Intensity ("Shadow Intensity", Range(0, 5)) = 1.0
        _Contrast ("Cloud Contrast", Range(0, 10)) = 1.0
        _NoiseScale ("Noise Scale (XYZ)", Vector) = (3, 3, 3, 0)
        _Speed ("Speed (XYZ)", Vector) = (0.2, 0.1, 0.2, 0)
        _EdgeSoftness ("Edge Softness", Range(0.001, 0.5)) = 0.1
    }
    SubShader
    {
        Tags { "Queue"="Transparent+1" "RenderType"="Transparent" "DisableBatching"="True" }
        LOD 100

        Cull Front
        ZWrite Off
        ZTest Always
        Blend DstColor Zero

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 rayDir : TEXCOORD1;
            };

            sampler2D _CameraDepthTexture;
            
            fixed4 _ShadowColor;
            float _Intensity;
            float _Contrast;
            float4 _NoiseScale;
            float4 _Speed;
            float _EdgeSoftness;

            // --- Simple 3D Noise Function ---
            float hash(float3 p) 
            {
                p = frac(p * 0.3183099 + .1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float noise(float3 x) 
            {
                float3 i = floor(x);
                float3 f = frac(x);
                // Cubic smoothing
                f = f * f * (3.0 - 2.0 * f);
                
                return lerp(lerp(lerp(hash(i + float3(0,0,0)), 
                                      hash(i + float3(1,0,0)), f.x),
                                 lerp(hash(i + float3(0,1,0)), 
                                      hash(i + float3(1,1,0)), f.x), f.y),
                            lerp(lerp(hash(i + float3(0,0,1)), 
                                      hash(i + float3(1,0,1)), f.x),
                                 lerp(hash(i + float3(0,1,1)), 
                                      hash(i + float3(1,1,1)), f.x), f.y), f.z);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                
                // Calculate Ray Direction (Camera to Vertex)
                // We use the vertex world position to determine the ray direction
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.rayDir = worldPos - _WorldSpaceCameraPos;
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 1. Calculate Screen UV
                float2 uv = i.screenPos.xy / i.screenPos.w;
                
                // 2. Sample Depth
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
                float linearDepth = LinearEyeDepth(rawDepth);
                
                // 3. Reconstruct World Position (FakeLight Method)
                float3 rayDir = normalize(i.rayDir);
                
                // ViewZ is the distance along the camera's forward axis
                // We need to convert LinearEyeDepth (which is Z distance) to Radial Distance
                float3 cameraForward = -UNITY_MATRIX_V[2].xyz;
                float viewZ = dot(rayDir, cameraForward);
                float dist = linearDepth / viewZ;
                
                float3 worldPos = _WorldSpaceCameraPos + rayDir * dist;
                
                // 4. Object Space Projection
                float3 objPos = mul(unity_WorldToObject, float4(worldPos, 1.0)).xyz;
                
                // 5. Box Bounds Check (-0.5 to 0.5)
                float3 distToEdge = 0.5 - abs(objPos);
                float minEdgeDist = min(distToEdge.x, min(distToEdge.y, distToEdge.z));
                
                if (minEdgeDist < 0) return fixed4(1, 1, 1, 1);

                float edgeMask = smoothstep(0, _EdgeSoftness, minEdgeDist);

                // 6. 3D Procedural Noise Sampling
                float3 noisePos = (objPos * _NoiseScale.xyz) + (_Speed.xyz * _Time.y);
                float n = noise(noisePos);
                
                // Contrast Adjustment
                // Shift range to -0.5 to 0.5, multiply by contrast, shift back
                n = saturate((n - 0.5) * _Contrast + 0.5);
                
                float shadowFactor = n * _Intensity * edgeMask;
                fixed3 finalColor = lerp(fixed3(1,1,1), _ShadowColor.rgb, saturate(shadowFactor));

                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
}
