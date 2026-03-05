#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace RnDTools
{
    public sealed class TextureBulkEditor : EditorWindow
    {

        private class TextureEntry
        {
            public string assetPath;
            public string fileName;
            public string infoText;
            public bool selected;
            public Texture cachedIcon;

            public TextureEntry(string path)
            {
                assetPath = path;
                fileName = Path.GetFileName(path);
                selected = true;
                cachedIcon = AssetDatabase.GetCachedIcon(path);
                CacheInfoText();
            }

            public void CacheInfoText()
            {
                TextureImporter imp = AssetImporter.GetAtPath(assetPath) as TextureImporter;
                if (imp != null)
                {
                    infoText = $"{imp.textureType}  |  Max:{imp.maxTextureSize}";
                }
                else
                {
                    infoText = assetPath;
                }
            }
        }

        private class PlatformOverride
        {
            public string platformName;
            public string displayName;
            public bool enabled;
            public int maxSize;
            public TextureImporterFormat format;
            public int compressionQuality;

            public PlatformOverride(string name, string display)
            {
                platformName = name;
                displayName = display;
                enabled = false;
                maxSize = 2048;
                format = TextureImporterFormat.Automatic;
                compressionQuality = 50;
            }
        }


        private static readonly int[] MaxSizeValues = { 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384 };
        private static readonly string[] MaxSizeLabels = { "32", "64", "128", "256", "512", "1024", "2048", "4096", "8192", "16384" };

        private const float THUMBNAIL_SIZE = 48f;
        private const float ROW_HEIGHT = 52f;
        private const float SECTION_SPACING = 8f;


        private List<TextureEntry> textureEntries = new List<TextureEntry>();

        private bool overrideTextureType;
        private bool overrideSRGB;
        private bool overrideAlphaSource;
        private bool overrideAlphaIsTransparency;
        private bool overrideMaxSize;
        private bool overrideCompression;
        private bool overrideFilterMode;
        private bool overrideWrapMode;
        private bool overrideMipMaps;
        private bool overrideReadWrite;
        private bool overrideStreamingMips;

        private TextureImporterType textureType = TextureImporterType.Default;
        private bool sRGB = true;
        private TextureImporterAlphaSource alphaSource = TextureImporterAlphaSource.FromInput;
        private bool alphaIsTransparency = true;
        private int maxSize = 2048;
        private TextureImporterCompression compression = TextureImporterCompression.Compressed;
        private FilterMode filterMode = FilterMode.Bilinear;
        private TextureWrapMode wrapMode = TextureWrapMode.Repeat;
        private bool generateMipMaps = true;
        private bool readWriteEnabled;
        private bool streamingMipmaps;

        private List<PlatformOverride> platformOverrides = new List<PlatformOverride>();

        private Vector2 textureListScroll;
        private Vector2 mainScroll;

        private bool showOverrideSettings = true;
        private bool showPlatformOverrides;
        private bool performanceMode;


        [MenuItem("Tools/Texture Bulk Editor")]
        private static void Open()
        {
            var window = GetWindow<TextureBulkEditor>("Texture Bulk Editor");
            window.minSize = new Vector2(420, 500);
        }


        private void OnEnable()
        {
            InitializePlatformOverrides();
        }

        private void InitializePlatformOverrides()
        {
            platformOverrides = new List<PlatformOverride>
            {
                new PlatformOverride("Standalone", "PC / Mac / Linux"),
                new PlatformOverride("Android", "Android"),
                new PlatformOverride("iPhone", "iOS"),
                new PlatformOverride("Switch", "Nintendo Switch"),
                new PlatformOverride("PS4", "PlayStation 4"),
                new PlatformOverride("PS5", "PlayStation 5"),
                new PlatformOverride("XboxOne", "Xbox One"),
                new PlatformOverride("GameCoreScarlett", "Xbox Series X|S"),
                new PlatformOverride("WebGL", "WebGL"),
            };
        }


        private void OnGUI()
        {
            mainScroll = EditorGUILayout.BeginScrollView(mainScroll);

            DrawHeader();
            DrawTextureAddButtons();
            DrawDragDropArea();
            DrawTextureList();
            DrawSelectionControls();
            DrawOverrideSettings();
            DrawPlatformOverrides();
            DrawApplyButton();

            EditorGUILayout.EndScrollView();
        }


        private void DrawHeader()
        {
            EditorGUILayout.Space(SECTION_SPACING);
            EditorGUILayout.LabelField("Texture Bulk Editor", EditorStyles.boldLabel);
            EditorGUILayout.Space(4);

            int selectedCount = textureEntries.Count(e => e.selected);
            EditorGUILayout.LabelField(
                $"{textureEntries.Count} texture(s) loaded, {selectedCount} selected",
                EditorStyles.miniLabel
            );

            performanceMode = EditorGUILayout.Toggle("Performance Mode (Hide Previews)", performanceMode);
            EditorGUILayout.Space(4);
        }


        private void DrawTextureAddButtons()
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
                textureEntries.Clear();
            }

            EditorGUILayout.EndHorizontal();
        }


        private void DrawDragDropArea()
        {
            EditorGUILayout.Space(2);

            Rect dropRect = GUILayoutUtility.GetRect(0, 40, GUILayout.ExpandWidth(true));
            GUI.Box(dropRect, "Drag & Drop Textures or Folders Here", EditorStyles.helpBox);

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
                    AddTexturesFromFolder(path);
                }
                else if (IsTexturePath(path))
                {
                    AddTextureEntry(path);
                }
            }

            foreach (Object obj in objects)
            {
                if (obj is Texture2D)
                {
                    string assetPath = AssetDatabase.GetAssetPath(obj);
                    if (!string.IsNullOrEmpty(assetPath))
                    {
                        AddTextureEntry(assetPath);
                    }
                }
            }
        }


        private void DrawTextureList()
        {
            if (textureEntries.Count == 0)
            {
                return;
            }

            EditorGUILayout.Space(4);
            EditorGUILayout.LabelField("Textures", EditorStyles.boldLabel);

            float listHeight = Mathf.Min(textureEntries.Count * ROW_HEIGHT, 300f);
            textureListScroll = EditorGUILayout.BeginScrollView(
                textureListScroll,
                GUILayout.Height(listHeight)
            );

            for (int i = 0; i < textureEntries.Count; i++)
            {
                DrawTextureRow(textureEntries[i], i);
            }

            EditorGUILayout.EndScrollView();
        }

        private void DrawTextureRow(TextureEntry entry, int index)
        {
            EditorGUILayout.BeginHorizontal(EditorStyles.helpBox, GUILayout.Height(ROW_HEIGHT));

            entry.selected = EditorGUILayout.Toggle(entry.selected, GUILayout.Width(18));

            if (!performanceMode)
            {
                Rect thumbRect = GUILayoutUtility.GetRect(THUMBNAIL_SIZE, THUMBNAIL_SIZE,
                    GUILayout.Width(THUMBNAIL_SIZE), GUILayout.Height(THUMBNAIL_SIZE));

                if (entry.cachedIcon != null)
                {
                    GUI.DrawTexture(thumbRect, entry.cachedIcon, ScaleMode.ScaleToFit);
                }
            }

            EditorGUILayout.BeginVertical();
            GUILayout.FlexibleSpace();

            EditorGUILayout.LabelField(entry.fileName, EditorStyles.boldLabel);
            EditorGUILayout.LabelField(entry.infoText, EditorStyles.miniLabel);

            GUILayout.FlexibleSpace();
            EditorGUILayout.EndVertical();

            GUILayout.FlexibleSpace();

            if (GUILayout.Button("✕", GUILayout.Width(22), GUILayout.Height(22)))
            {
                textureEntries.RemoveAt(index);
                GUIUtility.ExitGUI();
            }

            EditorGUILayout.EndHorizontal();
        }


        private void DrawSelectionControls()
        {
            if (textureEntries.Count == 0)
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
                textureEntries.RemoveAll(e => !e.selected);
            }

            if (GUILayout.Button("Remove Checked", EditorStyles.miniButtonRight))
            {
                textureEntries.RemoveAll(e => e.selected);
            }

            EditorGUILayout.EndHorizontal();
        }

        private void SetAllSelected(bool value)
        {
            foreach (var entry in textureEntries)
            {
                entry.selected = value;
            }
        }


        private void DrawOverrideSettings()
        {
            EditorGUILayout.Space(SECTION_SPACING);
            showOverrideSettings = EditorGUILayout.Foldout(showOverrideSettings, "Override Settings", true, EditorStyles.foldoutHeader);

            if (!showOverrideSettings)
            {
                return;
            }

            EditorGUI.indentLevel++;

            EditorGUILayout.HelpBox(
                "Only settings with the checkbox enabled will be applied. " +
                "Unchecked settings will remain unchanged on the textures.",
                MessageType.Info
            );

            EditorGUILayout.Space(4);

            DrawOverrideRow(
                ref overrideTextureType,
                "Texture Type",
                () => { textureType = (TextureImporterType)EditorGUILayout.EnumPopup(textureType); }
            );

            DrawOverrideRow(
                ref overrideSRGB,
                "sRGB (Color Texture)",
                () => { sRGB = EditorGUILayout.Toggle(sRGB); }
            );

            DrawOverrideRow(
                ref overrideAlphaSource,
                "Alpha Source",
                () => { alphaSource = (TextureImporterAlphaSource)EditorGUILayout.EnumPopup(alphaSource); }
            );

            DrawOverrideRow(
                ref overrideAlphaIsTransparency,
                "Alpha Is Transparency",
                () => { alphaIsTransparency = EditorGUILayout.Toggle(alphaIsTransparency); }
            );

            DrawOverrideRow(
                ref overrideMaxSize,
                "Max Size",
                () => { maxSize = EditorGUILayout.IntPopup(maxSize, MaxSizeLabels, MaxSizeValues); }
            );

            DrawOverrideRow(
                ref overrideCompression,
                "Compression",
                () => { compression = (TextureImporterCompression)EditorGUILayout.EnumPopup(compression); }
            );

            DrawOverrideRow(
                ref overrideFilterMode,
                "Filter Mode",
                () => { filterMode = (FilterMode)EditorGUILayout.EnumPopup(filterMode); }
            );

            DrawOverrideRow(
                ref overrideWrapMode,
                "Wrap Mode",
                () => { wrapMode = (TextureWrapMode)EditorGUILayout.EnumPopup(wrapMode); }
            );

            DrawOverrideRow(
                ref overrideMipMaps,
                "Generate Mip Maps",
                () => { generateMipMaps = EditorGUILayout.Toggle(generateMipMaps); }
            );

            DrawOverrideRow(
                ref overrideReadWrite,
                "Read/Write Enabled",
                () => { readWriteEnabled = EditorGUILayout.Toggle(readWriteEnabled); }
            );

            DrawOverrideRow(
                ref overrideStreamingMips,
                "Streaming Mipmaps",
                () => { streamingMipmaps = EditorGUILayout.Toggle(streamingMipmaps); }
            );

            EditorGUI.indentLevel--;
        }

        private void DrawOverrideRow(ref bool toggle, string label, System.Action drawControl)
        {
            EditorGUILayout.BeginHorizontal();

            toggle = EditorGUILayout.Toggle(toggle, GUILayout.Width(18));

            EditorGUI.BeginDisabledGroup(!toggle);
            EditorGUILayout.LabelField(label, GUILayout.Width(160));
            drawControl();
            EditorGUI.EndDisabledGroup();

            EditorGUILayout.EndHorizontal();
        }


        private void DrawPlatformOverrides()
        {
            EditorGUILayout.Space(SECTION_SPACING);
            showPlatformOverrides = EditorGUILayout.Foldout(showPlatformOverrides, "Platform Overrides", true, EditorStyles.foldoutHeader);

            if (!showPlatformOverrides)
            {
                return;
            }

            EditorGUI.indentLevel++;

            EditorGUILayout.HelpBox(
                "Enable a platform to set specific import settings for that build target. " +
                "Disabled platforms will keep their current settings.",
                MessageType.Info
            );

            EditorGUILayout.Space(4);

            foreach (var platform in platformOverrides)
            {
                DrawPlatformRow(platform);
            }

            EditorGUI.indentLevel--;
        }

        private void DrawPlatformRow(PlatformOverride platform)
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);

            EditorGUILayout.BeginHorizontal();
            platform.enabled = EditorGUILayout.ToggleLeft(platform.displayName, platform.enabled, EditorStyles.boldLabel);
            EditorGUILayout.EndHorizontal();

            if (platform.enabled)
            {
                EditorGUI.indentLevel++;

                platform.maxSize = EditorGUILayout.IntPopup(
                    "Max Size",
                    platform.maxSize,
                    MaxSizeLabels,
                    MaxSizeValues
                );

                platform.format = (TextureImporterFormat)EditorGUILayout.EnumPopup(
                    "Format",
                    platform.format
                );

                platform.compressionQuality = EditorGUILayout.IntSlider(
                    "Compressor Quality",
                    platform.compressionQuality,
                    0,
                    100
                );

                EditorGUI.indentLevel--;
            }

            EditorGUILayout.EndVertical();
        }


        private void DrawApplyButton()
        {
            EditorGUILayout.Space(SECTION_SPACING);

            int selectedCount = textureEntries.Count(e => e.selected);
            bool hasOverrides = HasAnyOverrideEnabled();

            EditorGUI.BeginDisabledGroup(selectedCount == 0 || !hasOverrides);

            if (GUILayout.Button($"Apply to {selectedCount} Selected Texture(s)", GUILayout.Height(36)))
            {
                ApplySettings();
            }

            EditorGUI.EndDisabledGroup();

            if (selectedCount == 0 && textureEntries.Count > 0)
            {
                EditorGUILayout.HelpBox("No textures selected. Check the boxes next to the textures you want to modify.", MessageType.Warning);
            }
            else if (!hasOverrides && selectedCount > 0)
            {
                EditorGUILayout.HelpBox("No override settings enabled. Enable at least one setting or platform override to apply.", MessageType.Warning);
            }

            EditorGUILayout.Space(SECTION_SPACING);
        }

        private bool HasAnyOverrideEnabled()
        {
            if (overrideTextureType || overrideSRGB || overrideAlphaSource ||
                overrideAlphaIsTransparency || overrideMaxSize || overrideCompression ||
                overrideFilterMode || overrideWrapMode || overrideMipMaps ||
                overrideReadWrite || overrideStreamingMips)
            {
                return true;
            }

            foreach (var platform in platformOverrides)
            {
                if (platform.enabled)
                {
                    return true;
                }
            }

            return false;
        }


        private void ApplySettings()
        {
            var selected = textureEntries.Where(e => e.selected).ToList();

            if (selected.Count == 0)
            {
                EditorUtility.DisplayDialog("Texture Bulk Editor", "No textures selected.", "OK");
                return;
            }

            bool confirm = EditorUtility.DisplayDialog(
                "Texture Bulk Editor",
                $"Apply override settings to {selected.Count} texture(s)?\n\nThis action supports Undo.",
                "Apply",
                "Cancel"
            );

            if (!confirm)
            {
                return;
            }

            int processed = 0;
            int failed = 0;

            try
            {
                AssetDatabase.StartAssetEditing();

                for (int i = 0; i < selected.Count; i++)
                {
                    bool cancelled = EditorUtility.DisplayCancelableProgressBar(
                        "Texture Bulk Editor",
                        $"Processing {selected[i].assetPath} ({i + 1}/{selected.Count})",
                        (float)(i + 1) / selected.Count
                    );

                    if (cancelled)
                    {
                        Debug.Log("[TextureBulkEditor] Operation cancelled by user.");
                        break;
                    }

                    bool success = ApplyToTexture(selected[i].assetPath);

                    if (success)
                    {
                        processed++;
                    }
                    else
                    {
                        failed++;
                    }
                }
            }
            finally
            {
                AssetDatabase.StopAssetEditing();
                EditorUtility.ClearProgressBar();
            }

            AssetDatabase.Refresh();

            foreach (var entry in selected)
            {
                entry.CacheInfoText();
            }

            Debug.Log($"[TextureBulkEditor] Done. {processed} texture(s) updated, {failed} failed.");
        }

        private bool ApplyToTexture(string assetPath)
        {
            TextureImporter importer = GetImporter(assetPath);

            if (importer == null)
            {
                Debug.LogWarning($"[TextureBulkEditor] Could not get TextureImporter for: {assetPath}");
                return false;
            }

            Undo.RecordObject(importer, "Texture Bulk Editor");

            if (overrideTextureType)
            {
                importer.textureType = textureType;
            }

            if (overrideSRGB)
            {
                importer.sRGBTexture = sRGB;
            }

            if (overrideAlphaSource)
            {
                importer.alphaSource = alphaSource;
            }

            if (overrideAlphaIsTransparency)
            {
                importer.alphaIsTransparency = alphaIsTransparency;
            }

            if (overrideMaxSize)
            {
                importer.maxTextureSize = maxSize;
            }

            if (overrideCompression)
            {
                importer.textureCompression = compression;
            }

            if (overrideFilterMode)
            {
                importer.filterMode = filterMode;
            }

            if (overrideWrapMode)
            {
                importer.wrapMode = wrapMode;
            }

            if (overrideMipMaps)
            {
                importer.mipmapEnabled = generateMipMaps;
            }

            if (overrideReadWrite)
            {
                importer.isReadable = readWriteEnabled;
            }

            if (overrideStreamingMips)
            {
                importer.streamingMipmaps = streamingMipmaps;
            }

            foreach (var platform in platformOverrides)
            {
                TextureImporterPlatformSettings platformSettings = importer.GetPlatformTextureSettings(platform.platformName);

                if (platform.enabled)
                {
                    platformSettings.overridden = true;
                    platformSettings.maxTextureSize = platform.maxSize;
                    platformSettings.format = platform.format;
                    platformSettings.compressionQuality = platform.compressionQuality;
                }
                else
                {
                    platformSettings.overridden = false;
                }

                importer.SetPlatformTextureSettings(platformSettings);
            }

            importer.SaveAndReimport();
            return true;
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
                    AddTexturesFromFolder(path);
                }
                else if (IsTexturePath(path))
                {
                    AddTextureEntry(path);
                }
            }
        }

        private void AddFromFolder()
        {
            string folder = EditorUtility.OpenFolderPanel("Select Texture Folder", "Assets", "");

            if (string.IsNullOrEmpty(folder))
            {
                return;
            }

            string relativePath = FileUtil.GetProjectRelativePath(folder);

            if (string.IsNullOrEmpty(relativePath))
            {
                EditorUtility.DisplayDialog(
                    "Texture Bulk Editor",
                    "Selected folder must be inside the project's Assets directory.",
                    "OK"
                );
                return;
            }

            AddTexturesFromFolder(relativePath);
        }

        private void AddTexturesFromFolder(string folderPath)
        {
            string[] guids = AssetDatabase.FindAssets("t:Texture2D", new[] { folderPath });

            foreach (string guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                AddTextureEntry(path);
            }
        }

        private void AddTextureEntry(string path)
        {
            bool alreadyExists = textureEntries.Any(e => e.assetPath == path);

            if (alreadyExists)
            {
                return;
            }

            TextureImporter importer = GetImporter(path);

            if (importer == null)
            {
                return;
            }

            textureEntries.Add(new TextureEntry(path));
        }

        private static bool IsTexturePath(string path)
        {
            string ext = Path.GetExtension(path).ToLowerInvariant();

            switch (ext)
            {
                case ".png":
                case ".jpg":
                case ".jpeg":
                case ".tga":
                case ".psd":
                case ".tiff":
                case ".tif":
                case ".gif":
                case ".bmp":
                case ".exr":
                case ".hdr":
                    return true;
                default:
                    return false;
            }
        }

        private static TextureImporter GetImporter(string assetPath)
        {
            return AssetImporter.GetAtPath(assetPath) as TextureImporter;
        }
    }
}
#endif
