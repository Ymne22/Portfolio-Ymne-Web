Shader "YmneShader/ShellTexturingGrass"
{
    Properties
    {
        [Header(Grass Settings)]
        _GrassBottomColor ("Grass Bottom Color", Color) = (0.06, 0.15, 0.03, 1)
        _GrassColor ("Grass Base Color", Color) = (0.2, 0.5, 0.1, 1)
        _GrassTipColor ("Grass Tip Color", Color) = (0.4, 0.8, 0.2, 1)
        [IntRange] _GrassSize ("Grass Size", Range(16, 32)) = 30
        _GrassDensity ("Grass Density", Range(0.01, 1.0)) = 0.3
        
        [Header(Triplanar Settings)]
        _TriplanarScale ("Triplanar Scale", Float) = 0.5
        _TriplanarBlendSharpness ("Triplanar Blend Sharpness", Range(1, 64)) = 10.0
        
        [Header(Parallax Settings)]
        _ParallaxStrength ("Parallax Strength", Range(0.0, 0.5)) = 0.1
        [IntRange] _ParallaxSteps ("Parallax Steps", Range(2, 128)) = 8
        [IntRange] _ParallaxRefinement ("Parallax Refinement", Range(1, 8)) = 4
        
        [Header(Stylization)]

        [IntRange] _PixelTextureResolution ("Pixel Texture Resolution", Range(32, 512)) = 128
        
        [Header(Wind)]
        [Toggle(_WIND_ON)] _EnableWind ("Enable Wind", Float) = 1.0
        _WindStrength ("Wind Strength", Range(0, 32)) = 4.0
        _WindSpeed ("Wind Speed", Range(0.1, 32)) = 3.0
        _WindGustStrength ("Gust Strength", Range(0, 1)) = 0.15
        _WindGustFrequency ("Gust Frequency", Range(0.1, 2.0)) = 0.5
        _WindWaveScale ("Wind Wave Scale", Range(0.01, 1)) = 0.08
        
        [Header(Lighting)]
        _AmbientOcclusion ("Ambient Occlusion", Range(0, 1)) = 0.8
        _Smoothness ("Smoothness", Range(0, 1)) = 0.1

        _Brightness ("Brightness", Range(0.1, 2.0)) = 1.0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        
        CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        
        // Properties
        float4 _GrassBottomColor;
        float4 _GrassColor;
        float4 _GrassTipColor;
        int _GrassSize;
        float _GrassDensity;
        
        float _TriplanarScale;
        float _TriplanarBlendSharpness;
        
        float _ParallaxStrength;
        int _ParallaxSteps;
        int _ParallaxRefinement;
        

        int _PixelTextureResolution;
        
        float _WindStrength;
        float _WindSpeed;
        float _WindGustStrength;
        float _WindGustFrequency;
        float _WindWaveScale;
        
        float _AmbientOcclusion;
        float _Smoothness;

        float _Brightness;
        
        // Procedural Hash
        float Hash21(float2 p)
        {
            p = frac(p * float2(234.34, 435.345));
            p += dot(p, p + 34.23);
            return frac(p.x * p.y);
        }

        // Vectorized 2 to 3 Hash
        float3 Hash23(float2 p)
        {
            float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
            p3 += dot(p3, p3.yzx + 33.33);
            return frac((p3.xxy + p3.yzz) * p3.zyx);
        }
        
        // 2D Quintic Noise
        float Noise2D(float2 uv)
        {
            float2 i = floor(uv);
            float2 f = frac(uv);
            
            float a = Hash21(i);
            float b = Hash21(i + float2(1.0, 0.0));
            float c = Hash21(i + float2(0.0, 1.0));
            float d = Hash21(i + float2(1.0, 1.0));
            
            // Quintic interpolation for smoother results
            float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
            
            return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
        }
        
        // Fractal Brownian Motion
        float FBM(float2 uv, int octaves)
        {
            float value = 0.0;
            float amplitude = 0.5;
            float frequency = 1.0;
            float maxValue = 0.0;
            
            for (int i = 0; i < octaves; i++)
            {
                value += amplitude * Noise2D(uv * frequency);
                maxValue += amplitude;
                amplitude *= 0.5;
                frequency *= 2.0;
            }
            
            return value / maxValue;
        }
        
        // Wind Wave Calculation
        float2 WindWave(float2 pos, float time)
        {
            float2 wave1 = sin(pos * 1.5 + time * float2(1.0, 0.7)) * 0.5;
            float2 wave2 = sin(pos * 2.3 + time * float2(0.8, 1.1) + 1.57) * 0.3;
            float2 wave3 = sin(pos * 0.7 + time * float2(0.5, 0.3) + 3.14) * 0.2;
            return wave1 + wave2 + wave3;
        }
        
        // Wind Gust Calculation
        float WindGust(float3 worldPos, float time)
        {
            float gustTime = time * _WindGustFrequency;
            // Prevent stretching on vertical surfaces
            float2 noisePos = worldPos.xz + worldPos.y * 0.5;
            float gustNoise = FBM(noisePos * 0.02 + gustTime * 0.3, 2);
            float gustWave = sin(gustTime + gustNoise * 6.28) * 0.5 + 0.5;
            gustWave = smoothstep(0.3, 0.7, gustWave);
            return lerp(1.0, 1.0 + _WindGustStrength, gustWave);
        }
        
        // Pixelate UV coordinates
        float2 PixelateUV(float2 uv, int pixelSize)
        {
            float size = (float)pixelSize;
            return floor(uv * size) / size;
        }
        
        // Triplanar Weights
        float3 GetTriplanarWeights(float3 normalWS, float sharpness)
        {
            float3 weights = abs(normalWS);
            weights = pow(weights, sharpness);
            return weights / (weights.x + weights.y + weights.z);
        }
        
        // Grass Blade Logic
        float GrassBladeMask(float2 uv, float shellHeight, int density)
        {
            float densityF = (float)density;
            float2 cellUV = frac(uv * densityF);
            float2 cellID = floor(uv * densityF);
            
            // Randomized attributes
            float3 rand = Hash23(cellID);
            
            float2 randomOffset = rand.xy * 0.5;
            float2 centeredUV = cellUV - 0.5 + randomOffset;
            
            float dist = length(centeredUV);
            float thicknessAtHeight = _GrassDensity * (1.0 - shellHeight * shellHeight);
            
            float bladeMaxHeight = rand.z;
            float heightMask = step(shellHeight, bladeMaxHeight);
            
            return step(dist, thicknessAtHeight) * heightMask;
        }
        
        // Pre-computed normalized wind direction (1, 0, 0.5) normalized = (0.894, 0, 0.447)
        static const float3 WIND_DIR = float3(0.894427, 0.0, 0.447214);
        
        // Wind Field Calculation
        float3 GetBaseWindVector(float3 worldPos) 
        {
            float time = _Time.y * _WindSpeed;
            
            // Primary smooth wave motion
            // Use 3D-ish position for noise to handle vertical surfaces correctly
            float2 noisePos = worldPos.xz + worldPos.y * 0.4;
            float2 waveOffset = WindWave(noisePos * _WindWaveScale, time);
            
            // Calculate wind gust intensity
            float gustIntensity = WindGust(worldPos, time);
            
            // Combine wind components (waves + gusts, no turbulence)
            float3 windOffset = float3(0, 0, 0);
            
            // Main directional wind with wave motion
            windOffset.xz += WIND_DIR.xz * _WindStrength * (0.5 + waveOffset.x * 0.5);
            windOffset.xz += waveOffset * _WindStrength * 0.4;
            
            // Apply gust multiplier
            windOffset *= gustIntensity;
            
            return windOffset;
        }

        // Height-based Wind Influence
        float3 ApplyWindHeight(float3 baseWind, float shellHeight) 
        {
            // Smooth height factor with easing curve
            float heightFactor = shellHeight * shellHeight * (3.0 - 2.0 * shellHeight);
            
            float3 finalWind = baseWind;
            
            // Slight vertical motion for more natural look
            finalWind.y = -length(finalWind.xz) * 0.1 * heightFactor;
            
            // Apply height-based influence
            finalWind *= heightFactor;
            
            return finalWind;
        }
        
        // Parallax Shell Sampler
        float ParallaxShellSample(float2 uv, float3 viewDirTangent, float3 worldPos, float3x3 TBN, float3 normalWS, out float3 grassColor, out float shellHeightOut)
        {
            // Calculate Triplanar Weights once
            float3 weights = GetTriplanarWeights(normalWS, _TriplanarBlendSharpness);
            
            float stepsF = (float)_ParallaxSteps;
            
            float3 viewDirWS = normalize(_WorldSpaceCameraPos - worldPos);
            float NdotV = dot(viewDirWS, normalWS);
            float rayLength = _ParallaxStrength / max(NdotV, 0.1); 
            float3 parallaxOffsetStep = -viewDirWS * rayLength / stepsF; 
            
            float3 currentPos = worldPos;
            
            float accumulatedMask = 0.0;
            grassColor = _GrassColor.rgb;
            shellHeightOut = 0.0;
            
            // Store previous for refinement
            float3 prevPos = currentPos;
            float prevShellHeight = 1.0;
            
            // OPTIMIZATION: Pre-calculate wind vector
            #if defined(_WIND_ON)
            float3 baseWind = GetBaseWindVector(worldPos);
            #endif
            
            // Phase 1: Coarse linear search
            for (int i = 0; i < _ParallaxSteps; i++)
            {
                float shellIndex = (float)i * (1.0 / stepsF);
                float shellHeight = 1.0 - shellIndex;
                
                #if defined(_WIND_ON)
                float3 windOffsetWS = ApplyWindHeight(baseWind, shellHeight);
                float3 samplePos = currentPos + windOffsetWS * 0.1;
                #else
                float3 samplePos = currentPos;
                #endif
                
                // Shell Sampling (Triplanar)
                // Plane X (YZ coords)
                float2 uvX = samplePos.zy * _TriplanarScale;
                float2 pixX = PixelateUV(uvX, _PixelTextureResolution);
                float maskX = GrassBladeMask(pixX, shellHeight, _GrassSize);
                
                // Plane Y (XZ coords) - Top down
                float2 uvY = samplePos.xz * _TriplanarScale;
                float2 pixY = PixelateUV(uvY, _PixelTextureResolution);
                float maskY = GrassBladeMask(pixY, shellHeight, _GrassSize);
                
                // Plane Z (XY coords)
                float2 uvZ = samplePos.xy * _TriplanarScale;
                float2 pixZ = PixelateUV(uvZ, _PixelTextureResolution);
                float maskZ = GrassBladeMask(pixZ, shellHeight, _GrassSize);
                
                // Blend Masks
                float blendedMask = maskX * weights.x + maskY * weights.y + maskZ * weights.z;
                
                if (blendedMask > 0.5 && accumulatedMask < 0.5)
                {
                    accumulatedMask = 1.0;
                    
                    // Phase 2: Refinement
                    float refinedHeight = shellHeight;
                    float refineF = (float)_ParallaxRefinement;
                    
                    for (int j = 1; j <= _ParallaxRefinement; j++)
                    {
                        float t = (float)j / refineF;
                        float3 refinePos = lerp(currentPos, prevPos, t);
                        float refineHeight = lerp(shellHeight, prevShellHeight, t);
                        
                        #if defined(_WIND_ON)
                        float3 refWindOffsetWS = ApplyWindHeight(baseWind, refineHeight);
                        float3 refSamplePos = refinePos + refWindOffsetWS * 0.1;
                        #else
                        float3 refSamplePos = refinePos;
                        #endif
                        
                        // Triplanar Sampling (Refinement)
                        float2 ruvX = refSamplePos.zy * _TriplanarScale;
                        float rmaskX = GrassBladeMask(PixelateUV(ruvX, _PixelTextureResolution), refineHeight, _GrassSize);
                        
                        float2 ruvY = refSamplePos.xz * _TriplanarScale;
                        float rmaskY = GrassBladeMask(PixelateUV(ruvY, _PixelTextureResolution), refineHeight, _GrassSize);
                        
                        float2 ruvZ = refSamplePos.xy * _TriplanarScale;
                        float rmaskZ = GrassBladeMask(PixelateUV(ruvZ, _PixelTextureResolution), refineHeight, _GrassSize);
                        
                        float refMask = rmaskX * weights.x + rmaskY * weights.y + rmaskZ * weights.z;
                        
                        if (refMask > 0.5)
                        {
                            refinedHeight = refineHeight;
                        }
                        else
                        {
                            break;
                        }
                    }
                    shellHeightOut = refinedHeight;
                    grassColor = lerp(_GrassColor.rgb, _GrassTipColor.rgb, shellHeightOut);
                    break;
                }
                
                prevPos = currentPos;
                currentPos += parallaxOffsetStep;
            }
            
            return accumulatedMask;
        }
        
        void SampleGrassBase(float2 uv, float3 positionWS, float3 normalWS, float3 tangentWS, float3 bitangentWS, float3 viewDirWS, 
                             out float3 grassColor, out float ao, out float3 outNormalWS, out float grassMask, out float shellHeight)
        {
            // Normalize TBN vectors for accurate projection
            float3 normal = normalize(normalWS);
            float3 tangent = normalize(tangentWS);
            float3 bitangent = normalize(bitangentWS);
            
            float3x3 TBN = float3x3(tangent, bitangent, normal);
            float3 viewDirTS = normalize(mul(TBN, viewDirWS));
            
            grassMask = ParallaxShellSample(uv, viewDirTS, positionWS, TBN, normal, grassColor, shellHeight);
            outNormalWS = normal;
            
            if (grassMask < 0.5)
            {
                grassColor = _GrassBottomColor.rgb;
                ao = _AmbientOcclusion;
            }
            else
            {
                ao = lerp(_AmbientOcclusion, 1.0, shellHeight);
            }
        }
        

        
        ENDCG
        
        // =============================================
        // Forward Base Pass - Main Directional Light
        // =============================================
        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode" = "ForwardBase" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fwdbase
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma shader_feature_local _WIND_ON
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1; // Lightmap UV
                float2 uv2 : TEXCOORD2; // Dynamic Lightmap UV
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float3 viewDirWS : TEXCOORD5;
                SHADOW_COORDS(6)
                #ifdef DYNAMICLIGHTMAP_ON
                float2 dynamicLightmapUV : TEXCOORD7;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.pos = UnityObjectToClipPos(v.vertex);
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = v.uv;
                
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.tangentWS = UnityObjectToWorldDir(v.tangent.xyz);
                o.bitangentWS = cross(o.normalWS, o.tangentWS) * v.tangent.w;
                o.viewDirWS = normalize(_WorldSpaceCameraPos - o.positionWS);
                
                #ifdef DYNAMICLIGHTMAP_ON
                o.dynamicLightmapUV = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                
                TRANSFER_SHADOW(o);
                
                return o;
            }
            
            float4 frag(v2f i) : SV_Target
            {
                float3 grassColor;
                float ao;
                float3 normalWS;
                float grassMask;
                float shellHeight;
                SampleGrassBase(i.uv, i.positionWS, i.normalWS, i.tangentWS, i.bitangentWS, i.viewDirWS, 
                               grassColor, ao, normalWS, grassMask, shellHeight);
                
                float3 V = normalize(i.viewDirWS);
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                
                float3 finalColor = float3(0, 0, 0);
                float3 diffuseColor = grassColor;
                
                // Shadow
                float shadow = SHADOW_ATTENUATION(i);
                
                // Ambient term (Environment Lighting + Realtime GI)
                float3 ambient = ShadeSH9(float4(normalWS, 1));
                
                #ifdef DYNAMICLIGHTMAP_ON
                // Sample realtime GI from dynamic lightmap
                float4 realtimeGI = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.dynamicLightmapUV);
                float3 decodedGI = DecodeRealtimeLightmap(realtimeGI);
                ambient += decodedGI;
                #endif
                
                float3 envLighting = diffuseColor * ambient;
                finalColor += envLighting;

                // Main directional light
                float NdotL = saturate(dot(normalWS, L));
                
                // Diffuse contribution
                float3 diffuse = diffuseColor * NdotL * shadow * _LightColor0.rgb;
                finalColor += diffuse;
                
                // Apply ambient occlusion
                finalColor *= ao;
                
                // Apply brightness
                finalColor *= _Brightness;
                
                // Clamp to valid range
                finalColor = saturate(finalColor);
                
                return float4(finalColor, 1.0);
            }
            
            ENDCG
        }
        
        // =============================================
        // Forward Add Pass - Additional Lights
        // =============================================
        Pass
        {
            Name "ForwardAdd"
            Tags { "LightMode" = "ForwardAdd" }
            
            Blend One One
            Cull Back
            ZWrite Off
            ZTest LEqual
            
            CGPROGRAM
            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #pragma multi_compile_instancing
            #pragma multi_compile_fwdadd_fullshadows
            #pragma shader_feature_local _WIND_ON
            
            struct appdata_add
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f_add
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float3 viewDirWS : TEXCOORD5;
                LIGHTING_COORDS(6, 7)
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            v2f_add vertAdd(appdata_add v)
            {
                v2f_add o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.pos = UnityObjectToClipPos(v.vertex);
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = v.uv;
                
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.tangentWS = UnityObjectToWorldDir(v.tangent.xyz);
                o.bitangentWS = cross(o.normalWS, o.tangentWS) * v.tangent.w;
                o.viewDirWS = normalize(_WorldSpaceCameraPos - o.positionWS);
                
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                
                return o;
            }
            
            float4 fragAdd(v2f_add i) : SV_Target
            {
                float3 grassColor;
                float ao;
                float3 normalWS;
                float grassMask;
                float shellHeight;
                SampleGrassBase(i.uv, i.positionWS, i.normalWS, i.tangentWS, i.bitangentWS, i.viewDirWS, 
                               grassColor, ao, normalWS, grassMask, shellHeight);
                
                // Calculate light direction (handles both directional and point/spot lights)
                float3 lightDir;
                
                #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
                    float3 lightToVertex = _WorldSpaceLightPos0.xyz - i.positionWS;
                    lightDir = normalize(lightToVertex);
                #else
                    lightDir = normalize(_WorldSpaceLightPos0.xyz);
                #endif
                
                // Use Unity's built-in light attenuation macro for proper falloff
                UNITY_LIGHT_ATTENUATION(atten, i, i.positionWS);
                
                // NdotL
                float NdotL = saturate(dot(normalWS, lightDir));
                
                // Diffuse contribution - use attenuation directly
                float3 diffuseColor = grassColor;
                float3 diffuse = diffuseColor * NdotL * atten * _LightColor0.rgb;
                
                // Apply ambient occlusion
                diffuse *= ao;
                
                // Apply brightness
                diffuse *= _Brightness;
                
                return float4(diffuse, 1.0);
            }
            
            ENDCG
        }
        
        // =============================================
        // Shadow Caster Pass
        // =============================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            
            CGPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_instancing
            #pragma multi_compile_shadowcaster
            
            struct appdata_shadow
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f_shadow
            {
                V2F_SHADOW_CASTER;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            v2f_shadow vertShadow(appdata_shadow v)
            {
                v2f_shadow o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }
            
            float4 fragShadow(v2f_shadow i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }
            
            ENDCG
        }
        
        // =============================================
        // Meta Pass - For Lightmap Baking
        // =============================================
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }
            
            Cull Off
            
            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta
            
            #include "UnityMetaPass.cginc"
            
            struct appdata_meta
            {
                float4 vertex : POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
            };
            
            struct v2f_meta
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            v2f_meta vert_meta(appdata_meta v)
            {
                v2f_meta o;
                o.pos = UnityMetaVertexPosition(v.vertex, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST);
                o.uv = v.uv0;
                return o;
            }
            
            float4 frag_meta(v2f_meta i) : SV_Target
            {
                UnityMetaInput metaIN;
                UNITY_INITIALIZE_OUTPUT(UnityMetaInput, metaIN);
                
                // Use the base grass color for lightmap baking
                metaIN.Albedo = _GrassColor.rgb;
                metaIN.Emission = float3(0, 0, 0);
                metaIN.SpecularColor = float3(0, 0, 0);
                
                return UnityMetaFragment(metaIN);
            }
            
            ENDCG
        }
    }
    
    Fallback "Diffuse"
}
