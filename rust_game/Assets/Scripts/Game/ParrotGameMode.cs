///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using Unity.Cinemachine;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace SecretDimension
{
    ///<summary>
    /// Sets up game objects and rules for gameplay
    ///</summary>
    [DefaultExecutionOrder(-100)]
    [RequireComponent(typeof(ParrotGameState))]
    public class ParrotGameMode : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Tooltip("The player pawn to spawn into the level when the game starts")]
        [Required]
        [SerializeField]
        private ParrotPlayerCharacter PawnPrefab;

        private ParrotGameState m_GameState;
        private ParrotPlayerController m_PlayerController;
        public ParrotPlayerController PlayerController { get { return m_PlayerController; } }
        private ParrotPlayerCharacter m_playerPawn;
        private Transform m_playerStart;
        private CinemachineCamera m_CinemachineCamera;

        private const string k_PlayerStartTag = "PlayerStart";

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            InitializeGameMode();
        }

        #endregion

        private void InitializeGameMode()
        {
            // Block the scene manager's transition until everything is initialized for play 
            var sceneManagerBlockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();

            string activeSceneName = SceneManager.GetActiveScene().name;

            m_GameState = GetComponent<ParrotGameState>();

            m_PlayerController = FindFirstObjectByType<ParrotPlayerController>();
            if (m_PlayerController == null)
            {
                Debug.LogError("Could not find player controller in " + activeSceneName + "! Aborting game mode initialization.");
                ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
                return;
            }

            GameObject playerStart = GameObject.FindWithTag(k_PlayerStartTag);
            if (playerStart == null)
            {
                Debug.LogError("No game object marked with player start in " + activeSceneName + "! Aborting game mode initialization.");
                ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
                return;
            }

            m_CinemachineCamera = FindFirstObjectByType<CinemachineCamera>();
            if (m_CinemachineCamera == null)
            {
                Debug.LogError("No cinemachine camera found in " + activeSceneName + "! Aborting game mode initialization.");
                ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
                return;
            }

            // Assign our start transform 
            m_playerStart = playerStart.transform;

            // Spawn pawn at player start position and rotation
            m_playerPawn = Instantiate(PawnPrefab, m_playerStart);

            // Initialize the controller with the pawn and the game state
            m_PlayerController.InitializeForGameplay(ref m_playerPawn, ref m_GameState);

            // Give our cinemachine camera the new follow target 
            m_CinemachineCamera.Target.TrackingTarget = m_playerPawn.GetComponent<Rigidbody>().transform;

            // Invalidate the previous state so that the camera snaps into the correct position this frame
            m_CinemachineCamera.PreviousStateIsValid = false;

            ParrotPositionComposer parrotPositionComposer = m_CinemachineCamera.gameObject.GetComponent<ParrotPositionComposer>();

            if (parrotPositionComposer != null)
            {
                parrotPositionComposer.SetPlayerCharacter(m_playerPawn);
            }

            // Bind to event
            ParrotSceneManager.OnSceneTransitionComplete += OnInitialSceneTransitionComplete;

            // Unblock the scene manager so that level transition can resume 
            ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
        }

        private void OnInitialSceneTransitionComplete(string scene)
        {
            // Unbind this event since we only care about this first time it's invoked
            ParrotSceneManager.OnSceneTransitionComplete -= OnInitialSceneTransitionComplete;

            // Intialize the game state for play
            m_GameState.InitializeGameState();
        }
    }
}
