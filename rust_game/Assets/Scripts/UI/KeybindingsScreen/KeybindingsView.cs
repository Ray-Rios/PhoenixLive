///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the view of the keybindings screen
    ///</summary>
    public class KeybindingsView : UIView
    {
        #region Attributes
        // Attributes

        private ParrotActionContainer m_JumpContainer;
        private ParrotActionContainer m_MoveRightContainer;
        private ParrotActionContainer m_MoveLeftContainer;
        private Button m_CloseButton;
        private Button m_ApplyButton;
        private Button m_ResetButton;
        private VisualElement m_PressKeyContainer;
        private Label m_PressKeyTextLabel;
        private Label m_RebindActionLabel;
        private Label m_CancelKeyTextLabel;
        private VisualElement m_ConfirmationModalContainer;
        private Button m_YesButton;
        private Button m_NoButton;
        private VisualElement m_UnsavedChangesModalContainer;
        private Button m_UnsavedYesButton;
        private Button m_UnsavedNoButton;

        private const string k_CloseButton = "close-button";
        private const string k_JumpActionContainer = "jump";
        private const string k_MoveRightContainer = "move-right";
        private const string k_MoveLeftContainer = "move-left";
        private const string k_ApplyButton = "apply-button";
        private const string k_ResetButton = "reset-all-button";
        private const string k_PressKeyContainer = "press-key-container";
        private const string k_PressKeyTextLabel = "press-key-text";
        private const string k_RebindActionTextLabel = "rebind-action-text";
        private const string k_CancelTextLabel = "cancel-key-text";
        private const string k_ConfirmationModalContainer = "confirmation-modal-container";
        private const string k_YesButton = "yes-button";
        private const string k_NoButton = "no-button";
        private const string k_UnsavedModalContainer = "unsaved-modal-container";

        // The amount of time to wait in milliseconds, after a rebind is finished before new screen close input actions are detected
        private const long k_PostRebindMinWaitDuration = 100;

        // SO with localized string data so that the rebind modal populates correctly 
        private KeyRebindStringData m_RebindStringData;

        // The active rebind operation 
        private InputActionRebindingExtensions.RebindingOperation m_RebindOperation;

        private InputType m_LastInputType;

        private bool m_DisplayUnsavedChangesModal = false;

        #endregion

        public KeybindingsView(VisualElement topElement, ParrotPlayerController playerController, KeyRebindStringData rebindStringData) : base(topElement, playerController)
        {
            m_RebindStringData = rebindStringData;
        }

        protected override void SetVisualElements()
        {
            m_CloseButton = m_TopElement.Q<Button>(k_CloseButton);

            // Get the jump container 
            var holder = m_TopElement.Q<VisualElement>(k_JumpActionContainer);
            if (holder != null)
            {
                m_JumpContainer = holder.Q<ParrotActionContainer>("main-container");
                m_JumpContainer.InitializeActionContainer();
            }

            // Get the move right container 
            holder = m_TopElement.Q<VisualElement>(k_MoveRightContainer);
            if (holder != null)
            {
                m_MoveRightContainer = holder.Q<ParrotActionContainer>("main-container");
                m_MoveRightContainer.InitializeActionContainer();
            }

            // Get the move left container 
            holder = m_TopElement.Q<VisualElement>(k_MoveLeftContainer);
            if (holder != null)
            {
                m_MoveLeftContainer = holder.Q<ParrotActionContainer>("main-container");
                m_MoveLeftContainer.InitializeActionContainer();
            }

            // Get the confirmation modal and modal buttons 
            m_ConfirmationModalContainer = m_TopElement.Q<VisualElement>(k_ConfirmationModalContainer);

            if (m_ConfirmationModalContainer == null)
            {
                Debug.LogError("Could not find confirmation modal on KeybindingsView");
            }
            else
            {
                m_YesButton = m_ConfirmationModalContainer.Q<Button>(k_YesButton);
                m_NoButton = m_ConfirmationModalContainer.Q<Button>(k_NoButton);
            }

            // Get the unsaved changes modal and modal buttons 
            m_UnsavedChangesModalContainer = m_TopElement.Q<VisualElement>(k_UnsavedModalContainer);

            if (m_UnsavedChangesModalContainer == null)
            {
                Debug.LogError("Could not find unsaved changes modal on KeybindingsView");
            }
            else
            {
                m_UnsavedYesButton = m_UnsavedChangesModalContainer.Q<Button>(k_YesButton);
                m_UnsavedNoButton = m_UnsavedChangesModalContainer.Q<Button>(k_NoButton);
            }

            m_ApplyButton = m_TopElement.Q<Button>(k_ApplyButton);
            m_ResetButton = m_TopElement.Q<Button>(k_ResetButton);

            // Rebind modal elements  
            m_PressKeyContainer = m_TopElement.Q<VisualElement>(k_PressKeyContainer);
            m_PressKeyTextLabel = m_TopElement.Q<Label>(k_PressKeyTextLabel);
            m_RebindActionLabel = m_TopElement.Q<Label>(k_RebindActionTextLabel);
            m_CancelKeyTextLabel = m_TopElement.Q<Label>(k_CancelTextLabel);

            base.SetVisualElements();
        }

        protected override void RegisterElementCallbacks()
        {
            base.RegisterElementCallbacks();

            if (ParrotAudioController.Instance)
            {
                m_CloseButton.clicked += ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_CloseButton.clicked += OnClosePressed;
            m_CloseButton.RegisterCallback<MouseOverEvent>(OnButtonHover);

            m_JumpContainer.GetGamepadButton().clicked += OnJumpGamepadRebindPressed;
            m_JumpContainer.GetKeyboardButton().clicked += OnJumpMKBRebindPressed;
            m_JumpContainer.GetGamepadButton().RegisterCallback<NavigationMoveEvent>(OnJumpNavigationEvent);

            m_MoveRightContainer.GetGamepadButton().clicked += OnMoveRightGamepadRebindPressed;
            m_MoveRightContainer.GetKeyboardButton().clicked += OnMoveRightMKBRebindPressed;
            m_MoveLeftContainer.GetGamepadButton().clicked += OnMoveLeftGamepadRebindPressed;
            m_MoveLeftContainer.GetKeyboardButton().clicked += OnMoveLeftMKBRebindPressed;
            m_MoveLeftContainer.GetGamepadButton().RegisterCallback<NavigationMoveEvent>(OnMoveLeftNavigationEvent);

            m_ApplyButton.clicked += ShowApplyModal;
            m_ApplyButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_ApplyButton.RegisterCallback<FocusEvent>(OnButtonHover);
            m_ApplyButton.RegisterCallback<NavigationMoveEvent>(OnApplyMoveEvent);
            m_ResetButton.clicked += ShowResetAllModal;
            m_ResetButton.RegisterCallback<NavigationMoveEvent>(OnResetMoveEvent);
            m_ResetButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_ResetButton.RegisterCallback<FocusEvent>(OnButtonHover);

            m_YesButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_YesButton.RegisterCallback<FocusEvent>(OnButtonHover);
            m_NoButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_NoButton.RegisterCallback<FocusEvent>(OnButtonHover);
            m_NoButton.clicked += HideConfirmationModal;

            m_YesButton.RegisterCallback<NavigationMoveEvent>(OnYesMoveEvent);
            m_NoButton.RegisterCallback<NavigationMoveEvent>(OnNoMoveEvent);

            m_UnsavedYesButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_UnsavedYesButton.RegisterCallback<FocusEvent>(OnButtonHover);
            m_UnsavedNoButton.RegisterCallback<MouseOverEvent>(OnButtonHover);
            m_UnsavedNoButton.RegisterCallback<FocusEvent>(OnButtonHover);

            m_UnsavedYesButton.RegisterCallback<NavigationMoveEvent>(OnUnsavedYesMoveEvent);
            m_UnsavedNoButton.RegisterCallback<NavigationMoveEvent>(OnUnsavedNoMoveEvent);

            m_UnsavedYesButton.clicked += UnsavedChangesYes;
            m_UnsavedNoButton.clicked += HideUnsavedChangesModal;
        }

        public override void Dispose()
        {
            base.Dispose();

            if (ParrotAudioController.Instance)
            {
                m_CloseButton.clicked -= ParrotAudioController.Instance.PlayButtonSelectionSound;
            }

            m_CloseButton.clicked -= OnClosePressed;
            m_CloseButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);

            m_ApplyButton.clicked -= ShowApplyModal;
            m_ApplyButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_ApplyButton.UnregisterCallback<FocusEvent>(OnButtonHover);
            m_ApplyButton.UnregisterCallback<NavigationMoveEvent>(OnApplyMoveEvent);
            m_ResetButton.clicked -= ShowResetAllModal;
            m_ResetButton.UnregisterCallback<NavigationMoveEvent>(OnResetMoveEvent);
            m_ResetButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_ResetButton.UnregisterCallback<FocusEvent>(OnButtonHover);

            m_YesButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_YesButton.UnregisterCallback<FocusEvent>(OnButtonHover);
            m_YesButton.UnregisterCallback<NavigationMoveEvent>(OnYesMoveEvent);
            m_NoButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_NoButton.UnregisterCallback<FocusEvent>(OnButtonHover);
            m_NoButton.UnregisterCallback<NavigationMoveEvent>(OnNoMoveEvent);
            m_NoButton.clicked -= HideConfirmationModal;

            m_UnsavedYesButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_UnsavedYesButton.UnregisterCallback<FocusEvent>(OnButtonHover);
            m_UnsavedNoButton.UnregisterCallback<MouseOverEvent>(OnButtonHover);
            m_UnsavedNoButton.UnregisterCallback<FocusEvent>(OnButtonHover);

            m_UnsavedYesButton.UnregisterCallback<NavigationMoveEvent>(OnUnsavedYesMoveEvent);
            m_UnsavedNoButton.UnregisterCallback<NavigationMoveEvent>(OnUnsavedNoMoveEvent);

            m_UnsavedYesButton.clicked -= UnsavedChangesYes;
            m_UnsavedNoButton.clicked -= HideUnsavedChangesModal;

            if (m_JumpContainer != null)
            {
                m_JumpContainer.GetGamepadButton().clicked -= OnJumpGamepadRebindPressed;
                m_JumpContainer.GetKeyboardButton().clicked -= OnJumpMKBRebindPressed;
                m_JumpContainer.GetGamepadButton().UnregisterCallback<NavigationMoveEvent>(OnJumpNavigationEvent);
            }

            if (m_MoveRightContainer != null)
            {
                m_MoveRightContainer.GetGamepadButton().clicked -= OnMoveRightGamepadRebindPressed;
                m_MoveRightContainer.GetKeyboardButton().clicked -= OnMoveRightMKBRebindPressed;
            }

            if (m_MoveLeftContainer != null)
            {
                m_MoveLeftContainer.GetGamepadButton().clicked -= OnMoveLeftGamepadRebindPressed;
                m_MoveLeftContainer.GetKeyboardButton().clicked -= OnMoveLeftMKBRebindPressed;
                m_MoveLeftContainer.GetGamepadButton().UnregisterCallback<NavigationMoveEvent>(OnMoveLeftNavigationEvent);
            }
        }

        public override void Hide()
        {
            base.Hide();
            m_PlayerController.CancelPressed -= OnClosePressed;
        }

        public override void Show()
        {
            base.Show();
            BindCancelAction();

            m_DisplayUnsavedChangesModal = false;

            if (UsingGamepad())
            {
                FocusFirstFocusableElement();
            }

            if (m_PlayerController != null)
            {
                m_LastInputType = m_PlayerController.CurrentInputType;
            }
        }

        private void BindCancelAction()
        {
            m_PlayerController.CancelPressed += OnClosePressed;
        }

        private void OnClosePressed()
        {
            // Ignore any requests to close the screen while a modal is active
            if (m_ConfirmationModalContainer.style.display == DisplayStyle.Flex || m_UnsavedChangesModalContainer.style.display == DisplayStyle.Flex)
            {
                return;
            }

            if (m_DisplayUnsavedChangesModal)
            {
                ShowUnsavedChangesModal();
            }
            else
            {
                KeybindingsUIEvents.CloseKeybindings?.Invoke();
            }
        }

        private void OnJumpGamepadRebindPressed()
        {
            if (!UsingGamepad())
            {
                UnfocusLastActiveElement();
                return;
            }

            ShowPressGamepadKeyModal(m_JumpContainer);
        }

        private void OnJumpMKBRebindPressed()
        {
            if (UsingGamepad())
            {
                FocusFirstFocusableElement();
                return;
            }

            ShowPressKeyboardKeyModal(m_JumpContainer);
        }

        private void OnMoveLeftGamepadRebindPressed()
        {
            if (!UsingGamepad())
            {
                UnfocusLastActiveElement();
                return;
            }

            ShowPressGamepadKeyModal(m_MoveLeftContainer);
        }

        private void OnMoveLeftMKBRebindPressed()
        {
            if (UsingGamepad())
            {
                FocusFirstFocusableElement();
                return;
            }

            ShowPressKeyboardKeyModal(m_MoveLeftContainer);
        }

        private void OnMoveRightGamepadRebindPressed()
        {
            if (!UsingGamepad())
            {
                UnfocusLastActiveElement();
                return;
            }

            ShowPressGamepadKeyModal(m_MoveRightContainer);
        }

        private void OnMoveRightMKBRebindPressed()
        {
            if (UsingGamepad())
            {
                FocusFirstFocusableElement();
                return;
            }

            ShowPressKeyboardKeyModal(m_MoveRightContainer);
        }

        private void ShowApplyModal()
        {
            m_YesButton.clicked += ApplyInputBindings;

            if (UsingGamepad())
            {
                m_YesButton.Focus();
            }

            m_ConfirmationModalContainer.style.display = DisplayStyle.Flex;
        }

        private void ShowResetAllModal()
        {
            m_YesButton.clicked += ResetInputBindingsConfirm;

            if (UsingGamepad())
            {
                m_YesButton.Focus();
            }

            m_ConfirmationModalContainer.style.display = DisplayStyle.Flex;
        }

        private void HideConfirmationModal()
        {
            m_YesButton.clicked -= ApplyInputBindings;
            m_YesButton.clicked -= ResetInputBindingsConfirm;

            m_ConfirmationModalContainer.style.display = DisplayStyle.None;

            if (UsingGamepad())
            {
                m_ApplyButton.Focus();
            }
        }

        private void ApplyInputBindings()
        {
            SaveInputBindingData();
            HideConfirmationModal();
        }

        private void ResetInputBindingsConfirm()
        {
            ResetInputBindings();
            HideConfirmationModal();
        }

        private void ResetInputBindings()
        {
            List<ParrotActionContainer> actionContainers = new List<ParrotActionContainer>
            {
                m_JumpContainer,
                m_MoveLeftContainer,
                m_MoveRightContainer
            };

            foreach (var actionContainer in actionContainers)
            {
                var action = actionContainer.ActionReference.action;
                action.RemoveAllBindingOverrides();
                actionContainer.UpdateBindingDisplay();
            }

            SaveInputBindingData();
        }

        private void SaveInputBindingData()
        {
            m_DisplayUnsavedChangesModal = false;
            m_PlayerController?.SaveInputBindings();
        }

        private void ShowUnsavedChangesModal()
        {
            if (UsingGamepad())
            {
                m_UnsavedYesButton.Focus();
            }

            m_UnsavedChangesModalContainer.style.display = DisplayStyle.Flex;
        }

        private void UnsavedChangesYes()
        {
            ParrotAudioController.Instance.PlayButtonSelectionSound();
            ResetInputBindings();
            HideUnsavedChangesModal();
            KeybindingsUIEvents.CloseKeybindings?.Invoke();
        }

        private void HideUnsavedChangesModal()
        {
            if (UsingGamepad())
            {
                m_ApplyButton.Focus();
            }

            m_UnsavedChangesModalContainer.style.display = DisplayStyle.None;
        }

        private void ShowPressKeyboardKeyModal(ParrotActionContainer parrotActionContainer)
        {
            if (parrotActionContainer == null)
            {
                Debug.LogError("Null Parrot Action container when calling ShowPressKeyboardKeyModal");
                return;
            }

            m_PressKeyTextLabel.text = m_RebindStringData.MKBPressKeyString.GetLocalizedString();
            m_CancelKeyTextLabel.text = m_RebindStringData.MKBCancelKeyString.GetLocalizedString();
            m_RebindActionLabel.text = parrotActionContainer.GetActionDisplayName();

            PerformInteractiveRebind(parrotActionContainer, parrotActionContainer.KeyboardBindingId, false);
        }

        private void ShowPressGamepadKeyModal(ParrotActionContainer parrotActionContainer)
        {
            if (parrotActionContainer == null)
            {
                Debug.LogError("Null Parrot Action container when calling ShowPressGamepadKeyModal");
                return;
            }

            m_PressKeyTextLabel.text = m_RebindStringData.GamepadPressKeyString.GetLocalizedString();
            m_CancelKeyTextLabel.text = m_RebindStringData.GamepadCancelKeyString.GetLocalizedString();
            m_RebindActionLabel.text = parrotActionContainer.GetActionDisplayName();

            PerformInteractiveRebind(parrotActionContainer, parrotActionContainer.GamepadBindingID, true);
        }

        private void HidePressKeyModal()
        {
            m_PressKeyContainer.style.display = DisplayStyle.None;
        }

        private void OnYesMoveEvent(NavigationMoveEvent evt)
        {
            m_NoButton.Focus();
            evt.StopPropagation();
            VisualElement target = (VisualElement)evt.target;
            target?.focusController?.IgnoreEvent(evt);
        }

        private void OnNoMoveEvent(NavigationMoveEvent evt)
        {
            m_YesButton.Focus();
            evt.StopPropagation();
            VisualElement target = (VisualElement)evt.target;
            target?.focusController?.IgnoreEvent(evt);
        }

        private void OnUnsavedYesMoveEvent(NavigationMoveEvent evt)
        {
            m_UnsavedNoButton.Focus();
            evt.StopPropagation();
            VisualElement target = (VisualElement)evt.target;
            target?.focusController?.IgnoreEvent(evt);
        }

        private void OnUnsavedNoMoveEvent(NavigationMoveEvent evt)
        {
            m_UnsavedYesButton.Focus();
            evt.StopPropagation();
            VisualElement target = (VisualElement)evt.target;
            target?.focusController?.IgnoreEvent(evt);
        }

        private void OnApplyMoveEvent(NavigationMoveEvent evt)
        {
            Button targetButton = null;
            if (evt.direction == NavigationMoveEvent.Direction.Up)
            {
                targetButton = m_MoveLeftContainer.GetGamepadButton();
            }
            else if (evt.direction == NavigationMoveEvent.Direction.Down)
            {
                targetButton = m_JumpContainer.GetGamepadButton();
            }
            else
            {
                targetButton = m_ResetButton;
            }

            if (targetButton != null)
            {
                targetButton.Focus();
                evt.StopPropagation();
                VisualElement target = (VisualElement)evt.target;
                target?.focusController?.IgnoreEvent(evt);
            }
        }

        private void OnResetMoveEvent(NavigationMoveEvent evt)
        {
            Button targetButton = null;
            if (evt.direction == NavigationMoveEvent.Direction.Up)
            {
                targetButton = m_MoveLeftContainer.GetGamepadButton();
            }
            else if (evt.direction == NavigationMoveEvent.Direction.Down)
            {
                targetButton = m_JumpContainer.GetGamepadButton();
            }
            else
            {
                targetButton = m_ApplyButton;
            }

            if (targetButton != null)
            {
                targetButton.Focus();
                evt.StopPropagation();
                VisualElement target = (VisualElement)evt.target;
                target?.focusController?.IgnoreEvent(evt);
            }
        }

        private void OnJumpNavigationEvent(NavigationMoveEvent evt)
        {
            Button targetButton = null;
            if (evt.direction == NavigationMoveEvent.Direction.Up)
            {
                targetButton = m_ResetButton;
            }

            if (targetButton != null)
            {
                targetButton.Focus();
                evt.StopPropagation();
                VisualElement target = (VisualElement)evt.target;
                target?.focusController?.IgnoreEvent(evt);
            }
        }

        private void OnMoveLeftNavigationEvent(NavigationMoveEvent evt)
        {
            Button targetButton = null;
            if (evt.direction == NavigationMoveEvent.Direction.Down)
            {
                targetButton = m_ResetButton;
            }

            if (targetButton != null)
            {
                targetButton.Focus();
                evt.StopPropagation();
                VisualElement target = (VisualElement)evt.target;
                target?.focusController?.IgnoreEvent(evt);
            }
        }

        private void PerformInteractiveRebind(ParrotActionContainer actionContainer, int bindingIndex, bool isGamepad = false)
        {
            InputAction action = actionContainer.ActionReference.action;

            m_RebindOperation?.Cancel(); // Will null out m_RebindOperation.

            // Disable the ability to close the screen when a rebind is active 
            m_PlayerController.CancelPressed -= OnClosePressed;

            void CleanUp()
            {
                m_RebindOperation?.Dispose();
                m_RebindOperation = null;
                action.Enable();

                // Allow the player to close the screen again now that the modal is closed
                // Note that we schedule this on a 100ms delay in order to ignore the cancel input that could have just been pressed
                actionContainer.schedule.Execute(BindCancelAction).StartingIn(k_PostRebindMinWaitDuration);
            }

            //Fixes the "InvalidOperationException: Cannot rebind action x while it is enabled" error
            action.Disable();

            m_RebindOperation = action.PerformInteractiveRebinding(bindingIndex);
            m_RebindOperation.WithControlsExcluding("<Keyboard>/anyKey");

            // Gamepad and MKB need different excluded controls and cancel keys 
            if (isGamepad)
            {
                m_RebindOperation
                    .WithControlsExcluding("<XInputController>/start")
                    .WithControlsExcluding("<XInputController>/select")
                    .WithControlsExcluding("<Gamepad>/select")
                    .WithControlsExcluding("<Gamepad>/start")
                    .WithCancelingThrough("<Gamepad>/start");
            }
            else
            {
                m_RebindOperation
                    .WithControlsExcluding("<Gamepad>/*")
                    .WithCancelingThrough("<Keyboard>/escape");
            }

            m_RebindOperation
                .OnCancel(
                    operation =>
                    {
                        actionContainer.UpdateBindingDisplay();
                        HidePressKeyModal();
                        CleanUp();
                    })
                .OnComplete(
                    operation =>
                    {
                        m_DisplayUnsavedChangesModal = true;
                        actionContainer.UpdateBindingDisplay();
                        HidePressKeyModal();
                        CleanUp();
                    });



            // Display the modal and wait for key press
            m_PressKeyContainer.style.display = DisplayStyle.Flex;

            // Start the rebind operation 
            m_RebindOperation.Start();
        }

        private bool UsingGamepad()
        {
            bool result = false;

            if (m_PlayerController != null)
            {
                result = m_PlayerController.CurrentInputType == InputType.Gamepad;
            }

            return result;
        }

        protected override VisualElement GetFirstFocusableElement()
        {
            return m_ApplyButton;
        }

        protected override void OnInputDeviceChanged(InputType type)
        {
            base.OnInputDeviceChanged(type);

            if (!m_IsVisible)
            {
                return;
            }

            if (type != m_LastInputType && m_RebindOperation != null)
            {
                // Cancel any active rebind operation
                m_RebindOperation.Cancel();
            }

            m_LastInputType = type;
        }
    }
}
