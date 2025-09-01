///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Manages the view of the Gameplay HUD 
    ///</summary>
    public class GameplayView : UIView
    {
        #region Attributes
        // Attributes
        private const string k_TimerViewName = "timer-time";
        private const string k_HeartContainerViewName = "heart-container";

        // Element that holds spawned hearts 
        private VisualElement m_HeartContainer;

        private Label m_Timer;

        // The template used for a hitpoint heart 
        private VisualTreeAsset m_HitPointTemplate;

        private ParrotPlayerCharacter m_PlayerCharacter;

        #endregion

        public GameplayView(VisualElement topElement, ParrotPlayerController playerController, VisualTreeAsset heartAsset) : base(topElement, playerController)
        {
            m_HitPointTemplate = heartAsset;

            // Set initial hitpoints 
            UpdateHitpointUI(m_PlayerCharacter.CurrentHitPoints);
        }

        protected override void SetVisualElements()
        {
            base.SetVisualElements();
            m_PlayerCharacter = m_PlayerController.PlayerCharacter;

            if (m_PlayerCharacter == null)
            {
                Debug.LogError("Could not get player character from controller in GameplayView!");
                return;
            }

            m_Timer = m_TopElement.Q<Label>(k_TimerViewName);
            m_HeartContainer = m_TopElement.Q<VisualElement>(k_HeartContainerViewName);
        }

        protected override void RegisterElementCallbacks()
        {
            base.RegisterElementCallbacks();
            m_PlayerCharacter.OnHitPointsAdded += HitPointsChanged;
            m_PlayerCharacter.OnCharacterHit += HitPointsChanged;
        }

        public override void Dispose()
        {
            base.Dispose();
            m_PlayerCharacter.OnHitPointsAdded -= HitPointsChanged;
            m_PlayerCharacter.OnCharacterHit -= HitPointsChanged;
        }

        private void HitPointsChanged()
        {
            UpdateHitpointUI(m_PlayerCharacter.CurrentHitPoints);
        }

        public void UpdateHitpointUI(int hitPoints)
        {
            if (m_HeartContainer.childCount < hitPoints)
            {
                // Add hearts
                for (int iHeart = m_HeartContainer.childCount; iHeart < hitPoints; iHeart++)
                {
                    var heart = m_HitPointTemplate.CloneTree();
                    m_HeartContainer.Add(heart);
                }
            }
            else if (m_HeartContainer.childCount > hitPoints)
            {
                // Remove hearts
                while (m_HeartContainer.childCount > hitPoints)
                {
                    m_HeartContainer.RemoveAt(m_HeartContainer.childCount - 1);
                }
            }
        }

        public void UpdateTimerValue(float time)
        {
            int minutes = Mathf.FloorToInt(time / 60.0f);
            int seconds = Mathf.FloorToInt(time - minutes * 60.0f);
            string formattedTime = string.Format("{0:0}:{1:00}", minutes, seconds);
            m_Timer.text = formattedTime;
        }
    }
}
