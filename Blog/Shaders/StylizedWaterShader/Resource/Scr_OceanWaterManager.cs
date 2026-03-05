using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteAlways]
public class Scr_OceanWaterManager : MonoBehaviour
{
    [Header("Water Settings")]
    [Range(0.01f, 10f)] public float waterTiling = 1.0f;
    [Range(0f, 2f)] public float waterHeightScale = 1.0f;
    public bool castShadows = true;
    public bool receiveDepthShadows = true;
    
    [Header("Grid Settings")]
    [Min(1f)] public float width = 64f;
    [Min(1f)] public float length = 64f;
    [Range(2, 255)] public int subdivisions = 255;
    
    [Header("Wave Settings")]
    public float waveHeight = 2.0f;
    public float waveFrequency = 1.0f;
    public float waveSpeed = 1.0f;
    public Vector4 waveDirection = new Vector4(1, 1, -1, 1);
    
    [Header("Water Colors")]
    public Color shallowColor = new Color(0.2f, 0.7f, 0.8f, 0.9f);
    public Color deepColor = new Color(0.05f, 0.15f, 0.4f, 1.0f);
    public Color foamColor = Color.white;
    [Range(0.1f, 20f)] public float depthFade = 0.1f;
    
    [Header("Toon Shading")]
    [Range(2, 8)] public int toonSteps = 2;
    [Range(0.01f, 1.0f)] public float shadowSoftness = 0.3f;
    public Color shadowColor = new Color(0.1f, 0.2f, 0.35f, 1.0f);
    
    [Header("Specular")]
    [Range(0.01f, 3.0f)] public float specularSize = 0.449f;
    [Range(0f, 3f)] public float specularIntensity = 0.5f;
    [Range(0.01f, 0.5f)] public float specularSmoothness = 0.01f;
    
    [Header("Fresnel")]
    [Range(0.5f, 5.0f)] public float fresnelPower = 3.0f;
    [Range(0f, 1f)] public float fresnelIntensity = 0.0f;
    public Color fresnelColor = Color.white;
    
    [Header("Foam")]
    public bool enableFoam = true;
    [Range(0.1f, 5.0f)] public float foamThreshold = 1.0f;
    [Range(0f, 2f)] public float foamIntensity = 1.0f;
    [Range(0.0f, 1.0f)] public float crestThreshold = 0.15f;
    
    [Header("Transparency")]
    public bool disableTransparency = false;
    [Range(0f, 1f)] public float baseOpacity = 1.0f;
    [Range(0.1f, 3.0f)] public float transparencyIntensity = 3.0f;
    
    [Header("Anime Sparkles")]
    [Range(0f, 5f)] public float sparkleIntensity = 0.5f;
    [Range(1f, 50f)] public float sparkleScale = 15.0f;
    [Range(0f, 100f)] public float sparkleSpeed = 12.0f;
    [Range(0f, 1f)] public float sparkleDensity = 0.05f;
    [Range(0f, 1f)] public float sparkleThreshold = 0.5f;
    [Range(1f, 50f)] public float sparkleBloom = 16.0f;
    public Color sparkleColor = new Color(1f, 1f, 0.9f, 1f);
    
    [Header("Screen Space Reflections")]
    public bool enableSSR = true;
    [Range(0f, 1f)] public float ssrIntensity = 0.5f;
    [Range(0.1f, 5.0f)] public float ssrStepSize = 1.0f;
    [Range(4, 64)] public int ssrSamples = 12;
    [Range(0f, 0.02f)] public float ssrBlur = 0.005f;
    [Range(1f, 100f)] public float ssrFadeDistance = 50.0f;
    
    [Header("Caustics")]
    public bool enableCaustics = true;
    [Range(0f, 2f)] public float causticsChromAb = 0.5f;
    [Header("Layer 1")]
    [Range(0f, 5f)] public float causticsIntensity1 = 1.5f;
    public float causticsScale1 = 2.0f;
    public float causticsSpeed1 = 0.5f;
    [Range(1f, 20f)] public float causticsContrast1 = 4.0f;
    [Range(0f, 0.5f)] public float causticsWarpStrength1 = 0.1f;
    public float causticsWarpScale1 = 0.5f;
    
