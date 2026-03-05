Shader "YmneShader/Shader_FakeLight"
{ 
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Intensity ("Intensity", Float) = 1.0
        _FalloffExp ("Falloff Exponent", Range(1.0, 5.0)) = 2.0
        [Toggle(_ENABLE_HALO)] _EnableHalo ("Enable Halo", Float) = 0
        _HaloSize ("Halo Size", Range(0.0, 5.0)) = 1.0
        _HaloIntensity ("Halo Intensity", Range(0.0, 5.0)) = 0.5
        _HaloFalloffExp ("Halo Falloff Exp", Range(1.0, 10.0)) = 2.0
        [Toggle(_ENABLE_SHADOWS)] _EnableShadows ("Enable Shadows", Float) = 0
        [Toggle(_USE_TAA_JITTER)] _UseTAAJitter ("TAA Mode (High Freq Noise)", Float) = 0
        _ShadowStrength ("Shadow Strength", Range(0.0, 1.0)) = 0.5
        _ShadowSteps ("Shadow Steps", Range(4, 128)) = 8
        _ShadowBias ("Shadow Bias", Range(0.001, 0.2)) = 0.05
        _ShadowMaxDist ("Shadow Distance", Range(0, 128)) = 8.0
        _ShadowBlur ("Shadow Blur (Jitter)", Range(0.0, 1.0)) = 0.0
        _ShadowSourceRadius ("Shadow Source Radius", Range(0.0, 1.0)) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent-1" "IgnoreProjector"="True" "RenderType"="Transparent" }
        Blend DstColor One
        ZWrite Off
        Cull Front
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma target 3.0
            
            #pragma shader_feature_local _ENABLE_HALO
            #pragma shader_feature_local _ENABLE_SHADOWS
            #pragma shader_feature_local _USE_TAA_JITTER

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                half4 color : COLOR;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                half4 color : COLOR;
                float3 rayDir : TEXCOORD2;
            };

            half4 _Color;
            half _Intensity;
            half _FalloffExp;
            
            #if defined(_ENABLE_HALO)
            half _HaloSize;
            half _HaloIntensity;
            half _HaloFalloffExp;
            #endif
            
            #if defined(_ENABLE_SHADOWS)
            half _ShadowStrength;
            half _ShadowSteps;
            half _ShadowBias;
            half _ShadowMaxDist;
            half _ShadowBlur;
            half _ShadowSourceRadius;
            #endif
            
            sampler2D _CameraDepthTexture;
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.color = v.color * _Color;
                
                o.rayDir = o.worldPos - _WorldSpaceCameraPos;
                
                return o;
            }

            inline half fastPow2(half x) { return x * x; }
            inline half fastPow3(half x) { return x * x * x; }
            inline half fastPow4(half x) { half x2 = x * x; return x2 * x2; }
            
            inline half cheapPow(half x, half p)
            {
                return pow(x, p);
            }

            half4 frag (v2f i) : SV_Target
            {
                // 1. Calculate Screen UV
                float2 uv = i.screenPos.xy / i.screenPos.w;

                // 2. Sample Depth
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
                float linearDepth = LinearEyeDepth(rawDepth);

                // 3. Reconstruct World Position of the Scene
                float3 rayDir = normalize(i.rayDir);
                
                float3 cameraForward = -UNITY_MATRIX_V[2].xyz;
                float viewZ = dot(rayDir, cameraForward);
                float dist = linearDepth / viewZ;
                
                float3 sceneWorldPos = _WorldSpaceCameraPos + rayDir * dist;

                // 4. Transform to Object Space
                float3 sceneObjPos = mul(unity_WorldToObject, float4(sceneWorldPos, 1.0)).xyz;
                
                // 5. Scene Intersection Lighting
                float distSqFromCenter = dot(sceneObjPos, sceneObjPos);
                float distFromCenter = sqrt(distSqFromCenter);
                half normalizedDist = distFromCenter * 2.0; 
                half attenuation = saturate(1.0 - normalizedDist);
                attenuation = pow(attenuation, _FalloffExp);
                
                half finalIntensity = attenuation;

                #if defined(UNITY_PASS_FORWARDBASE) || !defined(UNITY_PASS_FORWARDBASE)
                half sceneViewFactor = unity_OrthoParams.w;
                finalIntensity *= lerp(1.0h, 0.15h, sceneViewFactor);
                #endif

                // 6. Volumetric Halo
                #if defined(_ENABLE_HALO)
                {
                    UNITY_BRANCH
                    if (_HaloIntensity > 0.001h)
                    {
                        // Transform camera pos to object space
                        float3 camObjPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
                        
                        // Ray direction in object space
                        float3 objRayDir = normalize(sceneObjPos - camObjPos);
                        
                        // Distance from ray to center (0,0,0)
                        float t = dot(-camObjPos, objRayDir);
                        float3 closestPoint = camObjPos + objRayDir * t;
                        
                        // Use squared distance where possible
                        float distRayToCenterSq = dot(closestPoint, closestPoint);
                        float distRayToCenter = sqrt(distRayToCenterSq);
                        
                        // Halo Falloff
                        half safeHaloSize = max(_HaloSize, 0.001h);
                        half invHaloSize = 1.0h / safeHaloSize;
                        half haloNormDist = distRayToCenter * 2.0h * invHaloSize;
                        
                        half haloAtten = saturate(1.0h - haloNormDist);
                        haloAtten = pow(haloAtten, _HaloFalloffExp);
                        
                        // Depth occlusion
                        float distToSceneSq = dot(sceneObjPos - camObjPos, sceneObjPos - camObjPos);
                        float distToHaloSq = dot(closestPoint - camObjPos, closestPoint - camObjPos);
                        
                        // Occlude if scene is closer than halo plane
                        haloAtten *= step(distToHaloSq, distToSceneSq);
                        
                        finalIntensity += haloAtten * _HaloIntensity;
                    }
                }
                #endif

                // 7. Screen Space Shadows
                #if defined(_ENABLE_SHADOWS)
                UNITY_BRANCH
                if (attenuation > 0.001h)
                {
                    // Light center in view space
                    float3 lightViewPos = UnityObjectToViewPos(float3(0,0,0));
                    
                    // Scene surface in view space
                    float3 sceneViewPos = mul(UNITY_MATRIX_V, float4(sceneWorldPos, 1.0)).xyz;
                    
                    // Setup ray
                    float3 rayVec = lightViewPos - sceneViewPos;
                    float rayLenSq = dot(rayVec, rayVec);
                    float rayLen = sqrt(rayLenSq);
                    float invRayLen = 1.0 / rayLen;
                    float3 shadowRayDir = rayVec * invRayLen;
                    
                    // Precompute limits
                    float maxDistNorm = _ShadowMaxDist * invRayLen;
                    float sourceRadiusNorm = _ShadowSourceRadius * invRayLen;
                    
                    int steps = (int)_ShadowSteps;
                    float stepSize = 1.0 / steps;
                    
                    // Noise calculation
                    float noise;
                    float2 screenPixel = uv * _ScreenParams.xy;
                    
                    #if defined(_USE_TAA_JITTER)
                    {
                        // Interleaved Gradient Noise for TAA
                        float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
                        noise = frac(magic.z * frac(dot(screenPixel + _Time.y * 60.0, magic.xy)));
                    }
                    #else
                    {
                        int2 p = int2(screenPixel) & 3;
                        int idx = p.x + p.y * 4;
                        
                        static const float bayerMatrix[16] = {
                            0.0, 8.0, 2.0, 10.0,
                            12.0, 4.0, 14.0, 6.0,
                            3.0, 11.0, 1.0, 9.0,
                            15.0, 7.0, 13.0, 5.0
                        };
                        noise = bayerMatrix[idx] * 0.0625;
                    }
                    #endif
                    
                    // Orthogonal basis for blur jitter
                    float3 up = abs(shadowRayDir.y) < 0.999 ? float3(0,1,0) : float3(1,0,0);
                    float3 right = normalize(cross(shadowRayDir, up));
                    up = cross(right, shadowRayDir);
                    
                    // Golden angle constant
                    static const float GOLDEN_ANGLE = 2.39996;
                    static const float TWO_PI = 6.28318;
                    float baseAngle = noise * TWO_PI;
                    
                    half shadow = 0.0h;
                    
                    [loop]
                    for(int k = 1; k < steps; k++) 
                    {
                        float t = (float)k * stepSize;
                        
                        // Early out: distance limit
                        if (t > maxDistNorm) break;
                        
                        // Early out: inside light source
                        if ((1.0 - t) < sourceRadiusNorm) break;
                        
                        // Interpolate position
                        float3 samplePosView = lerp(sceneViewPos, lightViewPos, t);
                        
                        // Apply blur jitter
                        float angle = k * GOLDEN_ANGLE + baseAngle;
                        float sinAngle, cosAngle;
                        sincos(angle, sinAngle, cosAngle);
                        
                        float blurRadius = t * _ShadowBlur;
                        samplePosView += (right * cosAngle + up * sinAngle) * blurRadius;
                        
                        // Project to screen
                        float4 sampleClip = mul(UNITY_MATRIX_P, float4(samplePosView, 1.0));
                        float2 sampleUV = (sampleClip.xy / sampleClip.w) * 0.5 + 0.5;
                        
                        // Handle platform differences in UV
                        #if UNITY_UV_STARTS_AT_TOP
                        if (_ProjectionParams.x < 0)
                            sampleUV.y = 1.0 - sampleUV.y;
                        #endif
                        
                        // Bounds check - use step for branchless
                        float inBounds = step(0.0, sampleUV.x) * step(sampleUV.x, 1.0) * 
                                        step(0.0, sampleUV.y) * step(sampleUV.y, 1.0);
                        
                        if (inBounds < 0.5) continue;
                        
                        float sRawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampleUV);
                        float sLinearDepth = LinearEyeDepth(sRawDepth);
                        
                        float rayDepth = -samplePosView.z;
                        
                        if (sLinearDepth < rayDepth - _ShadowBias)
                        {
                            shadow = 1.0h;
                            break;
                        }
                    }
                    
                    finalIntensity *= (1.0h - shadow * _ShadowStrength);
                }
                #endif

                // 8. Final Color
                half3 col = i.color.rgb * _Intensity * finalIntensity;
                
                return half4(col, 1.0h);
            }
            ENDCG
        }
    }
}
