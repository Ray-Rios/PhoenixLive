///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the loading screen view 
    ///</summary>
    public class LoadingScreenView : UIView
    {
        #region Attributes
        // Attributes
        private ProgressBar m_ProgressBar;
        private const string k_ProgressBarViewName = "loading-progress";
        #endregion

        public LoadingScreenView(VisualElement topElement) : base(topElement)
        {
        }

        protected override void SetVisualElements()
        {
            base.SetVisualElements();
            m_ProgressBar = m_TopElement.Q<ProgressBar>(k_ProgressBarViewName);
        }

        public void SetProgress(float progress)
        {
            m_ProgressBar.value = progress;
        }

        public float GetProgress()
        {
            return m_ProgressBar.value;
        }
    }
}
