///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the Game Over view
    ///</summary>
    public class GameOverView : UIView
    {
        #region Attributes
        // Attributes
        private const string k_ContinueButtonViewName = "continue-button";
        private const string k_QuitButtonViewName = "quit-button";

        private Button m_ContinueButton;
        private Button m_QuitButton;

        #endregion

        public GameOverView(VisualElement topElement, ParrotPlayerController playerController) : base(topElement, playerController)
        {
        }

        protected override void SetVisualElements()
        {
            base.SetVisualElements();
            m_ContinueButton = m_TopElement.Q<Button>(k_ContinueButtonViewName);
            m_QuitButton = m_TopElement.Q<Button>(k_QuitButtonViewName);
        }

        protected override void RegisterElementCallbacks()
        {
            base.RegisterElementCallbacks();

            if (ParrotAudioController.Instance)
            {
                m_ContinueButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_QuitButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_ContinueButton.clicked += OnContinuePressed;
            m_ContinueButton.RegisterCallback<FocusEvent>(OnButtonHover);
            m_ContinueButton.RegisterCallback<MouseOverEvent>(OnButtonHover);

            m_QuitButton.clicked += OnQuitPressed;
            m_QuitButton.RegisterCallback<FocusEvent>(OnButtonHover);
            m_QuitButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
        }

        public override void Dispose()
        {
            base.Dispose();

            if (ParrotAudioController.Instance)
            {
                m_ContinueButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_QuitButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_ContinueButton.clicked -= OnContinuePressed;
            m_ContinueButton.UnregisterCallback<FocusEvent>(OnButtonHover);
            m_ContinueButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);

            m_QuitButton.clicked -= OnQuitPressed;
            m_QuitButton.UnregisterCallback<FocusEvent>(OnButtonHover);
            m_QuitButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
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
            ParrotGameInstance.Instance.RestartLevel();
        }

        private void OnQuitPressed()
        {
            ParrotGameInstance.Instance.GoToMainMenu();
        }
    }
}
