///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// The cannonball fired by the shooting cannon
    ///</summary>
    [RequireComponent(typeof(Rigidbody))]
    public class ParrotCannonBall : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Header("CannonBall")]
        [SerializeField]
        [Tooltip("The speed at which the cannonball flies.")]
        private float CannonBallSpeed;

        [SerializeField]
        [Tooltip("The force applied to the player when hit.")]
        private float HitForce;

        [Header("VFX")]
        [Tooltip("The VFX to play when the cannonball is destroyed/hits something")]
        [SerializeField]
        [Required]
        private ParrotVFXWrapper HitVFX;

        [Header("SFX")]
        [SerializeField]
        [Tooltip("The sound to play when the cannonball hits")]
        private AudioClip HitSFX;

        #region References

        Rigidbody m_Rigidbody;

        #endregion

        float m_LifetimeEndTime;

        #endregion

        #region Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            ValidateRequiredComponents();
        }

        /// <summary>
        /// FixedUpdate is called once per frame
        /// </summary>
        private void FixedUpdate()
        {
            if (Time.time > m_LifetimeEndTime)
            {
                Destroy(gameObject);
                return;
            }

            m_Rigidbody.MovePosition(m_Rigidbody.position + CannonBallSpeed * transform.forward * Time.deltaTime);
        }

        #endregion

        #region Initialization

        public void Initialize(float Lifetime)
        {
            m_LifetimeEndTime = Time.time + Lifetime;
        }
        void ValidateRequiredComponents()
        {
            m_Rigidbody = GetComponent<Rigidbody>();
        }

        #endregion

        private void OnTriggerEnter(Collider other)
        {
            HitVFX?.Play();
            ParrotAudioController.Instance.PlayGameplaySFX(HitSFX);

            ParrotPlayerCharacter player = other.gameObject.GetComponent<ParrotPlayerCharacter>();
            if (player != null)
            {
                // If it's a player, only react if they're alive
                if (!player.IsDead())
                {
                    player.HitCharacterWithLaunchForce(HitForce * Vector3.Normalize(player.GetPosition() - m_Rigidbody.position));
                    Destroy(gameObject);
                }
            }
            // If it's not a player destroy yourself anyway
            else
            {
                Destroy(gameObject);
            }
        }
    }
}
