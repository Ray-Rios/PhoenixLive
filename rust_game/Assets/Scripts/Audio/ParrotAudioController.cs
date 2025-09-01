///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.Audio;
using Singleton = SecretDimension.Singleton<SecretDimension.ParrotAudioController>;

namespace SecretDimension
{
    ///<summary>
    /// Manages how all sound is interacted with in the game. Controls audio mixes and updates player prefs related to audio. 
    ///</summary>
    [RequireComponent(typeof(AudioListener))]
    public class ParrotAudioController : MonoBehaviour
    {
        #region Attributes
        // Attributes

        public static ParrotAudioController Instance => Singleton.FindInstance();

        [Header("Mixers")]
        [Tooltip("The main audio mixer used by the game that controls all volumes")]
        [Required]
        [SerializeField]
        private AudioMixer PrimaryAudioMixer;

        [Header("Audio Sources")]
        [Tooltip("The audio source that music will play from")]
        [Required]
        [SerializeField]
        private AudioSource MusicAudioSource;

        [Tooltip("The audio source that UI sfx will play from")]
        [Required]
        [SerializeField]
        private AudioSource UIAudioSource;

        [Tooltip("The audio source that Gameplay sfx will play from")]
        [Required]
        [SerializeField]
        private AudioSource GameplayAudioSource;

        [Header("Music")]
        [Tooltip("The music to play when the level completes")]
        [SerializeField]
        private AssetReference LevelCompleteMusicAsset;

        [Tooltip("The music to play when the game's over")]
        [SerializeField]
        private AssetReference GameOverMusicAsset;

        [Header("UI Sounds")]
        [Tooltip("The sound a button plays when hovered")]
        [SerializeField]
        private AudioClip ButtonHoverSound;

        [Tooltip("The sound a button plays on selection")]
        [SerializeField]
        private AudioClip ButtonSelectionSound;

        private AudioClip m_LevelCompleteMusic;

        private AudioClip m_GameOverMusic;

        private const string k_MainVolumeKey = "MainVolume";
        private const string k_MusicVolumeKey = "MusicVolume";
        private const string k_SFXVolumeKey = "SFXVolume";

        private const float k_DefaultMainVolume = 1.0f;
        private const float k_DefaultMusicVolume = 0.5f;
        private const float k_DefaultSFXVolume = 1.0f;

        private AssetReference m_CurrentWorldMusicAsset;

        private AudioClip m_CurrentWorldMusic;
        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            DontDestroyOnLoad(gameObject);

            LoadVolumes();
            SubscribeToEvents();
            StartCoroutine(LoadDefaultAudioAssets());
        }

        void OnDestroy()
        {
            ReleaseAudioAssets();
            UnsubscribeFromEvents();
        }

        #endregion

        private IEnumerator LoadDefaultAudioAssets()
        {
            // Block the scene manager until our audio assets have loaded
            var blockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();

            if (LevelCompleteMusicAsset != null)
            {
                var loadOp = LevelCompleteMusicAsset.LoadAssetAsync<AudioClip>();
                yield return loadOp;
                if (loadOp.Status == UnityEngine.ResourceManagement.AsyncOperations.AsyncOperationStatus.Succeeded)
                {
                    m_LevelCompleteMusic = loadOp.Result;
                }
            }

            if (GameOverMusicAsset != null)
            {
                var loadOp = GameOverMusicAsset.LoadAssetAsync<AudioClip>();
                yield return loadOp;
                if (loadOp.Status == UnityEngine.ResourceManagement.AsyncOperations.AsyncOperationStatus.Succeeded)
                {
                    m_GameOverMusic = loadOp.Result;
                }
            }

            ParrotSceneManager.Instance.BlockingOperations.Release(blockOp);
        }

        private void ReleaseAudioAssets()
        {
            if (MusicAudioSource != null)
            {
                MusicAudioSource.Stop();
                MusicAudioSource.clip = null;
            }

            if (LevelCompleteMusicAsset != null && LevelCompleteMusicAsset.IsValid())
            {
                LevelCompleteMusicAsset.ReleaseAsset();
            }

            if (GameOverMusicAsset != null && GameOverMusicAsset.IsValid())
            {
                GameOverMusicAsset.ReleaseAsset();
            }

            if (m_CurrentWorldMusicAsset != null && m_CurrentWorldMusicAsset.IsValid())
            {
                m_CurrentWorldMusicAsset.ReleaseAsset();
            }
        }

