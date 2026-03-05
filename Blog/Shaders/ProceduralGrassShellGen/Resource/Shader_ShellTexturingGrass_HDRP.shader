Shader "Custom/ShellTexturingGrass"
{
    Properties
    {
        [Header(Grass Settings)]
        _GrassBottomColor ("Grass Bottom Color", Color) = (0.06, 0.15, 0.03, 1)
        _GrassColor ("Grass Base Color", Color) = (0.2, 0.5, 0.1, 1)
        _GrassTipColor ("Grass Tip Color", Color) = (0.4, 0.8, 0.2, 1)
        [IntRange] _GrassSize ("Grass Size", Range(16, 32)) = 30
        _GrassDensity ("Grass Density", Range(0.01, 1.0)) = 0.3
        
        [Header(UV Tiling)]
        _Tiling ("Tiling", Vector) = (1, 1, 0, 0)
        _Offset ("Offset", Vector) = (0, 0, 0, 0)
        
        [Header(Parallax Settings)]
        _ParallaxStrength ("Parallax Strength", Range(0.0, 0.5)) = 0.1
        [IntRange] _ParallaxSteps ("Parallax Steps", Range(2, 128)) = 8
        [IntRange] _ParallaxRefinement ("Parallax Refinement", Range(1, 8)) = 4
        
        [Header(Stylization)]
        [IntRange] _Posterize ("Posterize", Range(4, 64)) = 24
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
        _AmbientStrength ("Ambient Strength", Range(0, 0.5)) = 0.1
        _Smoothness ("Smoothness", Range(0, 1)) = 0.1
        _ShadowStrength ("Shadow Strength", Range(0, 1)) = 1.0
        _Brightness ("Brightness", Range(0.1, 2.0)) = 1.0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderPipeline" = "HDRenderPipeline"
            "RenderType" = "HDLitShader"
            "Queue" = "Geometry+0"
        }
        
        HLSLINCLUDE
        #pragma target 4.5
        
        // Core HDRP includes
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
        #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"
        
        // Properties
        float4 _GrassBottomColor;
        float4 _GrassColor;
        float4 _GrassTipColor;
        int _GrassSize;
        float _GrassDensity;
        
        float4 _Tiling;
        float4 _Offset;
        
        float _ParallaxStrength;
        int _ParallaxSteps;
        int _ParallaxRefinement;
        
        int _Posterize;
        int _PixelTextureResolution;
        
        float _WindStrength;
        float _WindSpeed;
        float _WindGustStrength;
        float _WindGustFrequency;
        float _WindWaveScale;
        
        float _AmbientOcclusion;
        float _AmbientStrength;
        float _Smoothness;
        float _ShadowStrength;
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
            // Include Y in noise to prevent stretching on vertical surfaces
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
        
        // Apply tiling and offset to UV
        float2 ApplyTiling(float2 uv)
        {
            return uv * _Tiling.xy + _Offset.xy;
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
        float ParallaxShellSample(float2 uv, float3 viewDirTangent, float3 worldPos, float3x3 TBN, out float3 grassColor, out float shellHeightOut)
        {
            float2 tiledUV = ApplyTiling(uv);
            float2 currentUV = tiledUV;
            float stepsF = (float)_ParallaxSteps;
            float2 uvDelta = viewDirTangent.xy * _ParallaxStrength / stepsF;
            float invSteps = 1.0 / stepsF;
            
            float accumulatedMask = 0.0;
            grassColor = _GrassColor.rgb;
            shellHeightOut = 0.0;
            
            // Store previous layer for refinement
            float2 prevUV = currentUV;
            float prevShellHeight = 1.0;
            
            // Pre-calculate wind vector once per pixel
            #if defined(_WIND_ON)
            float3 baseWind = GetBaseWindVector(worldPos);
            #endif
            
            // Phase 1: Coarse linear search (only _ParallaxSteps iterations)
            for (int i = 0; i < _ParallaxSteps; i++)
            {
                float shellIndex = (float)i * invSteps;
                float shellHeight = 1.0 - shellIndex;
                
                #if defined(_WIND_ON)
                float3 windOffsetWS = ApplyWindHeight(baseWind, shellHeight);
                // Transform wind to tangent space for correct orientation on all surfaces
                float3 windOffsetTS = mul(TBN, windOffsetWS);
                // Use TS.xy for UV offset (U and V directions)
                float2 windUV = currentUV + windOffsetTS.xy * 0.02;
                #else
                float2 windUV = currentUV;
                #endif
                
                float2 pixelatedUV = PixelateUV(windUV, _PixelTextureResolution);
                float bladeMask = GrassBladeMask(pixelatedUV, shellHeight, _GrassSize);
                
                if (bladeMask > 0.5 && accumulatedMask < 0.5)
                {
                    accumulatedMask = 1.0;
                    
                    // Phase 2: Refinement
                    float refinedHeight = shellHeight;
                    float refineF = (float)_ParallaxRefinement;
                    
                    for (int j = 1; j <= _ParallaxRefinement; j++)
                    {
                        float t = (float)j / refineF;
                        float2 refineUV = lerp(currentUV, prevUV, t);
                        float refineHeight = lerp(shellHeight, prevShellHeight, t);
                        
                        #if defined(_WIND_ON)
                        float3 refWindOffsetWS = ApplyWindHeight(baseWind, refineHeight);
                        float3 refWindOffsetTS = mul(TBN, refWindOffsetWS);
                        float2 refWindUV = refineUV + refWindOffsetTS.xy * 0.02;
                        #else
                        float2 refWindUV = refineUV;
                        #endif
                        
                        float2 refPixelUV = PixelateUV(refWindUV, _PixelTextureResolution);
                        float refMask = GrassBladeMask(refPixelUV, refineHeight, _GrassSize);
                        
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
                    
                    float pixelSizeF = (float)_Posterize;
                    grassColor = lerp(_GrassColor.rgb, _GrassTipColor.rgb, shellHeightOut);
                    grassColor = floor(grassColor * pixelSizeF) / pixelSizeF;
                    break;
                }
                
                // Store current as previous
                prevUV = currentUV;
                prevShellHeight = shellHeight;
                currentUV -= uvDelta;
            }
            
            return accumulatedMask;
        }
        
        // Vertex structure
        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 uv : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };
        
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 positionWS : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float3 tangentWS : TEXCOORD3;
            float3 bitangentWS : TEXCOORD4;
            float3 viewDirWS : TEXCOORD5;
            UNITY_VERTEX_OUTPUT_STEREO
        };
        
        Varyings CommonVert(Attributes input)
        {
            Varyings output;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            
            float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
            output.positionCS = TransformWorldToHClip(positionWS);
            output.positionWS = positionWS;
            output.uv = input.uv;
            
            output.normalWS = TransformObjectToWorldNormal(input.normalOS);
            output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
            output.bitangentWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;
            output.viewDirWS = GetWorldSpaceNormalizeViewDir(positionWS);
            
            return output;
        }
        
        void SampleGrassBase(Varyings input, out float3 grassColor, out float ao, out float3 normalWS, out float grassMask, out float shellHeight)
        {
            // Normalize TBN vectors for accurate projection
            float3 normal = normalize(input.normalWS);
            float3 tangent = normalize(input.tangentWS);
            float3 bitangent = normalize(input.bitangentWS);
            
            float3x3 TBN = float3x3(tangent, bitangent, normal);
            float3 viewDirTS = normalize(mul(TBN, input.viewDirWS));
            
            grassMask = ParallaxShellSample(input.uv, viewDirTS, input.positionWS, TBN, grassColor, shellHeight);
            normalWS = normal;
             
            if (grassMask < 0.5)
            {
                grassColor = _GrassBottomColor.rgb;
                grassColor = floor(grassColor * _Posterize) / _Posterize;
                ao = _AmbientOcclusion;
            }
            else
            {
                ao = lerp(_AmbientOcclusion, 1.0, shellHeight);
                ao = floor(ao * 4.0) / 4.0;
            }
        }
        
        ENDHLSL
        
        // =============================================
        // GBuffer Pass - HDRP Lit Compatible Format
        // =============================================
        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "GBuffer" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            
            Stencil
            {
                WriteMask 7
                Ref 2
                Comp Always
                Pass Replace
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma shader_feature_local _WIND_ON
            
            Varyings vert(Attributes input)
            {
                return CommonVert(input);
            }
            
            // GBuffer output matching HDRP Lit Standard format
            void frag(Varyings input,
                out float4 outGBuffer0 : SV_Target0,
                out float4 outGBuffer1 : SV_Target1,
                out float4 outGBuffer2 : SV_Target2,
                out float4 outGBuffer3 : SV_Target3)
            {
                float3 grassColor;
                float ao;
                float3 normalWS;
                float grassMask;
                float shellHeight;
                SampleGrassBase(input, grassColor, ao, normalWS, grassMask, shellHeight);
                
                // Perceptual roughness from smoothness
                float perceptualRoughness = 1.0 - _Smoothness;
                
                // ========================================
                // GBuffer0: baseColor.rgb + specularOcclusion
                // ========================================
                // For standard Lit: diffuseColor in RGB, specularOcclusion in A
                // Grass is fully non-metallic, so diffuseColor = baseColor
                outGBuffer0 = float4(grassColor, ao);
                
                // ========================================
                // GBuffer1: Normal (octahedron encoded) + perceptualRoughness
                // ========================================
                // Use HDRP's standard normal buffer encoding
                NormalData normalData;
                normalData.normalWS = normalWS;
                normalData.perceptualRoughness = perceptualRoughness;
                EncodeIntoNormalBuffer(normalData, outGBuffer1);
                
                // ========================================
                // GBuffer2: fresnel0 (sRGB encoded) + materialFeatureId
                // ========================================
                // For dielectric (non-metal) materials, fresnel0 = 0.04
                // MaterialFeatureId for standard Lit = 0 (GBUFFER_LIT_STANDARD)
                float3 fresnel0 = float3(0.04, 0.04, 0.04);
                // Fast linear to sRGB for storage (matching HDRP's encoding)
                float3 fresnel0SRGB = sqrt(fresnel0); // Approximate sRGB
                // Pack: coatMask(5 bits) | materialFeatureId(3 bits) = 0 for standard
                uint materialFeatureId = 0; // GBUFFER_LIT_STANDARD
                uint coatMask = 0;
                uint packedAlpha = (coatMask << 3) | materialFeatureId;
                outGBuffer2 = float4(fresnel0SRGB, packedAlpha / 255.0);
                
                // ========================================
                // GBuffer3: bakeDiffuseLighting (pre-exposed)
                // ========================================
                // For deferred-only objects, this contains baked lighting * AO + emissive
                // We use 0 since we rely on dynamic lighting from the light loop
                // The deferred lighting pass will add all lighting
                outGBuffer3 = float4(0.0, 0.0, 0.0, 0.0);
            }
            
            ENDHLSL
        }
        
        // =============================================
        // Forward Pass with HDRP Multi-Light Support
        // =============================================
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma shader_feature_local _WIND_ON
            
            // Light and shadow keywords for HDRP 17.x
            #pragma multi_compile_fragment _ SCREEN_SPACE_SHADOWS_ON
            #pragma multi_compile USE_FPTL_LIGHTLIST USE_CLUSTERED_LIGHTLIST
            #pragma multi_compile_fragment PUNCTUAL_SHADOW_LOW PUNCTUAL_SHADOW_MEDIUM PUNCTUAL_SHADOW_HIGH
            #pragma multi_compile_fragment DIRECTIONAL_SHADOW_LOW DIRECTIONAL_SHADOW_MEDIUM DIRECTIONAL_SHADOW_HIGH
            #pragma multi_compile_fragment AREA_SHADOW_LOW AREA_SHADOW_MEDIUM AREA_SHADOW_HIGH
            
            // CRITICAL: Include shadow context FIRST before anything else to avoid redefinition
            // This must come before LightLoopDef.hlsl
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/Shadow/HDShadowContext.hlsl"
            
            // HDRP lighting includes
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightDefinition.cs.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoopDef.hlsl"
            
            // Shadow sampling functions
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/HDShadow.hlsl"
            
            // Suppress loop unrolling warnings/errors
            #pragma warning (disable : 3078) // loop control variable conflicts
            #pragma warning (disable : 3557) // loop only executes for 1 iteration
            #pragma warning (disable : 4714) // sum of temp registers exceeds buffer
            
            // Max light counts to prevent excessive loop iterations
            #define MAX_DIRECTIONAL_LIGHTS 2
            #define MAX_PUNCTUAL_LIGHTS 8
            #define MAX_AREA_LIGHTS 4
            
            Varyings vert(Attributes input)
            {
                return CommonVert(input);
            }
            
            // Smooth distance attenuation with Hermite smoothstep
            float SmoothDistanceAttenuation(float distanceSqr, float invSqrAttenuationRadius)
            {
                float factor = distanceSqr * invSqrAttenuationRadius;
                float smoothFactor = saturate(1.0 - factor);
                return smoothFactor * smoothFactor * (3.0 - 2.0 * smoothFactor);
            }
            
            // Angle attenuation for spot lights with smooth falloff
            float AngleAttenuation(float cosFwd, float lightAngleScale, float lightAngleOffset)
            {
                float atten = saturate(cosFwd * lightAngleScale + lightAngleOffset);
                return atten * atten * (3.0 - 2.0 * atten);
            }
            
            // Soft posterize - reduces harsh banding while maintaining stylized look
            float SoftPosterize(float value, float steps)
            {
                float stepped = floor(value * steps + 0.5) / steps;
                return lerp(value, stepped, 0.5);
            }
            
            float3 SoftPosterize3(float3 value, float steps)
            {
                float3 stepped = floor(value * steps + 0.5) / steps;
                return lerp(value, stepped, 0.5);
            }
            
            float4 frag(Varyings input) : SV_Target
            {
                float3 grassColor;
                float ao;
                float3 normalWS;
                float grassMask;
                float shellHeight;
                SampleGrassBase(input, grassColor, ao, normalWS, grassMask, shellHeight);
                
                float3 V = normalize(input.viewDirWS);
                float2 positionSS = input.positionCS.xy;
                
                // Initialize shadow context
                HDShadowContext shadowContext = InitShadowContext();
                
                float3 finalColor = float3(0, 0, 0);
                float3 diffuseColor = grassColor;
                
                // Ambient term - scale by directional light presence for proper darkness
                float ambientScale = _DirectionalLightCount > 0 ? 1.0 : 0.1;
                float3 ambient = diffuseColor * _AmbientStrength * ambientScale;
                finalColor += ambient;
                
                // =============================================
                // DIRECTIONAL LIGHTS
                // =============================================
                uint dirLightCount = min(_DirectionalLightCount, MAX_DIRECTIONAL_LIGHTS);
                for (uint i = 0; i < dirLightCount; i++)
                {
                    DirectionalLightData light = _DirectionalLightDatas[i];
                    float3 L = -light.forward.xyz;
                    
                    // Get light color
                    float rawIntensity = max(max(light.color.r, light.color.g), light.color.b);
                    float3 lightColorNorm = light.color.rgb / max(rawIntensity, 0.0001);
                    float lightIntensity = saturate(rawIntensity * 0.01);
                    
                    // NdotL with soft posterization
                    float NdotL = saturate(dot(normalWS, L));
                    NdotL = SoftPosterize(NdotL, 4.0);
                    
                    // Shadow sampling
                    float shadow = 1.0;
                    #if defined(SCREEN_SPACE_SHADOWS_ON)
                        int2 coord = int2(positionSS.xy);
                        shadow = LOAD_TEXTURE2D_ARRAY(_ScreenSpaceShadowsTexture, coord, i).x;
                    #else
                        if (light.shadowIndex >= 0)
                        {
                            shadow = GetDirectionalShadowAttenuation(shadowContext, positionSS, input.positionWS, normalWS, light.shadowIndex, L);
                        }
                    #endif
                    // Apply shadow strength and ensure shadows never go completely black
                    shadow = lerp(1.0, shadow, _ShadowStrength);
                    shadow = max(shadow, 0.15); // Minimum shadow to prevent pure black
                    shadow = SoftPosterize(shadow, 3.0);
                    
                    // Diffuse contribution
                    float3 diffuse = diffuseColor * NdotL * shadow * lightIntensity;
                    diffuse *= lightColorNorm;
                    
                    finalColor += diffuse;
                }
                
                // =============================================
                // PUNCTUAL LIGHTS (Point and Spot)
                // =============================================
                uint punctualCount = min(_PunctualLightCount, MAX_PUNCTUAL_LIGHTS);
                for (uint p = 0; p < punctualCount; p++)
                {
                    LightData lightData = _LightDatas[p];
                    
                    // Calculate light direction and distance
                    float3 lightToSample = input.positionWS - lightData.positionRWS;
                    float distSq = dot(lightToSample, lightToSample);
                    float dist = sqrt(distSq);
                    float3 L = -lightToSample / max(dist, 0.0001);
                    
                    // Smooth distance attenuation
                    float attenuation = SmoothDistanceAttenuation(distSq, lightData.rangeAttenuationScale);
                    
                    if (attenuation <= 0.001)
                        continue;
                    
                    // Spot light cone attenuation
                    bool isSpot = (lightData.lightType == GPULIGHTTYPE_SPOT);
                    bool isPoint = (lightData.lightType == GPULIGHTTYPE_POINT);
                    
                    if (isSpot)
                    {
                        float cosTheta = dot(-L, lightData.forward);
                        attenuation *= AngleAttenuation(cosTheta, lightData.angleScale, lightData.angleOffset);
                    }
                    
                    // NdotL with soft posterization
                    float NdotL = saturate(dot(normalWS, L));
                    NdotL = SoftPosterize(NdotL, 8.0);
                    
                    if (NdotL <= 0.0)
                        continue;
                    
                    // Shadow sampling for punctual lights
                    float shadow = 1.0;
                    if (lightData.shadowIndex >= 0)
                    {
                        shadow = GetPunctualShadowAttenuation(shadowContext, positionSS, input.positionWS, normalWS, 
                            lightData.shadowIndex, L, dist, isPoint, !isPoint);
                        shadow = lerp(1.0, shadow, _ShadowStrength);
                        shadow = max(shadow, 0.15); // Minimum shadow to prevent pure black
                        shadow = SoftPosterize(shadow, 3.0);
                    }
                    
                    // Get light color
                    float3 lightColorRaw = lightData.color;
                    float lightMagnitude = max(max(lightColorRaw.r, lightColorRaw.g), lightColorRaw.b);
                    float3 lightColorNorm = lightColorRaw / max(lightMagnitude, 0.0001);
                    
                    // Intensity with smooth attenuation
                    float intensityScale = lightMagnitude * attenuation;
                    intensityScale = saturate(intensityScale * 0.002);
                    
                    // Diffuse contribution
                    float3 diffuse = diffuseColor * NdotL * shadow * intensityScale;
                    diffuse *= lightColorNorm;
                    
                    finalColor += diffuse;
                }
                
                // =============================================
                // AREA LIGHTS (Rectangle and Tube)
                // =============================================
                uint areaLightStart = _PunctualLightCount;
                uint areaCount = min(_AreaLightCount, MAX_AREA_LIGHTS);
                for (uint a = 0; a < areaCount; a++)
                {
                    LightData lightData = _LightDatas[areaLightStart + a];
                    
                    // Simplified area light handling - treat as point light from center
                    float3 lightToSample = input.positionWS - lightData.positionRWS;
                    float distSq = dot(lightToSample, lightToSample);
                    float dist = sqrt(distSq);
                    float3 L = -lightToSample / max(dist, 0.0001);
                    
                    // Distance attenuation with softer falloff for area lights
                    float attenuation = SmoothDistanceAttenuation(distSq, lightData.rangeAttenuationScale);
                    attenuation *= 0.7;
                    
                    if (attenuation <= 0.001)
                        continue;
                    
                    // NdotL with soft posterization
                    float NdotL = saturate(dot(normalWS, L));
                    NdotL = SoftPosterize(NdotL, 8.0);
                    
                    if (NdotL <= 0.0)
                        continue;
                    
                    // Shadow for area lights
                    float shadow = 1.0;
                    if (lightData.shadowIndex >= 0)
                    {
                        shadow = GetRectAreaShadowAttenuation(shadowContext, positionSS, input.positionWS, normalWS,
                            lightData.shadowIndex, L, dist);
                        shadow = lerp(1.0, shadow, _ShadowStrength);
                        shadow = max(shadow, 0.15); // Minimum shadow to prevent pure black
                        shadow = SoftPosterize(shadow, 3.0);
                    }
                    
                    // Get light color
                    float3 lightColorRaw = lightData.color;
                    float lightMagnitude = max(max(lightColorRaw.r, lightColorRaw.g), lightColorRaw.b);
                    float3 lightColorNorm = lightColorRaw / max(lightMagnitude, 0.0001);
                    
                    float intensityScale = lightMagnitude * attenuation;
                    intensityScale = saturate(intensityScale * 0.001);
                    
                    float3 diffuse = diffuseColor * NdotL * shadow * intensityScale;
                    diffuse *= lightColorNorm;
                    
                    finalColor += diffuse;
                }
                
                // Apply ambient occlusion
                finalColor *= ao;
                
                // Apply brightness
                finalColor *= _Brightness;
                
                // Final soft posterization for stylized look
                finalColor = SoftPosterize3(finalColor, _Posterize * 2.0);
                
                // Clamp to valid range
                finalColor = saturate(finalColor);
                
                return float4(finalColor, 1.0);
            }
            
            ENDHLSL
        }
        
        // =============================================
        // Depth Prepass
        // =============================================
        Pass
        {
            Name "DepthForwardOnly"
            Tags { "LightMode" = "DepthForwardOnly" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vertDepth
            #pragma fragment fragDepth
            #pragma multi_compile_instancing
            
            struct AttributesDepth
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsDepth
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            VaryingsDepth vertDepth(AttributesDepth input)
            {
                VaryingsDepth output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }
            
            void fragDepth(VaryingsDepth input) {}
            
            ENDHLSL
        }
        
        // =============================================
        // Shadow Caster
        // =============================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_instancing
            
            struct AttributesShadow
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsShadow
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            VaryingsShadow vertShadow(AttributesShadow input)
            {
                VaryingsShadow output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }
            
            void fragShadow(VaryingsShadow input) {}
            
            ENDHLSL
        }
        
        // =============================================
        // Depth Only
        // =============================================
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vertDepthOnly
            #pragma fragment fragDepthOnly
            #pragma multi_compile_instancing
            
            struct AttributesDepthOnly
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsDepthOnly
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            VaryingsDepthOnly vertDepthOnly(AttributesDepthOnly input)
            {
                VaryingsDepthOnly output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }
            
            void fragDepthOnly(VaryingsDepthOnly input) {}
            
            ENDHLSL
        }
        
        // =============================================
        // Motion Vectors
        // =============================================
        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }
            
            Cull Back
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM
            #pragma vertex vertMotion
            #pragma fragment fragMotion
            #pragma multi_compile_instancing
            
            struct AttributesMotion
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsMotion
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            VaryingsMotion vertMotion(AttributesMotion input)
            {
                VaryingsMotion output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(positionWS);
                
                return output;
            }
            
            float4 fragMotion(VaryingsMotion input) : SV_Target
            {
                return float4(0.5, 0.5, 0, 1);
            }
            
            ENDHLSL
        }
    }
    
    Fallback "HDRP/lit"
}
