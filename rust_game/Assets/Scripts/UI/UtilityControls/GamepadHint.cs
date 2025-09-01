///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Maps an input action reference to the the sprite value label
    ///</summary>
    [UxmlElement]
    public partial class GamepadHint : VisualElement
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
        private Label m_TitleText;
        private Label m_IconText;
        private int m_GamepadBindingId = 0;
        private InputBinding.DisplayStringOptions m_DisplayStringOptions;
        private Dictionary<string, string> m_SpriteDictionary = new Dictionary<string, string>();
        private const string k_GamepadDisplayPrefx = "<Gamepad>/";
        private const string k_IconTitle = "title";
        private const string k_Icon = "icon";

        public GamepadHint()
        {
            RegisterCallback<AttachToPanelEvent>(OnAttachToPanel);
        }

        private void OnAttachToPanel(AttachToPanelEvent e)
        {
            UnregisterCallback<AttachToPanelEvent>(OnAttachToPanel);
            RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
        }

        private void OnGeometryChanged(GeometryChangedEvent e)
        {
            InitializeHint();
        }

        private void InitializeHint()
        {
            m_TitleText = this.Q<Label>(k_IconTitle);
            m_IconText = this.Q<Label>(k_Icon);

            // Initialize our sprite dictionary once
            if (SpriteData != null && m_SpriteDictionary.Count < 1)
            {
                m_SpriteDictionary = SpriteData.GetDictionary();
            }

            UpdateActionLabel();
            UpdateBindingDisplay();
        }

        private void UpdateActionLabel()
        {
            if (m_TitleText != null)
            {
                m_TitleText.text = GetActionDisplayName();
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

            // Get display string from action.
            var action = m_Action?.action;
            if (action != null)
            {
                if (m_IconText != null)
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

                    m_IconText.text = displayString;
                }
            }
        }
    }
}
