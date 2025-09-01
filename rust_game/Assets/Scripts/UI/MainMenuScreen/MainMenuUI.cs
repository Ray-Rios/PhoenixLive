///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Handles main menu behavior driven by UI events 
    ///</summary>
    ///
    [RequireComponent(typeof(UIDocument))]
    public class MainMenuUI : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Tooltip("Key Rebinding Data")]
        [SerializeField]
        private KeyRebindStringData KeyRebindData;

        private UIDocument m_MainMenuDocument;

        private UIView m_CurrentView;

        // List of all UIViews
        List<UIView> m_AllViews = new List<UIView>();

        // VisualTree string IDs for UIViews; each represents one branch of the tree
        const string k_MainViewName = "main-screen";
        const string k_SettingsViewName = "settings-screen-template";
        const string k_KeybindingsViewName = "keybindings-screen-template";

        private MainView m_MainView;
        private SettingsScreenView m_SettingsView;
        private KeybindingsView m_KeybindingsView;

        private ParrotAudioController m_AudioController;

        // The player that owns this UI
        private ParrotPlayerController m_OwningPlayerController;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void OnEnable()
        {
            ValidateComponents();
            SetupViews();
            SubscribeToEvents();
        }

        private void OnDisable()
        {
            UnsubscribeFromEvents();

            foreach (UIView view in m_AllViews)
            {
                view.Dispose();
            }
        }

        #endregion

        #region UI

        private void ValidateComponents()
        {
            m_MainMenuDocument = GetComponent<UIDocument>();
            m_AudioController = ParrotAudioController.Instance;

            m_OwningPlayerController = FindFirstObjectByType<ParrotPlayerController>();

            if (m_OwningPlayerController == null)
            {
                Debug.LogError("Owning player controller is null on MainMenuUI!");
                return;
            }
        }

        private void SubscribeToEvents()
        {
            // Scene management 
            if (!ParrotGameInstance.Instance.GetLogoTrainDisplayed())
            {
                ParrotSceneManager.OnLogoTrainComplete += ShowInitialView;
            }
            else
            {
                ParrotSceneManager.OnSceneTransitionComplete += TransitionComplete;
            }

            // Main Menu events 
            MainMenuUIEvents.MainScreenShown += OnMainScreenShown;
            MainMenuUIEvents.SettingsScreenShown += OnSettingsScreenShown;
            MainMenuUIEvents.PlayGamePressed += OnPlay;
            MainMenuUIEvents.QuitPressed += OnQuit;

            // Settings events 
            SettingsUIEvents.CloseSettings += OnCloseSettings;
            SettingsUIEvents.KeybindingsScreenShown += OnKeybindingsScreenShown;

            // Keybindings events 
            KeybindingsUIEvents.CloseKeybindings += OnCloseKeybindings;
        }

        private void UnsubscribeFromEvents()
        {
            // Scene management 
            ParrotSceneManager.OnLogoTrainComplete -= ShowInitialView;
            ParrotSceneManager.OnSceneTransitionComplete -= TransitionComplete;

            // Main Menu events 
            MainMenuUIEvents.MainScreenShown -= OnMainScreenShown;
            MainMenuUIEvents.SettingsScreenShown -= OnSettingsScreenShown;
            MainMenuUIEvents.PlayGamePressed -= OnPlay;
            MainMenuUIEvents.QuitPressed -= OnQuit;

            // Settings events 
            SettingsUIEvents.CloseSettings -= OnCloseSettings;
            SettingsUIEvents.KeybindingsScreenShown -= OnKeybindingsScreenShown;

            // Keybindings events 
            KeybindingsUIEvents.CloseKeybindings -= OnCloseKeybindings;
        }

        private void SetupViews()
        {
            VisualElement root = m_MainMenuDocument.rootVisualElement;

            // Create full-screen view with branched views: MainView, SettingsView, InfoView, KeybindingsView
            m_MainView = new MainView(root.Q<VisualElement>(k_MainViewName), m_OwningPlayerController); // The main title screen 
            m_SettingsView = new SettingsScreenView(root.Q<VisualElement>(k_SettingsViewName), m_OwningPlayerController); // The settings screen 
            m_KeybindingsView = new KeybindingsView(root.Q<VisualElement>(k_KeybindingsViewName), m_OwningPlayerController, KeyRebindData); // The keybindings screen 

            // Track views in a list for disposal 
            m_AllViews.Add(m_MainView);
            m_AllViews.Add(m_SettingsView);
            m_AllViews.Add(m_KeybindingsView);
        }

        private void TransitionComplete(string scene)
        {
            ShowInitialView();
        }

        private void ShowInitialView()
        {
            // Inform our game instance that we've displayed the logo train at least once this application lifecycle
            if (!ParrotGameInstance.Instance.GetLogoTrainDisplayed())
            {
                ParrotGameInstance.Instance.SetLogoTrainDisplayed();
            }

            ShowView(m_MainView);
        }

        private void ShowView(UIView newView)
        {
            if (m_CurrentView != null)
            {
                m_CurrentView.Hide();
            }

            m_CurrentView = newView;

            // Show the screen and notify any listeners that the menu has updated

            if (m_CurrentView != null)
            {
                m_CurrentView.Show();
                MainMenuUIEvents.CurrentViewChanged?.Invoke(m_CurrentView.GetType().Name);
            }
        }

        private void OnMainScreenShown()
        {
            ShowView(m_MainView);
        }

        private void OnSettingsScreenShown()
        {
            ShowView(m_SettingsView);
        }

        private void OnKeybindingsScreenShown()
        {
            ShowView(m_KeybindingsView);
        }

        private void OnPlay()
        {
            ParrotGameInstance.Instance.GoToNextLevel();
        }

        private void OnQuit()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#else
            Application.Quit(); 
#endif
        }

        private void OnCloseSettings()
        {
            ShowView(m_MainView);
        }

        private void OnCloseKeybindings()
        {
            ShowView(m_SettingsView);
        }

        #endregion
    }
}
