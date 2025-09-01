///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using Unity.Behavior;
using UnityEngine;
using UnityEngine.AI;
using UnityEngine.Splines;

namespace SecretDimension
{
    ///<summary>
    /// A Base character pawn class for the enemy, controlled by its Behavior Agent instead of a controller.
    ///</summary>
    [RequireComponent(typeof(BehaviorGraphAgent))]
    public class ParrotEnemyCharacterBase : ParrotCharacterBase
    {
        #region Attributes
        // Attributes

        #region Effects

        [Header("SFX")]
        [Tooltip("The pool of sounds to play from when this enemy is hit")]
        [SerializeField]
        protected List<AudioClip> HitSounds;

        [Tooltip("The pool of sounds to play from when the enemy dies")]
        [SerializeField]
        protected List<AudioClip> DeathSounds;

        [Header("VFX")]
        [Tooltip("The VFX to play when the enemy is hit")]
        [SerializeField]
        protected ParrotVFXWrapper HitVFX;

        [Tooltip("The smoke VFX to play when the enemy corpse is despawned")]
        [SerializeField]
        protected ParrotVFXWrapper DespawnVFX;

        #endregion

        [Header("Patrol")]
        [Tooltip("The patrol speed of this enemy.")]
        [SerializeField]
        protected float PatrolSpeed = 3.5f;

        [Tooltip("The maximum acceleration rate of this enemy.")]
        [SerializeField]
        protected float MaxAccelerationRate = 20.48f;

        [Tooltip("The maximum braking/deceleration rate of this enemy.")]
        [SerializeField]
        protected float MaxBrakingRate = 20.48f;

        [Header("Tuning")]
        [Tooltip("The knockback force to be applied when this enemy hits the player.")]
        [SerializeField]
        protected float BodyKnockbackForce = 10.0f;

        // Any EnemyColliders that are attached to this enemy
        ParrotEnemyCollider[] m_EnemyColliders;

        // The patrol spline authored to be used for navigating the patrol
        Spline m_PatrolSpline;

        // The patrol rig we were spawned from
        ParrotEnemyPatrolRig m_PatrolRig;

        // Our behavior graph component
        protected BehaviorGraphAgent m_BehaviorAgent;

        // Tracks our current patrol point as we progress through a patrol
        int m_CurrentPatrolPointIndex = -1;

        const string k_IsPlayerInPatrolVolume = "IsPlayerInPatrolVolume";
        const string k_EnemyAgent = "EnemyAgent";
        const string k_NextPatrolPosition = "NextPatrolPosition";
        protected const string k_PatrolSpeed = "PatrolSpeed";

        // target forward and movement speed from the behavior agent
        Vector3 m_NewForward;
        float m_TargetSpeed;

        // Our current speed based on acceleration/deceleration toward the target speed
        float m_CurrentSpeed;

        #endregion

        #region Unity Methods
        // Unity Methods
        protected virtual void Start()
        {
            m_BehaviorAgent.SetVariableValue(k_PatrolSpeed, PatrolSpeed);
        }

        protected override void OnDestroy()
        {
            base.OnDestroy();

            if (m_PatrolRig != null)
            {
                m_PatrolRig.PatrolTriggerEnter -= OnPatrolTriggerEntered;
                m_PatrolRig.PatrolTriggerExit -= OnPatrolTriggerExited;
            }

            OnCharacterHit -= PlayHitSound;
            OnCharacterDeath -= PlayDeathSound;

            UnsubscribeFromEnemyColliders();
        }

        protected virtual void FixedUpdate()
        {
            // If we're not moving and don't need to start
            if (m_CurrentSpeed == 0.0f && m_TargetSpeed == 0.0f)
            {
                return;
            }

            float speedDifference = m_CurrentSpeed - m_TargetSpeed;

            // If we need to speed up
            if (speedDifference < float.Epsilon)
            {
                float accel = (m_TargetSpeed - m_CurrentSpeed) / Time.deltaTime;
                accel = Mathf.Min(accel, MaxAccelerationRate);
                m_CurrentSpeed += accel * Time.deltaTime;

                // Make sure the target speed is the ceiling
                m_CurrentSpeed = Mathf.Min(m_CurrentSpeed, m_TargetSpeed);
            }
            // If we need to slow down
            else if (speedDifference > float.Epsilon)
            {
                float decel = (m_CurrentSpeed - m_TargetSpeed) / Time.deltaTime;
                decel = Mathf.Min(decel, MaxBrakingRate);
                m_CurrentSpeed -= decel * Time.deltaTime;

                // Make sure the target speed is the floor
                m_CurrentSpeed = Mathf.Max(m_CurrentSpeed, m_TargetSpeed);
            }

            m_Rigidbody.MoveRotation(Quaternion.LookRotation(m_NewForward));
            m_Rigidbody.MovePosition(m_Rigidbody.position + (m_NewForward * m_CurrentSpeed * Time.deltaTime));
        }

