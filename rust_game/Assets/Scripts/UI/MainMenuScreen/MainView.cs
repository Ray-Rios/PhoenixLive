///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the main view of the Main Menu
    ///</summary>
    public class MainView : UIView
    {
        #region Attributes
        // Attributes

        private const string k_PlayButtonViewName = "play-button";
        private const string k_SettingsButtonViewName = "settings-button";
        private const string k_ExitToDesktopButtonViewName = "exit-button";

        private Button m_PlayButton;
        private Button m_SettingsButton;
        private Button m_ExitButton;

        #endregion

        public MainView(VisualElement topElement, ParrotPlayerController playerController) : base(topElement, playerController)
        {
        }

        protected override void SetVisualElements()
        {
            base.SetVisualElements();
            m_PlayButton = m_TopElement.Q<Button>(k_PlayButtonViewName);
            m_SettingsButton = m_TopElement.Q<Button>(k_SettingsButtonViewName);
            m_ExitButton = m_TopElement.Q<Button>(k_ExitToDesktopButtonViewName);
        }

        protected override void RegisterElementCallbacks()
        {
            base.RegisterElementCallbacks();

            if (ParrotAudioController.Instance)
            {
                m_PlayButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_SettingsButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_ExitButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_PlayButton.clicked += OnPlayPressed;
            m_PlayButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_PlayButton.RegisterCallback<FocusEvent>(OnButtonHover);

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
                m_PlayButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_SettingsButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_ExitButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_PlayButton.clicked -= OnPlayPressed;
            m_PlayButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_PlayButton.UnregisterCallback<FocusEvent>(OnButtonHover);

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

            if (m_PlayerController.CurrentInputType == InputType.Gamepad)
            {
                FocusFirstFocusableElement();
            }
        }

        private void OnPlayPressed()
        {
            ParrotAudioController.Instance.PlayButtonSelectionSound();
            MainMenuUIEvents.PlayGamePressed?.Invoke();
        }

        private void OnSettingsPressed()
        {
            ParrotAudioController.Instance.PlayButtonSelectionSound();
            MainMenuUIEvents.SettingsScreenShown?.Invoke();
        }

        private void OnExitPressed()
        {
            ParrotAudioController.Instance.PlayButtonSelectionSound();
            MainMenuUIEvents.QuitPressed?.Invoke();
        }

        protected override VisualElement GetFirstFocusableElement()
        {
            return m_PlayButton;
        }
    }
}
