///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using Unity.Cinemachine;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Custom version of CinemachinePositionComposer with tweaks made for Parrot.
    ///</summary>

    [AddComponentMenu("Cinemachine/Procedural/Position Control/Parrot Position Composer")]
    [SaveDuringPlay]
    [DisallowMultipleComponent]
    [CameraPipeline(CinemachineCore.Stage.Body)]
    [RequiredTarget(RequiredTargetAttribute.RequiredTargets.Tracking)]
    public class ParrotPositionComposer : CinemachineComponentBase
        , CinemachineFreeLookModifier.IModifiablePositionDamping
        , CinemachineFreeLookModifier.IModifiableDistance
        , CinemachineFreeLookModifier.IModifiableComposition
    {
        /// <summary>The distance along the camera axis that will be maintained from the target</summary>
        [Header("Camera Position")]
        [Tooltip("The distance along the camera axis that will be maintained from the target")]
        public float CameraDistance = 10f;

        /// <summary>The camera will not move along its z-axis if the target is within
        /// this distance of the specified camera distance</summary>
        [Tooltip("The camera will not move along its z-axis if the target is within "
            + "this distance of the specified camera distance")]
        public float DeadZoneDepth = 0;

        /// <summary>Settings for screen-space composition</summary>
        [Header("Composition")]
        [HideFoldout]
        public ScreenComposerSettings Composition = ScreenComposerSettings.Default;

        /// <summary>Force target to center of screen when this camera activates.  
        /// If false, will clamp target to the edges of the dead zone</summary>
        [Tooltip("Force target to center of screen when this camera activates.  If false, will "
            + "clamp target to the edges of the dead zone")]
        public bool CenterOnActivate = true;

        /// <summary>
        /// Offset from the target object (in target-local co-ordinates).  The camera will attempt to
        /// frame the point which is the target's position plus this offset.  Use it to correct for
        /// cases when the target's origin is not the point of interest for the camera.
        /// </summary>
        [Header("Target Tracking")]
        [Tooltip("Offset from the target object (in target-local co-ordinates).  "
            + "The camera will attempt to frame the point which is the target's position plus "
            + "this offset.  Use it to correct for cases when the target's origin is not the "
            + "point of interest for the camera.")]
        public Vector3 TargetOffset;

        /// <summary>How aggressively the camera tries to follow the target in screen space.
        /// Small numbers are more responsive, rapidly orienting the camera to keep the target in
        /// the dead zone. Larger numbers give a more heavy slowly responding camera.
        /// Using different vertical and horizontal settings can yield a wide range of camera behaviors.</summary>
        [Tooltip("How aggressively the camera tries to follow the target in the screen space. "
            + "Small numbers are more responsive, rapidly orienting the camera to keep the target in "
            + "the dead zone. Larger numbers give a more heavy slowly responding camera. Using different "
            + "vertical and horizontal settings can yield a wide range of camera behaviors.")]
        public Vector3 Damping;

        /// <summary>This setting will instruct the composer to adjust its target offset based
        /// on the motion of the target.  The composer will look at a point where it estimates
        /// the target will be a little into the future.</summary>
        [FoldoutWithEnabledButton]
        public LookaheadSettings Lookahead;

        [SerializeField]
        [Range(-15.0f, 15.0f)]
        private float UpperWorldCutoff = 15.0f;

        [SerializeField]
        [Range(-15.0f, 15.0f)]
        private float LowerWorldCutoff = -1.0f;

        private const float kMinimumCameraDistance = 0.01f;

        /// <summary>State information for damping</summary>
        private Vector3 m_PreviousCameraPosition = Vector3.zero;

        private Vector3 m_PreviousTargetPosition = Vector3.negativeInfinity;
        internal PositionPredictor m_Predictor = new PositionPredictor(); // internal for tests
        private Quaternion m_prevRotation;

        // The player associated with this camera
        private ParrotPlayerCharacter m_PlayerCharacter;

        private bool m_InheritingPosition;
        private float m_GroundCutoffY;

        private void Reset()
        {
            TargetOffset = Vector3.zero;
            Lookahead = new LookaheadSettings();
            Damping = Vector3.one;
            CameraDistance = 10;
            Composition = ScreenComposerSettings.Default;
            DeadZoneDepth = 0;
            CenterOnActivate = true;
        }

        private void OnValidate()
        {
            Damping.x = Mathf.Max(0, Damping.x);
            Damping.y = Mathf.Max(0, Damping.y);
            Damping.z = Mathf.Max(0, Damping.z);
            CameraDistance = Mathf.Max(kMinimumCameraDistance, CameraDistance);
            DeadZoneDepth = Mathf.Max(0, DeadZoneDepth);
            Composition.Validate();
        }

        ScreenComposerSettings CinemachineFreeLookModifier.IModifiableComposition.Composition
        {
            get => Composition;
            set => Composition = value;
        }

        Vector3 CinemachineFreeLookModifier.IModifiablePositionDamping.PositionDamping
        {
            get => Damping;
            set => Damping = value;
        }

        float CinemachineFreeLookModifier.IModifiableDistance.Distance
        {
            get => CameraDistance;
            set => CameraDistance = value;
        }

        /// <summary>True if component is enabled and has a valid Follow target</summary>
        public override bool IsValid => enabled && FollowTarget != null;

        /// <summary>Get the Cinemachine Pipeline stage that this component implements.
        /// Always returns the Body stage</summary>
        public override CinemachineCore.Stage Stage => CinemachineCore.Stage.Body;

        /// <summary>FramingTransposer algorithm takes camera orientation as input, 
        /// so even though it is a Body component, it must apply after Aim</summary>
        public override bool BodyAppliesAfterAim => true;

        /// <summary>Internal API for inspector</summary>
        internal Vector3 TrackedPoint { get; private set; }

        /// <summary>This is called to notify the user that a target got warped,
        /// so that we can update its internal state to make the camera
        /// also warp seamlessly.</summary>
        /// <param name="target">The object that was warped</param>
        /// <param name="positionDelta">The amount the target's position changed</param>
        public override void OnTargetObjectWarped(Transform target, Vector3 positionDelta)
        {
            base.OnTargetObjectWarped(target, positionDelta);
            if (target == FollowTarget)
            {
                m_PreviousCameraPosition += positionDelta;
                m_Predictor.ApplyTransformDelta(positionDelta);
            }
        }

        /// <summary>
        /// Force the virtual camera to assume a given position and orientation
        /// </summary>
        /// <param name="pos">World-space position to take</param>
        /// <param name="rot">World-space orientation to take</param>
        public override void ForceCameraPosition(Vector3 pos, Quaternion rot)
        {
            base.ForceCameraPosition(pos, rot);
            m_PreviousCameraPosition = pos;
            m_prevRotation = rot;
        }

        /// <summary>
        /// Report maximum damping time needed for this component.
        /// </summary>
        /// <returns>Highest damping setting in this component</returns>
        public override float GetMaxDampTime() => Mathf.Max(Damping.x, Mathf.Max(Damping.y, Damping.z));

        /// <summary>Notification that this virtual camera is going live.
        /// Base class implementation does nothing.</summary>
        /// <param name="fromCam">The camera being deactivated.  May be null.</param>
        /// <param name="worldUp">Default world Up, set by the CinemachineBrain</param>
        /// <param name="deltaTime">Delta time for time-based effects (ignore if less than or equal to 0)</param>
        /// <returns>True if the vcam should do an internal update as a result of this call</returns>
        public override bool OnTransitionFromCamera(
            ICinemachineCamera fromCam, Vector3 worldUp, float deltaTime)
        {
            if (fromCam != null
                && (VirtualCamera.State.BlendHint & CameraState.BlendHints.InheritPosition) != 0
                && !CinemachineCore.IsLiveInBlend(VirtualCamera))
            {
                m_PreviousCameraPosition = fromCam.State.RawPosition;
                m_prevRotation = fromCam.State.RawOrientation;
                m_InheritingPosition = true;
                return true;
            }
            return false;
        }

        // Convert from screen coords to normalized orthographic distance coords
        private Rect ScreenToOrtho(Rect rScreen, float orthoSize, float aspect)
        {
            var r = new Rect();
            r.yMax = 2 * orthoSize * ((1f - rScreen.yMin) - 0.5f);
            r.yMin = 2 * orthoSize * ((1f - rScreen.yMax) - 0.5f);
            r.xMin = 2 * orthoSize * aspect * (rScreen.xMin - 0.5f);
            r.xMax = 2 * orthoSize * aspect * (rScreen.xMax - 0.5f);
            return r;
        }

        private Vector3 OrthoOffsetToScreenBounds(Vector3 targetPos2D, Rect screenRect)
        {
            // Bring it to the edge of screenRect, if outside.  Leave it alone if inside.
            var delta = Vector3.zero;
            if (targetPos2D.x < screenRect.xMin)
                delta.x += targetPos2D.x - screenRect.xMin;
            if (targetPos2D.x > screenRect.xMax)
                delta.x += targetPos2D.x - screenRect.xMax;
            if (targetPos2D.y < screenRect.yMin)
                delta.y += targetPos2D.y - screenRect.yMin;
            if (targetPos2D.y > screenRect.yMax)
                delta.y += targetPos2D.y - screenRect.yMax;

            return delta;
        }

        /// <summary>Positions the virtual camera according to the transposer rules.</summary>
        /// <param name="curState">The current camera state</param>
        /// <param name="deltaTime">Used for damping.  If less than 0, no damping is done.</param>
        public override void MutateCameraState(ref CameraState curState, float deltaTime)
        {
            var lens = curState.Lens;
            var followTargetPosition = FollowTargetPosition + (FollowTargetRotation * TargetOffset);
            bool previousStateIsValid = deltaTime >= 0 && VirtualCamera.PreviousStateIsValid;
            if (!previousStateIsValid || VirtualCamera.FollowTargetChanged)
                m_Predictor.Reset();
            if (!previousStateIsValid)
            {
                m_PreviousCameraPosition = curState.RawPosition;
                m_prevRotation = curState.RawOrientation;
                if (!m_InheritingPosition && CenterOnActivate)
                {
                    m_PreviousCameraPosition = FollowTargetPosition
                        + (curState.RawOrientation * Vector3.back) * CameraDistance;
                }
            }
            if (!IsValid)
            {
                m_InheritingPosition = false;
                return;
            }

            var verticalFOV = lens.FieldOfView;

            TrackedPoint = followTargetPosition;
            if (Lookahead.Enabled && Lookahead.Time > Epsilon)
            {
                m_Predictor.Smoothing = Lookahead.Smoothing;
                m_Predictor.AddPosition(followTargetPosition, deltaTime);
                var delta = m_Predictor.PredictPositionDelta(Lookahead.Time);
                if (Lookahead.IgnoreY)
                    delta = delta.ProjectOntoPlane(curState.ReferenceUp);
                TrackedPoint = followTargetPosition + delta;
            }
            if (!curState.HasLookAt() || curState.ReferenceLookAt == FollowTargetPosition)
                curState.ReferenceLookAt = followTargetPosition;

            // Allow undamped camera orientation change
            Quaternion localToWorld = curState.RawOrientation;
            if (previousStateIsValid)
            {
                var q = localToWorld * Quaternion.Inverse(m_prevRotation);
                m_PreviousCameraPosition = TrackedPoint + q * (m_PreviousCameraPosition - TrackedPoint);
            }
            m_prevRotation = localToWorld;

            // Work in camera-local space
            var camPosWorld = m_PreviousCameraPosition;
            var worldToLocal = Quaternion.Inverse(localToWorld);
            var cameraPos = worldToLocal * camPosWorld;
            var targetPos = (worldToLocal * TrackedPoint) - cameraPos;
            var lookAtPos = targetPos;

            // Move along camera z
            var cameraOffset = Vector3.zero;
            float cameraMin = Mathf.Max(kMinimumCameraDistance, CameraDistance - DeadZoneDepth / 2);
            float cameraMax = Mathf.Max(cameraMin, CameraDistance + DeadZoneDepth / 2);

            float targetZ = Mathf.Min(targetPos.z, lookAtPos.z);
            if (targetZ < cameraMin)
                cameraOffset.z = targetZ - cameraMin;
            if (targetZ > cameraMax)
                cameraOffset.z = targetZ - cameraMax;

            // Move along the XY plane
            float screenSize = lens.Orthographic
                ? lens.OrthographicSize
                : Mathf.Tan(0.5f * verticalFOV * Mathf.Deg2Rad) * (targetZ - cameraOffset.z);
            var softGuideOrtho = ScreenToOrtho(Composition.DeadZoneRect, screenSize, lens.Aspect);
            if (!previousStateIsValid)
            {
                // No damping or hard bounds, just snap to central bounds, skipping the soft zone
                var rect = softGuideOrtho;
                if (CenterOnActivate && !m_InheritingPosition)
                    rect = new Rect(rect.center, Vector2.zero); // Force to center
                cameraOffset += OrthoOffsetToScreenBounds(targetPos, rect);
            }
            else
            {
                // Move it through the soft zone, with damping
                cameraOffset += OrthoOffsetToScreenBounds(targetPos, softGuideOrtho);
                cameraOffset = VirtualCamera.DetachedFollowTargetDamp(cameraOffset, Damping, deltaTime);

                // Make sure the real target (not the lookahead one) is still in the frame
                if (Composition.HardLimits.Enabled
                    && (deltaTime < 0 || VirtualCamera.FollowTargetAttachment > 1 - Epsilon))
                {
                    var hardGuideOrtho = ScreenToOrtho(Composition.HardLimitsRect, screenSize, lens.Aspect);
                    var realTargetPos = (worldToLocal * followTargetPosition) - cameraPos;
                    cameraOffset += OrthoOffsetToScreenBounds(
                        realTargetPos - cameraOffset, hardGuideOrtho);
                }
            }

            bool goToPreviousPosition = false;

            // When we're outside of world bounds, do not move the camera 
            if (TrackedPoint.y < LowerWorldCutoff || TrackedPoint.y > UpperWorldCutoff)
            {
                goToPreviousPosition = true;
            }
            else if (m_PlayerCharacter != null)
            {
                bool shouldAdjustY = false;

                // Check if the character is airborne 
                if (!m_PlayerCharacter.IsGrounded())
                {
                    if (m_PlayerCharacter.IsFalling())
                    {
                        // If we're falling and above our ground cutoff - we're likely falling from a jump
                        if (TrackedPoint.y > m_GroundCutoffY)
                        {
                            shouldAdjustY = true;
                        }
                    }
                    // If we're ascending and above our ground cutoff, wait until we've landed 
                    else if (TrackedPoint.y > m_GroundCutoffY)
                    {
                        shouldAdjustY = true;
                    }

                    if (shouldAdjustY)
                    {
                        float targetY = (worldToLocal.y * m_GroundCutoffY) - cameraPos.y;
                        Vector3 result = cameraOffset;
                        result.y = targetY;
                        result.y = OrthoOffsetToScreenBounds(result, softGuideOrtho).y;
                        result = VirtualCamera.DetachedFollowTargetDamp(result, Damping, deltaTime);

                        cameraOffset.y = result.y;
                    }
                }
                else
                {
                    UpdateGroundCutoff();
                }
            }
            else
            {
                // When we have no player, we should just go to the last good position
                goToPreviousPosition = true;
            }

            if (cameraOffset.x < 0 && !goToPreviousPosition)
            {
                cameraOffset.x = 0.0f;
            }

            if (goToPreviousPosition)
            {
                // Damp camera to last good position before
                var prevTargetPos = (worldToLocal * m_PreviousTargetPosition) - cameraPos;
                cameraOffset.x = 0.0f;
                cameraOffset.y = 0.0f;
                cameraOffset += OrthoOffsetToScreenBounds(prevTargetPos, softGuideOrtho);
                cameraOffset = VirtualCamera.DetachedFollowTargetDamp(cameraOffset, Damping, deltaTime);
            }

            curState.RawPosition = camPosWorld + localToWorld * cameraOffset;
            m_PreviousCameraPosition = curState.RawPosition;

            // When we're already using the previous position, do not update the previous position
            if (!goToPreviousPosition)
                m_PreviousTargetPosition = GetTargetPosition();

            m_InheritingPosition = false;
        }

        public void SetPlayerCharacter(ParrotPlayerCharacter playerCharacter)
        {
            if (m_PlayerCharacter != null)
            {
                m_PlayerCharacter.OnLanded -= OnPlayerLanded;
            }

            m_PlayerCharacter = playerCharacter;

            if (m_PlayerCharacter != null)
            {
                m_PlayerCharacter.OnLanded += OnPlayerLanded;
                UpdateGroundCutoff();
            }
        }

        private void OnPlayerLanded()
        {
            UpdateGroundCutoff();
        }

        private void UpdateGroundCutoff()
        {
            Vector3 newTarget = GetTargetPosition();
            m_GroundCutoffY = newTarget.y;
        }

        private Vector3 GetTargetPosition()
        {
            return m_PlayerCharacter.GetPosition() + (FollowTargetRotation * TargetOffset);
        }

        private void OnDestroy()
        {
            if (m_PlayerCharacter != null)
            {
                m_PlayerCharacter.OnLanded -= OnPlayerLanded;
            }
        }
    }
}
