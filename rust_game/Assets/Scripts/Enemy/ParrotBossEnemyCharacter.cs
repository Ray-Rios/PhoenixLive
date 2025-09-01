///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Implements special behavior for the boss shark enemy
    ///</summary>
    public class ParrotBossEnemyCharacter : ParrotCombatEnemyCharacterBase
    {
        #region Attributes
        // Attributes

        [Header("Boss")]
        [Tooltip("The multiplier to apply to the boss walk speed upon being hit by the player.")]
        [SerializeField]
        private float HitSpeedMultiplier = 6.0f;

        [Tooltip("The duration of the angry reaction when hitting the boss.")]
        [SerializeField]
        private float BossAngryTime = 5.0f;

        [Tooltip("The duration of the head shake reaction when hitting the boss.")]
        [SerializeField]
        private float ShakeHeadTime = 2.5f;

        [Tooltip("The amount of time to start the flame effect early.")]
        [SerializeField]
        private float FlameStartOffset = 2.0f;

        [Tooltip("The amount of time to stop the flame effect early.")]
        [SerializeField]
        private float FlameStopOffset = 0.8f;

        [Header("VFX")]
        [Tooltip("The VFX to play for the left footstep")]
        [SerializeField]
        protected ParrotVFXWrapper LeftFootstepVFX;

        [Tooltip("The VFX to play for the right footstep")]
        [SerializeField]
        protected ParrotVFXWrapper RightFootstepVFX;

        [Tooltip("The VFX to play for rage sequence")]
        [SerializeField]
        protected ParrotVFXWrapper RageFireVFX;

        const string k_IsFast = "IsFast";

        #endregion

        protected override void OnDestroy()
        {
            base.OnDestroy();

            m_AnimationController.LeftFootstepEvent -= LeftFootstepEffect;
            m_AnimationController.RightFootstepEvent -= RightFootstepEffect;
        }
        protected override void InitializeCharacter()
        {
            base.InitializeCharacter();

            m_AnimationController.LeftFootstepEvent += LeftFootstepEffect;
            m_AnimationController.RightFootstepEvent += RightFootstepEffect;
        }

        private void LeftFootstepEffect()
        {
            LeftFootstepVFX?.Play();
        }

        private void RightFootstepEffect()
        {
            RightFootstepVFX?.Play();
        }

        public override void HitCharacter()
        {
            base.HitCharacter();

            if (IsDead())
            {
                return;
            }

            m_IsInvulernable = true;
            StartCoroutine(BossAngryTimeRoutine());
        }

        IEnumerator BossAngryTimeRoutine()
        {
            yield return new WaitForSeconds(HitVFXDuration);

            m_AnimationController.BeginShakeHead();

            // Start the flame early because it takes time to actually "spin up" the effect
            yield return new WaitForSeconds(ShakeHeadTime - FlameStartOffset);

            RageFireVFX?.Play();

            yield return new WaitForSeconds(FlameStartOffset);

            m_AnimationController.EndShakeHead();
            m_BehaviorAgent.SetVariableValue(k_PatrolSpeed, PatrolSpeed * HitSpeedMultiplier);
            m_BehaviorAgent.SetVariableValue(k_IsFast, true);

            // Stop the flame early because it takes time for the effect to fade out
            yield return new WaitForSeconds(BossAngryTime - FlameStopOffset);

            RageFireVFX?.Stop();

            yield return new WaitForSeconds(FlameStopOffset);

            m_BehaviorAgent.SetVariableValue(k_PatrolSpeed, PatrolSpeed);
            m_BehaviorAgent.SetVariableValue(k_IsFast, false);
            m_IsInvulernable = false;
        }

        protected override void CharacterDeath()
        {
            ParrotPlayerCharacter player = FindFirstObjectByType<ParrotPlayerCharacter>();

            if (player == null)
            {
                Debug.LogError("Parrot Boss Enemy Character could not find player character object! Cannot complete level!", gameObject);
                return;
            }

            player.DefeatBoss(PostDeathDelay);
            base.CharacterDeath();
        }
    }
}