        private void SubscribeToEvents()
        {
            ParrotSceneManager.OnBeforeTransition += OnBeforeSceneTransition;
            ParrotSceneManager.OnSceneTransitionComplete += OnSceneTransitionComplete;
            ParrotSceneManager.OnLogoTrainComplete += OnLogoTrainComplete;
            GameplayEvents.Victory += OnVictory;
            GameplayEvents.GameOver += OnGameOver;
        }

        private void UnsubscribeFromEvents()
        {
            ParrotSceneManager.OnBeforeTransition -= OnBeforeSceneTransition;
            ParrotSceneManager.OnSceneTransitionComplete -= OnSceneTransitionComplete;
            ParrotSceneManager.OnLogoTrainComplete -= OnLogoTrainComplete;
            GameplayEvents.Victory -= OnVictory;
            GameplayEvents.GameOver -= OnGameOver;
        }

        public void SetMainVolume(float volume)
        {
            PrimaryAudioMixer.SetFloat(k_MainVolumeKey, GetLogVolume(volume));
            PlayerPrefs.SetFloat(k_MainVolumeKey, volume);
        }

        public void SetMusicVolume(float volume)
        {
            PrimaryAudioMixer.SetFloat(k_MusicVolumeKey, GetLogVolume(volume));
            PlayerPrefs.SetFloat(k_MusicVolumeKey, volume);
        }

        public void SetSFXVolume(float volume)
        {
            PrimaryAudioMixer.SetFloat(k_SFXVolumeKey, GetLogVolume(volume));
            PlayerPrefs.SetFloat(k_SFXVolumeKey, volume);
        }

        public float GetSavedMainVolume()
        {
            return PlayerPrefs.GetFloat(k_MainVolumeKey, 1.0f);
        }

        public float GetSavedMusicVolume()
        {
            return PlayerPrefs.GetFloat(k_MusicVolumeKey, 1.0f);
        }

        public float GetSavedSFXVolume()
        {
            return PlayerPrefs.GetFloat(k_SFXVolumeKey, 1.0f);
        }

        private float GetLogVolume(float alpha)
        {
            // Clamp alpha to near zero
            if (alpha <= 0)
            {
                alpha = 0.0001f;
            }

            // Note: multiplying by 20 here to hit -90db for silence
            return Mathf.Log10(alpha) * 20.0f;
        }

        private void LoadVolumes()
        {
            // Load volumes from player prefs - default value is second parameter setting value was not found
            float mainVolume = PlayerPrefs.GetFloat(k_MainVolumeKey, k_DefaultMainVolume);
            float musicVolume = PlayerPrefs.GetFloat(k_MusicVolumeKey, k_DefaultMusicVolume);
            float sfxVolume = PlayerPrefs.GetFloat(k_SFXVolumeKey, k_DefaultSFXVolume);

            // Apply volumes to mixer 
            PrimaryAudioMixer.SetFloat(k_MainVolumeKey, GetLogVolume(mainVolume));
            PrimaryAudioMixer.SetFloat(k_MusicVolumeKey, GetLogVolume(musicVolume));
            PrimaryAudioMixer.SetFloat(k_SFXVolumeKey, GetLogVolume(sfxVolume));
        }

        public void SetWorldMusic(AssetReference musicTrackAsset)
        {
            // When the asset is the same and already loaded, we can just return
            if (m_CurrentWorldMusicAsset != null && musicTrackAsset == m_CurrentWorldMusicAsset && m_CurrentWorldMusicAsset.IsValid())
            {
                return;
            }

            StartCoroutine(LoadWorldMusicAsset(musicTrackAsset));
        }

        private IEnumerator LoadWorldMusicAsset(AssetReference musicTrackAsset)
        {
            m_CurrentWorldMusicAsset = musicTrackAsset;

            // Block the scene manager until our audio assets have loaded
            var blockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();

            if (m_CurrentWorldMusicAsset != null)
            {
                var loadOp = m_CurrentWorldMusicAsset.LoadAssetAsync<AudioClip>();
                yield return loadOp;
                if (loadOp.Status == UnityEngine.ResourceManagement.AsyncOperations.AsyncOperationStatus.Succeeded)
                {
                    m_CurrentWorldMusic = loadOp.Result;
                }
            }

            ParrotSceneManager.Instance.BlockingOperations.Release(blockOp);
        }

