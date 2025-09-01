///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    // Automatically adjusts text size
    [UxmlElement]
    public partial class LabelAutofit : Label
    {
        private float m_minFontSize = 20.0f;
        private float m_maxFontSize = 400.0f;
        private string m_TargetText = "";

        [UxmlAttribute]
        [SerializeField]
        public string TargetText
        {
            get => m_TargetText;
            set
            {
                m_TargetText = value;
                text = m_TargetText;
            }
        }

        [UxmlAttribute]
        [SerializeField]
        public float MinFontSize
        {
            get => m_minFontSize;
            set
            {
                m_minFontSize = value;
                UpdateFontSize();
            }
        }

        [UxmlAttribute]
        [SerializeField]
        public float MaxFontSize
        {
            get => m_maxFontSize;
            set
            {
                m_maxFontSize = value;
                UpdateFontSize();
            }
        }

        // When true, a resize is being executed
        bool m_ExecutingShedule;

        public LabelAutofit()
        {
            RegisterCallback<AttachToPanelEvent>(OnAttachToPanel);
        }

        public LabelAutofit(string newText, float newMin, float newMax)
        {
            TargetText = newText;
            MinFontSize = newMin;
            MaxFontSize = newMax;
        }

        private void OnAttachToPanel(AttachToPanelEvent e)
        {
            UnregisterCallback<AttachToPanelEvent>(OnAttachToPanel);
            RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
        }

        private void OnGeometryChanged(GeometryChangedEvent e)
        {
            UpdateFontSize();
        }

        private void UpdateFontSize()
        {
            // Schedule resize
            schedule.Execute(() =>
            {
                var textSize = MeasureTextSize(text, float.MaxValue, MeasureMode.AtMost, float.MaxValue, MeasureMode.AtMost);
                var fontSize = Mathf.Max(resolvedStyle.fontSize, 1);
                var heightDictatedFontSize = Mathf.Abs(contentRect.height);
                var widthDictatedFontSize = Mathf.Abs(contentRect.width / textSize.x) * fontSize;
                var newFontSize = Mathf.FloorToInt(Mathf.Min(heightDictatedFontSize, widthDictatedFontSize));
                newFontSize = (int)Mathf.Clamp(newFontSize, MinFontSize, MaxFontSize);

                m_ExecutingShedule = Mathf.Abs(newFontSize - fontSize) > 1;

                if (!m_ExecutingShedule)
                    return;

                style.fontSize = new StyleLength(newFontSize);
            }).Until(() => !m_ExecutingShedule);
        }
    }
}
