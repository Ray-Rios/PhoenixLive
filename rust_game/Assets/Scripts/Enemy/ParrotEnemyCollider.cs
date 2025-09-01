///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Here we identify what kind of collider exists on this child GameObject of an enemy prefab and provide trigger events
    ///</summary>
    [RequireComponent(typeof(Collider))]
    public class ParrotEnemyCollider : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [SerializeField]
        [Tooltip("If the collider belongs to a weapon")]
        bool IsWeapon;

        Collider m_Collider;

        #endregion

        // Event to dispatch information about us and the player we've collided with
        public Action<bool, ParrotPlayerCharacter> EnemyColliderEvent;

        #region Unity Methods
        // Unity Methods

        private void Awake()
        {
            m_Collider = GetComponent<Collider>();
        }

        private void OnTriggerEnter(Collider other)
        {
            ParrotPlayerCharacter player = other.gameObject.GetComponent<ParrotPlayerCharacter>();
            {
                if (player != null)
                {
                    EnemyColliderEvent.Invoke(IsWeapon, player);
                }
            }
        }

        #endregion
    }
}
