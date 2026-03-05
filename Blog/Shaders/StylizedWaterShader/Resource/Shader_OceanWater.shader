Shader "YmneShader/OceanWater"
{
    Properties
    {
        [Header(Water Settings)]
        _WaterTiling ("Water Tiling", Range(0.01, 10)) = 1.0
        _WaterHeightScale ("Water Height Scale", Range(0, 2)) = 1.0
        
        [Header(Water Colors)]
        _ShallowColor ("Shallow Water Color", Color) = (0.2, 0.7, 0.8, 0.9)
        _DeepColor ("Deep Water Color", Color) = (0.05, 0.15, 0.4, 1.0)
        _FoamColor ("Foam Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _DepthFade ("Depth Fade Distance", Range(0.1, 20)) = 5.0
        
        [Header(Wave Settings)]
        _WaveHeight ("Wave Height", Range(0.0, 2.0)) = 0.3
        _WaveFrequency ("Wave Frequency", Range(0.1, 5.0)) = 1.0
        _WaveSpeed ("Wave Speed", Range(0.1, 5.0)) = 1.0
        _WaveDirection ("Wave Direction", Vector) = (1, 0, 0, 0)
        
        [Header(Toon Shading)]
        [Toggle(_RECEIVE_SHADOWS_ON)] _receiveDepthShadows ("Receive Shadows", Float) = 1
        [IntRange] _ToonSteps ("Toon Steps", Range(2, 8)) = 4
        _ShadowSoftness ("Shadow Softness", Range(0.01, 1.0)) = 0.3
        _ShadowColor ("Shadow Color", Color) = (0.1, 0.2, 0.35, 1)
        
        [Header(Specular)]
        _SpecularSize ("Specular Size", Range(0.01, 3.0)) = 0.15
        _SpecularIntensity ("Specular Intensity", Range(0, 3)) = 1.5
        _SpecularSmoothness ("Specular Smoothness", Range(0.01, 0.5)) = 0.1
        
        [Header(Anime Sparkles)]
        _SparkleIntensity ("Sparkle Intensity", Range(0, 5)) = 1.0
        _SparkleScale ("Sparkle Scale", Range(0, 50)) = 15.0
        _SparkleSpeed ("Sparkle Speed", Range(0, 100)) = 1.0
        _SparkleDensity ("Sparkle Density", Range(0, 1)) = 0.5
        _SparkleThreshold ("Sparkle Threshold", Range(0, 1)) = 0.5
        _SparkleBloom ("Sparkle Bloom", Range(1, 50)) = 5.0
        _SparkleColor ("Sparkle Color", Color) = (1, 1, 0.9, 1)
        
        [Header(Fresnel)]
        _FresnelPower ("Fresnel Power", Range(0.5, 5.0)) = 2.0
        _FresnelIntensity ("Fresnel Intensity", Range(0, 1)) = 0.5
        _FresnelColor ("Fresnel Color", Color) = (0.6, 0.9, 1.0, 1.0)
        
        [Header(Foam)]
        [Toggle(_FOAM_ON)] _EnableFoam ("Enable Foam", Float) = 1.0
        _FoamThreshold ("Foam Edge Distance", Range(0.1, 5.0)) = 1.0
        _FoamIntensity ("Foam Intensity", Range(0, 2)) = 1.0
        _CrestThreshold ("Wave Crest Threshold", Range(0.0, 1.0)) = 0.65
        
        [Header(Transparency)]
        _Opacity ("Base Opacity", Range(0, 1)) = 0.85
        _OpacityIntensity ("Transparency Intensity", Range(0.1, 3.0)) = 1.0
        [Toggle(_DISABLE_TRANSPARENCY)] _DisableTransparency ("Disable Transparency", Float) = 0
        
        [Header(Screen Space Reflections)]
        [Toggle(_SSR_ON)] _EnableSSR ("Enable SSR", Float) = 1.0
        _SSRIntensity ("SSR Intensity", Range(0, 1)) = 0.5
        _SSRStepSize ("SSR Step Size", Range(0.1, 5.0)) = 1.0
        [IntRange] _SSRSamples ("SSR Samples", Range(4, 64)) = 12
        _SSRBlur ("SSR Blur", Range(0, 0.02)) = 0.005
        _SSRFadeDistance ("SSR Fade Distance", Range(1, 100)) = 50.0

        [Header(Caustics)]
        [Toggle(_CAUSTICS_ON)] _EnableCaustics("Enable Caustics", Float) = 1
        _CausticsChromAb("Chromatic Aberration", Range(0, 2)) = 0.5
        
        [Header(Layer 1)] 
        _CausticsIntensity1("Intensity 1", Range(0, 5)) = 1.5
        _CausticsScale1("Scale 1", Float) = 2.0
        _CausticsSpeed1("Speed 1", Float) = 0.5
        _CausticsContrast1("Contrast 1", Range(1, 20)) = 4.0
        _CausticsWarpStrength1("Warp Strength 1", Range(0, 0.5)) = 0.1
        _CausticsWarpScale1("Warp Scale 1", Float) = 0.5
        
        [Header(Layer 2)] 
        _CausticsIntensity2("Intensity 2", Range(0, 5)) = 0.8
        _CausticsScale2("Scale 2", Float) = 4.0
        _CausticsSpeed2("Speed 2", Float) = 0.8
        _CausticsContrast2("Contrast 2", Range(1, 20)) = 4.0
        _CausticsWarpStrength2("Warp Strength 2", Range(0, 0.5)) = 0.1
        _CausticsWarpScale2("Warp Scale 2", Float) = 1.0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }
        
        // GrabPass for SSR
        GrabPass { "_GrabTexture" }
        
        CGINCLUDE
        #include "HLSL_OceanWater.hlsl"
        ENDCG
        
        // =============================================
        // Forward Base Pass
        // =============================================
        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode" = "ForwardBase" }
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On
            Cull Back
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fwdbase
            #pragma shader_feature_local _FOAM_ON
            #pragma shader_feature_local _DISABLE_TRANSPARENCY
            #pragma shader_feature_local _RECEIVE_SHADOWS_ON
            #pragma shader_feature_local _CAUSTICS_ON
            #pragma shader_feature_local _SSR_ON
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
            ZWrite Off
            Cull Back
            
            CGPROGRAM
            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #pragma multi_compile_instancing
            #pragma multi_compile_fwdadd_fullshadows
            ENDCG
        }
        
        // =============================================
        // Shadow Caster Pass
        // =============================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            Cull Back
            
            CGPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_instancing
            #pragma multi_compile_shadowcaster
            ENDCG
        }
    }
    
    Fallback "Diffuse"
}
