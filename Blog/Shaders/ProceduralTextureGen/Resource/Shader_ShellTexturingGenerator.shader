Shader "YmneShader/ShellTexturingGenerator"
{
    Properties
    {
        [Header(General Settings)]
        [Enum(Dirt, 0, Sand, 1, Rock, 2, Brick, 3, Floor, 4, Wood, 5, Cloth, 6)] _MaterialType ("Material Type", Int) = 1
        
        [Header(Floor Settings)]
        _FloorTileCount ("Floor Tile Count", Vector) = (4, 4, 0, 0)
        _FloorGroutWidth ("Floor Grout Width", Range(0.01, 0.2)) = 0.05
        _FloorTileGap ("Floor Tile Gap Depth", Range(0.0, 0.5)) = 0.3
        
        [Header(Wood Settings)]
        _WoodPlankCount ("Wood Plank Count", Vector) = (2, 8, 0, 0)
        _WoodGapWidth ("Wood Gap Width", Range(0.005, 0.1)) = 0.02
        _WoodGapDepth ("Wood Gap Depth", Range(0.0, 0.5)) = 0.25
        _WoodGrainScale ("Wood Grain Scale", Range(1, 50)) = 20
        
        [Header(Cloth Settings)]
        _ClothWeaveScale ("Cloth Weave Scale", Range(5, 100)) = 30
        _ClothThreadWidth ("Thread Width", Range(0.3, 0.9)) = 0.7
        _ClothDepth ("Weave Depth", Range(0.0, 0.3)) = 0.1
        _ClothFuzziness ("Fuzziness", Range(0, 1)) = 0.3
        
        [Header(Colors)]
        _BaseColor ("Base Color", Color) = (0.76, 0.65, 0.38, 1)
        _VariationColor ("Variation Color", Color) = (0.6, 0.5, 0.3, 1)
        _ColorVariationScale ("Color Noise Scale", Float) = 0.5
        
        [Header(PBR)]
        _Smoothness ("Smoothness", Range(0, 1)) = 0.2
        _SmoothnessVariation ("Smoothness Randomness", Range(0, 1)) = 0.1
        _SpecularColor ("Specular Color", Color) = (0.2, 0.2, 0.2, 1)
        
        [Header(Geometry)]
        _Density ("Density", Range(0.01, 10.0)) = 0.5
        _ShellThickness ("Shell Thickness", Range(0, 1)) = 0.5
        
        [Header(Triplanar Settings)]
        _TriplanarScale ("Triplanar Scale", Float) = 0.5
        _TriplanarBlendSharpness ("Triplanar Blend Sharpness", Range(1, 64)) = 10.0
        
        [Header(Parallax Settings)]
        _ParallaxStrength ("Parallax Strength", Range(0.0, 0.5)) = 0.1
        [IntRange] _ParallaxSteps ("Parallax Steps", Range(2, 128)) = 16
        [IntRange] _ParallaxRefinement ("Refinement Steps", Range(1, 8)) = 4
        
        [Header(Stylization)]
        [IntRange] _PixelTextureResolution ("Pixel Texture Resolution", Range(4, 512)) = 128
        _Dirtiness ("Dirtiness", Range(0, 10)) = 0.3
        
        [Header(Lighting)]
        _AmbientOcclusion ("Ambient Occlusion", Range(0, 1)) = 0.8
        _Brightness ("Brightness", Range(0.1, 10.0)) = 1.0
        
        [Header(Cutout)]
        [Toggle] _EnableCutout ("Enable Cutout", Float) = 0
        _CutoutThreshold ("Cutout Threshold", Range(0.01, 0.5)) = 0.1
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
        }
        
        CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        
        // Properties
        int _MaterialType;
        float4 _BaseColor;
        float4 _VariationColor;
        float _ColorVariationScale;
        
        float _Smoothness;
        float _SmoothnessVariation;
        float4 _SpecularColor;
        
        float _Density;
        float _ShellThickness;
        
        float _TriplanarScale;
        float _TriplanarBlendSharpness;
        
        float _ParallaxStrength;
        int _ParallaxSteps;
        int _ParallaxRefinement;
        
        int _PixelTextureResolution;
        float _Dirtiness;
        
        float4 _FloorTileCount;
        float _FloorGroutWidth;
        float _FloorTileGap;
        
        float4 _WoodPlankCount;
        float _WoodGapWidth;
        float _WoodGapDepth;
        float _WoodGrainScale;
        
        float _ClothWeaveScale;
        float _ClothThreadWidth;
        float _ClothDepth;
        float _ClothFuzziness;
        
        float _AmbientOcclusion;
        float _Brightness;
        
        float _EnableCutout;
        float _CutoutThreshold;
        
        // --- NOISE FUNCTIONS ---
        
        float Hash21(float2 p)
        {
            p = frac(p * float2(234.34, 435.345));
            p += dot(p, p + 34.23);
            return frac(p.x * p.y);
        }

        float3 Hash23(float2 p)
        {
            float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
            p3 += dot(p3, p3.yzx + 33.33);
            return frac((p3.xxy + p3.yzz) * p3.zyx);
        }
        
        float Noise2D(float2 uv)
        {
            float2 i = floor(uv);
            float2 f = frac(uv);
            
            float a = Hash21(i);
            float b = Hash21(i + float2(1.0, 0.0));
            float c = Hash21(i + float2(0.0, 1.0));
            float d = Hash21(i + float2(1.0, 1.0));
            
            float2 u = f * f * (3.0 - 2.0 * f);
            
            return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
        }
        
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

        // Voronoi / Cellular Noise for Rock
        float Voronoi(float2 uv, float angleOffset, float cellDensity)
        {
            float2 g = floor(uv * cellDensity);
            float2 f = frac(uv * cellDensity);
            float t = 8.0;
            float3 res = float3(8.0, 0.0, 0.0);

            for(int y = -1; y <= 1; y++)
            {
                for(int x = -1; x <= 1; x++)
                {
                    float2 lattice = float2(x,y);
                    float2 offset = Hash23(g + lattice).xy;
                    float d = distance(lattice + offset, f);
                    if(d < res.x)
                    {
                        res = float3(d, offset.x, offset.y);
                    }
                }
            }
            return res.x;
        }
        
        float2 PixelateUV(float2 uv, int pixelSize)
        {
            float size = (float)pixelSize;
            return floor(uv * size) / size;
        }
        
        float3 GetTriplanarWeights(float3 normalWS, float sharpness)
        {
            float3 weights = abs(normalWS);
            weights = pow(weights, sharpness);
            return weights / (weights.x + weights.y + weights.z);
        }
        
        // --- MATERIAL GENERATION ---
        
        float GetMaterialDensity(float2 uv, float height, int type)
        {
            float density = 0.0;
            
            if (type == 0) // Dirt
            {
                // Clumpy, noisy
                float noiseVal = FBM(uv * 4.0, 3);
                density = smoothstep(height, height + 0.2, noiseVal);
            }
            else if (type == 1) // Sand
            {
                // Simple high frequency noise, very dense
                float noiseVal = Noise2D(uv * 50.0);
                // Mix with lower freq for dunes/variation
                float dune = Noise2D(uv * 2.0);
                noiseVal = lerp(noiseVal, dune, 0.3);
                density = step(height, noiseVal * 0.8 + 0.2); // Usually fairly solid
            }
            else if (type == 2) // Rock
            {
                 // Voronoi for cracks/chips
                float v = Voronoi(uv, 0.0, 4.0);
                density = step(height, 1.0 - v); 
            }
            else if (type == 3) // Brick
            {
                // Minecraft-style brick pattern with offset rows
                float2 brickUV = uv * 4.0; // Scale for brick size
                float2 brickSize = float2(2.0, 1.0); // Brick aspect ratio (wider than tall)
                float mortarThickness = 0.08; // Mortar line thickness
                
                // Determine which row we're in (handle negative UVs)
                float row = floor(brickUV.y / brickSize.y);
                // Offset odd rows by half a brick width
                float rowMod = fmod(row, 2.0);
                rowMod = rowMod < 0 ? rowMod + 2.0 : rowMod; // Handle negative
                float offset = rowMod * (brickSize.x * 0.5);
                float2 brickCoord = float2(brickUV.x + offset, brickUV.y);
                
                // Get position within the brick cell (handle negative with frac-like behavior)
                float2 cellMod = fmod(brickCoord, brickSize);
                cellMod = cellMod < 0 ? cellMod + brickSize : cellMod; // Wrap negative to positive
                float2 cellPos = cellMod / brickSize;
                
                // Mortar lines (horizontal and vertical)
                float mortarH = step(cellPos.y, mortarThickness / brickSize.y) + step(1.0 - mortarThickness / brickSize.y, cellPos.y);
                float mortarV = step(cellPos.x, mortarThickness / brickSize.x) + step(1.0 - mortarThickness / brickSize.x, cellPos.x);
                float isMortar = saturate(mortarH + mortarV);
                
                // Brick ID for per-brick variation
                float2 brickID = floor(brickCoord / brickSize);
                
                // === GRASS-STYLE DENSITY VARIATION ===
                // Each brick has a random max height (like grass blades)
                // Some bricks are tall (1.0), some thin (0.3), some missing (0.0)
                float brickMaxHeight = Hash21(brickID * 1.234); // 0.0 - 1.0 random per brick
                
                // Apply density threshold - skip very low values (creates missing bricks)
                float densityThreshold = 1.0 - _Density; // Use shader's density parameter
                brickMaxHeight = brickMaxHeight > densityThreshold ? 
                    (brickMaxHeight - densityThreshold) / (1.0 - densityThreshold) : 0.0;
                
                // Height mask - brick only exists up to its max height
                float heightMask = step(height, brickMaxHeight);
                
                // Per-brick base variation for existing bricks
                float brickBaseHeight = Hash21(brickID) * 0.3 + 0.7; // 0.7 - 1.0 for brick surface
                
                // Edge chipping - bricks worn at edges
                float2 edgeDist = min(cellPos, 1.0 - cellPos);
                float edgeFactor = smoothstep(0.0, 0.15, min(edgeDist.x, edgeDist.y));
                float chipNoise = Hash21(brickID * 7.31) * 0.25;
                float edgeWear = lerp(chipNoise, 0.0, edgeFactor);
                
                // Surface roughness
                float surfaceNoise = FBM(uv * 16.0, 2) * 0.06;
                
                // Brick surface height
                float brickSurface = brickBaseHeight - edgeWear - surfaceNoise;
                
                // Mortar is always recessed
                float mortarDepth = 0.25;
                
                // Combine: brick surface where brick exists, mortar in gaps
                float surfaceHeight = lerp(brickSurface, mortarDepth, isMortar);
                
                // Apply both height mask (brick exists at this height) and surface height
                density = step(height, surfaceHeight) * heightMask;
                
                // Also show mortar in missing brick areas (deeper mortar)
                if (heightMask < 0.5 && height < 0.2)
                {
                    density = 1.0; // Show deep mortar/hole bottom
                }
            }
            else if (type == 4) // Floor
            {
                float2 scaledUV = uv * _FloorTileCount.xy;
                float2 tileID = floor(scaledUV);
                float2 tileUV = frac(scaledUV);
                
                float halfGrout = _FloorGroutWidth * 0.5;
                float2 edgeDistXY = min(tileUV, 1.0 - tileUV);
                float edgeDist = min(edgeDistXY.x, edgeDistXY.y);
                
                // Density-based tile visibility (like brick)
                float tileMaxHeight = Hash21(tileID * 1.234);
                float densityThreshold = 1.0 - _Density;
                tileMaxHeight = tileMaxHeight > densityThreshold ? 
                    (tileMaxHeight - densityThreshold) / (1.0 - densityThreshold) : 0.0;
                float heightMask = step(height, tileMaxHeight);
                
                float tileRandom = Hash21(tileID * 1.37);
                float tileBaseHeight = 0.7 + tileRandom * 0.3;
                
                float3 wearOffset = Hash23(tileID * 2.71);
                float wearNoise = FBM(uv * 8.0 + wearOffset.xy * 10.0, 2);
                float wear = wearNoise * 0.15;
                
                float surfaceNoise = Noise2D(uv * 32.0) * 0.05;
                
                float cornerDist = length(edgeDistXY);
                float edgeWear = (1.0 - smoothstep(0.0, 0.2, cornerDist)) * 0.1;
                
                float crackPattern = Voronoi(uv + tileID * 0.5, 0.0, 6.0);
                float cracks = (1.0 - smoothstep(0.0, 0.08, crackPattern)) * 0.15;
                
                float tileHeight = tileBaseHeight - wear - surfaceNoise - edgeWear - cracks;
                float groutHeight = _FloorTileGap;
                
                float groutBlend = smoothstep(0.0, halfGrout, edgeDist);
                float finalHeight = lerp(groutHeight, tileHeight, groutBlend);
                
                density = step(height, finalHeight) * heightMask;
                
                // Show grout in missing tile areas
                if (heightMask < 0.5 && height < 0.2)
                {
                    density = 1.0;
                }
            }
            else if (type == 5) // Wood
            {
                float2 plankSize = float2(1.0 / _WoodPlankCount.x, 1.0 / _WoodPlankCount.y);
                
                // Offset every other row
                float row = floor(uv.y / plankSize.y);
                float rowOffset = fmod(row, 2.0) * plankSize.x * 0.5;
                float2 offsetUV = float2(uv.x + rowOffset, uv.y);
                
                float2 plankID = floor(offsetUV / plankSize);
                float2 plankUV = frac(offsetUV / plankSize);
                
                // Gap detection
                float halfGap = _WoodGapWidth * 0.5 / plankSize.x;
                float halfGapY = _WoodGapWidth * 0.5 / plankSize.y;
                float2 edgeDistXY = min(plankUV, 1.0 - plankUV);
                float isGapX = step(edgeDistXY.x, halfGap);
                float isGapY = step(edgeDistXY.y, halfGapY);
                float isGap = saturate(isGapX + isGapY);
                
                // Density-based plank visibility
                float plankMaxHeight = Hash21(plankID * 1.234);
                float densityThreshold = 1.0 - _Density;
                plankMaxHeight = plankMaxHeight > densityThreshold ? 
                    (plankMaxHeight - densityThreshold) / (1.0 - densityThreshold) : 0.0;
                float heightMask = step(height, plankMaxHeight);
                
                // Per-plank variation
                float plankRandom = Hash21(plankID * 2.57);
                float plankBaseHeight = 0.75 + plankRandom * 0.25;
                
                // Wood grain (elongated noise along plank)
                float grainUV = plankUV.y * _WoodGrainScale + plankID.x * 3.7;
                float grain = Noise2D(float2(grainUV, plankID.y * 0.5)) * 0.08;
                
                // Surface wear
                float3 wearOffset = Hash23(plankID * 3.14);
                float wear = FBM(uv * 6.0 + wearOffset.xy * 10.0, 2) * 0.1;
                
                // Edge wear on planks
                float edgeDist = min(edgeDistXY.x, edgeDistXY.y);
                float edgeWear = (1.0 - smoothstep(0.0, 0.15, edgeDist)) * 0.08;
                
                float plankHeight = plankBaseHeight - grain - wear - edgeWear;
                float gapHeight = _WoodGapDepth;
                
                float gapBlend = smoothstep(0.0, halfGap * 0.5, edgeDist);
                float finalHeight = lerp(gapHeight, plankHeight, gapBlend);
                
                density = step(height, finalHeight) * heightMask;
                
                // Show gap floor in missing plank areas
                if (heightMask < 0.5 && height < 0.15)
                {
                    density = 1.0;
                }
            }
            else if (type == 6) // Cloth
            {
                float2 weaveUV = uv * _ClothWeaveScale;
                float2 weaveCell = floor(weaveUV);
                float2 weaveLocal = frac(weaveUV);
                
                // Determine if horizontal or vertical thread is on top (checkerboard weave)
                float checker = fmod(weaveCell.x + weaveCell.y, 2.0);
                
                // Thread coverage
                float halfThread = _ClothThreadWidth * 0.5;
                float threadH = smoothstep(0.5 - halfThread, 0.5 - halfThread + 0.1, weaveLocal.y) * 
                                 smoothstep(0.5 + halfThread, 0.5 + halfThread - 0.1, weaveLocal.y);
                float threadV = smoothstep(0.5 - halfThread, 0.5 - halfThread + 0.1, weaveLocal.x) * 
                                 smoothstep(0.5 + halfThread, 0.5 + halfThread - 0.1, weaveLocal.x);
                
                // Weave pattern - one thread over, one under
                float threadOnTop = checker > 0.5 ? threadH : threadV;
                float threadBelow = checker > 0.5 ? threadV : threadH;
                
                // Height for threads
                float topHeight = 0.9 - Noise2D(weaveUV * 0.5) * 0.05;
                float bottomHeight = topHeight - _ClothDepth;
                
                // Fuzziness / fiber noise
                float fuzz = (Noise2D(uv * _ClothWeaveScale * 4.0) - 0.5) * _ClothFuzziness * 0.15;
                
                // Combine threads with height
                float surfaceHeight = 0.0;
                if (threadOnTop > 0.5)
                {
                    surfaceHeight = topHeight + fuzz;
                }
                else if (threadBelow > 0.5)
                {
                    surfaceHeight = bottomHeight + fuzz;
                }
                else
                {
                    // Gap between threads
                    surfaceHeight = bottomHeight - 0.1;
                }
                
                // Density-based wear/holes
                float wearNoise = FBM(uv * 3.0, 3);
                float densityThreshold = 1.0 - _Density;
                float wearMask = step(densityThreshold, wearNoise);
                
                // Apply thread fraying at wear edges
                float frayEdge = smoothstep(densityThreshold, densityThreshold + 0.15, wearNoise);
                surfaceHeight *= frayEdge;
                
                density = step(height, surfaceHeight) * wearMask;
                
                // Show backing in holes
                if (wearMask < 0.5 && height < 0.1)
                {
                    density = 1.0;
                }
            }
            
            return density;
        }
        
        float3 GetMaterialColor(float3 worldPos, float2 uv, int type, float height)
        {
            // Random variation based on position
            float3 noisePos = worldPos * _ColorVariationScale;
            float variation = Noise2D(noisePos.xz + noisePos.y);
            
            float3 col = lerp(_BaseColor.rgb, _VariationColor.rgb, variation);
            
            // Add some per-pixel noise for texture
            float grain = Hash21(uv * 100.0);
            col += (grain - 0.5) * 0.05;
            
            // === DIRT/GRIME STAINS ===
            if (_Dirtiness > 0.01)
            {
                // Multi-layered dirt noise for realistic stains
                float dirtNoise1 = FBM(uv * 3.0 + worldPos.xz * 0.1, 3); // Large splotches
                float dirtNoise2 = FBM(uv * 8.0 + worldPos.y * 0.5, 2); // Medium streaks
                float dirtNoise3 = Noise2D(uv * 20.0); // Fine grime
                
                // Combine dirt layers
                float dirtPattern = dirtNoise1 * 0.5 + dirtNoise2 * 0.35 + dirtNoise3 * 0.15;
                
                // Dirt accumulates in crevices (lower heights) and on surfaces
                float crustFactor = 1.0 - height; // More dirt in crevices
                dirtPattern = dirtPattern * (0.7 + crustFactor * 0.3);
                
                // Apply threshold to create patchy dirt
                float dirtMask = smoothstep(0.3, 0.7, dirtPattern);
                
                // Dirt color - desaturated dark brown/gray
                float3 dirtColor = col * 0.4; // Darkened version of base
                dirtColor = lerp(dirtColor, float3(0.15, 0.12, 0.1), 0.5); // Mix with dark grime
                
                // Apply dirt based on slider
                col = lerp(col, dirtColor, dirtMask * _Dirtiness);
                
                // Additional subtle overall darkening with dirtiness
                col *= lerp(1.0, 0.85, _Dirtiness * 0.5);
            }
            
            // darken lower layers for pseudo-AO
            col *= lerp(0.5, 1.0, height);
            
            return col;
        }

        // --- PARALLAX ---
        
        // Output: mask (0 or 1), materialColor, finalHeight, randomSpecular
        float ParallaxShellSample(float3 worldPos, float3 normalWS, out float3 materialColor, out float finalHeight, out float randomSpec)
        {
            float3 weights = GetTriplanarWeights(normalWS, _TriplanarBlendSharpness);
            
            float3 viewDirWS = normalize(_WorldSpaceCameraPos - worldPos);
            float NdotV = dot(viewDirWS, normalWS);
            float rayLength = _ParallaxStrength / max(NdotV, 0.1);
            
            float3 parallaxOffsetStep = -viewDirWS * rayLength / (float)_ParallaxSteps;
            float3 currentPos = worldPos;
            
            float accumulatedMask = 0.0;
            materialColor = _BaseColor.rgb;
            finalHeight = 0.0;
            randomSpec = 0.0;
            
            // Specular randomness based on position
            float3 specNoisePos = worldPos * _ColorVariationScale * 2.0;
            randomSpec = Noise2D(specNoisePos.xz); 
            
            // Phase 1: March
            for (int i = 0; i < _ParallaxSteps; i++)
            {
                float shellIndex = (float)i / (float)_ParallaxSteps;
                float shellHeight = 1.0 - shellIndex;
                
                // Triplanar Sample
                float2 uvX = PixelateUV(currentPos.zy * _TriplanarScale, _PixelTextureResolution);
                float maskX = GetMaterialDensity(uvX, shellHeight, _MaterialType);
                
                float2 uvY = PixelateUV(currentPos.xz * _TriplanarScale, _PixelTextureResolution);
                float maskY = GetMaterialDensity(uvY, shellHeight, _MaterialType);
                
                float2 uvZ = PixelateUV(currentPos.xy * _TriplanarScale, _PixelTextureResolution);
                float maskZ = GetMaterialDensity(uvZ, shellHeight, _MaterialType);
                
                float blendedMask = maskX * weights.x + maskY * weights.y + maskZ * weights.z;
                
                if (blendedMask > 0.5)
                {
                    accumulatedMask = 1.0;
                    finalHeight = shellHeight;
                    
                    // Sample Color at this height/pos
                    // Use dominant plane UV for color sampling or blended? Blended is better.
                    float3 colX = GetMaterialColor(currentPos, uvX, _MaterialType, shellHeight);
                    float3 colY = GetMaterialColor(currentPos, uvY, _MaterialType, shellHeight);
                    float3 colZ = GetMaterialColor(currentPos, uvZ, _MaterialType, shellHeight);
                    
                    materialColor = colX * weights.x + colY * weights.y + colZ * weights.z;
                    break;
                }
                
                currentPos += parallaxOffsetStep;
            }
            
            if (accumulatedMask < 0.5)
            {
               // Hit nothing (below depth), show background/bottom
               materialColor = _VariationColor.rgb * 0.2; // very dark
               finalHeight = 0.0;
            }
            
            return accumulatedMask;
        }
        
        ENDCG
        
        // =============================================
        // Forward Base Pass
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
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                SHADOW_COORDS(2)
                #ifdef DYNAMICLIGHTMAP_ON
                float2 dynamicLightmapUV : TEXCOORD3;
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
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                
                #ifdef DYNAMICLIGHTMAP_ON
                o.dynamicLightmapUV = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif
                
                TRANSFER_SHADOW(o);
                return o;
            }
            
            float4 frag(v2f i) : SV_Target
            {
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - i.positionWS);
                
                float3 matColor;
                float height;
                float rndSpec;
                float mask = ParallaxShellSample(i.positionWS, normalize(i.normalWS), matColor, height, rndSpec);
                
                // Cutout - discard pixels in holes
                if (_EnableCutout > 0.5)
                {
                    clip(height - _CutoutThreshold);
                }
                
                float3 normalWS = normalize(i.normalWS);
                
                // --- PBR LIGHTING CALCULATION ---
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 H = normalize(L + viewDirWS);
                
                float NdotL = saturate(dot(normalWS, L));
                float NdotH = saturate(dot(normalWS, H));
                
                // Randomized Specular/Smoothness
                float smoothVal = clamp(_Smoothness + (rndSpec - 0.5) * _SmoothnessVariation * 2.0, 0.0, 1.0);
                float specPower = exp2(10.0 * smoothVal + 1.0);
                
                // Specular term (Blinn-Phong)
                float3 spec = _SpecularColor.rgb * pow(NdotH, specPower) * smoothVal;
                
                // Shadows
                float shadow = SHADOW_ATTENUATION(i);
                
                // Ambient (GI)
                float3 ambient = ShadeSH9(float4(normalWS, 1));
                #ifdef DYNAMICLIGHTMAP_ON
                float4 realtimeGI = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.dynamicLightmapUV);
                ambient += DecodeRealtimeLightmap(realtimeGI);
                #endif
                
                float3 finalColor = matColor * (ambient + NdotL * _LightColor0.rgb * shadow) + spec * NdotL * shadow * _LightColor0.rgb;
                
                // AO at bottom
                float ao = lerp(_AmbientOcclusion, 1.0, height);
                finalColor *= ao;
                
                finalColor *= _Brightness;
                
                return float4(finalColor, 1.0);
            }
            ENDCG
        }
        
        // =============================================
        // Forward Add Pass
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
            
            struct appdata_add
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f_add
            {
                float4 pos : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                LIGHTING_COORDS(2, 3)
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            v2f_add vertAdd(appdata_add v)
            {
                v2f_add o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
            
            float4 fragAdd(v2f_add i) : SV_Target
            {
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - i.positionWS);
                 
                // Re-sample for consistancy (expensive, but necessary for multipass)
                float3 matColor;
                float height;
                float rndSpec;
                float mask = ParallaxShellSample(i.positionWS, normalize(i.normalWS), matColor, height, rndSpec);
                
                // Cutout - discard pixels in holes
                if (_EnableCutout > 0.5)
                {
                    clip(height - _CutoutThreshold);
                }
                
                float3 normalWS = normalize(i.normalWS);
                
                float3 lightDir;
                #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
                    float3 lightToVertex = _WorldSpaceLightPos0.xyz - i.positionWS;
                    lightDir = normalize(lightToVertex);
                #else
                    lightDir = normalize(_WorldSpaceLightPos0.xyz);
                #endif
                
                UNITY_LIGHT_ATTENUATION(atten, i, i.positionWS);
                
                float NdotL = saturate(dot(normalWS, lightDir));
                
                // Specular
                float3 H = normalize(lightDir + viewDirWS);
                float NdotH = saturate(dot(normalWS, H));
                float smoothVal = clamp(_Smoothness + (rndSpec - 0.5) * _SmoothnessVariation * 2.0, 0.0, 1.0);
                float specPower = exp2(10.0 * smoothVal + 1.0);
                float3 spec = _SpecularColor.rgb * pow(NdotH, specPower) * smoothVal;
                
                float ao = lerp(_AmbientOcclusion, 1.0, height);
                
                float3 diff = matColor * NdotL;
                float3 finalColor = (diff + spec) * atten * _LightColor0.rgb * ao * _Brightness;
                
                return float4(finalColor, 1.0);
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
            
            struct appdata_shadow { float4 vertex : POSITION; float3 normal : NORMAL; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct v2f_shadow { V2F_SHADOW_CASTER; UNITY_VERTEX_OUTPUT_STEREO };
            
            v2f_shadow vertShadow(appdata_shadow v)
            {
                v2f_shadow o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }
            float4 fragShadow(v2f_shadow i) : SV_Target { SHADOW_CASTER_FRAGMENT(i); }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
