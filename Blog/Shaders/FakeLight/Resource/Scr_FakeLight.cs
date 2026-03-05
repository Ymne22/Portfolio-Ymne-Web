using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteAlways]
public class Scr_FakeLight : MonoBehaviour
{
    [Header("Light Settings")]
    public Color lightColor = new Color(0.95f, 0.95f, 0.95f, 1f);
    [Min(0f)] public float intensity = 128f;
    [Range(1f, 5f)] public float falloffExponent = 2.8f;
    [Min(0.01f)] public float lightSize = 1f;
    
    [Header("Halo Settings")]
    public bool enableHalo = false;
    [Range(0f, 5f)] public float haloSize = 0.5f;
    [Range(0f, 5f)] public float haloIntensity = 1f;
    [Range(1f, 10f)] public float haloFalloffExponent = 4f;
    
    [Header("Shadow Settings")]
    public bool enableShadows = false;
    public bool useTAAJitter = false;
    [Range(0f, 1f)] public float shadowStrength = 1f;
    [Range(4, 128)] public int shadowSteps = 4;
    [Range(0.001f, 0.2f)] public float shadowBias = 0.05f;
    [Range(0f, 128f)] public float shadowMaxDistance = 4f;
    [Range(0f, 1f)] public float shadowBlur = 0f;
    [Range(0f, 1f)] public float shadowSourceRadius = 1f;
    
    [HideInInspector] public Mesh sphereMesh;
    [HideInInspector] public Shader shader; 
    private Material _instanceMaterial;

    private static readonly int ColorID = Shader.PropertyToID("_Color");
    private static readonly int IntensityID = Shader.PropertyToID("_Intensity");
    private static readonly int FalloffExpID = Shader.PropertyToID("_FalloffExp");
    private static readonly int EnableHaloID = Shader.PropertyToID("_EnableHalo");
    private static readonly int HaloSizeID = Shader.PropertyToID("_HaloSize");
    private static readonly int HaloIntensityID = Shader.PropertyToID("_HaloIntensity");
    private static readonly int HaloFalloffExpID = Shader.PropertyToID("_HaloFalloffExp");
    private static readonly int EnableShadowsID = Shader.PropertyToID("_EnableShadows");
    private static readonly int UseTAAJitterID = Shader.PropertyToID("_UseTAAJitter");
    private static readonly int ShadowStrengthID = Shader.PropertyToID("_ShadowStrength");
    private static readonly int ShadowStepsID = Shader.PropertyToID("_ShadowSteps");
    private static readonly int ShadowBiasID = Shader.PropertyToID("_ShadowBias");
    private static readonly int ShadowMaxDistID = Shader.PropertyToID("_ShadowMaxDist");
    private static readonly int ShadowBlurID = Shader.PropertyToID("_ShadowBlur");
    private static readonly int ShadowSourceRadiusID = Shader.PropertyToID("_ShadowSourceRadius");
    
    private void OnEnable()
    {
        if (sphereMesh == null) sphereMesh = GenerateLowPolySphere(1, 0.5f);
        if (_instanceMaterial == null && shader != null)
        {
            _instanceMaterial = new Material(shader);
            _instanceMaterial.hideFlags = HideFlags.HideAndDontSave;
        }
        transform.localScale = Vector3.one;
        UpdateMaterial();
    }

    private void OnDisable()
    {
        if (_instanceMaterial != null) { DestroyImmediate(_instanceMaterial); _instanceMaterial = null; }
    }
    
    private void OnValidate() { UpdateMaterial(); transform.localScale = Vector3.one; }
    private void Start() { UpdateMaterial(); }
    
    private void Update()
    {
        #if UNITY_EDITOR
        if (!Application.isPlaying && transform.localScale != Vector3.one) transform.localScale = Vector3.one;
        #endif
    }
    
    private void OnRenderObject()
    {
        if (sphereMesh == null || _instanceMaterial == null) return;
        Matrix4x4 matrix = Matrix4x4.TRS(transform.position, transform.rotation, Vector3.one * lightSize);
        _instanceMaterial.SetPass(0);
        Graphics.DrawMeshNow(sphereMesh, matrix);
    }
    
