///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the Level Complete view 
    ///</summary>
    public class VictoryScreenView : UIView
    {
        #region Attributes
        // Attributes
        private const string k_LevelCompleteTextViewName = "level-complete-text";
        private const string k_ContinueButtonViewName = "continue-button";

        private Button m_ContinueButton;
        private Label m_CompletionTextLabel;

        #endregion

        public VictoryScreenView(VisualElement topElement, ParrotPlayerController playerController) : base(topElement, playerController)
        {
        }

        protected override void SetVisualElements()
        {
            base.SetVisualElements();
            m_CompletionTextLabel = m_TopElement.Q<Label>(k_LevelCompleteTextViewName);
            m_ContinueButton = m_TopElement.Q<Button>(k_ContinueButtonViewName);
        }

        protected override void RegisterElementCallbacks()
        {
            base.RegisterElementCallbacks();

            if (ParrotAudioController.Instance)
            {
                m_ContinueButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_ContinueButton.clicked += OnContinuePressed;
            m_ContinueButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_ContinueButton.RegisterCallback<FocusEvent>(OnButtonHover);
        }

        public override void Dispose()
        {
            base.Dispose();

            if (ParrotAudioController.Instance)
            {
                m_ContinueButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_ContinueButton.clicked -= OnContinuePressed;
            m_ContinueButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_ContinueButton.UnregisterCallback<FocusEvent>(OnButtonHover);
        }

        public override void Show()
        {
            base.Show();

            if (m_PlayerController.CurrentInputType == InputType.Gamepad)
            {
                FocusFirstFocusableElement();
            }
        }

        protected override VisualElement GetFirstFocusableElement()
        {
            return m_ContinueButton;
        }

        private void OnContinuePressed()
        {
            ParrotGameInstance.Instance.GoToNextLevel();
        }

        public void UpdateFinishTime(float time)
        {
            int minutes = Mathf.FloorToInt(time / 60.0f);
            int seconds = Mathf.FloorToInt(time - minutes * 60.0f);
            string formattedTime = string.Format("{0:0}:{1:00}", minutes, seconds);
            m_CompletionTextLabel.text = "Completed in " + formattedTime;
        }
    }
}
