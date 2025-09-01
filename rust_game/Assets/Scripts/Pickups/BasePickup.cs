///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Base class that controls pickup behavior 
    ///</summary>
    [RequireComponent(typeof(Collider))]
    [RequireComponent(typeof(Rigidbody))]
    [RequireComponent(typeof(MeshFilter))]
    [RequireComponent(typeof(MeshRenderer))]
    public abstract class BasePickup : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Header("Tuning Data")]
        [Tooltip("The speed to move the sine wave movement")]
        [SerializeField]
        protected float SineWaveSpeed = 3.0f;

        [Tooltip("How far to offset the peak off the sine wave")]
        [SerializeField]
        protected float SineWavePeakOffset = 0.05f;

        [Tooltip("The speed at which this game object rotates on Y (Yaw)")]
        [SerializeField]
        protected float RotationSpeed = 150.0f;

        [Header("SFX")]
        [SerializeField]
        protected AudioClip PickupSound;

        [Header("VFX")]
        [SerializeField]
        private ParrotVFXWrapper PickupVFX;

        protected Rigidbody m_RigidBody;
        protected Vector3 m_StartPosition;

        #endregion

        #region Unity Methods
        // Unity Methods

        void Awake()
        {
            m_RigidBody = GetComponent<Rigidbody>();

            // This rigidbody should be kinematic no matter what
            m_RigidBody.isKinematic = true;
        }

        void Start()
        {
            m_StartPosition = m_RigidBody.position;
        }

        void OnTriggerEnter(Collider other)
        {
            ParrotPlayerCharacter player = other.gameObject.GetComponent<ParrotPlayerCharacter>();
            if (player != null)
            {
                if (PickupSound != null)
                {
                    ParrotAudioController.Instance.PlayGameplaySFX(PickupSound);
                }

                PickupVFX?.Play();

                OnPickedUp(player);
                Destroy(gameObject);
            }
        }

        private void FixedUpdate()
        {
            // Yaw the object 
            Quaternion newRotation = m_RigidBody.rotation * Quaternion.Euler(0.0f, RotationSpeed * Time.fixedDeltaTime, 0.0f);
            m_RigidBody.MoveRotation(newRotation);

            // Apply sine wave to movement
            Vector3 newPosition = m_RigidBody.position;
            newPosition.y = m_StartPosition.y + Mathf.Sin(SineWaveSpeed * Time.time) * SineWavePeakOffset;

            m_RigidBody.MovePosition(newPosition);
        }
        #endregion

        protected virtual void OnPickedUp(ParrotPlayerCharacter player)
        {
        }
    }
}
