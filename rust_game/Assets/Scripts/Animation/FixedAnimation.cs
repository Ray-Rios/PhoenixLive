///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Poses an animator for animation 
    ///</summary>
    /// 

    [RequireComponent(typeof(Animator))]
    public class FixedAnimation : MonoBehaviour
    {
        #region Attributes

        // Attributes

        // The clip to pose to 
        [SerializeField]
        [Required]
        private AnimationClip TargetClip;

        // The playback position to pose to 
        [SerializeField]
        private float playbackPosition = 0.0f;

        private AnimatorOverrideController m_OverrideController;
        private Animator m_Animator;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void Start()
        {
            m_Animator = GetComponent<Animator>();
            m_Animator.speed = 0.0f;
            m_OverrideController = new AnimatorOverrideController(m_Animator.runtimeAnimatorController);

            m_OverrideController[m_Animator.GetCurrentAnimatorClipInfo(0)[0].clip.name] = TargetClip;
            m_Animator.runtimeAnimatorController = m_OverrideController;
            m_Animator.Play("BaseState", 0, playbackPosition);

        }
        #endregion

    }
}
