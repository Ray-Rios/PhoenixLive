///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Sets the playback speed of the animator for the pirate on the main menu
    ///</summary>

    [RequireComponent(typeof(Animator))]
    public class MainMenuAnimationController : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [SerializeField]
        private float playbackSpeed = 0.5f;

        private Animator m_Animator;

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            m_Animator = GetComponent<Animator>();

            // Play idle at half speed in the main menu
            m_Animator.speed = playbackSpeed;
        }

        #endregion  
    }
}
