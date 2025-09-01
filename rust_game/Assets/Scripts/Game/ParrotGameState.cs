///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections;
using UnityEngine;

namespace SecretDimension
{
    // Tracks the simple state of what is happening in the level 
    public enum ELevelState
    {
        Preload,
        Ready,
        Running,
        Paused,
        GameOver,
        Victory
    }

    ///<summary>
    /// Handles the current state of the game
    ///</summary>
    public class ParrotGameState : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Tooltip("The amount of time per level in seconds")]
        [SerializeField]
        [Range(0.0f, 1000.0f)]
        private float TimePerLevel = 300.0f;

        // The amount of time left remaining since the player started the level
        private float m_RemainingTime;

        public float TimeRemaining { get { return m_RemainingTime; } }

        // The amount of time accumulated since the player started the level
        private float m_AccumulatedTime;

        public float AccumulatedTime { get { return m_AccumulatedTime; } }

        // The previous state of the level
        private ELevelState m_PreviousLevelState;

        // The current state of the level
        private ELevelState m_CurrentLevelState = ELevelState.Preload;

        public ELevelState CurrentLevelStatate { get { return m_CurrentLevelState; } }

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Update is called once per frame
        /// </summary>
        private void Update()
        {
            UpdateGameTimer(Time.deltaTime);
        }
        #endregion

        // Called by the game mode when it's ready to start the game 
        public void InitializeGameState()
        {
            SetLevelState(ELevelState.Ready);

            // Broadcast that the game state has been initialized 
            GameplayEvents.GameStateInitialized?.Invoke(this);
        }

        private void SetLevelState(ELevelState NewState)
        {
            // Don't continue if we haven't actually changed state 
            if (m_CurrentLevelState == NewState)
            {
                return;
            }

            // Update previous level state
            m_PreviousLevelState = m_CurrentLevelState;

            // Update our current level state 
            m_CurrentLevelState = NewState;

            // Run any C++ specific state handling logic 
            switch (m_CurrentLevelState)
            {
                case ELevelState.GameOver:
                    HandleGameOver();
                    break;
                case ELevelState.Victory:
                    HandleVictory();
                    break;
                case ELevelState.Paused:
                    HandlePaused();
                    break;
                case ELevelState.Running:
                    HandleRunning();
                    break;
                case ELevelState.Ready:
                    HandleReady();
                    break;
                default:
                    break;
            }

            // Broadcast that the level state has changed to our action 
            GameplayEvents.LevelStateChanged?.Invoke(m_CurrentLevelState);
        }

        public void PauseGame()
        {
            SetLevelState(ELevelState.Paused);
        }

        public void UnPauseGame()
        {
            SetLevelState(ELevelState.Running);
        }

        public void PlayerOutOfBounds(ParrotPlayerCharacter player)
        {
            SetLevelState(ELevelState.GameOver);
        }

        public void PlayerDeath(ParrotPlayerCharacter player)
        {
            SetLevelState(ELevelState.GameOver);
        }

        public void CompleteLevel(ParrotPlayerCharacter player)
        {
            SetLevelState(ELevelState.Victory);
        }

        public void BossDefeated(float delay = 0.0f)
        {
            if (delay <= 0)
            {
                BossDefeatedTimerComplete();
                return;
            }

            StartCoroutine(BossDefeatedDelay(delay));
        }

        private IEnumerator BossDefeatedDelay(float delay)
        {
            yield return new WaitForSeconds(delay);
            BossDefeatedTimerComplete();
        }

        private void BossDefeatedTimerComplete()
        {
            SetLevelState(ELevelState.Victory);
        }

        private void HandleReady()
        {
            // Initialize our transient properties when a level is loaded but before it starts. 
            m_RemainingTime = TimePerLevel;
            m_AccumulatedTime = 0;

            SetLevelState(ELevelState.Running);
        }

        private void HandleGameOver()
        {
            // Broadcast game over event 
            GameplayEvents.GameOver?.Invoke();
        }

        private void HandleVictory()
        {
            // Broadcast victory event 
            GameplayEvents.Victory?.Invoke();
        }

        private void HandlePaused()
        {
            Time.timeScale = 0.0f;

            // Broadcast that the game has paused 
            GameplayEvents.PauseGame?.Invoke();
        }

        private void HandleRunning()
        {
            Time.timeScale = 1.0f;

            if (m_PreviousLevelState == ELevelState.Paused)
            {
                // Broadcast that the game has unpaused 
                GameplayEvents.ResumeGame?.Invoke();
            }
        }

        private void UpdateGameTimer(float deltaTime)
        {
            if (m_CurrentLevelState != ELevelState.Running)
            {
                return;
            }

            m_RemainingTime -= deltaTime;
            m_AccumulatedTime += deltaTime;

            if (m_RemainingTime <= 0)
            {
                // When the time runs out, the game is over 
                m_RemainingTime = 0.0f;
                SetLevelState(ELevelState.GameOver);
            }
        }
    }
}
