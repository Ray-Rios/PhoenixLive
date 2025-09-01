///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using System.Collections;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// A base character pawn class that can be controlled
    ///</summary>
    [RequireComponent(typeof(Rigidbody))]
    [RequireComponent(typeof(CapsuleCollider))]
    public abstract class ParrotCharacterBase : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Tooltip("A duration that the hit VFX will play for.")]
        [SerializeField]
        [Range(0.0f, 10.0f)]
        protected float HitVFXDuration = 0.5f;

        [Tooltip("The duration of the flash in the hit VFX.")]
        [SerializeField]
        [Range(0.0f, 1.0f)]
        private float HitVFXFlashInterval = 0.05f;

        #region References

        // The skinned mesh material for the player
        private SkinnedMeshRenderer m_SkinnedMeshRenderer;

        // The Rigidbody that is owned by this character
        protected Rigidbody m_Rigidbody;

        // The capsule collider used by this character
        protected CapsuleCollider m_Capsule;

        #endregion

        #region Character Properties 

        [Header("Character Properties")]
        [Tooltip("The default hitpoints that this character starts with")]
        [SerializeField]
        [Range(1, 100)]
        protected int HitPoints = 1;

        // The character's current hit points 
        public int CurrentHitPoints { get; protected set; }

        // Called when a character dies
        public Action OnCharacterDeath;

        // Called when the character is hit
        public Action OnCharacterHit;

        #endregion

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        protected virtual void Awake()
        {
            ValidateRequiredComponents();
            InitializeCharacter();
        }

        protected virtual void OnDestroy()
        {
            OnCharacterHit -= StartHitEffectRoutine;
        }

        #endregion

        #region Character Methods 

        // Gets all the expected components from the hierarchy
        protected virtual void ValidateRequiredComponents()
        {
            m_Rigidbody = GetComponent<Rigidbody>();
            m_Capsule = GetComponent<CapsuleCollider>();
            m_SkinnedMeshRenderer = GetComponentInChildren<SkinnedMeshRenderer>();

            if (!m_SkinnedMeshRenderer)
            {
                Debug.LogError("Skinned mesh renderer not found on child ", this);
            }
        }

        // Initializes the character properties 
        protected virtual void InitializeCharacter()
        {
            CurrentHitPoints = HitPoints;
            OnCharacterHit += StartHitEffectRoutine;
        }

        // Returns whether or not the character is dead
        public bool IsDead()
        {
            return CurrentHitPoints <= 0;
        }

        // Applies a hit to the character 
        public virtual void HitCharacter()
        {
            if (IsDead())
            {
                return;
            }

            // Subtract from hit points by one but clamp to zero 
            CurrentHitPoints = (CurrentHitPoints > 0) ? CurrentHitPoints - 1 : 0;

            // Broadcast hit event 
            OnCharacterHit?.Invoke();

            // Check if the character has died 
            if (IsDead())
            {
                // Do any relevant death logic 
                CharacterDeath();
            }
        }


        // Instantly kills the character regardless of hitpoints value 
        public void KillCharacter()
        {
            if (IsDead())
            {
                return;
            }

            // Clear hitpoints and call our death logic  
            CurrentHitPoints = 0;
            CharacterDeath();
        }

        // Implementation for when the character dies 
        protected virtual void CharacterDeath()
        {
            // Broadcast the death event 
            OnCharacterDeath?.Invoke();
        }

        protected void HaltMovementAndPhysics()
        {
            // Disable physics and collision on the rigidbody so we don't move anymore.
            m_Rigidbody.isKinematic = true;
            m_Rigidbody.detectCollisions = false;
        }

        #endregion

        #region Combat

        void StartHitEffectRoutine()
        {
            // Don't play this effect if we're dead
            if (IsDead())
            {
                return;
            }

            // Play the flashing material hit VFX
            StartCoroutine(HitEffectRoutine(HitVFXDuration));
        }

        private IEnumerator HitEffectRoutine(float duration)
        {
            Material playerMaterial = m_SkinnedMeshRenderer.material;
            Color materialBaseColor = playerMaterial.color;
            Color flashColor = Color.red;
            float endTime = Time.time + duration;

            while (Time.time < endTime)
            {
                playerMaterial.color = flashColor;
                yield return new WaitForSeconds(HitVFXFlashInterval);
                playerMaterial.color = materialBaseColor;
                yield return new WaitForSeconds(HitVFXFlashInterval);
            }
        }

        #endregion
    }
}
