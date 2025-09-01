///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    // Modified from Unity Samples: https://docs.unity3d.com/6000.0/Documentation/Manual/UIE-create-aspect-ratios-custom-control.html

    ///<summary>
    /// Visual Element which adjusts children to stay within aspect ratio bounds 
    ///</summary>
    [UxmlElement]
    public partial class AspectRatioContainer : VisualElement
    {
        // The ratio of width.
        [UxmlAttribute("width")]
        public int RatioWidth
        {
            get => m_RatioWidth;
            set
            {
                m_RatioWidth = value;
                UpdateAspect();
            }
        }

        // The ratio of height.
        [UxmlAttribute("height")]
        public int RatioHeight
        {
            get => m_RatioHeight;
            set
            {
                m_RatioHeight = value;
                UpdateAspect();
            }
        }

        // Backing fields for RatioWidth and RatioHeight with default aspect ratio of 16:9.
        int m_RatioWidth = 16;
        int m_RatioHeight = 9;

        public AspectRatioContainer()
        {
            RegisterCallback<AttachToPanelEvent>(OnAttachToPanel);
        }

        private void OnAttachToPanel(AttachToPanelEvent e)
        {
            UnregisterCallback<AttachToPanelEvent>(OnAttachToPanel);
            RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
        }

        private void OnGeometryChanged(GeometryChangedEvent e)
        {
            UpdateAspect();
        }

        /// <summary>
        /// Clears all padding on the element.
        /// </summary>
        private void ClearPadding()
        {
            style.paddingLeft = 0;
            style.paddingRight = 0;
            style.paddingBottom = 0;
            style.paddingTop = 0;
        }

        // Update the padding.
        private void UpdateAspect()
        {
            // The desired aspect ratio
            var designRatio = (float)RatioWidth / RatioHeight;

            // The current aspect ratio
            var currRatio = resolvedStyle.width / resolvedStyle.height;

            // Determine the difference between the current ratio and the desired ratio.
            var diff = currRatio - designRatio;

            // Define a small threshold to account for floating-point inaccuracies.
            const float epsilon = 0.01f;

            if (RatioWidth <= 0.0f || RatioHeight <= 0.0f)
            {
                ClearPadding();
                Debug.LogError($"[AspectRatio] Invalid width:{RatioWidth} or height:{RatioHeight}");
                return;
            }

            // Check that resolved width and height are valid.
            if (float.IsNaN(resolvedStyle.width) || float.IsNaN(resolvedStyle.height))
            {
                return;
            }

            // If the element is wider than the desired aspect ratio.
            if (diff > epsilon)
            {
                var w = (resolvedStyle.width - (resolvedStyle.height * designRatio)) * 0.5f;
                style.paddingLeft = w;
                style.paddingRight = w;
                style.paddingTop = 0;
                style.paddingBottom = 0;
            }
            // If the element is taller than the desired aspect ratio.
            else if (diff < -epsilon)
            {
                var h = (resolvedStyle.height - (resolvedStyle.width * (1 / designRatio))) * 0.5f;
                style.paddingLeft = 0;
                style.paddingRight = 0;
                style.paddingTop = h;
                style.paddingBottom = h;
            }
            else
            {
                // The current aspect ratio is close enough; clear any padding.
                ClearPadding();
            }
        }
    }
}