    [Header("Layer 2")]
    [Range(0f, 5f)] public float causticsIntensity2 = 0.8f;
    public float causticsScale2 = 4.0f;
    public float causticsSpeed2 = 0.8f;
    [Range(1f, 20f)] public float causticsContrast2 = 4.0f;
    [Range(0f, 0.5f)] public float causticsWarpStrength2 = 0.1f;
    public float causticsWarpScale2 = 1.0f;
    
    [Header("References")]
    public Material waterMaterial;
    
    [HideInInspector] public Mesh waterMesh;
    private MeshFilter meshFilter;
    private MeshRenderer meshRenderer;
    
    [HideInInspector] public float _prevWidth;
    [HideInInspector] public float _prevLength;
    
    private Material _instanceMaterial;
    
    private void OnEnable()
    {
        InitializeComponents();
        UpdateMaterial();
    }
    
    private void OnDisable()
    {
        CleanupShadowBuffer();

        // Cleanup material instance to avoid leaks
        if (_instanceMaterial != null)
        {
            if (Application.isPlaying) Destroy(_instanceMaterial);
            else DestroyImmediate(_instanceMaterial);
            _instanceMaterial = null;
        }
    }
    
    private void OnValidate()
    {
        InitializeComponents();
        UpdateMaterial();
        UpdateShadowBuffer();
    }
    
    private void Update()
    {
        UpdateShadowBuffer();
#if UNITY_EDITOR
        if (!Application.isPlaying)
            UpdateMaterial();
#endif
    }

    // =========================================================
    // SHADOW MAP CAPTURE
    // =========================================================
    private UnityEngine.Rendering.CommandBuffer shadowCB;
    private Light dirLight;

    private void UpdateShadowBuffer()
    {
        if (!receiveDepthShadows)
        {
            CleanupShadowBuffer();
            return;
        }

        if (dirLight == null)
        {
            FindDirectionalLight();
        }

        if (dirLight != null && shadowCB == null)
        {
            InitializeShadowBuffer();
        }
        
        // If light lost or destroyed, cleanup
        if (dirLight == null && shadowCB != null)
        {
            CleanupShadowBuffer();
        }
    }

    private void FindDirectionalLight()
    {
        Light[] lights = FindObjectsOfType<Light>();
        foreach (var l in lights)
        {
            if (l.type == LightType.Directional && l.isActiveAndEnabled)
            {
                dirLight = l;
                break;
            }
        }
    }

    private void InitializeShadowBuffer()
    {
        if (dirLight == null) return;

        shadowCB = new UnityEngine.Rendering.CommandBuffer();
        shadowCB.name = "Copy Screen Space Shadows (Manager)";
        
        int shadowMapID = Shader.PropertyToID("_ShadowMapTexture");
        int myShadowMapID = Shader.PropertyToID("_GlobalScreenSpaceShadowMap");
        
        shadowCB.GetTemporaryRT(myShadowMapID, -1, -1, 0, FilterMode.Bilinear, RenderTextureFormat.R8, RenderTextureReadWrite.Linear);
        shadowCB.Blit(shadowMapID, myShadowMapID);
        shadowCB.SetGlobalTexture("_GlobalScreenSpaceShadowMap", myShadowMapID); 
        
        dirLight.AddCommandBuffer(UnityEngine.Rendering.LightEvent.AfterScreenspaceMask, shadowCB);
    }

    private void CleanupShadowBuffer()
    {
        if (dirLight != null && shadowCB != null)
        {
            dirLight.RemoveCommandBuffer(UnityEngine.Rendering.LightEvent.AfterScreenspaceMask, shadowCB);
        }
        if (shadowCB != null)
        {
            shadowCB.Release();
            shadowCB = null;
        }
    }
    
