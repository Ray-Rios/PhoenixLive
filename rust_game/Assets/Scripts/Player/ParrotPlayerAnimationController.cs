///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Controls the animator for the player character  
    ///</summary>
    [RequireComponent(typeof(Animator))]
    public class ParrotPlayerAnimationController : MonoBehaviour
    {
        #region Attributes
        // Attributes

        #region References 

        // The animator component that drives character animation 
        private Animator m_Animator;

        #endregion

        #region Animation Events

        // Event for footstep effects
        public Action FootstepEvent;

        #endregion

        #region Animation properties

        [Tooltip("The speed threshold where the character blends from idle to ground locomotion.")]
        [SerializeField]
        private float MovementSpeedThreshold = 0.05f;

        [Tooltip("The blend minimum to apply when the player changes directions")]
        [SerializeField]
        private float DirectionChangeBlendMinimum = 0.25f;

        [Tooltip("The playback speed of grounded locomotion when move speed is exceeding normal max")]
        [SerializeField]
        private float OverMaxSpeedPlaybackRate = 2.0f;

        // The speed at which the character is moving while on the ground
        private float m_MovementSpeedPercentage;

        // When true, the character is in the air
        private bool m_IsAirborne;

        // When true, the character is dead
        private bool m_IsDead;

        // When true, the character has an X speed greater than zero 
        private bool m_IsMoving;

        // The previous movement input direction
        private float m_LastInputDirection;

        // When true, the minimum direction change blend is applied 
        private bool m_ApplyDirectionChangeBlend;

        // The previous frame's footstep value
        private float m_PreviousFootstep;

        #endregion

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

        private void Update()
        {
            // If we're not moving, we don't play footsteps
            if (!m_IsMoving)
            {
                return;
            }

            float footstep = m_Animator.GetFloat(AnimatorStrings.Footstep);

            // If the signs are different, we've crossed zero and should play a footstep
            if (footstep * m_PreviousFootstep < 0.0f)
            {
                FootstepEvent?.Invoke();
            }
            m_PreviousFootstep = footstep;
        }

        #endregion

        #region Initialization 

        // Gets all the expected components from the hierarchy
        private void ValidateRequiredComponents()
        {
            m_Animator = GetComponent<Animator>();
        }

        #endregion

        #region Animator Methods 

        // Updates animation variables related to move speed 
        public void UpdateAnimatorFromCharacterSpeed(float currentSpeed, float maxSpeed, float inputDirection)
        {
            float absSpeed = Mathf.Abs(currentSpeed);

            // When below the threshold and neutral direction, we should be in an idle animation or transitioning to one
            m_IsMoving = (absSpeed < MovementSpeedThreshold && inputDirection == 0.0f) ? false : true;
            m_Animator.SetBool(AnimatorStrings.IsMoving, m_IsMoving);

            float unclampedMoveSpeedPercentage = absSpeed / maxSpeed;

            // Calculate the speed fraction based on current and max speed 
            m_MovementSpeedPercentage = Mathf.Clamp01(unclampedMoveSpeedPercentage);

            // When the blend is less than the minimum, set it to the minimum
            if (m_IsMoving && inputDirection != m_LastInputDirection && inputDirection != 0.0f && m_LastInputDirection != 0.0f)
            {
                m_ApplyDirectionChangeBlend = true;
            }

            if (m_ApplyDirectionChangeBlend)
            {
                m_MovementSpeedPercentage = Mathf.Max(m_MovementSpeedPercentage, DirectionChangeBlendMinimum);
            }

            // Animate grounded locomotion 
            m_Animator.SetFloat(AnimatorStrings.MovementSpeed, m_MovementSpeedPercentage);

            // When our unclamped move speed percentage is over 1, animate grounded locomotion quicker to illustrate the speed powerup
            if (unclampedMoveSpeedPercentage > 1)
            {
                m_Animator.SetFloat(AnimatorStrings.MovementAnimationSpeed, OverMaxSpeedPlaybackRate);
            }
            else
            {
                m_Animator.SetFloat(AnimatorStrings.MovementAnimationSpeed, 1.0f);
            }

            m_LastInputDirection = inputDirection;
        }

        // Set the airborne variable on the animator 
        public void SetAirborne(bool airbone)
        {
            m_IsAirborne = airbone;
            m_Animator.SetBool(AnimatorStrings.IsAirborne, m_IsAirborne);
        }

        // Set the animator death state
        public void SetIsDead(bool isDead)
        {
            m_IsDead = isDead;
            m_Animator.SetBool(AnimatorStrings.IsDead, m_IsDead);
            m_Animator.ResetTrigger(AnimatorStrings.Hit);
        }

        // Triggers a hit on the animator 
        public void TriggerHit()
        {
            m_Animator.SetTrigger(AnimatorStrings.Hit);
        }

        #endregion
    }
}
