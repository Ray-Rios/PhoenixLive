///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Diagnostics;
using System.Linq;
using UnityEngine;
using UnityEngine.Serialization;
using Object = UnityEngine.Object;

#if UNITY_EDITOR
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor;
#endif

namespace SecretDimension
{
    // Credit to Aesthetician Labs
    // Modified from source available here: https://github.com/aestheticianlabs/com.aela.utilities/blob/main/Scripts/SceneField.cs

    /// <summary>
	/// Unity editor-friendly scene reference field.
	/// </summary>
	[System.Serializable]
    public class SceneField
    {
        [SerializeField] private Object sceneAsset;
        [FormerlySerializedAs("sceneName")][SerializeField] private string scenePath = "";

        /// <summary>
        /// The name of the scene.
        /// </summary>
        public string ScenePath => scenePath;

        // makes it work with the existing Unity methods (LoadLevel/LoadScene)
        public static implicit operator string(SceneField sceneField)
        {
            return sceneField?.ScenePath;
        }

        [Conditional("UNITY_EDITOR")]
        public void RefreshScenePath()
        {
#if UNITY_EDITOR
            scenePath = AssetDatabase.GetAssetPath(sceneAsset);
#endif
        }
    }

#if UNITY_EDITOR
    /// <summary>
    /// Provides a <see cref="PropertyDrawer"/> for <see cref="SceneField"/>.
    /// </summary>
    [CustomPropertyDrawer(typeof(SceneField))]
    public class SceneFieldPropertyDrawer : PropertyDrawer
    {
        public override void OnGUI(
            Rect position,
            SerializedProperty property,
            GUIContent label
        )
        {
            float baseWidth = position.width;
            float baseHeight = position.height;

            EditorGUI.BeginProperty(position, GUIContent.none, property);
            var sceneAsset = property.FindPropertyRelative("sceneAsset");
            var scenePath = property.FindPropertyRelative("scenePath");

            position = EditorGUI.PrefixLabel(
                totalPosition: position,
                id: GUIUtility.GetControlID(FocusType.Passive),
                label: label
            );

            if (sceneAsset != null)
            {
                // warn if scene isn't in build settings
                string path = AssetDatabase.GetAssetPath(
                    assetObject: sceneAsset.objectReferenceValue
                );

                EditorGUI.BeginChangeCheck();

                Rect objFieldRect = position;
                objFieldRect.width = baseWidth / 5;

                var value = sceneAsset.objectReferenceValue;
                value = EditorGUI.ObjectField(
                    position: objFieldRect,
                    obj: value,
                    objType: typeof(SceneAsset),
                    allowSceneObjects: false
                );

                var valuePath = value ? AssetDatabase.GetAssetPath(value) : null;

                if (value && (EditorGUI.EndChangeCheck() || valuePath != scenePath.stringValue))
                {
                    sceneAsset.objectReferenceValue = value;
                    scenePath.stringValue = valuePath;
                }

                // name label
                EditorGUI.BeginDisabledGroup(true);
                var style = new GUIStyle(EditorStyles.label);

                // Change text color if we're not in build settings or not addressable
                bool isAddressable = IsAssetAddressable(valuePath);

                bool isInvalidValue = false;

                if (!isAddressable)
                {
                    isInvalidValue = true;
                }
                else if (!EditorBuildSettings.scenes.Any(s => s.path == path) && !isAddressable)
                {
                    isInvalidValue = true;
                }

                if (isInvalidValue)
                {
                    style.normal.textColor = Color.red;
                }
                else
                {
                    style.normal.textColor = Color.green;
                }

                style.normal.background = Texture2D.grayTexture;

                Rect labelRect = new Rect(objFieldRect.position.x - (objFieldRect.width - 20), position.y, baseWidth, baseHeight);

                EditorGUI.LabelField(labelRect, null, scenePath.stringValue, style);
                EditorGUI.EndDisabledGroup();
            }
            EditorGUI.EndProperty();
        }

        private static bool IsAssetAddressable(string assetPath)
        {
            if (assetPath == null)
            {
                return false;
            }

            AddressableAssetSettings settings = AddressableAssetSettingsDefaultObject.Settings;
            AddressableAssetEntry entry = settings.FindAssetEntry(AssetDatabase.AssetPathToGUID(assetPath));
            return entry != null;
        }
    }
#endif
}