        public void MuteMusic(bool shouldMute)
        {
            MusicAudioSource.mute = shouldMute;
        }

        private void OnBeforeSceneTransition(string currentScene, string nextScene)
        {
            // Stop playing music if we were playing any 
            if (MusicAudioSource.isPlaying)
            {
                MusicAudioSource.Stop();
            }

            if (GameplayAudioSource.isPlaying)
            {
                GameplayAudioSource.Stop();
                GameplayAudioSource.clip = null;
                GameplayAudioSource.loop = false;
            }

            m_CurrentWorldMusic = null;

            if (m_CurrentWorldMusicAsset != null && m_CurrentWorldMusicAsset.IsValid())
            {
                m_CurrentWorldMusicAsset.ReleaseAsset();
                m_CurrentWorldMusicAsset = null;
            }
        }

        private void OnLogoTrainComplete()
        {
            // Play world music when the logo train for the game completes
            PlayWorldMusic();
        }

        private void OnSceneTransitionComplete(string newScene)
        {
            // If the logo train hasn't completed, do not play music when the scene transition completes
            if (!ParrotGameInstance.Instance.GetLogoTrainDisplayed())
            {
                return;
            }

            PlayWorldMusic();
        }

        private void PlayWorldMusic()
        {
            if (m_CurrentWorldMusic == null)
            {
                return;
            }

            MusicAudioSource.clip = m_CurrentWorldMusic;
            MusicAudioSource.Play();
        }

        private void OnGameOver()
        {
            if (m_GameOverMusic == null)
            {
                return;
            }

            if (MusicAudioSource.isPlaying)
            {
                MusicAudioSource.Stop();
            }
            MusicAudioSource.clip = m_GameOverMusic;
            MusicAudioSource.Play();
        }

        private void OnVictory()
        {
            if (m_LevelCompleteMusic == null)
            {
                return;
            }

            if (MusicAudioSource.isPlaying)
            {
                MusicAudioSource.Stop();
            }
            MusicAudioSource.clip = m_LevelCompleteMusic;
            MusicAudioSource.Play();
        }

        public void PlayGameplaySFX(AudioClip targetClip, float volumeScale = 1.0f)
        {
            // Do not play any new gameplay SFX when a loading screen is displayed 
            if (ParrotGameInstance.Instance != null)
            {
                if (ParrotGameInstance.Instance.GetLoadingScreenActive())
                {
                    return;
                }
            }

            if (targetClip == null)
            {
                return;
            }

            GameplayAudioSource.PlayOneShot(targetClip, volumeScale);
        }

        public void PlayRandomGameplaySFX(List<AudioClip> audioClips, float volumeScale = 1.0f)
        {
            if (audioClips.Count < 1)
            {
                return;
            }

            AudioClip sound = audioClips[Random.Range(0, audioClips.Count)];

            if (sound != null)
            {
                PlayGameplaySFX(sound, volumeScale);
            }
        }

        public void PlayLoopingGameplaySFX(AudioClip targetClip, float volumeScale = 1.0f)
        {
            // Do not play any new gameplay SFX when a loading screen is displayed 
            if (ParrotGameInstance.Instance != null)
            {
                if (ParrotGameInstance.Instance.GetLoadingScreenActive())
                {
                    return;
                }
            }

            if (targetClip == null)
            {
                return;
            }

            GameplayAudioSource.clip = targetClip;
            GameplayAudioSource.loop = true;
            GameplayAudioSource.Play();
        }

        public void PlayUISFX(AudioClip targetClip, float volumeScale = 1.0f)
        {
            // Do not play any new UI SFX when a loading screen is displayed 
            if (ParrotGameInstance.Instance != null)
            {
                if (ParrotGameInstance.Instance.GetLoadingScreenActive())
                {
                    return;
                }
            }

            if (targetClip == null)
            {
                return;
            }

            UIAudioSource.PlayOneShot(targetClip, volumeScale);
        }

        public void PlayButtonHoverSound()
        {
            if (ButtonHoverSound)
            {
                PlayUISFX(ButtonHoverSound);
            }
        }

        public void PlayButtonSelectionSound()
        {
            if (ButtonSelectionSound)
            {
                PlayUISFX(ButtonSelectionSound);
            }
        }

        public void StopGameplaySFXSource()
        {
            GameplayAudioSource.Stop();
        }

        public void StopUISFXSource()
        {
            UIAudioSource.Stop();
        }
    }
}
