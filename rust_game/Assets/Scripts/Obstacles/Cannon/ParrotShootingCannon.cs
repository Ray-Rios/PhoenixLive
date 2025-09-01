///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// An automatically firing cannon that begins when the player enters its trigger volume
    ///</summary>
    public class ParrotShootingCannon : MonoBehaviour
    {
        #region Attributes
        // Attributes
        [Header("References")]
        [SerializeField]
        [Required]
        [Tooltip("The empty gameobject used to author the spawn point of the cannonball.")]
        private GameObject CannonballSpawnPoint;

        [SerializeField]
        [Required]
        [Tooltip("The empty gameobject used to author the spawn point of the smoke VFX.")]
        private GameObject SmokeVFXSpawnPoint;

        [SerializeField]
        [Required]
        [Tooltip("The empty gameobject used to author the spawn point of the fuse VFX.")]
        private GameObject FuseVFXSpawnPoint;

        [Header("Cannon")]
        [SerializeField]
        [Tooltip("The initial delay between the player entering the trigger and the first firing of the cannon.")]
        private float InitialFiringDelay;

        [SerializeField]
        [Tooltip("The loop time for cannon firings.")]
        private float FireLoopTime;

        [SerializeField]
        [Tooltip("The delay for the cannon firing sound to play before the cannonball is fired, due to the sound having a 'lead up' to the BOOM.")]
        private float CannonFireSoundDelayTime;

        [SerializeField]
        [Tooltip("The delay for the fuse to play its VFX and sound before the cannon fires.")]
        private float CannonFireFuseDelayTime;

        [SerializeField]
        [Tooltip("The maximum lifetime of the cannonball.")]
        private float CannonBallLifetime;

        [SerializeField]
        [Required]
        [Tooltip("The prefab to spawn for the cannonball.")]
        private GameObject CannonBallPrefab;

        [Header("SFX")]
        [SerializeField]
        [Tooltip("The sound to play when the player lands")]
        private AudioClip CannonFuseSound;

        [SerializeField]
        [Tooltip("The sound to play when the player lands")]
        private AudioClip CannonFiringSound;

        [Header("VFX")]
        [Tooltip("The VFX to play for the burning fuse")]
        [SerializeField]
        private ParrotVFXWrapper FuseVFX;

        [Tooltip("The smoke VFX to play when the cannonball is fired")]
        [SerializeField]
        private ParrotVFXWrapper SmokeVFX;

        [Tooltip("The spark VFX to play when the cannonball is fired")]
        [SerializeField]
        private ParrotVFXWrapper SparkVFX;

        #region References

        // The trigger volume that begins the cannon firing sequence when the player enters.
        Collider m_FireTriggerCollider;

        #endregion

        Coroutine m_FiringRoutine;

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            ValidateRequiredComponents();
        }

        private void OnTriggerEnter(Collider Other)
        {
            // Collision layers limit this to only player layer overlaps
            StartCannonFiringRoutine();
        }

        private void OnTriggerExit(Collider Other)
        {
            // Collision layers limit this to only player layer overlaps
            StopCannonFiringRoutine();
        }

        #endregion

        #region Initialization

        void ValidateRequiredComponents()
        {
            m_FireTriggerCollider = GetComponentInChildren<Collider>();

            if (m_FireTriggerCollider == null)
            {
                Debug.LogError("Cannon is missing a trigger collider necessary to function.", this);
            }
        }

        #endregion

        #region Cannon Firing

        private void StartCannonFiringRoutine()
        {
            m_FiringRoutine = StartCoroutine(CannonFiringRoutine());
        }

        private void StopCannonFiringRoutine()
        {
            if (m_FiringRoutine != null)
            {
                StopCoroutine(m_FiringRoutine);
                m_FiringRoutine = null;
            }
        }

        private IEnumerator CannonFiringRoutine()
        {
            yield return new WaitForSeconds(InitialFiringDelay);

            while (true)
            {
                StartCoroutine(ActiveCannonFiringRoutine());
                yield return new WaitForSeconds(FireLoopTime);
            }
        }

        private IEnumerator ActiveCannonFiringRoutine()
        {
            FuseVFX?.Play();
            ParrotAudioController.Instance.PlayGameplaySFX(CannonFuseSound);

            yield return new WaitForSeconds(CannonFireFuseDelayTime);

            ParrotAudioController.Instance.PlayGameplaySFX(CannonFiringSound);

            yield return new WaitForSeconds(CannonFireSoundDelayTime);

            SmokeVFX?.Play();
            SparkVFX?.Play();

            ParrotCannonBall cannonBall = Instantiate(
                CannonBallPrefab,
                CannonballSpawnPoint.transform.position,
                transform.rotation).GetComponent<ParrotCannonBall>();

            if (cannonBall != null)
            {
                cannonBall.Initialize(CannonBallLifetime);
            }
        }

        #endregion
    }
}
