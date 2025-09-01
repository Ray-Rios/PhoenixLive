///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace SecretDimension
{
    ///<summary>
    /// Changes the outline color on the indexed post process effect
    ///</summary>
    public class OutlineColorChanger : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Tooltip("The render feature index")]
        [SerializeField]
        private int TargetIndex = 0;

        private EdgeDetection m_EdgeDetectionFeature;

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
                if (feature.GetType() == typeof(EdgeDetection))
                {
                    if (indexCount == TargetIndex)
                    {
                        m_EdgeDetectionFeature = feature as EdgeDetection;
                        break;
                    }

                    indexCount++;
                }
            }
        }

        void OnDestroy()
        {
            if (m_EdgeDetectionFeature != null)
            {
                m_EdgeDetectionFeature.ClearRuntimeColorOverride();
            }
        }

        #endregion

        public void ApplyOutlineOverride(Color TargetColor)
        {
            float a = m_EdgeDetectionFeature.DefaultEdgeAlpha;
            Color newColor = TargetColor;
            newColor.a = a;
            m_EdgeDetectionFeature.SetRuntimeEdgeColorOverride(newColor);
        }

        public void ClearOutlineOverride()
        {
            m_EdgeDetectionFeature.ClearRuntimeColorOverride();
        }
    }
}
