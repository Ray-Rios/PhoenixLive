///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the view of the pause screen
    ///</summary>
    public class PauseScreenView : UIView
    {
        #region Attributes
        // Attributes
        private const string k_ResumeButtonViewName = "resume-button";
        private const string k_SettingsButtonViewName = "settings-button";
        private const string k_ExitToMainMenuButtonViewName = "exit-button";

        private Button m_ResumeButton;
        private Button m_SettingsButton;
        private Button m_ExitButton;
        #endregion

        public PauseScreenView(VisualElement topElement, ParrotPlayerController playerController) : base(topElement, playerController)
        {
        }

        protected override void SetVisualElements()
        {
            base.SetVisualElements();
            m_ResumeButton = m_TopElement.Q<Button>(k_ResumeButtonViewName);
            m_SettingsButton = m_TopElement.Q<Button>(k_SettingsButtonViewName);
            m_ExitButton = m_TopElement.Q<Button>(k_ExitToMainMenuButtonViewName);
        }

        protected override void RegisterElementCallbacks()
        {
            base.RegisterElementCallbacks();

            if (ParrotAudioController.Instance)
            {
                m_ResumeButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_SettingsButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_ExitButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_ResumeButton.clicked += OnResumePressed;
            m_ResumeButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_ResumeButton.RegisterCallback<FocusEvent>(OnButtonHover);

            m_SettingsButton.clicked += OnSettingsPressed;
            m_SettingsButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_SettingsButton.RegisterCallback<FocusEvent>(OnButtonHover);

            m_ExitButton.clicked += OnExitPressed;
            m_ExitButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_ExitButton.RegisterCallback<FocusEvent>(OnButtonHover);
        }

        public override void Dispose()
        {
            base.Dispose();

            if (ParrotAudioController.Instance)
            {
                m_ResumeButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_SettingsButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_ExitButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_ResumeButton.clicked -= OnResumePressed;
            m_ResumeButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_ResumeButton.UnregisterCallback<FocusEvent>(OnButtonHover);

            m_SettingsButton.clicked -= OnSettingsPressed;
            m_SettingsButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_SettingsButton.UnregisterCallback<FocusEvent>(OnButtonHover);

            m_ExitButton.clicked -= OnExitPressed;
            m_ExitButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_ExitButton.UnregisterCallback<FocusEvent>(OnButtonHover);
        }

        public override void Show()
        {
            base.Show();

            m_PlayerController.CancelPressed += OnResumePressed;

            if (m_PlayerController.CurrentInputType == InputType.Gamepad)
            {
                FocusFirstFocusableElement();
            }
        }

        public override void Hide()
        {
            base.Hide();
            m_PlayerController.CancelPressed -= OnResumePressed;
        }

        private void OnResumePressed()
        {
            PauseScreenUIEvents.ResumeGame?.Invoke();
        }

        private void OnSettingsPressed()
        {
            PauseScreenUIEvents.SettingsScreenShown?.Invoke();
        }

        private void OnExitPressed()
        {
            PauseScreenUIEvents.QuitPressed?.Invoke();
        }

        protected override VisualElement GetFirstFocusableElement()
        {
            return m_ResumeButton;
        }
    }
}
