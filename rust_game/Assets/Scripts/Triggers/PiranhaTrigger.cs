///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Kills a player when they enter this game object's trigger bounds 
    ///</summary>
    [RequireComponent(typeof(Collider))]
    public class PiranhaTrigger : MonoBehaviour
    {
        #region Attributes

        [Tooltip("The piranha VFX to play when the player enters the trigger")]
        [SerializeField]
        private ParrotVFXWrapper PiranhaVFX;

        [Tooltip("The sound to play for the piranha effect")]
        [SerializeField]
        private AudioClip PiranhaSound;

        [Tooltip("The water splashing sound pool to play")]
        [SerializeField]
        private List<AudioClip> SplashSounds;

        [Tooltip("The minimum delay between playing splashing sounds")]
        [SerializeField]
        private float SplashSoundLoopDelayMin = 0.05f;

        [Tooltip("The maximum delay between playing splashing sounds")]
        [SerializeField]
        private float SplashSoundLoopDelayMax = 0.3f;

        [Tooltip("The volume to play the splash sounds")]
        [SerializeField]
        private float SplashSoundVolume = 0.6f;

        private Coroutine m_SplashSoundLoop;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void OnTriggerEnter(Collider other)
        {
            ParrotPlayerCharacter player = other.gameObject.GetComponent<ParrotPlayerCharacter>();
            if (player != null)
            {
                ParrotAudioController.Instance.PlayLoopingGameplaySFX(PiranhaSound);

                // Position the VFX where the player fell in
                PiranhaVFX.transform.SetPositionAndRotation(player.transform.position, PiranhaVFX.transform.rotation);
                PiranhaVFX.Play();

                m_SplashSoundLoop = StartCoroutine(SplashSoundLoop());
            }
        }

        private void OnDestroy()
        {
            if (m_SplashSoundLoop != null)
            {
                StopCoroutine(m_SplashSoundLoop);
                m_SplashSoundLoop = null;
            }
        }
        #endregion

        #region Coroutines

        IEnumerator SplashSoundLoop()
        {
            while (true)
            {
                ParrotAudioController.Instance.PlayRandomGameplaySFX(SplashSounds, SplashSoundVolume);
                yield return new WaitForSeconds(Random.Range(SplashSoundLoopDelayMin, SplashSoundLoopDelayMax));
            }
        }

        #endregion
    }
}
