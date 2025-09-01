///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.Video;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace SecretDimension
{
    ///<summary>
    /// Plays the boot splash video at the start of the game
    ///</summary>
    ///
    [RequireComponent(typeof(VideoPlayer))]
    public class LogoTrain : MonoBehaviour
    {
        #region Attributes
        // Attributes

        private VideoPlayer m_VideoPlayer;
        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            m_VideoPlayer = GetComponent<VideoPlayer>();
            DontDestroyOnLoad(gameObject);

#if UNITY_EDITOR
            if (EditorPrefs.GetBool("ShowBootSplash") == false)
            {
                ParrotSceneManager.OnSceneTransitionComplete += EditorBootSplashCheck;
                return;
            }
#endif
            m_VideoPlayer.loopPointReached += EndPlaybackReached;
        }

        void OnDestroy()
        {
            m_VideoPlayer.loopPointReached -= EndPlaybackReached;
#if UNITY_EDITOR
            if (EditorPrefs.GetBool("ShowBootSplash") == false)
            {
                ParrotSceneManager.OnSceneTransitionComplete -= EditorBootSplashCheck;
            }
#endif
        }

        #endregion

#if UNITY_EDITOR
        private void EditorBootSplashCheck(string scene)
        {
            if (scene.Contains("MainMenu"))
            {
                m_VideoPlayer.Stop();
                OnLogoTrainComplete();
            }
        }
#endif

        private void EndPlaybackReached(VideoPlayer source)
        {
            OnLogoTrainComplete();
        }

        private void OnLogoTrainComplete()
        {
            // Broadcast that the logo train has finished 
            ParrotSceneManager.OnLogoTrainComplete?.Invoke();
            // Destroy self 
            Destroy(gameObject);
        }
    }
}
