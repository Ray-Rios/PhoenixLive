///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine;
using UnityEngine.InputSystem;

namespace SecretDimension
{
    ///<summary>
    /// The player controller class reperesents the human player's will. It is responsible for controlling the pawn. 
    ///</summary>

    [RequireComponent(typeof(PlayerInput))]
    public class ParrotPlayerController : MonoBehaviour
    {
        #region Attributes
        // Attributes

        #region  References

        // The pawn object in the world that this controller will control
        private ParrotPlayerCharacter m_PlayerCharacter;

        public ParrotPlayerCharacter PlayerCharacter { get { return m_PlayerCharacter; } }

        // The player input component maps inputs to actions and allows this player controller to query those actions
        private PlayerInput m_PlayerInput;

        // The game state from the current game mode 
        private ParrotGameState m_GameState;

        public ParrotGameState ParrotGameState { get { return m_GameState; } }

        #endregion

        // Input Actions 
        // Move Axis
        private InputAction m_MovementInputAction;

        private InputAction m_MoveLeftInputAction;

        private InputAction m_MoveRightInputAction;

        // Jump
        private InputAction m_JumpInputAction;

        // Input Action Values
        private float m_MovementValue;

        // Whether true, the jump button is being pressed and has passed it's actuation threshold
        private bool m_JumpPressed;

        // When true, the jump button was pressed this frame 
        private bool m_JumpPressedThisFrame;

        // When true, the jump button was released this frame 
        private bool m_JumpReleaseThisFrame;

        // The current input control scheme that the player is using 
        private InputType m_CurrentInputType = InputType.MouseAndKeyboard;
        public InputType CurrentInputType { get { return m_CurrentInputType; } }

        private const string k_GameplayActionMap = "Gameplay";
        private const string k_UIActionMap = "UI";
        private const string k_GamepadControlSchemeKey = "Gamepad";
        private const string k_RebindPlayerPrefs = "rebinds";

        private bool m_UsingGameplayInput;

        // Called when the cancel input action has been pressed
        public Action CancelPressed;

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            ValidateRequiredComponents();
            SetupController();
        }

        void OnDestroy()
        {
            UnsubscribeToEvents();
        }

        /// <summary>
        /// Update is called once per frame
        /// </summary>
        private void Update()
        {
            if (m_UsingGameplayInput)
            {
                PollGameplayInput();
                ProcessGameplayInput();
            }
        }
        #endregion

        #region Initialization 

        // Ensure all required components are set on this controller
        private void ValidateRequiredComponents()
        {
            m_PlayerInput = GetComponent<PlayerInput>();
        }

        // Handles controller initialization
        private void SetupController()
        {
            SetupInput();
            SubscribeToEvents();
        }

        private void SubscribeToEvents()
        {
            GameplayEvents.ResumeGame += ResumeGameplayInput;
        }

        private void UnsubscribeToEvents()
        {
            GameplayEvents.ResumeGame -= ResumeGameplayInput;
        }

        public void InitializeForUI()
        {
            m_PlayerInput.SwitchCurrentActionMap(k_UIActionMap);
            m_UsingGameplayInput = false;
        }

        public void InitializeForGameplay(ref ParrotPlayerCharacter targetPawn, ref ParrotGameState gameState)
        {
            m_PlayerCharacter = targetPawn;

            m_PlayerCharacter.OnCharacterDeath += CharacterDeath;
            m_PlayerCharacter.OnVictoryTriggered += VictoryTriggered;
            m_PlayerCharacter.OnBossDefeated += BossDefeated;

            m_GameState = gameState;
            m_PlayerInput.SwitchCurrentActionMap(k_GameplayActionMap);
            m_UsingGameplayInput = true;
        }

        private void UnsubscribeFromCharacterEvents()
        {
            m_PlayerCharacter.OnCharacterDeath -= CharacterDeath;
            m_PlayerCharacter.OnVictoryTriggered -= VictoryTriggered;
            m_PlayerCharacter.OnBossDefeated -= BossDefeated;
        }

        #endregion

        #region Input

        private void SetupInput()
        {
            // Set the current input mode 
            if (m_PlayerInput.currentControlScheme.Equals(k_GamepadControlSchemeKey, StringComparison.OrdinalIgnoreCase))
            {
                m_CurrentInputType = InputType.Gamepad;
            }
            else
            {
                m_CurrentInputType = InputType.MouseAndKeyboard;
            }

            // Setup actions 
            LoadInputBindings();
            m_MovementInputAction = m_PlayerInput.actions[InputActionStrings.Move];
            m_MoveLeftInputAction = m_PlayerInput.actions[InputActionStrings.MoveLeft];
            m_MoveRightInputAction = m_PlayerInput.actions[InputActionStrings.MoveRight];
            m_JumpInputAction = m_PlayerInput.actions[InputActionStrings.Jump];
        }

