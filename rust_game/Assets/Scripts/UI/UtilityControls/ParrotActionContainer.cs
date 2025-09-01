///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using System.Text.RegularExpressions;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Visual Element which handles display and adjustment of an input action binding
    ///</summary>
    [UxmlElement]
    public partial class ParrotActionContainer : VisualElement
    {

        [UxmlAttribute("Action")]
        [SerializeField]
        public InputActionReference ActionReference
        {
            get => m_Action;
            set
            {
                m_Action = value;
                UpdateActionLabel();
                UpdateBindingDisplay();
            }
        }

        [UxmlAttribute("KeyboardBindingID")]
        [SerializeField]
        public int KeyboardBindingId
        {
            get => m_KeyboardBindingId;
            set
            {
                m_KeyboardBindingId = value;
                if (m_KeyboardBindingId < 0)
                {
                    m_KeyboardBindingId = 0;
                }

                var action = m_Action?.action;
                if (action != null)
                {
                    if (m_KeyboardBindingId > action.bindings.Count - 1)
                    {
                        m_KeyboardBindingId = action.bindings.Count - 1;
                    }
                }
                UpdateBindingDisplay();
            }
        }

        [UxmlAttribute("GamepadBindingID")]
        [SerializeField]
        public int GamepadBindingID
        {
            get => m_GamepadBindingId;
            set
            {
                m_GamepadBindingId = value;
                if (m_GamepadBindingId < 0)
                {
                    m_GamepadBindingId = 0;
                }

                var action = m_Action?.action;
                if (action != null)
                {
                    if (m_GamepadBindingId > action.bindings.Count - 1)
                    {
                        m_GamepadBindingId = action.bindings.Count - 1;
                    }
                }
            }
        }

        [UxmlAttribute("SpriteData")]
        [SerializeField]
        public KeyGlyphData SpriteData;


        // Reference to the action to be rebound from the UI 
        private InputActionReference m_Action;

        private int m_KeyboardBindingId = 0;

        private int m_GamepadBindingId = 1;

        private InputBinding.DisplayStringOptions m_DisplayStringOptions;

        private Label m_ActionTitleLabel;
        private LabelAutofit m_ActionKeyboardLabel;
        private Button m_GamepadButton;
        private Button m_KeyboardButton;
        private LabelAutofit m_GamepadLabel;

        private const string k_ActionTitle = "action-title";
        private const string k_ActionKeyboard = "keyboard-label";
        private const string k_ActionGamepadButton = "gamepad-button";
        private const string k_ActionKeyboardButton = "keyboard-button";
        private const string k_ActionGamepadLabel = "gamepad-label";
        private const string k_GamepadDisplayPrefx = "<Gamepad>/";

        private Dictionary<string, string> m_SpriteDictionary = new Dictionary<string, string>();

        public ParrotActionContainer()
        {
            RegisterCallback<AttachToPanelEvent>(OnAttachToPanel);
        }

        ~ParrotActionContainer()
        {
            ApplicationEvents.InputDeviceChanged -= InputDeviceChanged;
        }

        private void OnAttachToPanel(AttachToPanelEvent e)
        {
            UnregisterCallback<AttachToPanelEvent>(OnAttachToPanel);
            RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
        }

        private void OnGeometryChanged(GeometryChangedEvent e)
        {
            InitializeActionContainer();
        }

        public void InitializeActionContainer()
        {
            m_ActionTitleLabel = this.Q<Label>(k_ActionTitle);
            m_ActionKeyboardLabel = this.Q<LabelAutofit>(k_ActionKeyboard);
            m_GamepadButton = this.Q<Button>(k_ActionGamepadButton);
            m_KeyboardButton = this.Q<Button>(k_ActionKeyboardButton);
            m_GamepadLabel = this.Q<LabelAutofit>(k_ActionGamepadLabel);

            // Initialize our sprite dictionary once
            if (SpriteData != null && m_SpriteDictionary.Count < 1)
            {
                m_SpriteDictionary = SpriteData.GetDictionary();
            }

            ApplicationEvents.InputDeviceChanged += InputDeviceChanged;

            UpdateActionLabel();
            UpdateBindingDisplay();
        }

        public void InputDeviceChanged(InputType newType)
        {
            if (newType == InputType.Gamepad)
            {
                m_KeyboardButton.SetEnabled(false);
                m_GamepadButton.SetEnabled(true);
            }
            else
            {
                m_GamepadButton.SetEnabled(false);
                m_KeyboardButton.SetEnabled(true);
            }
        }

        private void UpdateActionLabel()
        {
            if (m_ActionTitleLabel != null)
            {
                m_ActionTitleLabel.text = GetActionDisplayName();
            }
        }

        public string GetActionDisplayName()
        {
            var action = m_Action?.action;

            if (action != null)
            {
                var text = action.name;
                text = Regex.Replace(text, "([A-Z])", " $1", RegexOptions.Compiled);
                return text;
            }
            else
            {
                return string.Empty;
            }
        }

        public void UpdateBindingDisplay()
        {
            var displayString = string.Empty;
            var deviceLayoutName = default(string);
            var controlPath = default(string);

            // Get display string from action.
            var action = m_Action?.action;
            if (action != null)
            {
                // Update the keyboard binding display 
                displayString = action.GetBindingDisplayString(m_KeyboardBindingId, out deviceLayoutName, out controlPath, m_DisplayStringOptions);

                if (m_ActionKeyboardLabel != null)
                {
                    m_ActionKeyboardLabel.TargetText = displayString;
                }

                if (m_GamepadLabel != null)
                {
                    // Update the gamepad binding display 
                    displayString = action.bindings[m_GamepadBindingId].effectivePath;
                    displayString = displayString.Replace(k_GamepadDisplayPrefx, "");

                    if (m_SpriteDictionary.ContainsKey(displayString))
                    {
                        displayString = m_SpriteDictionary[displayString];
                    }
                    else
                    {
                        displayString = string.Empty;
                    }

                    m_GamepadLabel.text = displayString;
                }
            }
        }

        public Button GetGamepadButton()
        {
            return m_GamepadButton;
        }

        public Button GetKeyboardButton()
        {
            return m_KeyboardButton;
        }

        public void SetGamepadLabelText(string newText)
        {
            if (m_GamepadLabel != null)
            {
                m_GamepadLabel.text = newText;
            }
        }
    }
}
