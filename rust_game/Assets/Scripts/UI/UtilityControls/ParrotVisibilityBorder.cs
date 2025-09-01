///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using Unity.AppUI.UI;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Hides this element's children when the desired input type is not active 
    ///</summary>
    [UxmlElement]
    public partial class ParrotVisibilityBorder : VisualElement
    {
        [UxmlAttribute("VisibleInputType")]
        public InputType TargetType;

        public ParrotVisibilityBorder()
        {
            RegisterCallback<AttachToPanelEvent>(OnAttachToPanel);
        }

        ~ParrotVisibilityBorder()
        {
            ApplicationEvents.InputDeviceChanged -= InputDeviceChanged;
        }

        private void OnAttachToPanel(AttachToPanelEvent e)
        {
            UnregisterCallback<AttachToPanelEvent>(OnAttachToPanel);
            ApplicationEvents.InputDeviceChanged += InputDeviceChanged;
        }

        public void InputDeviceChanged(InputType newType)
        {
            if (newType == TargetType)
            {
                foreach (var child in this.GetChildren<VisualElement>(true))
                {
                    child.style.display = DisplayStyle.Flex;
                }
            }
            else
            {
                foreach (var child in this.GetChildren<VisualElement>(true))
                {
                    child.style.display = DisplayStyle.None;
                }
            }
        }
    }
}
