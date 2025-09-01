///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Updates the HUD view from world events. 
    /// Note that GameplayUI should have all prerequisite scenes loaded by the time this Monobehaviour is created. 
    ///</summary>
    public class GameplayHUD : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Header("Runtime UI Templates")]
        [Tooltip("The UI template to use when representing a hitpoint on the HUD at runtime")]
        [SerializeField]
        private VisualTreeAsset HitpointAsset;

        [Tooltip("Key Rebinding Data")]
        [SerializeField]
        private KeyRebindStringData KeyRebindData;

        private UIDocument m_GameplayHUDDocument;

        private UIView m_CurrentView;

        // List of all UIViews
        List<UIView> m_AllViews = new List<UIView>();

        // VisualTree string IDs for UIViews; each represents one branch of the tree
        const string k_HUDViewName = "game-hud";
        const string k_PauseViewName = "pause-screen-template";
        const string k_SettingsScreenViewName = "settings-screen-template";
        const string k_KeybindingsScreenViewName = "keybindings-screen-template";
        const string k_GameOverScreenViewName = "game-over-screen-template";
        const string k_VictoryScreenViewName = "victory-screen-template";

        // The player that owns this UI 
        private ParrotPlayerController m_OwningPlayerController;

        // The current game state 
        private ParrotGameState m_GameState;

        // The audio controller for the game 
        private ParrotAudioController m_AudioController;

        private GameplayView m_GameplayHUDView;
        private PauseScreenView m_PauseView;
        private SettingsScreenView m_SettingsView;
        private KeybindingsView m_KeybindingsView;
        private GameOverView m_GameOverView;
        private VictoryScreenView m_VictoryView;

        // When true, the game timer will update on the UI
        private bool m_ShouldUpdateTimer;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void OnEnable()
        {
            m_GameplayHUDDocument = GetComponent<UIDocument>();
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

        // Called every frame
        private void Update()
        {
            UpdateGameTimer();
        }

        #endregion

        #region UI

        private void SceneTransitionComplete(string scene)
        {
            ShowInitialView();
        }

        private void ValidateComponents()
        {
            ParrotGameMode parrotGameMode = FindFirstObjectByType<ParrotGameMode>();

            if (parrotGameMode == null)
            {
                Debug.LogError("Could not find ParrotGameMode in GameplayHUD!");
                return;
            }

            m_OwningPlayerController = parrotGameMode.PlayerController;

            if (m_OwningPlayerController == null)
            {
                Debug.LogError("Player controller from ParrotGameMode is null! No controller to own GameHUD!");
                return;
            }

            m_GameState = m_OwningPlayerController.ParrotGameState;

            if (m_GameState == null)
            {
                Debug.LogError("Could not get Game State from player during ValidateComponents in GameHUD!");
                return;
            }

            if (m_GameState.CurrentLevelStatate == ELevelState.Running)
            {
                m_ShouldUpdateTimer = true;
            }

            m_AudioController = ParrotAudioController.Instance;
        }

        private void SubscribeToEvents()
        {
            // Parrot Scene Manager
            ParrotSceneManager.OnSceneTransitionComplete += SceneTransitionComplete;

            // Gameplay events
            GameplayEvents.LevelStateChanged += LevelStateChanged;
            GameplayEvents.PauseGame += PauseGame;
            GameplayEvents.GameOver += ShowGameOver;
            GameplayEvents.Victory += ShowVictory;

            // Pause Screen
            PauseScreenUIEvents.ResumeGame += ResumeGame;
            PauseScreenUIEvents.SettingsScreenShown += ShowSettings;
            PauseScreenUIEvents.QuitPressed += ExitToMainMenu;

            // Settings events 
            SettingsUIEvents.CloseSettings += OnCloseSettings;
            SettingsUIEvents.KeybindingsScreenShown += OnKeybindingsScreenShown;

            // Keybindings events 
            KeybindingsUIEvents.CloseKeybindings += OnCloseKeybindings;
        }

        private void UnsubscribeFromEvents()
        {
            // Parrot Scene Manager 
            ParrotSceneManager.OnSceneTransitionComplete -= SceneTransitionComplete;

            // Gameplay events
            GameplayEvents.LevelStateChanged -= LevelStateChanged;
            GameplayEvents.PauseGame -= PauseGame;
            GameplayEvents.GameOver -= ShowGameOver;
            GameplayEvents.Victory -= ShowVictory;

            // Pause Screen
            PauseScreenUIEvents.ResumeGame -= ResumeGame;
            PauseScreenUIEvents.SettingsScreenShown -= ShowSettings;
            PauseScreenUIEvents.QuitPressed -= ExitToMainMenu;

            // Settings events 
            SettingsUIEvents.CloseSettings -= OnCloseSettings;
            SettingsUIEvents.KeybindingsScreenShown -= OnKeybindingsScreenShown;

            // Keybindings events 
            KeybindingsUIEvents.CloseKeybindings -= OnCloseKeybindings;
        }

        private void SetupViews()
        {
            VisualElement root = m_GameplayHUDDocument.rootVisualElement;

            // Create full-screen view with branched views
            m_GameplayHUDView = new GameplayView(root.Q<VisualElement>(k_HUDViewName), m_OwningPlayerController, HitpointAsset);
            m_PauseView = new PauseScreenView(root.Q<VisualElement>(k_PauseViewName), m_OwningPlayerController);
            m_SettingsView = new SettingsScreenView(root.Q<VisualElement>(k_SettingsScreenViewName), m_OwningPlayerController);
            m_KeybindingsView = new KeybindingsView(root.Q<VisualElement>(k_KeybindingsScreenViewName), m_OwningPlayerController, KeyRebindData);
            m_GameOverView = new GameOverView(root.Q<VisualElement>(k_GameOverScreenViewName), m_OwningPlayerController);
            m_VictoryView = new VictoryScreenView(root.Q<VisualElement>(k_VictoryScreenViewName), m_OwningPlayerController);

            // Track views in a list for disposal 
            m_AllViews.Add(m_GameplayHUDView);
            m_AllViews.Add(m_PauseView);
            m_AllViews.Add(m_SettingsView);
            m_AllViews.Add(m_KeybindingsView);
            m_AllViews.Add(m_GameOverView);
            m_AllViews.Add(m_VictoryView);
        }

        private void ShowInitialView()
        {
            ShowView(m_GameplayHUDView);
        }

        private void ShowView(UIView newView)
        {
            if (m_CurrentView != null)
            {
                m_CurrentView.Hide();
            }

            m_CurrentView = newView;

            if (m_CurrentView != null)
            {
                m_CurrentView.Show();
            }
        }

        private void PauseGame()
        {
            ShowView(m_PauseView);
        }

        private void ResumeGame()
        {
            ShowView(m_GameplayHUDView);

            // Inform the game state that we should no longer be paused
            m_GameState.UnPauseGame();
        }

        private void ShowGameOver()
        {
            ShowView(m_GameOverView);
        }

        private void ShowVictory()
        {
            m_VictoryView.UpdateFinishTime(m_GameState.AccumulatedTime);
            ShowView(m_VictoryView);
        }

        private void ShowSettings()
        {
            ShowView(m_SettingsView);
        }

        private void ExitToMainMenu()
        {
            ParrotGameInstance.Instance.GoToMainMenu();
        }

        private void OnCloseSettings()
        {
            ShowView(m_PauseView);
        }

        private void OnKeybindingsScreenShown()
        {
            ShowView(m_KeybindingsView);
        }

        private void OnCloseKeybindings()
        {
            ShowView(m_SettingsView);
        }

        private void LevelStateChanged(ELevelState state)
        {
            if (state == ELevelState.Running)
            {
                m_ShouldUpdateTimer = true;
            }
            else
            {
                m_ShouldUpdateTimer = false;
            }
        }

        private void UpdateGameTimer()
        {
            if (!m_ShouldUpdateTimer || m_GameState == null || m_GameplayHUDView == null)
            {
                return;
            }

            m_GameplayHUDView.UpdateTimerValue(m_GameState.TimeRemaining);
        }

        #endregion
    }
}
