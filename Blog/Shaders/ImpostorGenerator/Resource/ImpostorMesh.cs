using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace Impostor
{
    [ExecuteAlways]
    [RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
    public sealed class ImpostorMesh : MonoBehaviour
    {
        const string ShaderName = "Impostor/ImpostorShader";

        [Header("Atlas")]
        [SerializeField] Texture2D impostorAtlas;

        [Header("Settings")]
        [SerializeField] int gridSize = 12;
        [SerializeField, Range(0f, 1f)] float alphaCutoff = 0.5f;
        [SerializeField] Color tint = Color.white;

        [Header("Size (auto-set by generator)")]
        [SerializeField] float capturedSize = 1f;
        [SerializeField] Vector3 centerOffset = Vector3.zero;

        Material material;

        static readonly int AtlasID  = Shader.PropertyToID("_ImpostorAtlas");
        static readonly int GridID   = Shader.PropertyToID("_GridSize");
        static readonly int CutoffID = Shader.PropertyToID("_AlphaCutoff");
        static readonly int TintID   = Shader.PropertyToID("_Tint");

        void OnEnable()
        {
            EnsureMesh();
            EnsureMaterial();
            PushProperties();
        }

        void OnValidate()
        {
            RebuildMesh();
            PushProperties();
        }

        void Reset()
        {
            EnsureMesh();
            EnsureMaterial();
        }

        void OnDestroy()
        {
            if (material != null)
            {
                if (Application.isPlaying) Destroy(material);
                else DestroyImmediate(material);
            }
        }

        void EnsureMesh()
        {
            MeshFilter mf = GetComponent<MeshFilter>();
            if (mf.sharedMesh != null) return;
            mf.sharedMesh = BuildQuad(capturedSize, centerOffset);
        }

        void RebuildMesh()
        {
            MeshFilter mf = GetComponent<MeshFilter>();
            mf.sharedMesh = BuildQuad(capturedSize, centerOffset);
        }

        void EnsureMaterial()
        {
            MeshRenderer mr = GetComponent<MeshRenderer>();
            Shader shader = Shader.Find(ShaderName);

            if (shader == null)
            {
                Debug.LogError($"[Impostor] Shader '{ShaderName}' not found.");
                return;
            }

            if (material == null || material.shader != shader)
            {
                material = new Material(shader) { name = "Impostor (Instance)" };
                mr.sharedMaterial = material;
            }
        }

        void PushProperties()
        {
            if (material == null) return;
            material.SetTexture(AtlasID, impostorAtlas);
            material.SetFloat(GridID, gridSize);
            material.SetFloat(CutoffID, alphaCutoff);
            material.SetColor(TintID, tint);
        }

        static Mesh BuildQuad(float size, Vector3 offset)
        {
            float h = size * 0.5f;
            Mesh mesh = new Mesh { name = "ImpostorQuad" };

            mesh.vertices = new[]
            {
                new Vector3(-h + offset.x, -h + offset.y, offset.z),
                new Vector3( h + offset.x, -h + offset.y, offset.z),
                new Vector3( h + offset.x,  h + offset.y, offset.z),
                new Vector3(-h + offset.x,  h + offset.y, offset.z)
            };

            mesh.uv = new[]
            {
                new Vector2(0f, 0f),
                new Vector2(1f, 0f),
                new Vector2(1f, 1f),
                new Vector2(0f, 1f)
            };

            mesh.triangles = new[] { 0, 2, 1, 0, 3, 2 };
            mesh.normals = new[] { -Vector3.forward, -Vector3.forward, -Vector3.forward, -Vector3.forward };
            mesh.RecalculateBounds();
            return mesh;
        }

#if UNITY_EDITOR
        [MenuItem("GameObject/3D Object/Impostor", false, 10)]
        static void CreateImpostor(MenuCommand cmd)
        {
            GameObject go = new GameObject("Impostor");
            GameObjectUtility.SetParentAndAlign(go, cmd.context as GameObject);
            Undo.RegisterCreatedObjectUndo(go, "Create Impostor");
            go.AddComponent<ImpostorMesh>();
            Selection.activeGameObject = go;
        }

        public void Setup(Texture2D atlas, int grid, float size, Vector3 offset)
        {
            impostorAtlas = atlas;
            gridSize = grid;
            capturedSize = size;
            centerOffset = offset;
            RebuildMesh();
            EnsureMaterial();
            PushProperties();
        }
#endif
    }
}
