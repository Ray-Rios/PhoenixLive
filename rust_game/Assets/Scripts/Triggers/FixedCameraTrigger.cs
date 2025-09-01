///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using Unity.Cinemachine;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Affixes the camera to a point when the player interacts with this trigger 
    ///</summary>
    public class FixedCameraTrigger : MonoBehaviour
    {
        // The brain used by the game camera 
        [SerializeField]
        [Required]
        private CinemachineBrain CinemachineBrain;

        // The camera used to follow the player 
        [SerializeField]
        [Required]
        private CinemachineCamera CinemachineFollowCamera;

        // The fixed camera in the world 
        [SerializeField]
        [Required]
        private CinemachineCamera FixedCamera;

        private ParrotPlayerCharacter m_CurrentPlayer;

        #region Unity Methods
        // Unity Methods

        void OnTriggerEnter(Collider other)
        {
            m_CurrentPlayer = other.gameObject.GetComponent<ParrotPlayerCharacter>();

            if (m_CurrentPlayer != null)
            {
                // Change virutal camera priority, triggering the blend 
                FixedCamera.Priority = 1;
                CinemachineFollowCamera.Priority = 0;
            }
        }

        void OnTriggerExit(Collider other)
        {
            ParrotPlayerCharacter player = other.gameObject.GetComponent<ParrotPlayerCharacter>();

            if (player != null && m_CurrentPlayer == player)
            {
                if (player.IsDead())
                {
                    return;
                }

                // Change virutal camera priority, triggering the blend 
                FixedCamera.Priority = 0;
                CinemachineFollowCamera.Priority = 1;
                m_CurrentPlayer = null;
            }
        }
        #endregion
    }
}
