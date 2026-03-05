#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace RnDTools
{
    public sealed class LODGeneratorEditor : EditorWindow
    {

        private class MeshEntry
        {
            public string assetPath;
            public string fileName;
            public string infoText;
            public bool selected;
            public int vertexCount;
            public int triangleCount;
            public int submeshCount;

            public MeshEntry(string path)
            {
                assetPath = path;
                fileName = Path.GetFileName(path);
                selected = true;
                CacheInfoText();
            }

            public void CacheInfoText()
            {
                Mesh mesh = LoadFirstMesh(assetPath);
                if (mesh != null)
                {
                    vertexCount = mesh.vertexCount;
                    triangleCount = mesh.triangles.Length / 3;
                    submeshCount = mesh.subMeshCount;
                    infoText = $"Verts: {vertexCount}  |  Tris: {triangleCount}  |  Submeshes: {submeshCount}";
                }
                else
                {
                    infoText = assetPath;
                }
            }

            private static Mesh LoadFirstMesh(string path)
            {
                Mesh directMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
                if (directMesh != null)
                {
                    return directMesh;
                }

                GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                if (prefab != null)
                {
                    MeshFilter mf = prefab.GetComponentInChildren<MeshFilter>();
                    if (mf != null && mf.sharedMesh != null)
                    {
                        return mf.sharedMesh;
                    }

                    SkinnedMeshRenderer smr = prefab.GetComponentInChildren<SkinnedMeshRenderer>();
                    if (smr != null && smr.sharedMesh != null)
                    {
                        return smr.sharedMesh;
                    }
                }

                return null;
            }
        }

        private class LODLevelSettings
        {
            public float screenRelativeHeight;
            public int triangleReductionPercent;
            public bool preserveUVSeams;
            public bool preserveSurfaceCurvature;
            public float weldTolerance;
            public UnityEngine.Rendering.ShadowCastingMode castShadows;

            public LODLevelSettings(float screen, int reduction)
            {
                screenRelativeHeight = screen;
                triangleReductionPercent = reduction;
                preserveUVSeams = true;
                preserveSurfaceCurvature = true;
                weldTolerance = 0.001f;
                castShadows = UnityEngine.Rendering.ShadowCastingMode.On;
            }
        }

        private class EdgeCandidate
        {
            public int v0;
            public int v1;
            public int r0;
            public int r1;
            public float cost;
            public int stamp;
        }

        private class MeshDecimationData
        {
            public Vector3[] positions;
            public Vector3[] normals;
            public Vector2[] uvs;
            public Vector2[] uv2s;
            public Vector2[] uv3s;
            public Vector2[] uv4s;
            public Vector4[] tangents;
            public Color[] colors;
            public int[] triangles;
            
            public bool hasUV2, hasUV3, hasUV4, hasTangents, hasColors;
            
            public float progress;
            public bool isCancelled;
            
            public int[] newTriangles;
            public Vector3[] newPos;
            public Vector3[] newNorm;
            public Vector2[] newUV;
            public Vector2[] newUV2;
            public Vector2[] newUV3;
            public Vector2[] newUV4;
            public Vector4[] newTan;
            public Color[] newCol;
        }


        private const float ROW_HEIGHT = 36f;
        private const float SECTION_SPACING = 8f;

        private static readonly string[] MeshExtensions =
        {
            ".fbx", ".obj", ".blend", ".dae", ".3ds",
            ".max", ".ma", ".mb", ".asset", ".prefab"
        };

        private List<MeshEntry> meshEntries = new List<MeshEntry>();
        private List<LODLevelSettings> lodLevels = new List<LODLevelSettings>();

        private int lodCount = 3;
        private string outputSuffix = "_LOD";
        private bool saveAlongsideOriginal = true;
        private bool generateLODGroup = true;
        private LODFadeMode fadeMode = LODFadeMode.CrossFade;
        private bool animateCrossFading = true;
        private float crossFadeAnimationDuration = 0.5f;

        private Vector2 meshListScroll;
        private Vector2 mainScroll;

        private bool showLODSettings = true;
        private bool showGlobalSettings = true;
        private bool isProcessing = false;


        [MenuItem("Tools/LOD Generator")]
        private static void Open()
        {
            var window = GetWindow<LODGeneratorEditor>("LOD Generator");
            window.minSize = new Vector2(440, 540);
        }


        private void OnEnable()
        {
            InitializeLODLevels();
        }

        private void InitializeLODLevels()
        {
            lodLevels = new List<LODLevelSettings>
            {
                new LODLevelSettings(0.6f, 75),
                new LODLevelSettings(0.3f, 50),
                new LODLevelSettings(0.1f, 25),
            };
            lodCount = 3;
        }


        private void OnGUI()
        {
            EditorGUI.BeginDisabledGroup(isProcessing);

            mainScroll = EditorGUILayout.BeginScrollView(mainScroll);

            DrawHeader();
            DrawMeshAddButtons();
            DrawDragDropArea();
            DrawMeshList();
            DrawSelectionControls();
            DrawLODSettings();
            DrawGlobalSettings();
            DrawGenerateButton();

            EditorGUILayout.EndScrollView();

            EditorGUI.EndDisabledGroup();
        }


        private void DrawHeader()
        {
            EditorGUILayout.Space(SECTION_SPACING);
            EditorGUILayout.LabelField("LOD Generator", EditorStyles.boldLabel);
            EditorGUILayout.Space(4);

            int selectedCount = meshEntries.Count(e => e.selected);
            EditorGUILayout.LabelField(
                $"{meshEntries.Count} mesh(es) loaded, {selectedCount} selected",
                EditorStyles.miniLabel
            );

            EditorGUILayout.Space(4);
        }


        private void DrawMeshAddButtons()
        {
            EditorGUILayout.BeginHorizontal();

            if (GUILayout.Button("Add Selected", GUILayout.Height(24)))
            {
                AddFromProjectSelection();
            }

            if (GUILayout.Button("Add Folder", GUILayout.Height(24)))
            {
                AddFromFolder();
            }

            if (GUILayout.Button("Clear All", GUILayout.Height(24)))
            {
                meshEntries.Clear();
            }

            EditorGUILayout.EndHorizontal();
        }


        private void DrawDragDropArea()
        {
            EditorGUILayout.Space(2);

            Rect dropRect = GUILayoutUtility.GetRect(0, 40, GUILayout.ExpandWidth(true));
            GUI.Box(dropRect, "Drag & Drop Meshes or Folders Here", EditorStyles.helpBox);

            HandleDragAndDrop(dropRect);
        }

        private void HandleDragAndDrop(Rect dropRect)
        {
            Event evt = Event.current;

            if (!dropRect.Contains(evt.mousePosition))
            {
                return;
            }

            switch (evt.type)
            {
                case EventType.DragUpdated:
                    DragAndDrop.visualMode = DragAndDropVisualMode.Copy;
                    evt.Use();
                    break;

                case EventType.DragPerform:
                    DragAndDrop.AcceptDrag();
                    ProcessDroppedObjects(DragAndDrop.objectReferences, DragAndDrop.paths);
                    evt.Use();
                    break;
            }
        }

        private void ProcessDroppedObjects(Object[] objects, string[] paths)
        {
            foreach (string path in paths)
            {
                if (AssetDatabase.IsValidFolder(path))
                {
                    AddMeshesFromFolder(path);
                }
                else if (IsMeshPath(path))
                {
                    AddMeshEntry(path);
                }
            }

            foreach (Object obj in objects)
            {
                if (obj is Mesh || obj is GameObject)
                {
                    string assetPath = AssetDatabase.GetAssetPath(obj);
                    if (!string.IsNullOrEmpty(assetPath))
                    {
                        AddMeshEntry(assetPath);
                    }
                }
            }
        }


        private void DrawMeshList()
        {
            if (meshEntries.Count == 0)
            {
                return;
            }

            EditorGUILayout.Space(4);
            EditorGUILayout.LabelField("Meshes", EditorStyles.boldLabel);

            float listHeight = Mathf.Min(meshEntries.Count * ROW_HEIGHT, 300f);
            meshListScroll = EditorGUILayout.BeginScrollView(
                meshListScroll,
                GUILayout.Height(listHeight)
            );

            for (int i = 0; i < meshEntries.Count; i++)
            {
                DrawMeshRow(meshEntries[i], i);
            }

            EditorGUILayout.EndScrollView();
        }

        private void DrawMeshRow(MeshEntry entry, int index)
        {
            EditorGUILayout.BeginHorizontal(EditorStyles.helpBox, GUILayout.Height(ROW_HEIGHT));

            entry.selected = EditorGUILayout.Toggle(entry.selected, GUILayout.Width(18));

            EditorGUILayout.BeginVertical();
            GUILayout.FlexibleSpace();

            EditorGUILayout.LabelField(entry.fileName, EditorStyles.boldLabel);
            EditorGUILayout.LabelField(entry.infoText, EditorStyles.miniLabel);

            GUILayout.FlexibleSpace();
            EditorGUILayout.EndVertical();

            GUILayout.FlexibleSpace();

            if (GUILayout.Button("✕", GUILayout.Width(22), GUILayout.Height(22)))
            {
                meshEntries.RemoveAt(index);
                GUIUtility.ExitGUI();
            }

            EditorGUILayout.EndHorizontal();
        }


        private void DrawSelectionControls()
        {
            if (meshEntries.Count == 0)
            {
                return;
            }

            EditorGUILayout.Space(2);
            EditorGUILayout.BeginHorizontal();

            if (GUILayout.Button("Select All", EditorStyles.miniButtonLeft))
            {
                SetAllSelected(true);
            }

            if (GUILayout.Button("Deselect All", EditorStyles.miniButtonMid))
            {
                SetAllSelected(false);
            }

            if (GUILayout.Button("Remove Unchecked", EditorStyles.miniButtonMid))
            {
                meshEntries.RemoveAll(e => !e.selected);
            }

            if (GUILayout.Button("Remove Checked", EditorStyles.miniButtonRight))
            {
                meshEntries.RemoveAll(e => e.selected);
            }

            EditorGUILayout.EndHorizontal();
        }

        private void SetAllSelected(bool value)
        {
            foreach (var entry in meshEntries)
            {
                entry.selected = value;
            }
        }


        private void DrawLODSettings()
        {
            EditorGUILayout.Space(SECTION_SPACING);
            showLODSettings = EditorGUILayout.Foldout(showLODSettings, "LOD Level Settings", true, EditorStyles.foldoutHeader);

            if (!showLODSettings)
            {
                return;
            }

            EditorGUI.indentLevel++;

            EditorGUILayout.HelpBox(
                "Configure the number of LOD levels and the triangle reduction for each level. " +
                "Higher reduction percentages keep more triangles.",
                MessageType.Info
            );

            EditorGUILayout.Space(4);

            int newLodCount = EditorGUILayout.IntSlider("LOD Levels", lodCount, 1, 6);
            if (newLodCount != lodCount)
            {
                AdjustLODLevelCount(newLodCount);
            }

            EditorGUILayout.Space(4);

            for (int i = 0; i < lodLevels.Count; i++)
            {
                DrawLODLevelRow(lodLevels[i], i);
            }

            for (int i = 1; i < lodLevels.Count; i++)
            {
                if (lodLevels[i].screenRelativeHeight >= lodLevels[i - 1].screenRelativeHeight)
                {
                    lodLevels[i].screenRelativeHeight = lodLevels[i - 1].screenRelativeHeight * 0.99f;
                }
            }

            EditorGUI.indentLevel--;
        }

        private void AdjustLODLevelCount(int newCount)
        {
            lodCount = newCount;

            while (lodLevels.Count < lodCount)
            {
                float lastScreen = lodLevels.Count > 0 ? lodLevels[lodLevels.Count - 1].screenRelativeHeight : 1.0f;
                float screen = Mathf.Max(0.001f, lastScreen * 0.5f);
                
                int lastReduction = lodLevels.Count > 0 ? lodLevels[lodLevels.Count - 1].triangleReductionPercent : 100;
                int reduction = Mathf.Clamp(lastReduction - 15, 5, 95);
                
                lodLevels.Add(new LODLevelSettings(screen, reduction));
            }

            while (lodLevels.Count > lodCount)
            {
                lodLevels.RemoveAt(lodLevels.Count - 1);
            }

            for (int i = 1; i < lodLevels.Count; i++)
            {
                if (lodLevels[i].screenRelativeHeight >= lodLevels[i - 1].screenRelativeHeight)
                {
                    lodLevels[i].screenRelativeHeight = lodLevels[i - 1].screenRelativeHeight * 0.5f;
                }
            }
        }

        private void DrawLODLevelRow(LODLevelSettings level, int index)
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);

            EditorGUILayout.LabelField($"LOD {index + 1}", EditorStyles.boldLabel);

            EditorGUI.indentLevel++;

            level.screenRelativeHeight = EditorGUILayout.Slider(
                "Screen Relative Height",
                level.screenRelativeHeight,
                0.001f,
                1f
            );

            level.triangleReductionPercent = EditorGUILayout.IntSlider(
                "Triangle Reduction %",
                level.triangleReductionPercent,
                1,
                100
            );

            level.preserveUVSeams = EditorGUILayout.Toggle("Preserve UV Seams", level.preserveUVSeams);
            level.preserveSurfaceCurvature = EditorGUILayout.Toggle("Preserve Surface Curvature", level.preserveSurfaceCurvature);
            level.weldTolerance = EditorGUILayout.Slider("Weld Tolerance", level.weldTolerance, 0.0001f, 0.01f);
            level.castShadows = (UnityEngine.Rendering.ShadowCastingMode)EditorGUILayout.EnumPopup("Cast Shadows", level.castShadows);

            EditorGUI.indentLevel--;

            EditorGUILayout.EndVertical();
        }


        private void DrawGlobalSettings()
        {
            EditorGUILayout.Space(SECTION_SPACING);
            showGlobalSettings = EditorGUILayout.Foldout(showGlobalSettings, "Output Settings", true, EditorStyles.foldoutHeader);

            if (!showGlobalSettings)
            {
                return;
            }

            EditorGUI.indentLevel++;

            outputSuffix = EditorGUILayout.TextField("Output Suffix", outputSuffix);
            saveAlongsideOriginal = EditorGUILayout.Toggle("Save Alongside Original", saveAlongsideOriginal);
            generateLODGroup = EditorGUILayout.Toggle("Generate LODGroup Prefab", generateLODGroup);

            EditorGUILayout.Space(4);

            fadeMode = (LODFadeMode)EditorGUILayout.EnumPopup("Fade Mode", fadeMode);
            animateCrossFading = EditorGUILayout.Toggle("Animate Cross Fading", animateCrossFading);

            if (animateCrossFading)
            {
                crossFadeAnimationDuration = EditorGUILayout.Slider(
                    "Cross Fade Duration",
                    crossFadeAnimationDuration,
                    0.1f,
                    2f
                );
            }

            EditorGUI.indentLevel--;
        }


        private void DrawGenerateButton()
        {
            EditorGUILayout.Space(SECTION_SPACING);

            int selectedCount = meshEntries.Count(e => e.selected);

            EditorGUI.BeginDisabledGroup(selectedCount == 0);

            if (GUILayout.Button(isProcessing ? "Processing..." : "Generate LODs", GUILayout.Height(32)))
            {
                GenerateLODsAsync();
            }

            EditorGUI.EndDisabledGroup();

            if (selectedCount == 0 && meshEntries.Count > 0)
            {
                EditorGUILayout.HelpBox("No meshes selected. Check the boxes next to the meshes you want to process.", MessageType.Warning);
            }

            EditorGUILayout.Space(SECTION_SPACING);
        }


        private async void GenerateLODsAsync()
        {
            if (isProcessing) return;
            var selected = meshEntries.Where(e => e.selected).ToList();

            if (selected.Count == 0)
            {
                EditorUtility.DisplayDialog("LOD Generator", "No meshes selected.", "OK");
                return;
            }

            bool confirm = EditorUtility.DisplayDialog(
                "LOD Generator",
                $"Generate {lodCount} LOD level(s) for {selected.Count} mesh(es)?\n\nThis may take a while for complex meshes.",
                "Generate",
                "Cancel"
            );

            if (!confirm)
            {
                return;
            }

            EnsureMeshesReadable(selected);

            int processed = 0;
            int failed = 0;

            int parentProgressId = Progress.Start(
                "LOD Generator",
                $"Generating LODs for {selected.Count} mesh(es)...",
                Progress.Options.Managed
            );

            try
            {
                isProcessing = true;

                for (int i = 0; i < selected.Count; i++)
                {
                    if (Progress.GetStatus(parentProgressId) == Progress.Status.Canceled)
                    {
                        Debug.Log("[LODGenerator] Cancelled by user.");
                        break;
                    }

                    Progress.Report(parentProgressId, (float)i / selected.Count, selected[i].fileName);

                    bool success = await ProcessMeshEntryAsync(selected[i], i, selected.Count, parentProgressId);

                    if (success)
                    {
                        processed++;
                    }
                    else
                    {
                        failed++;
                    }
                }

                Progress.Report(parentProgressId, 1f, $"Done — {processed} processed, {failed} failed.");
                Progress.Finish(parentProgressId, failed > 0 ? Progress.Status.Failed : Progress.Status.Succeeded);
            }
            catch (System.Exception e)
            {
                Progress.Finish(parentProgressId, Progress.Status.Failed);
                Debug.LogError($"[LODGenerator] Unexpected error: {e}");
            }
            finally
            {
                isProcessing = false;
                AssetDatabase.Refresh();
            }

            Debug.Log($"[LODGenerator] Done. {processed} mesh(es) processed, {failed} failed.");
        }

        private void EnsureMeshesReadable(List<MeshEntry> entries)
        {
            bool anyChanged = false;

            foreach (var entry in entries)
            {
                Mesh mesh = LoadMeshFromPath(entry.assetPath);
                if (mesh == null)
                {
                    continue;
                }

                if (!mesh.isReadable)
                {
                    ModelImporter importer = AssetImporter.GetAtPath(entry.assetPath) as ModelImporter;
                    if (importer != null && !importer.isReadable)
                    {
                        importer.isReadable = true;
                        importer.SaveAndReimport();
                        anyChanged = true;
                        Debug.Log($"[LODGenerator] Enabled Read/Write for: {entry.assetPath}");
                    }
                }
            }

            if (anyChanged)
            {
                AssetDatabase.Refresh();
            }
        }

        private async Task<bool> ProcessMeshEntryAsync(MeshEntry entry, int currentIndex, int totalCount, int parentProgressId)
        {
            Mesh sourceMesh = LoadMeshFromPath(entry.assetPath);

            if (sourceMesh == null)
            {
                Debug.LogWarning($"[LODGenerator] Could not load mesh from: {entry.assetPath}");
                return false;
            }

            string directory = Path.GetDirectoryName(entry.assetPath);
            string baseName = Path.GetFileNameWithoutExtension(entry.assetPath);

            if (!saveAlongsideOriginal)
            {
                directory = "Assets/GeneratedLODs";
                if (!AssetDatabase.IsValidFolder(directory))
                {
                    AssetDatabase.CreateFolder("Assets", "GeneratedLODs");
                }
            }

            int childProgressId = Progress.Start(
                entry.fileName,
                $"Preparing LODs...",
                Progress.Options.None,
                parentProgressId
            );

            List<Mesh> generatedMeshes = new List<Mesh>();

            for (int lodIndex = 0; lodIndex < lodLevels.Count; lodIndex++)
            {
                if (Progress.GetStatus(parentProgressId) == Progress.Status.Canceled)
                {
                    Progress.Finish(childProgressId, Progress.Status.Canceled);
                    return generatedMeshes.Count > 0;
                }

                Progress.Report(childProgressId, (float)lodIndex / lodLevels.Count, $"Generating LOD {lodIndex + 1} / {lodLevels.Count}");

                LODLevelSettings level = lodLevels[lodIndex];
                float targetRatio = level.triangleReductionPercent / 100f;

                Mesh decimated = await DecimateMeshAsync(sourceMesh, targetRatio, level, entry.fileName, lodIndex + 1, childProgressId);

                if (decimated == null)
                {
                    Debug.LogWarning($"[LODGenerator] Decimation failed for {entry.fileName} at LOD {lodIndex + 1}");
                    continue;
                }

                decimated.name = $"{baseName}{outputSuffix}{lodIndex + 1}";

                string assetPath = $"{directory}/{decimated.name}.asset";
                assetPath = AssetDatabase.GenerateUniqueAssetPath(assetPath);

                AssetDatabase.StartAssetEditing();
                AssetDatabase.CreateAsset(decimated, assetPath);
                AssetDatabase.StopAssetEditing();
                
                generatedMeshes.Add(decimated);

                Debug.Log($"[LODGenerator] Created {assetPath} ({decimated.triangles.Length / 3} tris)");
            }

            if (generateLODGroup && generatedMeshes.Count > 0)
            {
                CreateLODGroupPrefab(sourceMesh, generatedMeshes, directory, baseName, entry.assetPath);
            }

            bool anyGenerated = generatedMeshes.Count > 0;
            Progress.Finish(childProgressId, anyGenerated ? Progress.Status.Succeeded : Progress.Status.Failed);
            return anyGenerated;
        }

        private void CreateLODGroupPrefab(Mesh sourceMesh, List<Mesh> lodMeshes, string directory, string baseName, string sourceAssetPath)
        {
            GameObject root = new GameObject($"{baseName}_LODGroup");
            LODGroup lodGroup = root.AddComponent<LODGroup>();

            lodGroup.fadeMode = fadeMode;
            lodGroup.animateCrossFading = animateCrossFading;

            Material defaultMaterial = GetSourceMaterial(sourceAssetPath);
            if (defaultMaterial == null)
            {
                defaultMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            }

            LOD[] lods = new LOD[lodMeshes.Count + 1];

            GameObject lod0Obj = new GameObject("LOD0");
            lod0Obj.transform.SetParent(root.transform);
            MeshFilter mf0 = lod0Obj.AddComponent<MeshFilter>();
            MeshRenderer mr0 = lod0Obj.AddComponent<MeshRenderer>();
            mf0.sharedMesh = sourceMesh;
            mr0.sharedMaterial = defaultMaterial;
            lods[0] = new LOD(lodLevels.Count > 0 ? lodLevels[0].screenRelativeHeight : 0.5f, new Renderer[] { mr0 });

            for (int i = 0; i < lodMeshes.Count; i++)
            {
                GameObject lodObj = new GameObject($"LOD{i + 1}");
                lodObj.transform.SetParent(root.transform);
                MeshFilter mf = lodObj.AddComponent<MeshFilter>();
                MeshRenderer mr = lodObj.AddComponent<MeshRenderer>();
                mf.sharedMesh = lodMeshes[i];
                mr.sharedMaterial = defaultMaterial;

                if (i < lodLevels.Count)
                {
                    mr.shadowCastingMode = lodLevels[i].castShadows;
                }

                float screenHeight = (i + 1 < lodLevels.Count) ? lodLevels[i + 1].screenRelativeHeight : 0.01f;
                
                if (screenHeight >= lods[i].screenRelativeTransitionHeight)
                {
                    screenHeight = lods[i].screenRelativeTransitionHeight * 0.5f;
                }

                lods[i + 1] = new LOD(screenHeight, new Renderer[] { mr });
            }

            lodGroup.SetLODs(lods);
            lodGroup.RecalculateBounds();

            string prefabPath = $"{directory}/{baseName}_LODGroup.prefab";
            prefabPath = AssetDatabase.GenerateUniqueAssetPath(prefabPath);
            
            AssetDatabase.StartAssetEditing();
            PrefabUtility.SaveAsPrefabAsset(root, prefabPath);
            AssetDatabase.StopAssetEditing();
            
            DestroyImmediate(root);

            Debug.Log($"[LODGenerator] Created LODGroup prefab: {prefabPath}");
        }

        private Material GetSourceMaterial(string assetPath)
        {
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(assetPath);
            if (prefab == null)
            {
                return null;
            }

            MeshRenderer mr = prefab.GetComponentInChildren<MeshRenderer>();
            if (mr != null && mr.sharedMaterial != null)
            {
                return mr.sharedMaterial;
            }

            SkinnedMeshRenderer smr = prefab.GetComponentInChildren<SkinnedMeshRenderer>();
            if (smr != null && smr.sharedMaterial != null)
            {
                return smr.sharedMaterial;
            }

            return null;
        }


        private async Task<Mesh> DecimateMeshAsync(Mesh source, float targetRatio, LODLevelSettings settings, string meshName, int lodIndex, int childProgressId)
        {
            if (!source.isReadable)
            {
                Debug.LogWarning($"[LODGenerator] Mesh '{source.name}' is not readable.");
                return null;
            }

            MeshDecimationData data = new MeshDecimationData();
            data.positions = source.vertices;
            data.triangles = source.triangles;

            if (data.positions.Length == 0 || data.triangles.Length == 0)
            {
                return null;
            }

            var normals = source.normals;
            if (normals == null || normals.Length != data.positions.Length)
            {
                Mesh tmp = Object.Instantiate(source);
                tmp.RecalculateNormals();
                normals = tmp.normals;
                DestroyImmediate(tmp);
            }
            data.normals = normals;

            data.uvs = source.uv;
            if (data.uvs == null || data.uvs.Length != data.positions.Length)
            {
                data.uvs = new Vector2[data.positions.Length];
            }

            data.uv2s = source.uv2;
            data.uv3s = source.uv3;
            data.uv4s = source.uv4;
            data.tangents = source.tangents;
            data.colors = source.colors;

            data.hasUV2 = data.uv2s != null && data.uv2s.Length == data.positions.Length;
            data.hasUV3 = data.uv3s != null && data.uv3s.Length == data.positions.Length;
            data.hasUV4 = data.uv4s != null && data.uv4s.Length == data.positions.Length;
            data.hasTangents = data.tangents != null && data.tangents.Length == data.positions.Length;
            data.hasColors = data.colors != null && data.colors.Length == data.positions.Length;

            Task mathTask = Task.Run(() => DecimateMath(data, targetRatio, settings));
            
            while (!mathTask.IsCompleted)
            {
                Progress.Report(childProgressId, data.progress, $"LOD {lodIndex} — {data.progress:P0}");

                if (Progress.GetStatus(childProgressId) == Progress.Status.Canceled)
                {
                    data.isCancelled = true;
                    return null;
                }
                
                await Task.Delay(30);
            }

            if (data.isCancelled || data.newPos == null || data.newPos.Length == 0)
            {
                return null;
            }

            Mesh result = new Mesh();
            result.indexFormat = data.newPos.Length > 65535
                ? UnityEngine.Rendering.IndexFormat.UInt32
                : UnityEngine.Rendering.IndexFormat.UInt16;
            result.vertices = data.newPos;
            result.normals = data.newNorm;
            result.uv = data.newUV;
            if (data.hasUV2) result.uv2 = data.newUV2;
            if (data.hasUV3) result.uv3 = data.newUV3;
            if (data.hasUV4) result.uv4 = data.newUV4;
            if (data.hasTangents) result.tangents = data.newTan;
            if (data.hasColors) result.colors = data.newCol;
            result.triangles = data.newTriangles;
            result.RecalculateBounds();

            return result;
        }

        private void DecimateMath(MeshDecimationData data, float targetRatio, LODLevelSettings settings)
        {
            Vector3[] positions = data.positions;
            Vector3[] normals = data.normals;
            Vector2[] uvs = data.uvs;
            Vector2[] uv2s = data.uv2s;
            Vector2[] uv3s = data.uv3s;
            Vector2[] uv4s = data.uv4s;
            Vector4[] tangents = data.tangents;
            Color[] colors = data.colors;
            int[] triangles = data.triangles;
            bool hasUV2 = data.hasUV2;
            bool hasUV3 = data.hasUV3;
            bool hasUV4 = data.hasUV4;
            bool hasTangents = data.hasTangents;
            bool hasColors = data.hasColors;

            int totalTriCount = triangles.Length / 3;
            int targetTriCount = Mathf.Max(4, Mathf.RoundToInt(totalTriCount * targetRatio));

            int vertCount = positions.Length;
            int[] remap = new int[vertCount];
            for (int i = 0; i < vertCount; i++)
            {
                remap[i] = i;
            }

            float toleranceSq = settings.weldTolerance * settings.weldTolerance;
            Dictionary<long, int> spatialHash = new Dictionary<long, int>();
            float cellSize = settings.weldTolerance * 2f;
            if (cellSize < 1e-8f) cellSize = 1e-8f;

            for (int i = 0; i < vertCount; i++)
            {
                if (remap[i] != i) continue;

                int cx = Mathf.FloorToInt(positions[i].x / cellSize);
                int cy = Mathf.FloorToInt(positions[i].y / cellSize);
                int cz = Mathf.FloorToInt(positions[i].z / cellSize);

                long key = ((long)cx * 73856093L) ^ ((long)cy * 19349663L) ^ ((long)cz * 83492791L);

                if (spatialHash.ContainsKey(key))
                {
                    int existing = spatialHash[key];
                    if ((positions[i] - positions[existing]).sqrMagnitude < toleranceSq)
                    {
                        remap[i] = existing;
                        continue;
                    }
                }

                spatialHash[key] = i;
            }

            HashSet<long> uvSeamEdges = new HashSet<long>();
            if (settings.preserveUVSeams)
            {
                uvSeamEdges = FindUVSeamEdges(uvs, triangles, remap);
            }

            HashSet<int> boundaryVerts = FindBoundaryVertices(triangles, remap);

            float[] curvature = null;
            if (settings.preserveSurfaceCurvature)
            {
                curvature = ComputeCurvatureWeights(normals, triangles, remap, vertCount);
            }

            bool[] alive = new bool[totalTriCount];
            for (int i = 0; i < totalTriCount; i++) alive[i] = true;

            int[][] triIndices = new int[totalTriCount][];
            for (int t = 0; t < totalTriCount; t++)
            {
                triIndices[t] = new int[] { triangles[t * 3], triangles[t * 3 + 1], triangles[t * 3 + 2] };
            }

            Dictionary<int, List<int>> vertToTris = new Dictionary<int, List<int>>();
            for (int t = 0; t < totalTriCount; t++)
            {
                for (int j = 0; j < 3; j++)
                {
                    int rv = remap[triIndices[t][j]];
                    if (!vertToTris.ContainsKey(rv))
                        vertToTris[rv] = new List<int>();
                    vertToTris[rv].Add(t);
                }
            }

            Matrix4x4[] quadrics = new Matrix4x4[vertCount];
            for (int i = 0; i < vertCount; i++) quadrics[i] = Matrix4x4.zero;

            for (int t = 0; t < totalTriCount; t++)
            {
                Vector3 p0 = positions[triIndices[t][0]];
                Vector3 p1 = positions[triIndices[t][1]];
                Vector3 p2 = positions[triIndices[t][2]];

                Vector3 n = Vector3.Cross(p1 - p0, p2 - p0);
                float area = n.magnitude;
                if (area < 1e-10f) continue;
                n /= area;
                float d = -Vector3.Dot(n, p0);

                Matrix4x4 q = PlaneQuadric(n.x, n.y, n.z, d);

                int r0 = remap[triIndices[t][0]];
                int r1 = remap[triIndices[t][1]];
                int r2 = remap[triIndices[t][2]];

                quadrics[r0] = AddMatrix(quadrics[r0], q);
                quadrics[r1] = AddMatrix(quadrics[r1], q);
                quadrics[r2] = AddMatrix(quadrics[r2], q);
            }

            List<EdgeCandidate> edgeHeap = new List<EdgeCandidate>();
            int[] vertStamp = new int[vertCount];
            int globalStamp = 0;

            BuildEdgeCandidates(edgeHeap, triIndices, alive, remap, positions, uvs, quadrics,
                curvature, uvSeamEdges, boundaryVerts, vertStamp, globalStamp);

            edgeHeap.Sort((a, b) => a.cost.CompareTo(b.cost));

            int currentTriCount = totalTriCount;
            int heapIdx = 0;

            while (currentTriCount > targetTriCount && heapIdx < edgeHeap.Count)
            {
                if (data.isCancelled) return;

                EdgeCandidate edge = edgeHeap[heapIdx];
                heapIdx++;

                if (edge.stamp != vertStamp[edge.r0] || edge.stamp != vertStamp[edge.r1])
                    continue;

                if (remap[edge.v0] != edge.r0 || remap[edge.v1] != edge.r1)
                    continue;

                if (edge.r0 == edge.r1)
                    continue;

                int keep = edge.v0;
                int remove = edge.v1;
                int rKeep = edge.r0;
                int rRemove = edge.r1;

                quadrics[rKeep] = AddMatrix(quadrics[rKeep], quadrics[rRemove]);

                for (int i = 0; i < vertCount; i++)
                {
                    if (remap[i] == rRemove)
                        remap[i] = rKeep;
                }

                List<int> affectedTris = new List<int>();
                if (vertToTris.ContainsKey(rRemove))
                {
                    affectedTris.AddRange(vertToTris[rRemove]);
                    if (vertToTris.ContainsKey(rKeep))
                        vertToTris[rKeep].AddRange(vertToTris[rRemove]);
                    else
                        vertToTris[rKeep] = vertToTris[rRemove];
                    vertToTris.Remove(rRemove);
                }

                if (vertToTris.ContainsKey(rKeep))
                {
                    foreach (int t in vertToTris[rKeep])
                    {
                        if (!alive[t]) continue;

                        for (int j = 0; j < 3; j++)
                        {
                            int vi = triIndices[t][j];
                            if (remap[vi] == rKeep && vi != keep)
                            {
                                float uvDistSq = (uvs[vi] - uvs[keep]).sqrMagnitude;
                                if (uvDistSq < 0.001f)
                                {
                                    triIndices[t][j] = keep;
                                }
                                else
                                {
                                    positions[vi] = positions[keep];
                                    normals[vi] = normals[keep];
                                }
                            }
                        }

                        int ra = remap[triIndices[t][0]];
                        int rb = remap[triIndices[t][1]];
                        int rc = remap[triIndices[t][2]];

                        if (ra == rb || rb == rc || ra == rc)
                        {
                            alive[t] = false;
                            currentTriCount--;
                        }
                    }
                }

                globalStamp++;
                vertStamp[rKeep] = globalStamp;
                
                if (totalTriCount - targetTriCount > 0)
                {
                    data.progress = 1f - (float)(currentTriCount - targetTriCount) / (totalTriCount - targetTriCount);
                }

                if (heapIdx > edgeHeap.Count * 0.8f && currentTriCount > targetTriCount)
                {
                    edgeHeap.Clear();
                    heapIdx = 0;
                    BuildEdgeCandidates(edgeHeap, triIndices, alive, remap, positions, uvs, quadrics,
                        curvature, uvSeamEdges, boundaryVerts, vertStamp, globalStamp);
                    edgeHeap.Sort((a, b) => a.cost.CompareTo(b.cost));
                }
            }

            List<int> finalTriangles = new List<int>();
            for (int t = 0; t < totalTriCount; t++)
            {
                if (!alive[t]) continue;
                finalTriangles.Add(triIndices[t][0]);
                finalTriangles.Add(triIndices[t][1]);
                finalTriangles.Add(triIndices[t][2]);
            }

            HashSet<int> usedVerts = new HashSet<int>(finalTriangles);
            Dictionary<int, int> vertexMap = new Dictionary<int, int>();
            List<Vector3> newPos = new List<Vector3>();
            List<Vector3> newNorm = new List<Vector3>();
            List<Vector2> newUV = new List<Vector2>();
            List<Vector2> newUV2 = hasUV2 ? new List<Vector2>() : null;
            List<Vector2> newUV3 = hasUV3 ? new List<Vector2>() : null;
            List<Vector2> newUV4 = hasUV4 ? new List<Vector2>() : null;
            List<Vector4> newTan = hasTangents ? new List<Vector4>() : null;
            List<Color> newCol = hasColors ? new List<Color>() : null;

            foreach (int vi in usedVerts)
            {
                vertexMap[vi] = newPos.Count;
                newPos.Add(positions[vi]);
                newNorm.Add(normals[vi]);
                newUV.Add(uvs[vi]);
                if (hasUV2) newUV2.Add(uv2s[vi]);
                if (hasUV3) newUV3.Add(uv3s[vi]);
                if (hasUV4) newUV4.Add(uv4s[vi]);
                if (hasTangents) newTan.Add(tangents[vi]);
                if (hasColors) newCol.Add(colors[vi]);
            }

            int[] newTriangles = new int[finalTriangles.Count];
            for (int i = 0; i < finalTriangles.Count; i++)
            {
                newTriangles[i] = vertexMap[finalTriangles[i]];
            }

            data.newPos = newPos.ToArray();
            data.newNorm = newNorm.ToArray();
            data.newUV = newUV.ToArray();
            if (hasUV2) data.newUV2 = newUV2.ToArray();
            if (hasUV3) data.newUV3 = newUV3.ToArray();
            if (hasUV4) data.newUV4 = newUV4.ToArray();
            if (hasTangents) data.newTan = newTan.ToArray();
            if (hasColors) data.newCol = newCol.ToArray();
            data.newTriangles = newTriangles;
        }

        private void BuildEdgeCandidates(List<EdgeCandidate> candidates, int[][] triIndices,
            bool[] alive, int[] remap, Vector3[] positions, Vector2[] uvs, Matrix4x4[] quadrics,
            float[] curvature, HashSet<long> uvSeamEdges, HashSet<int> boundaryVerts,
            int[] vertStamp, int stamp)
        {
            HashSet<long> seen = new HashSet<long>();

            for (int t = 0; t < triIndices.Length; t++)
            {
                if (!alive[t]) continue;

                for (int e = 0; e < 3; e++)
                {
                    int vi0 = triIndices[t][e];
                    int vi1 = triIndices[t][(e + 1) % 3];
                    int r0 = remap[vi0];
                    int r1 = remap[vi1];

                    if (r0 == r1) continue;

                    long edgeKey = r0 < r1 ? ((long)r0 << 32) | (uint)r1 : ((long)r1 << 32) | (uint)r0;
                    if (seen.Contains(edgeKey)) continue;
                    seen.Add(edgeKey);

                    if (uvSeamEdges.Contains(edgeKey)) continue;
                    if (boundaryVerts.Contains(r0) && boundaryVerts.Contains(r1)) continue;

                    Matrix4x4 combinedQ = AddMatrix(quadrics[r0], quadrics[r1]);

                    float cost0 = EvaluateQuadricError(combinedQ, positions[vi0]);
                    float cost1 = EvaluateQuadricError(combinedQ, positions[vi1]);

                    int keepVert, removeVert;
                    float cost;

                    if (cost0 <= cost1)
                    {
                        keepVert = vi0;
                        removeVert = vi1;
                        cost = cost0;
                    }
                    else
                    {
                        keepVert = vi1;
                        removeVert = vi0;
                        cost = cost1;
                    }

                    if (curvature != null)
                    {
                        float curvPenalty = (curvature[r0] + curvature[r1]) * 0.5f;
                        cost *= (1f + curvPenalty * 10f);
                    }

                    float uvDist = (uvs[vi0] - uvs[vi1]).sqrMagnitude;
                    cost *= (1f + uvDist * 100f);

                    candidates.Add(new EdgeCandidate
                    {
                        v0 = keepVert,
                        v1 = removeVert,
                        r0 = remap[keepVert],
                        r1 = remap[removeVert],
                        cost = cost,
                        stamp = stamp
                    });

                    vertStamp[r0] = stamp;
                    vertStamp[r1] = stamp;
                }
            }
        }


        private HashSet<long> FindUVSeamEdges(Vector2[] uvs, int[] triangles, int[] remap)
        {
            HashSet<long> seamEdges = new HashSet<long>();
            Dictionary<long, List<int[]>> edgeUVs = new Dictionary<long, List<int[]>>();

            for (int t = 0; t < triangles.Length; t += 3)
            {
                for (int e = 0; e < 3; e++)
                {
                    int vi0 = triangles[t + e];
                    int vi1 = triangles[t + (e + 1) % 3];
                    int r0 = remap[vi0];
                    int r1 = remap[vi1];

                    if (r0 == r1) continue;

                    long edgeKey = r0 < r1 ? ((long)r0 << 32) | (uint)r1 : ((long)r1 << 32) | (uint)r0;

                    if (!edgeUVs.ContainsKey(edgeKey))
                        edgeUVs[edgeKey] = new List<int[]>();

                    edgeUVs[edgeKey].Add(new int[] { vi0, vi1 });
                }
            }

            foreach (var kvp in edgeUVs)
            {
                var instances = kvp.Value;
                if (instances.Count < 2) continue;

                for (int i = 1; i < instances.Count; i++)
                {
                    int[] e0 = instances[0];
                    int[] ei = instances[i];

                    bool fwdMatch = (uvs[e0[0]] - uvs[ei[0]]).sqrMagnitude > 0.0001f ||
                                    (uvs[e0[1]] - uvs[ei[1]]).sqrMagnitude > 0.0001f;
                    bool revMatch = (uvs[e0[0]] - uvs[ei[1]]).sqrMagnitude > 0.0001f ||
                                    (uvs[e0[1]] - uvs[ei[0]]).sqrMagnitude > 0.0001f;

                    if (fwdMatch && revMatch)
                    {
                        seamEdges.Add(kvp.Key);
                        break;
                    }
                }
            }

            return seamEdges;
        }

        private HashSet<int> FindBoundaryVertices(int[] triangles, int[] remap)
        {
            Dictionary<long, int> edgeCounts = new Dictionary<long, int>();

            for (int t = 0; t < triangles.Length; t += 3)
            {
                for (int e = 0; e < 3; e++)
                {
                    int r0 = remap[triangles[t + e]];
                    int r1 = remap[triangles[t + (e + 1) % 3]];
                    if (r0 == r1) continue;

                    long edgeKey = r0 < r1 ? ((long)r0 << 32) | (uint)r1 : ((long)r1 << 32) | (uint)r0;

                    if (edgeCounts.ContainsKey(edgeKey))
                        edgeCounts[edgeKey]++;
                    else
                        edgeCounts[edgeKey] = 1;
                }
            }

            HashSet<int> boundary = new HashSet<int>();
            foreach (var kvp in edgeCounts)
            {
                if (kvp.Value == 1)
                {
                    boundary.Add((int)(kvp.Key >> 32));
                    boundary.Add((int)(kvp.Key & 0xFFFFFFFF));
                }
            }

            return boundary;
        }

        private float[] ComputeCurvatureWeights(Vector3[] normals, int[] triangles, int[] remap, int vertCount)
        {
            float[] curv = new float[vertCount];

            for (int t = 0; t < triangles.Length; t += 3)
            {
                int[] rv = { remap[triangles[t]], remap[triangles[t + 1]], remap[triangles[t + 2]] };

                for (int i = 0; i < 3; i++)
                {
                    for (int j = i + 1; j < 3; j++)
                    {
                        int a = rv[i];
                        int b = rv[j];
                        if (a < normals.Length && b < normals.Length)
                        {
                            float dot = Vector3.Dot(normals[a], normals[b]);
                            float c = (1f - Mathf.Clamp01(dot)) * 0.5f;
                            curv[a] = Mathf.Max(curv[a], c);
                            curv[b] = Mathf.Max(curv[b], c);
                        }
                    }
                }
            }

            return curv;
        }

        private Matrix4x4 PlaneQuadric(float a, float b, float c, float d)
        {
            Matrix4x4 q = new Matrix4x4();
            q.m00 = a * a; q.m01 = a * b; q.m02 = a * c; q.m03 = a * d;
            q.m10 = b * a; q.m11 = b * b; q.m12 = b * c; q.m13 = b * d;
            q.m20 = c * a; q.m21 = c * b; q.m22 = c * c; q.m23 = c * d;
            q.m30 = d * a; q.m31 = d * b; q.m32 = d * c; q.m33 = d * d;
            return q;
        }

        private Matrix4x4 AddMatrix(Matrix4x4 a, Matrix4x4 b)
        {
            Matrix4x4 result = new Matrix4x4();
            for (int i = 0; i < 16; i++)
            {
                result[i] = a[i] + b[i];
            }
            return result;
        }

        private float EvaluateQuadricError(Matrix4x4 q, Vector3 v)
        {
            float x = v.x, y = v.y, z = v.z;
            return q.m00 * x * x + 2f * q.m01 * x * y + 2f * q.m02 * x * z + 2f * q.m03 * x
                 + q.m11 * y * y + 2f * q.m12 * y * z + 2f * q.m13 * y
                 + q.m22 * z * z + 2f * q.m23 * z
                 + q.m33;
        }


        private Mesh LoadMeshFromPath(string path)
        {
            Mesh directMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (directMesh != null)
            {
                return directMesh;
            }

            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab != null)
            {
                MeshFilter mf = prefab.GetComponentInChildren<MeshFilter>();
                if (mf != null && mf.sharedMesh != null)
                {
                    return mf.sharedMesh;
                }

                SkinnedMeshRenderer smr = prefab.GetComponentInChildren<SkinnedMeshRenderer>();
                if (smr != null && smr.sharedMesh != null)
                {
                    return smr.sharedMesh;
                }
            }

            return null;
        }


        private void AddFromProjectSelection()
        {
            Object[] selectedObjects = Selection.objects;

            foreach (Object obj in selectedObjects)
            {
                string path = AssetDatabase.GetAssetPath(obj);

                if (string.IsNullOrEmpty(path))
                {
                    continue;
                }

                if (AssetDatabase.IsValidFolder(path))
                {
                    AddMeshesFromFolder(path);
                }
                else if (IsMeshPath(path))
                {
                    AddMeshEntry(path);
                }
            }
        }

        private void AddFromFolder()
        {
            string folder = EditorUtility.OpenFolderPanel("Select Mesh Folder", "Assets", "");

            if (string.IsNullOrEmpty(folder))
            {
                return;
            }

            string relativePath = FileUtil.GetProjectRelativePath(folder);

            if (string.IsNullOrEmpty(relativePath))
            {
                EditorUtility.DisplayDialog(
                    "LOD Generator",
                    "Selected folder must be inside the project's Assets directory.",
                    "OK"
                );
                return;
            }

            AddMeshesFromFolder(relativePath);
        }

        private void AddMeshesFromFolder(string folderPath)
        {
            string[] guids = AssetDatabase.FindAssets("t:Mesh t:GameObject", new[] { folderPath });

            foreach (string guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (IsMeshPath(path))
                {
                    AddMeshEntry(path);
                }
            }
        }

        private void AddMeshEntry(string path)
        {
            bool alreadyExists = meshEntries.Any(e => e.assetPath == path);

            if (alreadyExists)
            {
                return;
            }

            Mesh mesh = LoadMeshFromPath(path);

            if (mesh == null)
            {
                return;
            }

            meshEntries.Add(new MeshEntry(path));
        }

        private static bool IsMeshPath(string path)
        {
            string ext = Path.GetExtension(path).ToLowerInvariant();

            switch (ext)
            {
                case ".fbx":
                case ".obj":
                case ".blend":
                case ".dae":
                case ".3ds":
                case ".max":
                case ".ma":
                case ".mb":
                case ".asset":
                case ".prefab":
                    return true;
                default:
                    return false;
            }
        }
    }
}
#endif