///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;
using UnityEngine.Splines;

namespace SecretDimension
{
    ///<summary>
    /// The Patrol Rig defines a spline path for the enemy to patrol. 
	/// It also spawns and intitializes the patrolling enemy.
    ///</summary>
    [RequireComponent(typeof(SplineContainer))]
    [RequireComponent(typeof(Collider))]
    public class ParrotEnemyPatrolRig : MonoBehaviour
    {
        #region Attributes

        // Attributes
        [SerializeField]
        [Required]
        [Tooltip("The prefab of the enemy this patrol rig should spawn and initialize.")]
        private GameObject EnemyPrefab;

        // The spline authored on this patrol rig for an enemy patrol
        SplineContainer m_PatrolSpline;

        #endregion

        #region Events

        // Events for sending data about the Patrol trigger receiving overlaps
        public Action<Collider> PatrolTriggerEnter;
        public Action<Collider> PatrolTriggerExit;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void Awake()
        {
            ValidateRequiredComponents();

            bool HasPatrolPoints = m_PatrolSpline.Spline.Count > 0;
            bool HasValidPatrol = m_PatrolSpline.Spline.Count > 1;

            if (!HasPatrolPoints)
            {
                Debug.LogWarning("Patrol rig is missing patrol points. Have you authored points on the spline?");
            }
            else if (!HasValidPatrol)
            {
                Debug.LogWarning("Patrol rig only has a single patrol point. The enemy will spawn at this point and not patrol. Did you mean to add more points?");
            }


            Vector3 spawnPosition = transform.position;
            Quaternion spawnRotation = transform.rotation;
            if (HasPatrolPoints)
            {
                spawnPosition = transform.TransformPoint(m_PatrolSpline.Spline[0].Position);
                spawnRotation = m_PatrolSpline.Spline[0].Rotation;

            }

            GameObject enemy = Instantiate(EnemyPrefab, spawnPosition, spawnRotation);
            ParrotEnemyCharacterBase enemyCharacter = enemy.GetComponent<ParrotEnemyCharacterBase>();
            if (enemyCharacter == null)
            {
                return;
            }

            enemyCharacter.InitializePatrol(m_PatrolSpline.Spline, this);
        }
        private void OnTriggerEnter(Collider Other)
        {
            PatrolTriggerEnter?.Invoke(Other);
        }
        private void OnTriggerExit(Collider Other)
        {
            PatrolTriggerExit?.Invoke(Other);
        }

        #endregion

        #region Initialization

        void ValidateRequiredComponents()
        {
            m_PatrolSpline = GetComponent<SplineContainer>();
        }

        #endregion
    }
}