    public void UpdateMaterial()
    {
        if (_instanceMaterial == null) return;
        _instanceMaterial.SetColor(ColorID, lightColor);
        _instanceMaterial.SetFloat(IntensityID, intensity);
        _instanceMaterial.SetFloat(FalloffExpID, falloffExponent);
        _instanceMaterial.SetFloat(EnableHaloID, enableHalo ? 1f : 0f);
        _instanceMaterial.SetFloat(HaloSizeID, haloSize);
        _instanceMaterial.SetFloat(HaloIntensityID, haloIntensity);
        _instanceMaterial.SetFloat(HaloFalloffExpID, haloFalloffExponent);
        _instanceMaterial.SetFloat(EnableShadowsID, enableShadows ? 1f : 0f);
        _instanceMaterial.SetFloat(UseTAAJitterID, useTAAJitter ? 1f : 0f);
        _instanceMaterial.SetFloat(ShadowStrengthID, shadowStrength);
        _instanceMaterial.SetFloat(ShadowStepsID, shadowSteps);
        _instanceMaterial.SetFloat(ShadowBiasID, shadowBias);
        _instanceMaterial.SetFloat(ShadowMaxDistID, shadowMaxDistance);
        _instanceMaterial.SetFloat(ShadowBlurID, shadowBlur);
        _instanceMaterial.SetFloat(ShadowSourceRadiusID, shadowSourceRadius);
        
        if (enableHalo) _instanceMaterial.EnableKeyword("_ENABLE_HALO");
        else _instanceMaterial.DisableKeyword("_ENABLE_HALO");
        if (enableShadows) _instanceMaterial.EnableKeyword("_ENABLE_SHADOWS");
        else _instanceMaterial.DisableKeyword("_ENABLE_SHADOWS");
        if (useTAAJitter) _instanceMaterial.EnableKeyword("_USE_TAA_JITTER");
        else _instanceMaterial.DisableKeyword("_USE_TAA_JITTER");
    }
    
#if UNITY_EDITOR
    private void OnDrawGizmos()
    {
        Gizmos.DrawIcon(transform.position, "PointLight Gizmo", true, lightColor);
        Gizmos.color = new Color(lightColor.r, lightColor.g, lightColor.b, 0.3f);
        Gizmos.DrawWireSphere(transform.position, lightSize * 0.5f);
    }
    
    private void OnDrawGizmosSelected()
    {
        Gizmos.color = lightColor;
        Gizmos.DrawWireSphere(transform.position, lightSize * 0.5f);
        if (enableHalo)
        {
            Gizmos.color = new Color(lightColor.r, lightColor.g, lightColor.b, 0.2f);
            Gizmos.DrawWireSphere(transform.position, lightSize * 0.5f * haloSize);
        }
    }
    