    public void UpdateMaterial()
    {
        // Ensure we have an instance to modify
        if (_instanceMaterial == null) InitializeComponents();
        
        if (_instanceMaterial != null)
        {
            // Water Settings
            _instanceMaterial.SetFloat("_WaterTiling", waterTiling);
            _instanceMaterial.SetFloat("_WaterHeightScale", waterHeightScale);
            
            // Waves
            _instanceMaterial.SetFloat("_WaveHeight", waveHeight);
            _instanceMaterial.SetFloat("_WaveFrequency", waveFrequency);
            _instanceMaterial.SetFloat("_WaveSpeed", waveSpeed);
            _instanceMaterial.SetVector("_WaveDirection", waveDirection);
            
            // Colors
            _instanceMaterial.SetColor("_ShallowColor", shallowColor);
            _instanceMaterial.SetColor("_DeepColor", deepColor);
            _instanceMaterial.SetColor("_FoamColor", foamColor);
            _instanceMaterial.SetFloat("_DepthFade", depthFade);
            
            // Toon
            _instanceMaterial.SetInt("_ToonSteps", toonSteps);
            _instanceMaterial.SetFloat("_ShadowSoftness", shadowSoftness);
            
            // Shadows
            if(meshRenderer != null) 
                meshRenderer.shadowCastingMode = castShadows ? UnityEngine.Rendering.ShadowCastingMode.On : UnityEngine.Rendering.ShadowCastingMode.Off;
            
            if (receiveDepthShadows) _instanceMaterial.EnableKeyword("_RECEIVE_SHADOWS_ON");
            else _instanceMaterial.DisableKeyword("_RECEIVE_SHADOWS_ON");
                
            _instanceMaterial.SetColor("_ShadowColor", shadowColor);
            
            // Specular
            _instanceMaterial.SetFloat("_SpecularSize", specularSize);
            _instanceMaterial.SetFloat("_SpecularIntensity", specularIntensity);
            _instanceMaterial.SetFloat("_SpecularSmoothness", specularSmoothness);
            
            // Fresnel
            _instanceMaterial.SetFloat("_FresnelPower", fresnelPower);
            _instanceMaterial.SetFloat("_FresnelIntensity", fresnelIntensity);
            _instanceMaterial.SetColor("_FresnelColor", fresnelColor);
            
            // Foam
            if (enableFoam) _instanceMaterial.EnableKeyword("_FOAM_ON"); else _instanceMaterial.DisableKeyword("_FOAM_ON");
            _instanceMaterial.SetFloat("_FoamThreshold", foamThreshold);
            _instanceMaterial.SetFloat("_FoamIntensity", foamIntensity);
            _instanceMaterial.SetFloat("_CrestThreshold", crestThreshold);
            
            // Transparency
            if (disableTransparency) _instanceMaterial.EnableKeyword("_DISABLE_TRANSPARENCY"); 
            else _instanceMaterial.DisableKeyword("_DISABLE_TRANSPARENCY");
            
            _instanceMaterial.SetFloat("_Opacity", baseOpacity);
            if (_instanceMaterial.HasProperty("_OpacityIntensity"))
                _instanceMaterial.SetFloat("_OpacityIntensity", transparencyIntensity);

            // Anime Sparkles
            _instanceMaterial.SetFloat("_SparkleIntensity", sparkleIntensity);
            _instanceMaterial.SetFloat("_SparkleScale", sparkleScale);
            _instanceMaterial.SetFloat("_SparkleSpeed", sparkleSpeed);
            _instanceMaterial.SetFloat("_SparkleDensity", sparkleDensity);
            _instanceMaterial.SetFloat("_SparkleThreshold", sparkleThreshold);
            _instanceMaterial.SetFloat("_SparkleBloom", sparkleBloom);
            _instanceMaterial.SetColor("_SparkleColor", sparkleColor);
            
            // Screen Space Reflections (Raymarching)
            if (enableSSR) _instanceMaterial.EnableKeyword("_SSR_ON");
            else _instanceMaterial.DisableKeyword("_SSR_ON");
            _instanceMaterial.SetFloat("_SSRIntensity", ssrIntensity);
            _instanceMaterial.SetFloat("_SSRStepSize", ssrStepSize);
            _instanceMaterial.SetInt("_SSRSamples", ssrSamples);
            _instanceMaterial.SetFloat("_SSRBlur", ssrBlur);
            _instanceMaterial.SetFloat("_SSRFadeDistance", ssrFadeDistance);
            
            // Caustics
            if (enableCaustics) _instanceMaterial.EnableKeyword("_CAUSTICS_ON");
            else _instanceMaterial.DisableKeyword("_CAUSTICS_ON");
            _instanceMaterial.SetFloat("_CausticsChromAb", causticsChromAb);
            
            _instanceMaterial.SetFloat("_CausticsIntensity1", causticsIntensity1);
            _instanceMaterial.SetFloat("_CausticsScale1", causticsScale1);
            _instanceMaterial.SetFloat("_CausticsSpeed1", causticsSpeed1);
            _instanceMaterial.SetFloat("_CausticsContrast1", causticsContrast1);
            _instanceMaterial.SetFloat("_CausticsWarpStrength1", causticsWarpStrength1);
            _instanceMaterial.SetFloat("_CausticsWarpScale1", causticsWarpScale1);
            
            _instanceMaterial.SetFloat("_CausticsIntensity2", causticsIntensity2);
            _instanceMaterial.SetFloat("_CausticsScale2", causticsScale2);
            _instanceMaterial.SetFloat("_CausticsSpeed2", causticsSpeed2);
            _instanceMaterial.SetFloat("_CausticsContrast2", causticsContrast2);
            _instanceMaterial.SetFloat("_CausticsWarpStrength2", causticsWarpStrength2);
            _instanceMaterial.SetFloat("_CausticsWarpScale2", causticsWarpScale2);
        }
    }
    
