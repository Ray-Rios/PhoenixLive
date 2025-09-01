///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace SecretDimension
{
    ///<summary>
    /// Toggles on the specified index full screen render feature for the scope of this gameobject/scene
    ///</summary>
    public class FullScreenRenderFeatureToggler : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Tooltip("The render feature index")]
        [SerializeField]
        private int TargetIndex = 0;

        private FullScreenPassRendererFeature m_FullScreenPassRendererFeature;
        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            var renderer = (GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset).GetRenderer(0);
            var property = typeof(ScriptableRenderer).GetProperty("rendererFeatures", BindingFlags.NonPublic | BindingFlags.Instance);

            List<ScriptableRendererFeature> features = property.GetValue(renderer) as List<ScriptableRendererFeature>;

            int indexCount = 0;

            foreach (var feature in features)
            {
                if (feature.GetType() == typeof(FullScreenPassRendererFeature))
                {
                    if (indexCount == TargetIndex)
                    {
                        m_FullScreenPassRendererFeature = feature as FullScreenPassRendererFeature;
                        break;
                    }

                    indexCount++;
                }
            }

            m_FullScreenPassRendererFeature.SetActive(true);

            ParrotSceneManager.OnBeforeTransition += OnBeforeSceneTransition;

#if UNITY_EDITOR
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
#endif
        }

        private void OnBeforeSceneTransition(string currentScene, string nextScene)
        {
            // Turn this setting off before a new scene is loaded
            m_FullScreenPassRendererFeature.SetActive(false);
        }

#if UNITY_EDITOR
        private void OnPlayModeStateChanged(PlayModeStateChange playModeState)
        {
            // If we're alive when PIE ends, we need to reset here because the scene transition won't happen
            if (playModeState == PlayModeStateChange.ExitingPlayMode)
            {
                m_FullScreenPassRendererFeature.SetActive(false);
            }
        }

        private void OnDestroy()
        {
            EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
        }
#endif

        #endregion
    }
}
