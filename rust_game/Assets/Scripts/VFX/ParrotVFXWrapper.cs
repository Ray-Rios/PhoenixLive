///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.VFX;

namespace SecretDimension
{
    ///<summary>
    /// A basic wrapper for VisualEffect prefabs to allow some self-management
    ///</summary>
    [RequireComponent(typeof(VisualEffect))]
    public class ParrotVFXWrapper : MonoBehaviour
    {
        #region Attributes
        // Attributes
        [Header("VFX")]
        [Tooltip("If set to detatch, the VFX gameobject will unparent itself so it remains fixed at its starting position in world space during playback.")]
        [SerializeField]
        private bool DetatchDuringEffect = false;

        [SerializeField]
        [Tooltip("If set to destroy, the VFX gameobject will destroy itself after playback.")]
        private bool DestroyAfterEffect = false;

        private VisualEffect m_VisualEffect;
        private Transform m_Parent;
        private Vector3 m_OriginalLocalPosition;
        private Quaternion m_OriginalLocalRotation;

        #endregion

        private void Awake()
        {
            // Save our original values
            m_VisualEffect = GetComponent<VisualEffect>();
            m_Parent = transform.parent;
            m_OriginalLocalPosition = transform.localPosition;
            m_OriginalLocalRotation = transform.localRotation;
        }

        public void Play()
        {
            if (isActiveAndEnabled)
            {
                Stop();

                if (DetatchDuringEffect)
                {
                    // Reposition the VFX
                    transform.SetParent(m_Parent);
                    transform.localPosition = m_OriginalLocalPosition;
                    transform.localRotation = m_OriginalLocalRotation;
                    transform.SetParent(null);
                }

                m_VisualEffect.Play();
                return;
            }

            gameObject.SetActive(true);

            if (DetatchDuringEffect)
            {
                transform.SetParent(null);
            }
        }

        public void Stop()
        {
            m_VisualEffect.Stop();
        }

        private void Disable()
        {
            if (DestroyAfterEffect)
            {
                Destroy(gameObject);
                return;
            }
            if (DetatchDuringEffect)
            {
                transform.SetParent(m_Parent);
                transform.localPosition = m_OriginalLocalPosition;
                transform.localRotation = m_OriginalLocalRotation;
            }

            gameObject.SetActive(false);
        }

        /// <summary>
        /// Update is called once per frame
        /// </summary>
        private void Update()
        {
            if (m_VisualEffect == null)
            {
                return;
            }

            // If our emitters are off and all our particles are dead, stop. No, there's no other way to know we're finished.
            if (!m_VisualEffect.HasAnySystemAwake() && m_VisualEffect.aliveParticleCount == 0)
            {
                Disable();
            }
        }

    }
}
