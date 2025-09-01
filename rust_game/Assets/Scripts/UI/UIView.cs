///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using UnityEngine.UIElements;

namespace SecretDimension
{
    // Credit to Unity Sample Project: Dragon Crashers

    /// <summary>
    /// This is a base class for a functional unit of the UI. This can make up a full-screen interface or just
    /// part of one.
    /// </summary>

    public class UIView : IDisposable
    {
        protected bool m_HideOnAwake = true;

        // UI reveals other underlaying UIs, partially see-through
        protected bool m_IsOverlay;

        protected VisualElement m_TopElement;

        protected VisualElement m_FocusedElement;

        // The player that owns this UI View
        protected ParrotPlayerController m_PlayerController;

        // Properties
        public VisualElement Root => m_TopElement;
        public bool IsTransparent => m_IsOverlay;
        public bool IsHidden => m_TopElement.style.display == DisplayStyle.None;

        protected bool m_IsVisible;

        // Constructor
        /// <summary>
        /// Initializes a new instance of the UIView class.
        /// </summary>
        /// <param name="topElement">The topmost VisualElement in the UXML hierarchy.</param>
        public UIView(VisualElement topElement, ParrotPlayerController playerController = null)
        {
            m_TopElement = topElement ?? throw new ArgumentNullException(nameof(topElement));
            m_PlayerController = playerController;
            Initialize();
        }

        public virtual void Initialize()
        {
            if (m_HideOnAwake)
            {
                Hide();
            }
            SetVisualElements();
            RegisterElementCallbacks();
            ApplicationEvents.InputDeviceChanged += OnInputDeviceChanged;

            if (m_PlayerController != null)
            {
                if (m_PlayerController.CurrentInputType == InputType.Gamepad)
                {
                    FocusFirstFocusableElement();
                }

                // Initialize any input contingent visual elements
                var query = m_TopElement.Query<ParrotVisibilityBorder>(); 
                foreach(var hint in query.ToList())
                {
                    hint.InputDeviceChanged(m_PlayerController.CurrentInputType); 
                }
            }
        }

        // Sets up the VisualElements for the UI. Override to customize.
        protected virtual void SetVisualElements()
        {
        }

        // Registers callbacks for elements in the UI. Override to customize.
        protected virtual void RegisterElementCallbacks()
        {
        }

        // Displays the UI.
        public virtual void Show()
        {
            m_TopElement.style.display = DisplayStyle.Flex;
            m_IsVisible = true;
        }

        // Hides the UI.
        public virtual void Hide()
        {
            m_TopElement.style.display = DisplayStyle.None;
            m_IsVisible = false;
        }

        // Unregisters any callbacks or event handlers. Override to customize.
        public virtual void Dispose()
        {
            ApplicationEvents.InputDeviceChanged -= OnInputDeviceChanged;
        }

        // Handles input device changes for this screen. Override to customize
        protected virtual void OnInputDeviceChanged(InputType type)
        {
            if (!m_IsVisible)
            {
                return;
            }

            if (type == InputType.MouseAndKeyboard)
            {
                UnfocusLastActiveElement();
            }
            else
            {
                FocusLastActiveElement();
            }
        }

        // Restores focus to the last focused element if there is one
        protected void FocusLastActiveElement()
        {
            if (!m_IsVisible)
            {
                return;
            }

            if (m_FocusedElement != null)
            {
                m_FocusedElement.Focus();
            }
            else
            {
                FocusFirstFocusableElement();
            }
        }

        // Focuses to the first element available, if there is one 
        protected void FocusFirstFocusableElement()
        {
            if (!m_IsVisible)
            {
                return;
            }

            m_FocusedElement = GetFirstFocusableElement();

            if (m_FocusedElement != null)
            {
                m_FocusedElement.Focus();
            }
        }

        protected void UnfocusLastActiveElement()
        {
            // Tell the element to release the focus 
            if (m_FocusedElement != null)
            {
                m_FocusedElement.Blur();
            }
        }

        // Sets the first focusable element for this screen. Override to customize
        protected virtual VisualElement GetFirstFocusableElement()
        {
            return null;
        }

        protected void OnButtonHover(FocusEvent evt)
        {
            if (!m_IsVisible)
            {
                return;
            }

            m_FocusedElement = (VisualElement)evt.currentTarget;
            ParrotAudioController.Instance.PlayButtonHoverSound();
        }

        protected void OnButtonHover(MouseOverEvent evt)
        {
            if (!m_IsVisible)
            {
                return;
            }

            m_FocusedElement = (VisualElement)evt.currentTarget;
            ParrotAudioController.Instance.PlayButtonHoverSound();
        }
    }
}
