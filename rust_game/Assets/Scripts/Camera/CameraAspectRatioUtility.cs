///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Ensures that the camera always maintains a proper aspect ratio. Letterboxing if required.
    ///</summary>
    [RequireComponent(typeof(Camera))]
    public class CameraAspectRatioUtility : MonoBehaviour
    {
        #region Attributes

        [SerializeField]
        private float DesiredWidth = 16.0f;

        [SerializeField]
        private float DesiredHeight = 9.0f;

        // Attributes
        private Camera m_Camera;

        private Vector2 m_ScreenResolution;

        private float m_AspectRatio;

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            m_Camera = GetComponent<Camera>();
            m_ScreenResolution = new Vector2(Screen.width, Screen.height);
            m_AspectRatio = DesiredWidth / DesiredHeight;
        }

        /// <summary>
        /// Start is called once before the first execution of Update after the MonoBehaviour is created
        /// </summary>
        private void Start()
        {
            Adjust();
        }

        /// <summary>
        /// Update is called once per frame
        /// </summary>
        private void Update()
        {
            if (m_ScreenResolution.x != Screen.width || m_ScreenResolution.y != Screen.height)
            {
                Adjust();
            }
        }
        #endregion

        private void Adjust()
        {
            float windowAspect = (float)Screen.width / (float)Screen.height;
            float scaleHeight = windowAspect / m_AspectRatio;

            if (scaleHeight < 1.0f)
            {
                Rect rect = m_Camera.rect;
                rect.width = 1.0f;
                rect.height = scaleHeight;
                rect.x = 0;
                rect.y = (1.0f - scaleHeight) / 2.0f;

                m_Camera.rect = rect;
            }
            else
            {
                float scaleWidth = 1.0f / scaleHeight;

                Rect rect = m_Camera.rect;
                rect.width = scaleWidth;
                rect.height = 1.0f;
                rect.x = (1.0f - scaleWidth) / 2.0f;
                rect.y = 0;

                m_Camera.rect = rect;
            }
        }
    }
}
