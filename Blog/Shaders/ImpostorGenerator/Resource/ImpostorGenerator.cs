#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using System.IO;

namespace Impostor
{
    public sealed class ImpostorGenerator : EditorWindow
    {
        GameObject targetPrefab;
        int atlasResolution = 2048;
        int gridSize = 12;
        string savePath = "Assets/Impostors";
        float radiusMultiplier = 1.5f;
        bool safeMode = true;
        int safeBatchSize = 4;

        [MenuItem("Window/Impostor Generator")]
        static void Open()
        {
            GetWindow<ImpostorGenerator>("Impostor Generator");
        }

        void OnGUI()
        {
            EditorGUILayout.Space(8);
            EditorGUILayout.LabelField("Impostor Atlas Generator", EditorStyles.boldLabel);
            EditorGUILayout.Space(4);

            targetPrefab = (GameObject)EditorGUILayout.ObjectField("Target Prefab", targetPrefab, typeof(GameObject), true);
            atlasResolution = EditorGUILayout.IntPopup("Atlas Resolution",
                atlasResolution,
                new[] { "512", "1024", "2048", "4096" },
                new[] { 512, 1024, 2048, 4096 });
            gridSize = EditorGUILayout.IntSlider("Grid Size", gridSize, 4, 32);
            radiusMultiplier = EditorGUILayout.Slider("Radius Multiplier", radiusMultiplier, 1f, 3f);

            EditorGUILayout.Space(4);
            EditorGUILayout.BeginHorizontal();
            savePath = EditorGUILayout.TextField("Save Path", savePath);
            if (GUILayout.Button("...", GUILayout.Width(28)))
            {
                string selected = EditorUtility.OpenFolderPanel("Save Location", savePath, "");
                if (!string.IsNullOrEmpty(selected))
                    savePath = FileUtil.GetProjectRelativePath(selected);
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space(4);
            safeMode = EditorGUILayout.Toggle("Safe Mode (Low RAM)", safeMode);
            if (safeMode)
            {
                EditorGUI.indentLevel++;
                safeBatchSize = EditorGUILayout.IntSlider("Batch Size (rows)", safeBatchSize, 1, gridSize);
                EditorGUILayout.HelpBox(
                    "Renders in small batches and releases memory between each. " +
                    "Slower but prevents crashes on low-spec machines.",
                    MessageType.Info);
                EditorGUI.indentLevel--;
            }

            EditorGUILayout.Space(8);
            EditorGUI.BeginDisabledGroup(targetPrefab == null);
            if (GUILayout.Button("Generate Impostor Atlas", GUILayout.Height(32)))
                Generate();
            EditorGUI.EndDisabledGroup();
        }

        void Generate()
        {
            if (targetPrefab == null) return;

            int frameCount = gridSize * gridSize;
            int frameSize = atlasResolution / gridSize;

            GameObject instance = Instantiate(targetPrefab, Vector3.zero, Quaternion.identity);
            instance.hideFlags = HideFlags.HideAndDontSave;

            const int isoLayer = 31;
            var transforms = instance.GetComponentsInChildren<Transform>(true);
            for (int r = 0; r < transforms.Length; r++)
                transforms[r].gameObject.layer = isoLayer;

            Bounds bounds = CalculateBounds(instance);
            Vector3 center = bounds.center;
            float radius = bounds.extents.magnitude * radiusMultiplier;

            Texture2D atlas = new Texture2D(atlasResolution, atlasResolution, TextureFormat.RGBA32, false);

            GameObject camGO = new GameObject("_ImpostorCam") { hideFlags = HideFlags.HideAndDontSave };
            Camera cam = camGO.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0, 0, 0, 0);
            cam.orthographic = true;
            cam.orthographicSize = bounds.extents.magnitude;
            cam.nearClipPlane = 0.01f;
            cam.farClipPlane = radius * 3f;
            cam.cullingMask = 1 << isoLayer;
            cam.enabled = false;

            RenderTexture frameRT = null;

            for (int i = 0; i < frameCount; i++)
            {
                // Safe mode: allocate/release RT per batch to keep VRAM low
                if (safeMode)
                {
                    int row = i / gridSize;
                    bool batchStart = (i == 0) || (row % safeBatchSize == 0 && i % gridSize == 0);

                    if (batchStart)
                    {
                        if (frameRT != null)
                        {
                            RenderTexture.active = null;
                            RenderTexture.ReleaseTemporary(frameRT);
                        }
                        System.GC.Collect();
                        Resources.UnloadUnusedAssets();
                        frameRT = RenderTexture.GetTemporary(frameSize, frameSize, 24, RenderTextureFormat.ARGB32);
                        cam.targetTexture = frameRT;
                    }
                }
                else if (frameRT == null)
                {
                    frameRT = RenderTexture.GetTemporary(frameSize, frameSize, 24, RenderTextureFormat.ARGB32);
                    cam.targetTexture = frameRT;
                }

                int x = i % gridSize;
                int y = i / gridSize;

                Vector2 octUV = new Vector2(
                    (x + 0.5f) / gridSize * 2f - 1f,
                    (y + 0.5f) / gridSize * 2f - 1f);

                Vector3 dir = OctDecode(octUV);
                cam.transform.position = center + dir * radius;
                cam.transform.LookAt(center, Vector3.up);
                cam.Render();

                RenderTexture.active = frameRT;
                atlas.ReadPixels(new Rect(0, 0, frameSize, frameSize), x * frameSize, y * frameSize);

                if (EditorUtility.DisplayCancelableProgressBar("Generating Impostor",
                    $"Frame {i + 1}/{frameCount}{(safeMode ? " [Safe Mode]" : "")}",
                    (float)(i + 1) / frameCount))
                {
                    // User cancelled
                    RenderTexture.active = null;
                    if (frameRT != null) RenderTexture.ReleaseTemporary(frameRT);
                    DestroyImmediate(camGO);
                    DestroyImmediate(instance);
                    DestroyImmediate(atlas);
                    EditorUtility.ClearProgressBar();
                    Debug.Log("[Impostor] Generation cancelled.");
                    return;
                }
            }

            atlas.Apply();

            RenderTexture.active = null;
            if (frameRT != null) RenderTexture.ReleaseTemporary(frameRT);
            DestroyImmediate(camGO);
            DestroyImmediate(instance);

            if (safeMode) System.GC.Collect();

            if (!Directory.Exists(savePath))
                Directory.CreateDirectory(savePath);

            string fileName = $"{targetPrefab.name}_Impostor_{gridSize}x{gridSize}.png";
            string fullPath = Path.Combine(savePath, fileName);
            File.WriteAllBytes(fullPath, atlas.EncodeToPNG());
            DestroyImmediate(atlas);

            if (safeMode) System.GC.Collect();

            AssetDatabase.Refresh();

            TextureImporter importer = AssetImporter.GetAtPath(fullPath) as TextureImporter;
            if (importer != null)
            {
                importer.textureType = TextureImporterType.Default;
                importer.alphaIsTransparency = true;
                importer.sRGBTexture = true;
                importer.mipmapEnabled = true;
                importer.maxTextureSize = atlasResolution;
                importer.SaveAndReimport();
            }

            EditorUtility.ClearProgressBar();

            Texture2D savedAtlas = AssetDatabase.LoadAssetAtPath<Texture2D>(fullPath);

            float capturedSize = bounds.extents.magnitude * 2f;
            Vector3 centerOff = bounds.center;

            GameObject impostorGO = new GameObject($"{targetPrefab.name}_Impostor");
            Undo.RegisterCreatedObjectUndo(impostorGO, "Create Impostor");
            ImpostorMesh im = impostorGO.AddComponent<ImpostorMesh>();
            im.Setup(savedAtlas, gridSize, capturedSize, centerOff);
            Selection.activeGameObject = impostorGO;

            Debug.Log($"[Impostor] Atlas saved: {fullPath}  ({gridSize}x{gridSize}, {atlasResolution}px, size={capturedSize:F2})");
        }

        static Bounds CalculateBounds(GameObject go)
        {
            Renderer[] renderers = go.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0) return new Bounds(go.transform.position, Vector3.one);

            Bounds b = renderers[0].bounds;
            for (int i = 1; i < renderers.Length; i++)
                b.Encapsulate(renderers[i].bounds);
            return b;
        }

        static Vector3 OctDecode(Vector2 e)
        {
            Vector3 v = new Vector3(e.x, 1f - Mathf.Abs(e.x) - Mathf.Abs(e.y), e.y);
            if (v.y < 0f)
            {
                float sx = v.x >= 0f ? 1f : -1f;
                float sz = v.z >= 0f ? 1f : -1f;
                float ox = v.x;
                v.x = (1f - Mathf.Abs(v.z)) * sx;
                v.z = (1f - Mathf.Abs(ox)) * sz;
            }
            return v.normalized;
        }
    }
}
#endif
