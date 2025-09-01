///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the view of the settings screen 
    ///</summary>
    public class SettingsScreenView : UIView
    {
        #region Attributes
        // Attributes
        private const string k_closeButtonViewName = "close-button";
        private const string k_mainVolumeSliderViewName = "main-volume";
        private const string k_musicVolumeSliderViewName = "music-volume";
        private const string k_sfxVolumeSliderViewName = "sfx-volume";
        private const string k_keybindingsButtonViewName = "keybindings-button";

        private Button m_CloseButton;
        private Button m_KeybindingsButton;
        private Slider m_MainVolumeSlider;
        private Slider m_MusicVolumeSlider;
        private Slider m_SFXVolumeSlider;

        #endregion

        public SettingsScreenView(VisualElement topElement, ParrotPlayerController playerController) : base(topElement, playerController)
        {
        }
        protected override void SetVisualElements()
        {
            base.SetVisualElements();
            m_CloseButton = m_TopElement.Q<Button>(k_closeButtonViewName);
            m_KeybindingsButton = m_TopElement.Q<Button>(k_keybindingsButtonViewName);
            m_MainVolumeSlider = m_TopElement.Q<Slider>(k_mainVolumeSliderViewName);
            m_MusicVolumeSlider = m_TopElement.Q<Slider>(k_musicVolumeSliderViewName);
            m_SFXVolumeSlider = m_TopElement.Q<Slider>(k_sfxVolumeSliderViewName);

            // Initialize values 
            m_MainVolumeSlider.value = ParrotAudioController.Instance.GetSavedMainVolume();
            m_MusicVolumeSlider.value = ParrotAudioController.Instance.GetSavedMusicVolume();
            m_SFXVolumeSlider.value = ParrotAudioController.Instance.GetSavedSFXVolume();
        }

        protected override void RegisterElementCallbacks()
        {
            base.RegisterElementCallbacks();

            if (ParrotAudioController.Instance)
            {
                m_CloseButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_KeybindingsButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_CloseButton.clicked += OnClosePressed;
            m_CloseButton.RegisterCallback<MouseOverEvent>(OnButtonHover);

            m_KeybindingsButton.clicked += OnKeyBindingsPressed;
            m_KeybindingsButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_KeybindingsButton.RegisterCallback<FocusEvent>(OnButtonHover);

            m_MainVolumeSlider.RegisterValueChangedCallback(OnMainVolumeChanged);
            m_MusicVolumeSlider.RegisterValueChangedCallback(OnMusicVolumeChanged);
            m_SFXVolumeSlider.RegisterValueChangedCallback(OnSFXVolumeChanged);

            m_MainVolumeSlider.RegisterCallback<MouseOverEvent>(OnSliderHover);
            m_MainVolumeSlider.RegisterCallback<FocusEvent>(OnSliderHover);
            m_MusicVolumeSlider.RegisterCallback<MouseOverEvent>(OnSliderHover);
            m_MusicVolumeSlider.RegisterCallback<FocusEvent>(OnSliderHover);
            m_SFXVolumeSlider.RegisterCallback<MouseOverEvent>(OnSliderHover);
            m_SFXVolumeSlider.RegisterCallback<FocusEvent>(OnSliderHover);
        }

        public override void Dispose()
        {
            base.Dispose();

            if (ParrotAudioController.Instance)
            {
                m_CloseButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
                m_KeybindingsButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_CloseButton.clicked -= OnClosePressed;
            m_CloseButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);

            m_KeybindingsButton.clicked -= OnKeyBindingsPressed;
            m_KeybindingsButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_KeybindingsButton.UnregisterCallback<FocusEvent>(OnButtonHover);

            m_MainVolumeSlider.UnregisterValueChangedCallback(OnMainVolumeChanged);
            m_MusicVolumeSlider.UnregisterValueChangedCallback(OnMusicVolumeChanged);
            m_SFXVolumeSlider.UnregisterValueChangedCallback(OnSFXVolumeChanged);

            m_MainVolumeSlider.UnregisterCallback<MouseOverEvent>(OnSliderHover);
            m_MainVolumeSlider.UnregisterCallback<FocusEvent>(OnSliderHover);
            m_MusicVolumeSlider.UnregisterCallback<MouseOverEvent>(OnSliderHover);
            m_MusicVolumeSlider.UnregisterCallback<FocusEvent>(OnSliderHover);
            m_SFXVolumeSlider.UnregisterCallback<MouseOverEvent>(OnSliderHover);
            m_SFXVolumeSlider.UnregisterCallback<FocusEvent>(OnSliderHover);
        }

        public override void Hide()
        {
            base.Hide();
            m_PlayerController.CancelPressed -= OnClosePressed;
        }

        public override void Show()
        {
            base.Show();

            m_PlayerController.CancelPressed += OnClosePressed;

            if (m_PlayerController.CurrentInputType == InputType.Gamepad)
            {
                FocusFirstFocusableElement();
            }
        }

        protected override VisualElement GetFirstFocusableElement()
        {
            return m_MainVolumeSlider;
        }

        private void OnClosePressed()
        {
            SettingsUIEvents.CloseSettings?.Invoke();
        }

        private void OnKeyBindingsPressed()
        {
            SettingsUIEvents.KeybindingsScreenShown?.Invoke();
        }

        private void OnMainVolumeChanged(ChangeEvent<float> evt)
        {
            ParrotAudioController.Instance.SetMainVolume(evt.newValue);
        }

        private void OnMusicVolumeChanged(ChangeEvent<float> evt)
        {
            ParrotAudioController.Instance.SetMusicVolume(evt.newValue);
        }

        private void OnSFXVolumeChanged(ChangeEvent<float> evt)
        {
            ParrotAudioController.Instance.SetSFXVolume(evt.newValue);
        }

        protected void OnSliderHover(FocusEvent evt)
        {
            if (!m_IsVisible)
            {
                return;
            }

            m_FocusedElement = (VisualElement)evt.currentTarget;
        }

        protected void OnSliderHover(MouseOverEvent evt)
        {
            if (!m_IsVisible)
            {
                return;
            }

            m_FocusedElement = (VisualElement)evt.currentTarget;
        }
    }
}
