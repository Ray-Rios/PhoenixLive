///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using Singleton = SecretDimension.Singleton<SecretDimension.ParrotGameInstance>;

namespace SecretDimension
{
    ///<summary>
    /// Class that persists for the lifetime of the application 
    ///</summary>
    public class ParrotGameInstance : MonoBehaviour
    {
        #region Attributes
        // Attributes
        public static ParrotGameInstance Instance => Singleton.FindInstance();

        [SerializeField]
        [Required]
        private ParrotLevelData LevelData;

        private int m_CurrentLevelIndex = -1;
        private string m_CurrentLevel;
        private bool m_LogoTrainDisplayed;
        private bool m_LoadingScreenActive;

        #endregion

        #region Unity Methods

        void Awake()
        {
            DontDestroyOnLoad(gameObject);

            // Default to main menu
            m_CurrentLevel = LevelData.mainMenuLevel;
        }

        #endregion

        public void GoToNextLevel()
        {
            // Ensures that game flow works the same when testing from test levels in editor
#if UNITY_EDITOR
            if (PlayFromEnvironment.UsingCustomIndex)
            {
                m_CurrentLevelIndex = PlayFromEnvironment.LevelDataIndex;
                PlayFromEnvironment.UsingCustomIndex = false;
            }
#endif 

            m_CurrentLevelIndex++;
            if (m_CurrentLevelIndex >= LevelData.singlePlayerLevels.Length)
            {
                GoToMainMenu();
            }
            else
            {
                m_CurrentLevel = LevelData.singlePlayerLevels[m_CurrentLevelIndex];
                ParrotSceneManager.Instance.ChangeScene(m_CurrentLevel);
            }
        }

        public void GoToMainMenu()
        {
            m_CurrentLevelIndex = -1;
            m_CurrentLevel = LevelData.mainMenuLevel;
            ParrotSceneManager.Instance.ChangeScene(m_CurrentLevel);
        }

        public void RestartLevel()
        {
            // Ensures that game flow works the same when testing from test levels in editor
#if UNITY_EDITOR
            if (m_CurrentLevelIndex == -1 || PlayFromEnvironment.UsingCustomIndex)
            {
                m_CurrentLevelIndex = PlayFromEnvironment.LevelDataIndex;
                PlayFromEnvironment.UsingCustomIndex = false;
            }
#endif 
            m_CurrentLevel = LevelData.singlePlayerLevels[m_CurrentLevelIndex];
            ParrotSceneManager.Instance.ReloadScene(m_CurrentLevel);
        }

        // Informs the game instance that the logo train has been shown at least once this application lifecycle
        public void SetLogoTrainDisplayed()
        {
            m_LogoTrainDisplayed = true;
        }

        // When true, the logo train has been displayed at least once this application lifecycle 
        public bool GetLogoTrainDisplayed()
        {
            return m_LogoTrainDisplayed;
        }

        // Sets the loading screen state to active in the game instance 
        public void SetLoadingScreenActive(bool isActive)
        {
            m_LoadingScreenActive = isActive;
        }

        public bool GetLoadingScreenActive()
        {
            return m_LoadingScreenActive;
        }
    }
}
