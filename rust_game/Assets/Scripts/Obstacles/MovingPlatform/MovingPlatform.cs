///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Class that defines a moving platform that oscillates between its starting point and a defined end point
    ///</summary>
    [RequireComponent(typeof(Rigidbody))]
    public class MovingPlatform : MonoBehaviour
    {
        #region Attributes
        // Attributes
        [Header("References")]
        [SerializeField]
        [Required]
        [Tooltip("The empty gameobject used to author the endpoint of the platforms motion.")]
        private GameObject MoverEndPoint;

        [Header("Tunables")]
        [SerializeField]
        [Tooltip("The time in seconds the platform will take to move from its starting point to the end point.")]
        private float MoveDuration = 1.0f;

        [Header("Easing")]
        [SerializeField]
        [Tooltip("The easing function type to be used for easing the platforms position.")]
        private EasingFunctions.EasingFunctionType TargetEasingType = EasingFunctions.EasingFunctionType.EaseInOut;

        [SerializeField]
        [Tooltip("The exponent that controls the degree of the easing curve.")]
        private float BlendExponent = 2.0f;
        #endregion

        // The starting position used for easing the motion of the platform.
        private Vector3 m_StartPosition;
        // The ending position used for easing the motion of the platform.
        private Vector3 m_TargetPosition;
        // The alpha value we are using for timing of the ease, driven by DeltaTime
        // and divided by our MoveDuration.
        private float m_InterpolationAlpha;

        // The rigidbody which moves the platform 
        private Rigidbody m_Rigidbody; 

        // The delta between the previous frame position and current frame position
        public Vector3 Velocity { get; private set;}

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            m_Rigidbody = GetComponent<Rigidbody>(); 

            m_StartPosition = transform.position;
            m_TargetPosition = MoverEndPoint.transform.position;
        }

        /// <summary>
        /// FixedUpdate is called once per fixed framerate frame, after Update
        /// </summary>
        private void FixedUpdate()
        {
           UpdatePosition();   
        }
        #endregion
        
        void UpdatePosition()
        {
            m_InterpolationAlpha += Time.deltaTime;
            float clampedAlpha = Mathf.Clamp01(m_InterpolationAlpha / MoveDuration);
            Vector3 newPosition = EasingFunctions.Ease(m_StartPosition, m_TargetPosition, clampedAlpha, TargetEasingType, BlendExponent);
            Velocity = (newPosition - m_Rigidbody.position) / Time.deltaTime;
            m_Rigidbody.MovePosition(newPosition);

            if (Vector3.Distance(m_Rigidbody.position, m_TargetPosition) < float.Epsilon)
            {
                // Swap start and target positions and reset to move back the other direction
                Vector3 newStartPosition = m_TargetPosition;
                m_TargetPosition = m_StartPosition;
                m_StartPosition = newStartPosition;
                m_InterpolationAlpha = 0.0f;
            }
        }
    }
}