        #endregion

        #region Initialization

        protected override void ValidateRequiredComponents()
        {
            base.ValidateRequiredComponents();

            m_BehaviorAgent = GetComponent<BehaviorGraphAgent>();

            m_EnemyColliders = GetComponentsInChildren<ParrotEnemyCollider>();

            SubscribeToEnemyColliders();
        }

        // Initializes default values of the player
        protected override void InitializeCharacter()
        {
            base.InitializeCharacter();

            m_BehaviorAgent.SetVariableValue(k_EnemyAgent, this);

            OnCharacterHit += PlayHitSound;
            OnCharacterDeath += PlayDeathSound;
        }

        void SubscribeToEnemyColliders()
        {
            foreach (ParrotEnemyCollider enemyCollider in m_EnemyColliders)
            {
                enemyCollider.EnemyColliderEvent += OnEnemyTriggerEntered;
            }
        }

        void UnsubscribeFromEnemyColliders()
        {
            foreach (ParrotEnemyCollider enemyCollider in m_EnemyColliders)
            {
                enemyCollider.EnemyColliderEvent -= OnEnemyTriggerEntered;
            }
        }

        #endregion

        #region Patrol Management

        public Vector3 GetNextPatrolPoint()
        {
            if (m_PatrolSpline == null)
            {
                return transform.position;
            }

            if (m_CurrentPatrolPointIndex + 1 >= m_PatrolSpline.Count)
            {
                m_CurrentPatrolPointIndex = 0;
            }
            else
            {
                m_CurrentPatrolPointIndex++;
            }
            return m_PatrolRig.transform.TransformPoint(m_PatrolSpline[m_CurrentPatrolPointIndex].Position);
        }

        public void InitializePatrol(Spline PatrolSpline, ParrotEnemyPatrolRig PatrolRig)
        {
            m_PatrolSpline = PatrolSpline;
            m_PatrolRig = PatrolRig;

            // Initialize the behavior graph with the first patrol point
            m_BehaviorAgent.SetVariableValue(k_NextPatrolPosition, GetNextPatrolPoint());

            if (m_PatrolRig != null)
            {
                m_PatrolRig.PatrolTriggerEnter += OnPatrolTriggerEntered;
                m_PatrolRig.PatrolTriggerExit += OnPatrolTriggerExited;
            }
        }

        #endregion

        #region Event Methods

        protected void OnPatrolTriggerEntered(Collider other)
        {
            if (other.GetComponent<ParrotPlayerCharacter>())
            {
                m_BehaviorAgent.SetVariableValue(k_IsPlayerInPatrolVolume, true);
            }
        }
        protected void OnPatrolTriggerExited(Collider other)
        {
            if (other.GetComponent<ParrotPlayerCharacter>())
            {
                m_BehaviorAgent.SetVariableValue(k_IsPlayerInPatrolVolume, false);
            }
        }
        protected virtual void OnEnemyTriggerEntered(bool IsWeapon, ParrotPlayerCharacter player)
        {
            if (IsDead())
            {
                return;
            }

            player.HitCharacterWithLaunchForce(BodyKnockbackForce * Vector3.Normalize(player.GetPosition() - GetPosition()));
        }

        #endregion

        #region Effects

        protected void PlayHitEffect()
        {
            HitVFX?.Play();
        }

        protected void PlayHitSound()
        {
            // No hit sound if we're dead
            if (IsDead())
            {
                return;
            }

            ParrotAudioController.Instance.PlayRandomGameplaySFX(HitSounds);
        }

        protected void PlayDeathSound()
        {
            ParrotAudioController.Instance.PlayRandomGameplaySFX(DeathSounds);
        }

        #endregion

        #region Behavior Movement

        public void UpdateSpeedAndRotation(float newSpeed, Vector3 newForward)
        {
            m_TargetSpeed = newSpeed;
            m_NewForward = newForward;
        }

        public float GetCurrentSpeed()
        {
            return m_CurrentSpeed;
        }

        public Vector3 GetPosition()
        {
            if (m_Rigidbody == null)
            {
                return Vector3.negativeInfinity;
            }

            return m_Rigidbody.position;
        }

        #endregion
    }
}