        public void SaveInputBindings()
        {
            var rebinds = m_PlayerInput.actions.SaveBindingOverridesAsJson();
            PlayerPrefs.SetString(k_RebindPlayerPrefs, rebinds);
        }

        private void LoadInputBindings()
        {
            var rebinds = PlayerPrefs.GetString(k_RebindPlayerPrefs);
            m_PlayerInput.actions.LoadBindingOverridesFromJson(rebinds);
        }

        private void PollGameplayInput()
        {
            if (m_MoveLeftInputAction.IsPressed())
            {
                m_MovementValue = -1.0f;
            }
            else if (m_MoveRightInputAction.IsPressed())
            {
                m_MovementValue = 1.0f;
            }
            else
            {
                // Use the axis value. We only care about X-axis of this input action 
                m_MovementValue = m_MovementInputAction.ReadValue<Vector2>().x;
            }

            // Read jump input information
            m_JumpPressedThisFrame = m_JumpInputAction.WasPressedThisFrame();
            m_JumpPressed = m_JumpInputAction.IsPressed();
            m_JumpReleaseThisFrame = m_JumpInputAction.WasReleasedThisFrame();
        }

        private void ProcessGameplayInput()
        {
            // Pass along our processed input to the player character
            m_PlayerCharacter.UpdateMovementInputScalar(m_MovementValue);

            // Determine if a jump was started or stopped 
            if (m_JumpPressedThisFrame && m_JumpPressed)
            {
                StartJump();
            }
            else if (m_JumpReleaseThisFrame)
            {
                StopJump();
            }
        }

        // Invoked by the input system when controls change 
        private void OnControlsChanged(PlayerInput input)
        {
            if (input.currentControlScheme.Equals(k_GamepadControlSchemeKey, StringComparison.OrdinalIgnoreCase))
            {
                m_CurrentInputType = InputType.Gamepad;
            }
            else
            {
                m_CurrentInputType = InputType.MouseAndKeyboard;
            }

            // Broadcast event to application 
            ApplicationEvents.InputDeviceChanged?.Invoke(m_CurrentInputType);
        }

        // Starts a jump input action 
        private void StartJump()
        {
            m_PlayerCharacter.StartJumpInput();
        }

        private void StopJump()
        {
            m_PlayerCharacter.StopJumpInput();
        }

        // Invoked when the player presses the cancel button 
        private void OnCancel()
        {
            CancelPressed?.Invoke();
        }

        // Invoked when the player presses the pause input binding
        private void OnPause()
        {
            if (!m_UsingGameplayInput)
            {
                return;
            }

            // Swap input mode to UI 
            m_PlayerInput.SwitchCurrentActionMap(k_UIActionMap);
            m_UsingGameplayInput = false;

            m_GameState.PauseGame();
        }

        private void ResumeGameplayInput()
        {
            // Swap input mode to gameplay
            m_PlayerInput.SwitchCurrentActionMap(k_GameplayActionMap);
            m_UsingGameplayInput = true;
        }

        #endregion

        #region Gameplay

        private void CharacterDeath()
        {
            UnsubscribeFromCharacterEvents();

            // Swap input to UI 
            m_PlayerInput.SwitchCurrentActionMap(k_UIActionMap);
            m_UsingGameplayInput = false;

            // Inform the game state that this player's character has died 
            m_GameState.PlayerDeath(m_PlayerCharacter);
        }

        private void VictoryTriggered()
        {
            UnsubscribeFromCharacterEvents();

            // Swap input to UI 
            m_PlayerInput.SwitchCurrentActionMap(k_UIActionMap);
            m_UsingGameplayInput = false;

            // Inform the game state that this player has completed the level 
            m_GameState.CompleteLevel(m_PlayerCharacter);
        }

        private void BossDefeated(float delay = 0.0f)
        {
            UnsubscribeFromCharacterEvents();

            // Swap input to UI 
            m_PlayerInput.SwitchCurrentActionMap(k_UIActionMap);
            m_UsingGameplayInput = false;

            // Inform the game state that the boss has been defeated
            m_GameState.BossDefeated(delay);
        }

        #endregion
    }
}
