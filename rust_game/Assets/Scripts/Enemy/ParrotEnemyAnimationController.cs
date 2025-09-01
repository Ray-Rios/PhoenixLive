///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Controls the animator for the player character  
    ///</summary>
    [RequireComponent(typeof(Animator))]
    public class ParrotEnemyAnimationController : MonoBehaviour
    {
        #region Attributes
        // Attributes

        #region References 

        // The animator component that drives character animation 
        protected Animator m_Animator;

        #endregion

        #region Animation properties

        // When true, the character is dead
        private bool m_IsDead;

        #endregion

        #region Events

        // Events for sending data about the Patrol trigger receiving overlaps
        public Action EnableHitboxEvent;
        public Action DisableHitboxEvent;

        // Event for timing to play the hit effect
        public Action HitEffectEvent;

        // Event for footstep effects
        public Action LeftFootstepEvent;
        public Action RightFootstepEvent;

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

        #endregion

        #region Initialization 

        // Gets all the expected components from the hierarchy
        private void ValidateRequiredComponents()
        {
            m_Animator = GetComponent<Animator>();
        }

        #endregion

        #region Animator Methods 

        // Set the animator death state
        public void SetIsDead(bool isDead)
        {
            m_IsDead = isDead;
            m_Animator.SetBool(AnimatorStrings.IsDead, m_IsDead);
            m_Animator.ResetTrigger(AnimatorStrings.Hit);
            m_Animator.ResetTrigger(AnimatorStrings.Attack);
        }

        // Triggers a hit on the animator 
        public void TriggerHit()
        {
            m_Animator.SetTrigger(AnimatorStrings.Hit);
        }

        // Enables the attack bool
        public void BeginAttack()
        {
            m_Animator.SetBool(AnimatorStrings.Attack, true);
        }

        // Disables the attack bool
        public void EndAttack()
        {
            m_Animator.SetBool(AnimatorStrings.Attack, false);
        }

        public void BeginShakeHead()
        {
            m_Animator.SetBool(AnimatorStrings.IsShakingHead, true);
        }

        public void EndShakeHead()
        {
            m_Animator.SetBool(AnimatorStrings.IsShakingHead, false);
        }

        void EnableHitbox()
        {
            EnableHitboxEvent?.Invoke();
        }

        void DisableHitbox()
        {
            DisableHitboxEvent?.Invoke();
        }

        void HitEffect()
        {
            HitEffectEvent?.Invoke();
        }

        private void LeftFootstepEffect()
        {
            LeftFootstepEvent?.Invoke();
        }

        private void RightFootstepEffect()
        {
            RightFootstepEvent?.Invoke();
        }

        #endregion

    }
}