    private void InitializeComponents()
    {
        meshFilter = GetComponent<MeshFilter>();
        if (meshFilter == null) meshFilter = gameObject.AddComponent<MeshFilter>();
        
        meshRenderer = GetComponent<MeshRenderer>();
        if (meshRenderer == null) meshRenderer = gameObject.AddComponent<MeshRenderer>();

        if (meshRenderer != null)
        {
            meshRenderer.receiveShadows = receiveDepthShadows;
            meshRenderer.shadowCastingMode = castShadows ? UnityEngine.Rendering.ShadowCastingMode.On : UnityEngine.Rendering.ShadowCastingMode.Off;
        }
        
        // Find template if missing
        if (waterMaterial == null)
        {
#if UNITY_EDITOR
            // Try to find existing material first
            string[] guids = UnityEditor.AssetDatabase.FindAssets("t:Material OceanWater");
            if (guids.Length > 0)
            {
                waterMaterial = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(UnityEditor.AssetDatabase.GUIDToAssetPath(guids[0]));
            }
#endif
        }

        // Create Instance Material if needed
        if (_instanceMaterial == null)
        {
            if (waterMaterial != null)
            {
                _instanceMaterial = new Material(waterMaterial);
                _instanceMaterial.name = waterMaterial.name + " (Instance)";
            }
            else
            {
                // Fallback to shader search
                Shader shader = Shader.Find("YmneShader/OceanWater");
                if (shader != null)
                {
                    _instanceMaterial = new Material(shader);
                    _instanceMaterial.name = "Ocean_Material_Instance";
                }
            }
            
        }

        // Check if renderer needs update
        if (_instanceMaterial != null && meshRenderer.sharedMaterial != _instanceMaterial)
        {
            meshRenderer.sharedMaterial = _instanceMaterial;
        }
    }
    
