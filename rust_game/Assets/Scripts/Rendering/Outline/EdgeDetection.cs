using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace SecretDimension
{
    // Full credit to Alexander Ameye. Modified impelementation based on this technique: https://ameye.dev/notes/edge-detection-outlines/

    public class EdgeDetection : ScriptableRendererFeature
    {
        private class EdgeDetectionPass : ScriptableRenderPass
        {
            private Material material;

            private static readonly int OutlineThicknessProperty = Shader.PropertyToID("_OutlineThickness");
            private static readonly int OutlineColorProperty = Shader.PropertyToID("_OutlineColor");
            private static readonly int DepthThresholdProperty = Shader.PropertyToID("_DepthThreshold");
            private static readonly int NormalThresholdProperty = Shader.PropertyToID("_NormalThreshold");
            private static readonly int LuminanceThresholdProperty = Shader.PropertyToID("_LuminanceThreshold");

            private static readonly int StencilID = Shader.PropertyToID("_StencilID");


            public EdgeDetectionPass()
            {
                profilingSampler = new ProfilingSampler(nameof(EdgeDetectionPass));
            }

            public void Setup(ref EdgeDetectionSettings settings, ref Material edgeDetectionMaterial, ref Color targetColor)
            {
                material = edgeDetectionMaterial;
                renderPassEvent = settings.renderPassEvent;

                material.SetFloat(OutlineThicknessProperty, settings.outlineThickness);
                material.SetColor(OutlineColorProperty, targetColor);
                material.SetFloat(DepthThresholdProperty, settings.depthThreshold);
                material.SetFloat(NormalThresholdProperty, settings.normalThreshold);
                material.SetFloat(LuminanceThresholdProperty, settings.luminanceThreshold);
                material.SetFloat(StencilID, settings.StencilID);
            }

            private class PassData
            {
            }

            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                var resourceData = frameData.Get<UniversalResourceData>();

                using var builder = renderGraph.AddRasterRenderPass<PassData>("Edge Detection", out _);

                builder.SetRenderAttachment(resourceData.activeColorTexture, 0);
                builder.UseAllGlobalTextures(true);
                builder.AllowPassCulling(false);
                builder.SetRenderFunc((PassData _, RasterGraphContext context) => { Blitter.BlitTexture(context.cmd, Vector2.one, material, 0); });
            }
        }

        [Serializable]
        public class EdgeDetectionSettings
        {
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
            [Range(0, 15)] public int outlineThickness = 3;
            public Color outlineColor = Color.black;
            [Range(0, 0.125f)] public float depthThreshold = 0.005f;
            [Range(0, 1)] public float normalThreshold = 0.25f;
            [Range(0, 5)] public float luminanceThreshold = 2.0f;
            [Range(0, 255)] public int StencilID = 1;
        }

        [SerializeField] private EdgeDetectionSettings settings;
        private Material edgeDetectionMaterial;

        public float DefaultEdgeAlpha
        {
            get
            {
                if (settings != null)
                {
                    return settings.outlineColor.a;
                }

                return 1.0f;
            }
        }

        private Color m_TargetEdgeColor;

        private EdgeDetectionPass edgeDetectionPass;

        /// <summary>
        /// Called
        /// - When the Scriptable Renderer Feature loads the first time.
        /// - When you enable or disable the Scriptable Renderer Feature.
        /// - When you change a property in the Inspector window of the Renderer Feature.
        /// </summary>
        public override void Create()
        {
            // Always default to the settings
            m_TargetEdgeColor = settings.outlineColor;
            edgeDetectionPass ??= new EdgeDetectionPass();
        }

        /// <summary>
        /// Called
        /// - Every frame, once for each camera.
        /// </summary>
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // Don't render for some views.
            if (renderingData.cameraData.cameraType == CameraType.Preview
                || renderingData.cameraData.cameraType == CameraType.Reflection
                || UniversalRenderer.IsOffscreenDepthTexture(ref renderingData.cameraData))
                return;

            if (edgeDetectionMaterial == null)
            {
                edgeDetectionMaterial = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/Edge Detection"));
                if (edgeDetectionMaterial == null)
                {
                    Debug.LogWarning("Not all required materials could be created. Edge Detection will not render.");
                    return;
                }
            }

            edgeDetectionPass.ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal | ScriptableRenderPassInput.Color);
            edgeDetectionPass.requiresIntermediateTexture = true;
            edgeDetectionPass.Setup(ref settings, ref edgeDetectionMaterial, ref m_TargetEdgeColor);

            renderer.EnqueuePass(edgeDetectionPass);
        }

        /// <summary>
        /// Clean up resources allocated to the Scriptable Renderer Feature such as materials.
        /// </summary>
        override protected void Dispose(bool disposing)
        {
            edgeDetectionPass = null;
            CoreUtils.Destroy(edgeDetectionMaterial);
        }

        public void SetRuntimeEdgeColorOverride(Color newColor)
        {
            m_TargetEdgeColor = newColor;
        }

        public void ClearRuntimeColorOverride()
        {
            m_TargetEdgeColor = settings.outlineColor;
        }

    }
}