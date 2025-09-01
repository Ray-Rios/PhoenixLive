///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// The player character class is the pawn in the world. Controlled by the player controller. 
    ///</summary>
    public class ParrotPlayerCharacter : ParrotCharacterBase
    {
        #region Attributes
        // Attributes

        #region References 

        // The controller which interacts with the character's animator 
        private ParrotPlayerAnimationController m_AnimationController;

        // Changes the character outline color in the post process
        private OutlineColorChanger m_OutlineColorChanger;

        #endregion

        #region Collision Settings 

        [Header("Collision")]

        [Tooltip("Physics layers checked to consider the player grounded")]
        [SerializeField]
        private LayerMask GroundCheckLayers = -1;

        [Tooltip("Physics layer for moving platforms")]
        [SerializeField]
        private string MovingPlatformCheckLayer;

        [Tooltip("Physics layers checked to see if they can hit a ceiling")]
        [SerializeField]
        private LayerMask CeilingCheckLayers = -1;

        [Tooltip("Physics layers to ignore when invulnerable")]
        [SerializeField]
        private string[] InvulnerabilityLayers;

        [Tooltip("Distance from the bottom of the character capsule to test for grounded")]
        [SerializeField]
        [Range(0.0f, 1.0f)]
        private float GroundCheckDistance = 0.05f;

        [Tooltip("Distance from the bottom of the character capsule to test for keeping the player on the ground")]
        [SerializeField]
        [Range(0.0f, 1.0f)]
        private float GroundSnapDistance = 0.01f;

        [Tooltip("Distance from the top of the character capsule to test for grounded")]
        [SerializeField]
        [Range(0.0f, 1.0f)]
        private float CeilingCheckDistance = 0.05f;

        [Tooltip("The distance from bottom of the character capsule to test if the character is about to land so that the charatcer can start animating out of jump")]
        [SerializeField]
        [Range(0.0f, 10.0f)]
        private float AnimationLandingCheckDistance = 1.5f;

        [Tooltip("A width around the character used for collision contacts around the character")]
        [SerializeField]
        [Range(0.0f, 1.0f)]
        private float SkinWidth = 0.08f;

        [Tooltip("The allowed angle of slopes that the player can stand on. Note that when the character lands on angles above this, they will not count as grounded")]
        [SerializeField]
        [Range(0.0f, 90.0f)]
        private float SlopeLimit = 45.0f;

        // The duration to wait before applying grounding after the character has just jumped
        const float k_JumpGroundingPreventionTime = 0.2f;

        // The distance to check to the ground when the character is coming from an airborne position
        const float k_GroundCheckDistanceInAir = 0.07f;

        // When true, the character is on the ground 
        private bool m_IsGrounded;

        // When true, the character has hit a ceiling 
        private bool m_HitCeiling;

        // The normal of the last touched ground surface
        private Vector3 m_GroundNormal;

        #endregion

        #region Movement 

        // The maximum speed the character can move on the X-Axis
        [Header("Lateral Movement")]
        [Tooltip("The maximum speed the player can move on the X-axis")]
        [SerializeField]
        [Range(0.0f, 500.0f)]
        private float MaxLateralSpeed = 6.0f;

        [Tooltip("Max acceleration (rate of change of velocity)")]
        [SerializeField]
        private float MaxAcceleration = 7.5f;

        [Tooltip("Affects movement control on the ground. Higher values allow faster changes in direction")]
        [SerializeField]
        [Range(0.0f, 500.0f)]
        private float GroundFriction = 2.0f;

        [Tooltip("Affects movement control in the air. Higher values allow faster changes in direction")]
        [SerializeField]
        [Range(0.0f, 500.0f)]
        private float AirFriction = 0.0f;

        [Tooltip("Deceleration when walking and not applying acceleration. This is a constant opposing force that directly lowers velocity by a constant value.")]
        [SerializeField]
        [Range(0.0f, 500.0f)]
        private float GroundBrakingDeceleration = 12.0f;

        [Tooltip("Deceleration when falling and not applying acceleration. This is a constant opposing force that directly lowers velocity by a constant value.")]
        [SerializeField]
        [Range(0.0f, 500.0f)]
        private float AirBrakingDeceleration = 10.0f;

        [Tooltip("Factor used to multiply actual value of friction used when braking.")]
        [SerializeField]
        [Range(0.0f, 50.0f)]
        private float BrakingFrictionFactor = 2.0f;

        // Note that this does NOT ignore friction from Unity's physics materials!
        // Tune value accordingly
        [Tooltip("Friction (drag) coefficient applied when braking (whenever Acceleration = 0, or if character is exceeding max speed); actual value used is this multiplied by BrakingFrictionFactor.")]
        [SerializeField]
        [Range(0.0f, 500.0f)]
        private float BrakingFriction = 0.0f;

        [Tooltip("When airborne, amount of lateral movement control available to the character. 0 = no control, 1 = full control at Max Lateral Speed.")]
        [SerializeField]
        [Range(0.0f, 1.0f)]
        private float AirControlMultiplier = 0.5f;

        [Header("Vertical Movement")]
        [Tooltip("The height of the character's jump apex. Reached by holding the jump key the maximum amount of time")]
        [SerializeField]
        [Range(1.0f, 1000.0f)]
        private float ApexJumpHeight = 3.35f;

        [Tooltip("The Amount of time that the player must hold the button to reach the apex of the jump")]
        [SerializeField]
        [Range(0.1f, 5.0f)]
        private float JumpMaxHoldTime = 0.5f;

        [Tooltip("The amount of time that the player has to input a jump input after walking off a ledge")]
        [SerializeField]
        [Range(0.0f, 5.0f)]
        private float CoyoteTime = 0.25f;

        [Tooltip("The default scale at which gravity is applied to the player based on the project settings physics gravity")]
        [SerializeField]
        [Range(1.0f, 10.0f)]
        private float DefaultGravityScale = 1.0f;

        [Tooltip("A multiplier that increases gravity if the button is released early so the apex is reached more quickly.")]
        [SerializeField]
        [Range(1.0f, 50.0f)]
        private float EarlyReleaseGravityMultiplier = 2.0f;

        [Tooltip("The gravity scale we apply when the player reaches the apex. We ease from this to the max gravity based on the easing type.")]
        [SerializeField]
        [Range(1.0f, 10.0f)]
        private float FallBeginGravityScale = 3.0f;

        [Tooltip("The maximum gravity scale we will reach after easing from the beginning fall gravity.")]
        [SerializeField]
        [Range(1.0f, 10.0f)]
        private float FallMaxGravityScale = 5.0f;

        [Tooltip("The time our blend will take to transition from the FallBeginGravityScale to FallMaxGravityScale.")]
        [SerializeField]
        [Range(0.1f, 10f)]
        private float FallGravityBlendTime = 0.25f;

        [Tooltip("The type of easing to apply when interpolating gravity post jump apex or falling")]
        [SerializeField]
        private EasingFunctions.EasingFunctionType GravityEasingType = EasingFunctions.EasingFunctionType.EaseIn;

        [Tooltip("The time our blend will take to transition from the FallBeginGravityScale to FallMaxGravityScale.")]
        [SerializeField]
        [Range(0.0f, 10.0f)]
        private float FallGravityEaseBlend = 2.0f;

        // The velocity that this character is moving each frame
        private Vector3 m_CharacterVelocity;

        // The current scale at which gravity is being applied to this character
        private float m_CurrentGravityScale;

        // The movement input on the X-axis
        private float m_AnalogInputScalar;

        // The amount of time that the character has been airborne 
        private float m_AirborneTime;

        // When true, the character is about to land on the ground so the animation should start transitioning 
        private bool m_AboutToLand;

        // The number of times a jump has been performed before touching ground 
        private int m_JumpCount = 0;

        // The amount of time the character has been in a falling descent
        private float m_FallTime;

        // When true, gravity is being scaled by from a fall
        private bool m_ApplyFallingGravity;

        // When true, the jump input is being held 
        private bool m_JumpPressed;

        // When true, the jump input is being processed
        private bool m_JumpInputActive;

        // When true, applies early release gravity 
        private bool m_ApplyEarlyReleaseGravityMultiplier;

        // When true, a newly performed jump will not reset the jump state
        private bool m_IgnoreInitialJumpStateReset;

        // The timestamp of the last started jump 
        private float m_LastTimeJumped;

        // The half height of the capsule 
        private float m_CapsuleHalfHeight;

        // The quarter height of the capsule
        private float m_CapsuleQuarterheight;

        // The current allowed max lateral speed the character can move 
        private float m_CurrentMaxLateralSpeed;

        // The current allowed max acceleration the character can use
        private float m_CurrentMaxAcceleration;

        // Used for attaching the player to moving surfaces 
        private MovingPlatform m_MovingGround;

        // The cached velocity of the moving ground the player is standing on from the previous update
        // we use this to correct the velocity basis for our calculations on the next update
        private float m_MovingGroundVelocity;

        private Vector3 m_PendingLaunchVelocity;

        private bool m_WasLaunched;

        #endregion

        #region  Events 

        // Invoked when hitpoints are added to the player's health 
        public Action OnHitPointsAdded;

        // Invoked when this player has crossed a victory boundary
        public Action OnVictoryTriggered;

        // Invoked when this player has defeated the boss 
        public Action<float> OnBossDefeated;

        // Invoked when this player has just landed on the ground
        public Action OnLanded;

        #endregion

        #region Combat

        [Header("Combat")]
        [Tooltip("A duration to stun the player when hit. Zero will prevent any stun.")]
        [SerializeField]
        [Range(0.0f, 100.0f)]
        private float HitStunDuration = 0.0f;

        [Tooltip("When true, the player is allowed to be stunned mid-air.")]
        [SerializeField]
        private bool StunMidAir = false;

        [Tooltip("A duration that the player is invulnerable after being hit.")]
        [SerializeField]
        [Range(0.0f, 100.0f)]
        private float HitInvulnerabilityDuration = 0.0f;

        // When true, the player cannot be hit by enemies 
        private bool m_HitInvulnerable;

        // When true, the player cannot move
        private bool m_HitStunned;

        #endregion

        #region Effects

        [Header("VFX")]

        [Tooltip("The VFX for when the player lands on the ground")]
        [SerializeField]
        private ParrotVFXWrapper LandedVFX;

        [Header("SFX")]

        [Tooltip("The pool of sounds that can be player when the player starts a jump")]
        [SerializeField]
        private List<AudioClip> JumpStartSounds;

        [Tooltip("The sound to play when the player lands")]
        [SerializeField]
        private AudioClip JumpLandSound;

        [Tooltip("The pool of sounds that can be played when the player is hit")]
        [SerializeField]
        private List<AudioClip> HitSounds;

        [Tooltip("The sound to play when the character dies")]
        [SerializeField]
        private AudioClip DeathSound;

        [Tooltip("The sound to play when the player jumps off an enemy")]
        [SerializeField]
        private AudioClip EnemyJumpSound;

        [Tooltip("The pool of sounds to play for the player's footsteps")]
        [SerializeField]
        private List<AudioClip> FootstepSounds;

        #endregion

        #endregion

        #region Unity Methods
        // Unity Methods

        // Called after Awake
        private void Start()
        {
            // Check to see if the character's starting on the ground
            InitialGroundCheck();
        }

        // Fixed update is called once per frame after update
        private void FixedUpdate()
        {
            PhysicsCeilingCheck();
            PhysicsGroundCheck();
            ProcessGravityScaling();
            UpdateAnimator();
            ApplyCharacterMovementForces(Time.deltaTime);
        }

        protected override void OnDestroy()
        {
            m_AnimationController.FootstepEvent -= PlayFootstepSound;
            base.OnDestroy();
        }

        #endregion

        #region Initialization 

        // Gets all the expected components from the hierarchy
        protected override void ValidateRequiredComponents()
        {
            base.ValidateRequiredComponents();
            m_OutlineColorChanger = GetComponent<OutlineColorChanger>();
            m_AnimationController = GetComponentInChildren<ParrotPlayerAnimationController>();

            if (!m_OutlineColorChanger)
            {
                Debug.LogError("Outline color changer not found! ", this);
            }

            if (!m_AnimationController)
            {
                Debug.LogError("Parrot Animation Controller not found on child ", this);
            }
        }

        // Initializes default values of the player
        protected override void InitializeCharacter()
        {
            base.InitializeCharacter();

            // Set property defaults 
            m_CurrentMaxLateralSpeed = MaxLateralSpeed;
            m_CurrentMaxAcceleration = MaxAcceleration;
            m_CurrentGravityScale = DefaultGravityScale;
            m_CapsuleHalfHeight = m_Capsule.height / 2.0f;
            m_CapsuleQuarterheight = m_Capsule.height / 4.0f;

            m_AnimationController.FootstepEvent += PlayFootstepSound;
        }

        #endregion

        #region Movement

        // Called by the player controller to update this character's movement direction 
        public void UpdateMovementInputScalar(float input)
        {
            if (m_Rigidbody == null)
            {
                return;
            }

            if (m_HitStunned || IsDead())
            {
                return;
            }

            // Update input scalar
            // Note that the camera is rotated 180 degrees in our levels so we invert our input scalar
            m_AnalogInputScalar = -input;

            // Update character rotation instantly based on movement direction 
            if (m_AnalogInputScalar > 0)
            {
                // Face right
                m_Rigidbody.MoveRotation(Quaternion.Euler(Vector3.zero));
            }
            else if (m_AnalogInputScalar < 0)
            {
                // Face left 
                m_Rigidbody.MoveRotation(Quaternion.Euler(0, 180.0f, 0));
            }
        }

        private void ClearInputValues()
        {
            m_AnalogInputScalar = 0.0f;
        }

        // Called by the player controller to inform this character a jump was pressed
        public void StartJumpInput()
        {
            // Track that the input is active even if don't jump
            m_JumpPressed = true;

            if (!CanJump())
            {
                return;
            }

            DoJump();
        }

        // Called by the player controller to inform this character a jump input is released 
        public void StopJumpInput()
        {
            m_JumpPressed = false;
            m_JumpInputActive = false;

            if (!m_IsGrounded && !m_ApplyFallingGravity)
            {
                m_ApplyEarlyReleaseGravityMultiplier = true;
            }
        }

        // When true, the player is allowed to jump 
        private bool CanJump()
        {
            if (IsDead() || m_HitStunned || m_JumpCount > 0)
            {
                return false;
            }

            if (m_IsGrounded)
            {
                return true;
            }

            if (!m_IsGrounded && m_AirborneTime <= CoyoteTime)
            {
                return true;
            }

            return false;
        }

        public bool CanPerformEnemyJump()
        {
            // If the player is dead, they can't jump on an enemy
            if (IsDead())
            {
                return false;
            }

            return true;
        }

        // Performs a jump 
        private void DoJump()
        {
            ClearMovingGround();

            if (!m_IgnoreInitialJumpStateReset)
            {
                // Reset jump state variables in case we're coming from coyote time
                m_AirborneTime = 0.0f;
                m_FallTime = 0.0f;
                m_ApplyFallingGravity = false;
                m_ApplyEarlyReleaseGravityMultiplier = false;
            }

            // The time to reach the apex of our jump is always tied to the length of time the player's allowed to hold jump 
            float timeToApex = JumpMaxHoldTime;
            float g = Mathf.Abs(Physics.gravity.y);

            // We start with a couple design parameters: 
            // - The apex jump height
            // - The Jump Max Hold Time which is the same as the time it takes to reach the apex

            // Using Newton's Second Law of Motion, Force = Mass * Acceleration, 
            // we can calculate the gravity scale and initial force needed to reach a specific height in a fixed amount of time. 

            // Acceleration is the rate of change with respect to time. Utilizing acceleration due to gravity with respect to our jump apex time, 
            // we can integrate the equation and then calculate the needed jump force. 
            // 1. Time = Force / Gravity
            // 2. Force = Time * Gravity
            float f = timeToApex * g;

            // Using the newly calculated jump force, we can calculate the height you will reach given gravity = 1
            // We can again integrate for height and use the result to scale our jump force. 
            // 1. Force = Sqrt(2 * Gravity * Height)
            // 2. Height = Force ^ 2 / 2 * Gravity
            float h = f * f / (2.0f * g);

            // Calculate the scale based on the desired height 
            float jumpHeightGravityScale = ApexJumpHeight / h;

            // Add the jump force to our tracked velocity
            // This will sum later in fixed update with gravity, braking, etc. 
            float targetJumpSpeed = f * jumpHeightGravityScale;
            float ySpeed = Mathf.Max(m_Rigidbody.linearVelocity.y, targetJumpSpeed);
            m_CharacterVelocity.y = ySpeed;

            // Scale the gravity based on our jump 
            m_CurrentGravityScale = jumpHeightGravityScale;

            // Update our state tracking variables 
            m_JumpInputActive = true;
            m_IsGrounded = false;
            m_JumpCount++;
            m_LastTimeJumped = Time.time;

            // Play SFX
            PlayJumpStartSound();
        }

        // Returns true if the enemy jump is performed successfully
        public bool DoEnemyJump()
        {
            if (!CanPerformEnemyJump())
            {
                return false;
            }

            m_JumpCount = 0;

            if (m_JumpPressed || m_JumpInputActive)
            {
                m_CurrentGravityScale = DefaultGravityScale;
            }
            else
            {
                m_IgnoreInitialJumpStateReset = true;
            }

            PlayEnemyJumpSound();

            DoJump();

            return true;
        }

        public bool IsFalling()
        {
            return m_Rigidbody.linearVelocity.y < 0.0f;
        }

        public bool IsGrounded()
        {
            return m_IsGrounded;
        }

        public Vector3 GetVelocity()
        {
            return m_Rigidbody.linearVelocity;
        }

        // Returns the scaled gravity on the Y-axis for this character
        private float GetScaledGravityY()
        {
            return Physics.gravity.y * m_CurrentGravityScale;
        }

        // Moves the character 
        private void ApplyCharacterMovementForces(float deltaTime)
        {
            // Calculate our velocity
            m_CharacterVelocity = CalculateVelocity(deltaTime, GetMaxFriction(), GetMaxBrakingDeceleration());

            HandlePendingLaunch();

            if (IsDead())
            {
                m_CharacterVelocity.x = 0.0f;
            }

            // When we're standing on a moving surface, add its velocity
            if (m_IsGrounded && m_MovingGround != null)
            {
                m_MovingGroundVelocity = m_MovingGround.Velocity.x;
                m_CharacterVelocity.x += m_MovingGroundVelocity;
            }

            // Calculate the velocity delta and then update the rigidbody velocity directly
            Vector3 velocityDelta = m_CharacterVelocity - m_Rigidbody.linearVelocity;
            if (velocityDelta != Vector3.zero)
            {
                m_Rigidbody.AddForce(velocityDelta, ForceMode.VelocityChange);
            }
        }

        // Calculates the character's velocity based on design parameters
        private Vector3 CalculateVelocity(float deltaTime, float friction, float brakingDeceleration)
        {
            Vector3 result = m_CharacterVelocity;

            // Calculate X speed
            result.x = GetCharacterLateralSpeed();

            float inputScalar = m_AnalogInputScalar;

            // Limit control when airborne if desired
            if (!m_IsGrounded)
            {
                inputScalar *= AirControlMultiplier;
            }

            // Calculate acceleration, clamping to max
            float acceleration = m_CurrentMaxAcceleration * inputScalar;
            acceleration = Mathf.Clamp(acceleration, -m_CurrentMaxAcceleration, m_CurrentMaxAcceleration);

            // Apply braking or deceleration 
            bool isZeroAcceleration = acceleration == 0.0f ? true : false;
            bool isExceedingMax = IsExceedingMaxSpeed(m_CurrentMaxLateralSpeed);

            if (isExceedingMax || isZeroAcceleration)
            {
                ApplyBrakingValueToSpeed(deltaTime, BrakingFriction, brakingDeceleration, ref result.x);

                // Don't allow braking to lower us below max speed if we started above it 
                if (isExceedingMax && Square(result.x) < Square(m_CurrentMaxLateralSpeed))
                {
                    float previousSpeedDirection = GetCharacterLateralSpeedDirectionNormal();
                    result.x = previousSpeedDirection * m_CurrentMaxLateralSpeed;
                }
            }
            else if (!isZeroAcceleration)
            {
                // Apply Friction. Affects our ability to change direction.
                float accelDir = (acceleration < 0) ? -1.0f : 1.0f;
                float currentSpeed = GetCharacterLateralSpeed();
                result.x = currentSpeed - (currentSpeed - accelDir * Mathf.Abs(currentSpeed)) * Mathf.Min(friction * deltaTime, 1.0f);
            }

            isExceedingMax = IsExceedingMaxSpeed(m_CurrentMaxLateralSpeed);

            // Apply acceleration to X-axis only if we aren't already exceeding the max speed
            if (!isZeroAcceleration && !isExceedingMax)
            {
                result.x += acceleration * deltaTime;
                float sign = result.x > 0.0f ? 1.0f : -1.0f;
                result.x = Mathf.Min(Mathf.Abs(result.x), m_CurrentMaxLateralSpeed) * sign;
            }

            // Apply gravity when airborne
            if (!m_IsGrounded)
            {
                result.y += GetScaledGravityY() * deltaTime;
            }

            return result;
        }

        // Brake based on the current speed
        private void ApplyBrakingValueToSpeed(float deltaTime, float friction, float brakingDeceleration, ref float currentSpeed)
        {
            if (currentSpeed == 0.0f)
            {
                return;
            }

            float frictionFactor = Mathf.Max(0.0f, BrakingFrictionFactor);
            friction = Mathf.Max(0.0f, friction * frictionFactor);
            bool bZeroFriction = friction == 0.0f;
            brakingDeceleration = Mathf.Max(0.0f, brakingDeceleration);
            bool bZeroBraking = brakingDeceleration == 0.0f;

            if (bZeroFriction && bZeroBraking)
            {
                return;
            }

            float previousSpeed = currentSpeed;

            float reverseAcceleration = bZeroBraking ? 0.0f : -brakingDeceleration * GetCharacterLateralSpeedDirectionNormal();
            currentSpeed += (-friction) * currentSpeed + reverseAcceleration * deltaTime;

            if ((Mathf.Abs(previousSpeed) - Mathf.Abs(currentSpeed)) <= 0.0f)
            {
                currentSpeed = 0.0f;
                return;
            }

            // Clamp to zero if nearly zero or below min threshold and braking 
            // When our velocity is small enough, we just want to set it to zero so that we don't rubberband back and forth
            float speedSquared = Square(currentSpeed);
            float threshold = 0.0001f; // Magic number
            float thresoldSquared = Square(threshold);

            if (speedSquared <= threshold || (!bZeroBraking && speedSquared <= thresoldSquared))
            {
                currentSpeed = 0.0f;
                return;
            }
        }

        // When true, the current speed is past the max allowed speed
        private bool IsExceedingMaxSpeed(float maxSpeed)
        {
            maxSpeed = Mathf.Abs(maxSpeed);
            maxSpeed = Mathf.Max(0.0f, maxSpeed);
            float maxSpeedSquared = Square(maxSpeed);

            float currentSpeedSquared = Square(GetCharacterLateralSpeed());

            // Allow 1% error tolerance, to account for numeric imprecision.
            const float OverVelocityPercent = 1.01f;
            return currentSpeedSquared > maxSpeedSquared * OverVelocityPercent;
        }

        // Gets the character's current speed on the X-axis from the rigidbody
        private float GetCharacterLateralSpeed()
        {
            // We need to subtract the moving ground's velocity in order to get the
            // input-commanded velocity of the player to base our calculations on
            return m_Rigidbody.linearVelocity.x - m_MovingGroundVelocity;
        }

        // Gets the direction the character is facing -1 to 1
        private float GetCharacterLateralSpeedDirectionNormal()
        {
            return (GetCharacterLateralSpeed() < 0) ? -1.0f : 1.0f;
        }

        // Scales the gravity if character state conditions are met 
        private void ProcessGravityScaling()
        {
            if (m_IsGrounded)
            {
                return;
            }

            // When the character's ascending as part of a jump, do not apply fall gravity
            // If we were launched, we didn't jump
            if (m_Rigidbody.linearVelocity.y >= 0 && !m_WasLaunched)
            {
                if (!m_JumpInputActive && m_ApplyEarlyReleaseGravityMultiplier)
                {
                    // Apply the gravity multiplier so we attenuate to the apex more quickly
                    // when the player releases the button early
                    m_CurrentGravityScale *= EarlyReleaseGravityMultiplier;
                    m_ApplyEarlyReleaseGravityMultiplier = false;
                }
                return;
            }

            // Start tracking fall time if we aren't already 
            if (!m_ApplyFallingGravity)
            {
                m_ApplyFallingGravity = true;
                m_FallTime = 0.0f;
            }

            // We have to clamp the alpha otherwise the ease will take us beyond 1.0/target blend value
            float Alpha = Mathf.Clamp01(m_FallTime / FallGravityBlendTime);
            m_CurrentGravityScale = EasingFunctions.Ease(FallBeginGravityScale, FallMaxGravityScale, Alpha, GravityEasingType, FallGravityEaseBlend);

            m_FallTime += Time.deltaTime;
        }

        // Determines if the character is on the ground
        private void PhysicsGroundCheck()
        {
            // The character state can prevent ground check (i.e. just jumped)
            if (!CanCheckForGround())
            {
                if (!m_IsGrounded)
                {
                    m_AirborneTime += Time.deltaTime;
                }
                return;
            }

            bool hitGround = false;

            // Make sure that the ground check distance while already in air is very small, to prevent suddenly snapping to ground
            float chosenGroundCheckDistance = m_IsGrounded ? (SkinWidth + GroundCheckDistance) : k_GroundCheckDistanceInAir;

            // Note that diameter of the sphere is roughly half the height of the capsule which is why we use the quarter height here
            float castDistance = m_CapsuleQuarterheight + chosenGroundCheckDistance;

            // If we're grounded, collect info about the ground normal with a downward cast representing our character capsule
            if (Physics.SphereCast(m_Rigidbody.position, m_CapsuleQuarterheight, Vector3.down, out RaycastHit hit, castDistance, GroundCheckLayers, QueryTriggerInteraction.Ignore))
            {
                // Storing the upward direction for the surface found
                m_GroundNormal = hit.normal;

                // Only consider this a valid ground hit if the ground normal goes in the same direction as the character up
                // and if the slope angle is lower than the character controller's limit
                if (Vector3.Dot(hit.normal, Vector3.up) > 0f &&
                    IsNormalUnderSlopeLimit(m_GroundNormal))
                {
                    hitGround = true;

                    // When we ground on a moving platform, we should attach to it 
                    if (hit.collider.gameObject.layer == LayerMask.NameToLayer(MovingPlatformCheckLayer))
                    {
                        m_MovingGround = hit.collider.gameObject.GetComponentInParent<MovingPlatform>();
                    }
                    else
                    {
                        ClearMovingGround();
                    }

                    // If we are grounded but we're farther from the ground than our snap distance
                    // move the rigidbody to be on the ground. This keeps the player on the ground and 
                    // prevents them from "falling" when walking down a slope.
                    if (hit.distance > m_CapsuleQuarterheight + GroundSnapDistance)
                    {
                        Vector3 targetPosition = m_Rigidbody.position;
                        targetPosition.y = hit.point.y + m_CapsuleHalfHeight;
                        m_Rigidbody.MovePosition(targetPosition);
                    }
                }
            }

            if (hitGround)
            {
                SetGroundedState();
            }
            else
            {
                // At this point the character is no longer on the ground
                m_IsGrounded = false;
                ClearMovingGround();
            }

            if (!m_IsGrounded)
            {
                m_AirborneTime += Time.deltaTime;
            }
        }

        // Checks if the player hit a ceiling and puts them into a falling state 
        private void PhysicsCeilingCheck()
        {
            // Check if we can start casting for a ceiling
            if (m_IsGrounded || m_HitCeiling || !PassedJumpTimeThreshold())
            {
                return;
            }

            // Note that diameter of the sphere is roughly half the height of the capsule which is why we use the quarter height here
            float castDistance = m_CapsuleQuarterheight + CeilingCheckDistance;

            // Cast an upward capsule cast representing our character capsule
            if (Physics.SphereCast(m_Rigidbody.position, m_CapsuleQuarterheight, Vector3.up, out RaycastHit hit, castDistance, CeilingCheckLayers, QueryTriggerInteraction.Ignore))
            {
                m_HitCeiling = true;
            }

            if (m_HitCeiling)
            {
                // Clear any upward speed that this character had so that falling gravity can start to accumulate
                m_CharacterVelocity.y = 0.0f;
            }
        }

        // Sets the state variables for grounded character state
        private void SetGroundedState()
        {
            // Emit an event when we've just exited the airborne state 
            if (!m_IsGrounded)
            {
                PlayJumpLandSound();

                LandedVFX?.Play();

                OnLanded?.Invoke();

                // If we died while mid-air, we need to disable our rigidbody now.
                if (IsDead())
                {
                    HaltMovementAndPhysics();
                }
            }

            m_IsGrounded = true;
            m_WasLaunched = false;
            m_HitCeiling = false;
            m_ApplyFallingGravity = false;
            m_ApplyEarlyReleaseGravityMultiplier = false;
            m_FallTime = 0.0f;
            m_AirborneTime = 0.0f;
            m_JumpCount = 0;

            // Physics - Reset gravity and the character's gravity accumulation when grounded
            m_CurrentGravityScale = DefaultGravityScale;
            m_CharacterVelocity.y = 0.0f;
        }

        // Checks whether the character is about to land so that we can update the animator ahead of time if possible 
        private void AnimatorGroundCheck()
        {
            if (IsDead())
            {
                return;
            }

            // Check if the character state even allows us to check if we're about to land
            if (m_Rigidbody.linearVelocity.y > 0 || !PassedJumpTimeThreshold())
            {
                m_AboutToLand = false;
                return;
            }

            float distanceToCheck = m_CapsuleHalfHeight + AnimationLandingCheckDistance;

            // Cast to check if we're going to hit the ground
            if (Physics.Raycast(m_Rigidbody.position, Vector3.down, distanceToCheck, GroundCheckLayers, QueryTriggerInteraction.Ignore))
            {
                m_AboutToLand = true;
            }
            else
            {
                m_AboutToLand = false;
            }
        }

        // Initial check to see if the character is on the ground when they load in
        private void InitialGroundCheck()
        {
            // Look as far as you have to in order to find the ground, we want to initialize the player already standing on the ground
            if (Physics.Raycast(m_Rigidbody.position, Vector3.down, out RaycastHit hit, float.PositiveInfinity, GroundCheckLayers, QueryTriggerInteraction.Ignore))
            {
                // Snap the player's Y position to the ground we found
                Vector3 targetPosition = m_Rigidbody.position;
                targetPosition.y = hit.point.y + m_CapsuleHalfHeight;
                m_Rigidbody.MovePosition(targetPosition);

                // Force the grounded state so no SFX/VFX will react to this repositioning
                m_IsGrounded = true;

                // Initialize our grounded state
                SetGroundedState();
                m_AboutToLand = false;
            }
            else
            {
                Debug.LogError("Player was spawned without any ground underneath! Falling forever...");
            }
        }

        // When true, the character can check for the ground state
        private bool CanCheckForGround()
        {
            if (m_JumpCount > 0)
            {
                return PassedJumpTimeThreshold();
            }

            return true;
        }

        // When true, the character has exceeded the minimum time needed to start a jump
        private bool PassedJumpTimeThreshold()
        {
            return Time.time > m_LastTimeJumped + k_JumpGroundingPreventionTime;
        }

        // Returns true if the slope angle represented by the given normal is under the slope angle limit
        private bool IsNormalUnderSlopeLimit(Vector3 normal)
        {
            return Vector3.Angle(transform.up, normal) <= SlopeLimit;
        }

        private void ClearMovingGround()
        {
            if (m_MovingGround == null)
            {
                return;
            }

            m_MovingGround = null;
            m_MovingGroundVelocity = 0.0f;
        }

        float GetMaxBrakingDeceleration()
        {
            return IsGrounded() ? GroundBrakingDeceleration : AirBrakingDeceleration;
        }

        float GetMaxFriction()
        {
            return IsGrounded() ? GroundFriction : AirFriction;
        }

        private void HandlePendingLaunch()
        {
            // If we have a pending launch, force the velocity and zero it out
            if (m_PendingLaunchVelocity != Vector3.zero)
            {
                // If we are knocked off the ground, we need to gracefully enter a non-grounded state
                if (m_PendingLaunchVelocity.y > 0.0f && m_IsGrounded)
                {
                    m_IsGrounded = false;
                    // This allows fall gravity to immediately take effect even though we haven't reached the apex
                    m_WasLaunched = true;
                }

                m_CharacterVelocity = m_PendingLaunchVelocity;
                m_PendingLaunchVelocity = Vector3.zero;
                m_AnalogInputScalar = 0;
            }
        }

        public bool LaunchCharacter(Vector3 Force)
        {
            if (IsDead() || Force == Vector3.zero)
            {
                return false;
            }

            m_PendingLaunchVelocity = Force;
            return true;
        }

        #endregion

        #region Animation 

        // Pass along an per-frame data that can be used by the animator
        private void UpdateAnimator()
        {
            // Do a check to see if the character is about to land
            AnimatorGroundCheck();

            bool enterJumpState = false;

            if (!m_IsGrounded || m_HitCeiling)
            {
                // When the character is about to land, exit the jump state early
                // Note that 'about to land' here is contingent on transition duration out of the jump state
                // and the Raycast length when setting this variable
                if (m_AboutToLand)
                {
                    enterJumpState = false;
                }
                else
                {
                    enterJumpState = true;
                }
            }

            m_AnimationController.SetAirborne(enterJumpState);
            m_AnimationController.UpdateAnimatorFromCharacterSpeed(GetCharacterLateralSpeed(), MaxLateralSpeed, m_AnalogInputScalar);
        }

        #endregion

        #region Combat

        public override void HitCharacter()
        {
            if (m_HitInvulnerable)
            {
                return;
            }

            base.HitCharacter();

            if (IsDead())
            {
                return;
            }

            PlayHitSound();

            m_AnimationController.TriggerHit();

            // Do not allow mid air stuns if the flag is set to false
            if (!StunMidAir && IsFalling())
            {
                return;
            }

            if (HitStunDuration > 0.0f)
            {
                StartCoroutine(HitStunRoutine(HitStunDuration));
            }

            if (HitInvulnerabilityDuration > 0.0f)
            {
                m_HitInvulnerable = true;
                StartCoroutine(HitInvulnerableRoutine(HitInvulnerabilityDuration));
            }
        }

        // Applies a hit with a knockback force to the character 
        public virtual void HitCharacterWithLaunchForce(in Vector3 force)
        {
            if (IsDead() || m_HitInvulnerable)
            {
                return;
            }

            Vector3 hitForce = force;

            // Zero out any Z axis motion, the player cannot move on this plane.
            hitForce.z = 0.0f;

            LaunchCharacter(hitForce);

            // Proceed with hit logic 
            HitCharacter();
        }

        protected override void CharacterDeath()
        {
            base.CharacterDeath();

            ClearInputValues();

            // Apply early release gravity multiplier in case the character is airborne 
            m_ApplyEarlyReleaseGravityMultiplier = true;

            PlayDeathSound();

            m_AnimationController.SetIsDead(true);

            // Only halt movement if we are on the ground. If we're falling, do this when we land.
            if (m_IsGrounded)
            {
                HaltMovementAndPhysics();
            }
        }

        private IEnumerator HitStunRoutine(float duration)
        {
            // Zero out the player's movement
            UpdateMovementInputScalar(0.0f);
            StopJumpInput();
            m_HitStunned = true;

            yield return new WaitForSeconds(duration);

            StopHitStun();
        }

        private void StopHitStun()
        {
            m_HitStunned = false;
        }

        private IEnumerator HitInvulnerableRoutine(float duration)
        {
            yield return new WaitForSeconds(duration);
            StopHitInvulnerability();
        }

        private void StopHitInvulnerability()
        {
            m_HitInvulnerable = false;
        }

        #endregion

        #region Abilities

        public void AddHitpoints(int hitPointsToAdd)
        {
            CurrentHitPoints += hitPointsToAdd;

            // Broadcast to inform that hit points have been added to the player
            OnHitPointsAdded?.Invoke();
        }

        public void ActivateSpeedPowerup(float duration, float maxSpeedMultiplier, Color TargetColor)
        {
            m_HitInvulnerable = true;

            // Alter speed
            m_CurrentMaxLateralSpeed = MaxLateralSpeed * maxSpeedMultiplier;
            m_CurrentMaxAcceleration = MaxAcceleration * maxSpeedMultiplier;

            m_OutlineColorChanger.ApplyOutlineOverride(TargetColor);

            // Disable layer collisions
            ToggleInvulnerabilityLayerCollision(true);

            StartCoroutine(SpeedPowerupRoutine(duration));
        }

        private IEnumerator SpeedPowerupRoutine(float duration)
        {
            yield return new WaitForSeconds(duration);
            StopSpeedPowerup();
        }

        private void StopSpeedPowerup()
        {
            m_HitInvulnerable = false;

            // Re-enable layer collisions 
            ToggleInvulnerabilityLayerCollision(false);

            // Restore default outline color 
            m_OutlineColorChanger.ClearOutlineOverride();

            m_CurrentMaxLateralSpeed = MaxLateralSpeed;
            m_CurrentMaxAcceleration = MaxAcceleration;
        }

        // Enables and disables whether or not invulnerability layers will collide with the player
        private void ToggleInvulnerabilityLayerCollision(bool ignore)
        {
            foreach (string layer in InvulnerabilityLayers)
            {
                int layerMask = LayerMask.NameToLayer(layer);
                Physics.IgnoreLayerCollision(gameObject.layer, layerMask, ignore);
            }
        }

        #endregion

        #region Gameplay

        public void TriggerVictory()
        {
            OnVictoryTriggered?.Invoke();
            ClearInputValues();
        }

        public void DefeatBoss(float delay = 0.0f)
        {
            OnBossDefeated?.Invoke(delay);
            ClearInputValues();
        }

        #endregion

        #region Effects

        private void PlayHitSound()
        {
            ParrotAudioController.Instance.PlayRandomGameplaySFX(HitSounds);
        }

        private void PlayDeathSound()
        {
            ParrotAudioController.Instance.PlayGameplaySFX(DeathSound);
        }

        private void PlayEnemyJumpSound()
        {
            ParrotAudioController.Instance.PlayGameplaySFX(EnemyJumpSound);
        }

        private void PlayJumpStartSound()
        {
            ParrotAudioController.Instance.PlayRandomGameplaySFX(JumpStartSounds);
        }

        private void PlayJumpLandSound()
        {
            ParrotAudioController.Instance.PlayGameplaySFX(JumpLandSound);
        }

        private void PlayFootstepSound()
        {
            ParrotAudioController.Instance.PlayRandomGameplaySFX(FootstepSounds);
        }

        #endregion

        #region Utility

        private float Square(float value)
        {
            return value * value;
        }

        public Vector3 GetPosition()
        {
            if (m_Rigidbody == null)
            {
                return transform.position;
            }

            return m_Rigidbody.position;
        }

        #endregion
    }
}
