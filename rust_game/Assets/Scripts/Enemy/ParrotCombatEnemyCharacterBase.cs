///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// The enemy character subclass for enemies that will be involved in combat.
    ///</summary>
    public class ParrotCombatEnemyCharacterBase : ParrotEnemyCharacterBase
    {
        #region Attributes
        // Attributes
        [Tooltip("The amount of time in seconds to wait after this character has died before destroying the game object")]
        [SerializeField]
        protected float PostDeathDelay = 1.5f;

        [Tooltip("The knockback force to be applied when this enemy hits the player.")]
        [SerializeField]
        protected float WeaponKnockbackForce = 15.0f;

        [Tooltip("The recoil force to be applied to the player when they hurt this enemy.")]
        [SerializeField]
        protected float RecoilForce = 0.0f;

        [Tooltip("A duration to stun the enemy when hit. Zero will prevent any stun.")]
        [SerializeField]
        protected float HitStunDuration = 0.0f;

        const string k_IsStunned = "IsStunned";

        #region References

        // The controller which interacts with the character's animator 
        protected ParrotEnemyAnimationController m_AnimationController;

        [Header("Collision")]
        // The hitbox on the enemy's weapon
        [Tooltip("The collider on the weapon")]
        [SerializeField]
        [Required]
        private Collider HitboxCollider;

        [Tooltip("The position at which to perform the spherecast to detect player jumping on the enemy")]
        [SerializeField]
        [Required]
        private Transform HurtSphereCastTransform;

        [SerializeField]
        private LayerMask PlayerLayerMask;

        #endregion

        #endregion

        // Tracks when the player has entered our hurtbox so we can ignore hitbox triggers
        bool m_IsStunned = false;

        // This flag prevents us from performing hurt checking
        protected bool m_IsInvulernable = false;

        #region Unity Methods
        // Unity Methods
        protected override void FixedUpdate()
        {
            base.FixedUpdate();
            CheckHurtboxOverlap();
        }

        protected override void OnDestroy()
        {
            base.OnDestroy();

            if (m_AnimationController != null)
            {
                m_AnimationController.EnableHitboxEvent -= OnEnableHitbox;
                m_AnimationController.DisableHitboxEvent -= OnDisableHitbox;
                m_AnimationController.HitEffectEvent -= PlayHitEffect;
            }
        }

        #endregion

        #region Initialization

        protected override void InitializeCharacter()
        {
            base.InitializeCharacter();

            m_AnimationController = GetComponentInChildren<ParrotEnemyAnimationController>();
            if (m_AnimationController != null)
            {
                m_AnimationController.EnableHitboxEvent += OnEnableHitbox;
                m_AnimationController.DisableHitboxEvent += OnDisableHitbox;
                m_AnimationController.HitEffectEvent += PlayHitEffect;
            }

            HitboxCollider.enabled = false;
        }

        #endregion

        #region Event Methods

        protected override void OnEnemyTriggerEntered(bool IsWeapon, ParrotPlayerCharacter player)
        {
            if (IsDead() || m_IsStunned)
            {
                return;
            }

            float knockbackForce = IsWeapon ? WeaponKnockbackForce : BodyKnockbackForce;

            player.HitCharacterWithLaunchForce(knockbackForce * Vector3.Normalize(player.GetPosition() - GetPosition()));
        }

        void OnEnableHitbox()
        {
            HitboxCollider.enabled = true;
        }

        void OnDisableHitbox()
        {
            HitboxCollider.enabled = false;
        }

        #endregion

        #region Combat

        public void BeginAttack()
        {
            m_AnimationController.BeginAttack();
        }

        public void EndAttack()
        {
            m_AnimationController.EndAttack();
        }

        public override void HitCharacter()
        {
            base.HitCharacter();

            if (IsDead())
            {
                return;
            }

            if (HitStunDuration > 0.0f)
            {
                OnHitStun();
            }

            m_AnimationController.TriggerHit();
        }

        protected virtual void OnHitStun()
        {
            m_BehaviorAgent.SetVariableValue(k_IsStunned, true);
            m_IsStunned = true;
            StartCoroutine(HitStunRoutine(HitStunDuration));
        }

        private IEnumerator HitStunRoutine(float duration)
        {
            yield return new WaitForSeconds(duration);
            StopHitStun();
        }

        protected virtual void StopHitStun()
        {
            m_BehaviorAgent.SetVariableValue(k_IsStunned, false);
            m_IsStunned = false;
        }

        protected override void CharacterDeath()
        {
            base.CharacterDeath();

            // Enemy-specific death handling

            // Play the hit VFX since a hit is not processed when the character dies
            PlayHitEffect();

            // Play the death animation
            m_AnimationController.SetIsDead(true);
            // Stop the behavior agent so it no longer does stuff
            m_BehaviorAgent.End();

            HaltMovementAndPhysics();

            m_IsStunned = false;
            StartCoroutine(DeathRoutine());
        }

        private IEnumerator DeathRoutine()
        {
            yield return new WaitForSeconds(PostDeathDelay);
            DespawnVFX?.Play();
            Destroy(gameObject);
        }

        private void CheckHurtboxOverlap()
        {
            if (IsDead() || m_IsInvulernable)
            {
                return;
            }

            Collider[] overlaps = Physics.OverlapSphere(HurtSphereCastTransform.position, m_Capsule.radius, PlayerLayerMask, QueryTriggerInteraction.Ignore);
            foreach (var overlap in overlaps)
            {
                ParrotPlayerCharacter player = overlap.gameObject.GetComponent<ParrotPlayerCharacter>();
                {
                    if (player != null)
                    {
                        if (!m_IsStunned && player.IsFalling())
                        {
                            // Trigger the player to do an enemy jump
                            if (player.DoEnemyJump())
                            {
                                // If we have a recoil to apply, do it here. This will take over from the DoEnemyJump
                                if (RecoilForce > 0.0f)
                                {
                                    Vector3 hitForce = Vector3.zero;
                                    Vector3 playerVelocity = player.GetVelocity();
                                    hitForce.x = playerVelocity.normalized.x * -RecoilForce;
                                    hitForce.y = -playerVelocity.y;
                                    player.LaunchCharacter(hitForce);
                                }

                                // If the jump is successful, apply a hit to this enemy
                                HitCharacter();
                            }
                        }
                        return;
                    }
                }
            }
        }

        #endregion
    }
}
