///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// A UI Builder Button with an auto-sizing text label 
    ///</summary>
    ///

    [UxmlElement]
    public partial class ParrotButtonBase : Button
    {

        private string m_TargetText;
        private float m_minFontSize = 20.0f;
        private float m_maxFontSize = 400.0f;

        [UxmlAttribute]
        [SerializeField]
        private string TargetText
        {
            get => m_TargetText;
            set
            {
                m_TargetText = value;
                if (m_Label != null)
                {
                    m_Label.TargetText = m_TargetText;
                }
            }
        }

        [UxmlAttribute]
        [SerializeField]
        private float MinFontSize
        {
            get => m_minFontSize;
            set
            {
                m_minFontSize = value;
                if (m_Label != null)
                {
                    m_Label.MinFontSize = m_minFontSize;
                }
            }
        }

        [UxmlAttribute]
        [SerializeField]
        private float MaxFontSize
        {
            get => m_maxFontSize;
            set
            {
                m_maxFontSize = value;
                if (m_Label != null)
                {
                    m_Label.MaxFontSize = m_maxFontSize;
                }
            }
        }

        LabelAutofit m_Label;

        public ParrotButtonBase()
        {
            RegisterCallback<AttachToPanelEvent>(OnAttachToPanel);
        }

        private void OnAttachToPanel(AttachToPanelEvent e)
        {
            if (m_Label == null)
            {
                // Add autofit text  
                m_Label = new LabelAutofit(TargetText, MinFontSize, MaxFontSize);
                m_Label.name = "ButtonText";
                m_Label.pickingMode = PickingMode.Ignore;
            }

            Add(m_Label);
            UnregisterCallback<AttachToPanelEvent>(OnAttachToPanel);
        }
    }
}