    private static Mesh GenerateLowPolySphere(int subdivisions = 1, float radius = 0.5f)
    {
        Mesh mesh = new Mesh { name = "FakeLight_Sphere" };
        float t = (1f + Mathf.Sqrt(5f)) / 2f;
        var vertices = new System.Collections.Generic.List<Vector3>
        {
            new Vector3(-1, t, 0).normalized * radius, new Vector3(1, t, 0).normalized * radius,
            new Vector3(-1, -t, 0).normalized * radius, new Vector3(1, -t, 0).normalized * radius,
            new Vector3(0, -1, t).normalized * radius, new Vector3(0, 1, t).normalized * radius,
            new Vector3(0, -1, -t).normalized * radius, new Vector3(0, 1, -t).normalized * radius,
            new Vector3(t, 0, -1).normalized * radius, new Vector3(t, 0, 1).normalized * radius,
            new Vector3(-t, 0, -1).normalized * radius, new Vector3(-t, 0, 1).normalized * radius
        };
        var triangles = new System.Collections.Generic.List<int>
        {
            0,5,11, 0,1,5, 0,7,1, 0,10,7, 0,11,10,
            1,9,5, 5,4,11, 11,2,10, 10,6,7, 7,8,1,
            3,4,9, 3,2,4, 3,6,2, 3,8,6, 3,9,8,
            4,5,9, 2,11,4, 6,10,2, 8,7,6, 9,1,8
        };
        var midpointCache = new System.Collections.Generic.Dictionary<long, int>();
        for (int i = 0; i < subdivisions; i++)
        {
            var newTriangles = new System.Collections.Generic.List<int>();
            for (int j = 0; j < triangles.Count; j += 3)
            {
                int v1 = triangles[j], v2 = triangles[j+1], v3 = triangles[j+2];
                int a = GetMidpoint(v1, v2, vertices, midpointCache, radius);
                int b = GetMidpoint(v2, v3, vertices, midpointCache, radius);
                int c = GetMidpoint(v3, v1, vertices, midpointCache, radius);
                newTriangles.Add(v1); newTriangles.Add(c); newTriangles.Add(a);
                newTriangles.Add(v2); newTriangles.Add(a); newTriangles.Add(b);
                newTriangles.Add(v3); newTriangles.Add(b); newTriangles.Add(c);
                newTriangles.Add(a);  newTriangles.Add(c); newTriangles.Add(b);
            }
            triangles = newTriangles;
            midpointCache.Clear();
        }
        mesh.SetVertices(vertices);
        mesh.SetTriangles(triangles, 0);
        mesh.RecalculateNormals();
        return mesh;
    }
    
    private static int GetMidpoint(int i1, int i2, System.Collections.Generic.List<Vector3> vertices, System.Collections.Generic.Dictionary<long, int> cache, float radius)
    {
        long smallerIndex = Mathf.Min(i1, i2), greaterIndex = Mathf.Max(i1, i2), key = (smallerIndex << 32) + greaterIndex;
        if (cache.TryGetValue(key, out int ret)) return ret;
        Vector3 middle = ((vertices[i1] + vertices[i2]) / 2f).normalized * radius;
        int newIndex = vertices.Count; vertices.Add(middle); cache[key] = newIndex;
        return newIndex;
    }
    
    [MenuItem("GameObject/Light/Fake Light", false, 10)]
    private static void CreateFakeLight(MenuCommand menuCommand)
    {
        string[] guids = AssetDatabase.FindAssets("t:Script Scr_FakeLight");
        if (guids.Length == 0) return;
        string scriptPath = AssetDatabase.GUIDToAssetPath(guids[0]);
        string folderPath = System.IO.Path.GetDirectoryName(scriptPath);
        Shader fakeLightShader = AssetDatabase.LoadAssetAtPath<Shader>(folderPath + "/Shader_FakeLight.shader");
        if (fakeLightShader == null) return;
        GameObject lightObj = new GameObject("Fake Light");
        Scr_FakeLight fakeLight = lightObj.AddComponent<Scr_FakeLight>();
        fakeLight.shader = fakeLightShader;
        fakeLight.sphereMesh = GenerateLowPolySphere(1, 0.5f);
        fakeLight.SendMessage("OnEnable"); 
        fakeLight.UpdateMaterial();
        GameObjectUtility.SetParentAndAlign(lightObj, menuCommand.context as GameObject);
        Undo.RegisterCreatedObjectUndo(lightObj, "Create Fake Light");
        Selection.activeObject = lightObj;
    }
    
    [CustomEditor(typeof(Scr_FakeLight)), CanEditMultipleObjects]
    public class Scr_FakeLightEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            EditorGUI.BeginChangeCheck();
            DrawDefaultInspector();
            if (EditorGUI.EndChangeCheck())
            {
                foreach (Object obj in targets) ((Scr_FakeLight)obj).UpdateMaterial();
            }
            EditorGUILayout.Space();
            EditorGUILayout.HelpBox("Scale is locked to 1. Use 'Light Size' to adjust.", MessageType.Info);
        }
    }
#endif
}
