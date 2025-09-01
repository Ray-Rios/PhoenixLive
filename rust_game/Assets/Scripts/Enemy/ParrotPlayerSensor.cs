///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using Unity.Behavior;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// This class does a raycast to sense when the player is in line of sight and relays it to the Behavior Graph
    ///</summary>
    [RequireComponent(typeof(BehaviorGraphAgent))]
    public class ParrotPlayerSensor : MonoBehaviour
    {
        #region Attributes
        // Attributes
        [Header("Player Detection")]
        [Tooltip("The distance at which the player will be detected with the raycast.")]
        [SerializeField]
        [Range(0.0f, 500.0f)]
        float DetectionDistance = 3.0f;

        // The layermask we want to raycast against
        LayerMask m_LayerMask;

        // This enemy's behavior graph
        BehaviorGraphAgent m_Agent;

        const string k_TargetPlayer = "TargetPlayer";
        const string k_Player = "Player";

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            ValidateDependencies();
        }

        /// <summary>
        /// Update is called once per frame
        /// </summary>
        private void Update()
        {
            DetectPlayer();
        }

        #endregion

        #region Initialization

        void ValidateDependencies()
        {
            m_Agent = GetComponent<BehaviorGraphAgent>();
            m_LayerMask = LayerMask.GetMask(k_Player);
        }

        #endregion

        private void DetectPlayer()
        {
            RaycastHit hit;

            if (Physics.Raycast(transform.position, transform.forward, out hit, DetectionDistance, m_LayerMask))
            {
                ParrotPlayerCharacter player = hit.transform.gameObject.GetComponent<ParrotPlayerCharacter>();
                if (player != null && !player.IsDead())
                {
                    m_Agent.SetVariableValue(k_TargetPlayer, player);
                    return;
                }
            }
            m_Agent.SetVariableValue<ParrotPlayerCharacter>(k_TargetPlayer, null);
        }
    }
}