    public void GenerateWaterMesh()
    {
        if (meshFilter == null) return;
        
        // Cache current dimensions
        _prevWidth = width;
        _prevLength = length;
        
        // Create new mesh
        waterMesh = new Mesh();
        waterMesh.name = "Procedural_Ocean_Plane";
        
        // Calculate vertex count
        int xCount = subdivisions + 1;
        int zCount = subdivisions + 1;
        int numVertices = xCount * zCount;
        int numTriangles = subdivisions * subdivisions * 6;
        
        // Generate vertices and UVs
        Vector3[] vertices = new Vector3[numVertices];
        Vector2[] uvs = new Vector2[numVertices];
        int[] triangles = new int[numTriangles];
        
        float xStep = width / subdivisions;
        float zStep = length / subdivisions;
        float uvStep = 1.0f / subdivisions;
        
        // Center offset
        float xOffset = width * 0.5f;
        float zOffset = length * 0.5f;
        
        int vIndex = 0;
        for (int z = 0; z < zCount; z++)
        {
            for (int x = 0; x < xCount; x++)
            {
                vertices[vIndex] = new Vector3(x * xStep - xOffset, 0, z * zStep - zOffset);
                uvs[vIndex] = new Vector2(x * uvStep, z * uvStep);
                vIndex++;
            }
        }
        
        // Generate triangles
        int tIndex = 0;
        for (int z = 0; z < subdivisions; z++)
        {
            for (int x = 0; x < subdivisions; x++)
            {
                int bottomLeft = z * xCount + x;
                int bottomRight = bottomLeft + 1;
                int topLeft = (z + 1) * xCount + x;
                int topRight = topLeft + 1;
                
                // First triangle
                triangles[tIndex++] = bottomLeft;
                triangles[tIndex++] = topLeft;
                triangles[tIndex++] = bottomRight;
                
                // Second triangle
                triangles[tIndex++] = bottomRight;
                triangles[tIndex++] = topLeft;
                triangles[tIndex++] = topRight;
            }
        }
        
        waterMesh.vertices = vertices;
        waterMesh.uv = uvs;
        waterMesh.triangles = triangles;
        
        waterMesh.RecalculateNormals();
        waterMesh.RecalculateBounds();
        
        meshFilter.mesh = waterMesh;
    }
    
#if UNITY_EDITOR
    [MenuItem("GameObject/Water/Ocean Water", false, 10)]
    private static void CreateOceanWater(MenuCommand menuCommand)
    {
        GameObject go = new GameObject("Ocean Water");
        Scr_OceanWaterManager manager = go.AddComponent<Scr_OceanWaterManager>();
        
        // Try to find the material
        string[] guids = AssetDatabase.FindAssets("t:Material OceanWater");
        if (guids.Length > 0)
        {
            manager.waterMaterial = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guids[0]));
        }
        else
        {
            // Fallback: Create new material if not found
             Shader shader = Shader.Find("YmneShader/OceanWater");
             if (shader != null)
             {
                 Material mat = new Material(shader);
                 mat.name = "Ocean_Material";
                  manager.waterMaterial = mat;
             }
        }
        
        // Parent to context
        GameObjectUtility.SetParentAndAlign(go, menuCommand.context as GameObject);
        
        // Register undo
        Undo.RegisterCreatedObjectUndo(go, "Create Ocean Water");
        
        Selection.activeObject = go;
    }
    
    [CustomEditor(typeof(Scr_OceanWaterManager))]
    [CanEditMultipleObjects]
    public class Scr_OceanWaterManagerEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            UnityEngine.Object[] targets = base.targets;
            Scr_OceanWaterManager manager = (Scr_OceanWaterManager)target;
            
            EditorGUI.BeginChangeCheck();
            DrawDefaultInspector();
            
            if (EditorGUI.EndChangeCheck())
            {
                // Realtime update enabled again
                foreach (var t in targets)
                {
                    (t as Scr_OceanWaterManager)?.GenerateWaterMesh();
                    (t as Scr_OceanWaterManager)?.UpdateMaterial();
                }
            }
            
            EditorGUILayout.Space();
            if (GUILayout.Button("Regenerate Mesh"))
            {
                foreach (var t in targets)
                {
                    (t as Scr_OceanWaterManager)?.GenerateWaterMesh();
                }
            }
            
            if (GUILayout.Button("Force Update Material"))
            {
                foreach (var t in targets)
                {
                    (t as Scr_OceanWaterManager)?.UpdateMaterial();
                }
            }
        }
    }
#endif
}
