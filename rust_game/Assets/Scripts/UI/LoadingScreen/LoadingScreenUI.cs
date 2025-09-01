///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections;
using UnityEngine;
using UnityEngine.UIElements;

namespace SecretDimension
{
    ///<summary>
    /// Controls the loading screen, updates progress, and ensures that a minimum time has been reached before completing scene transition
    ///</summary>
    [RequireComponent(typeof(UIDocument))]
    [RequireComponent(typeof(Camera))]
    public class LoadingScreenUI : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Header("Loading Screen Settings")]
        [Tooltip("The minimum amount of time in seconds to hold the loading screen after scene transition's complete")]
        [SerializeField]
        private float MinLoadHoldTime = 2.0f;

        [Tooltip("The bootstrap scene that we should ignore when determining if the loading screen should be shown")]
        [SerializeField]
        [Required]
        private SceneField BootStrapScene;

        // The UI document that renders the loading screen 
        private UIDocument m_LoadingScreenDocument;

        // The camera that renders the UI document 
        private Camera m_LoadingCamera;
        private const string k_LoadingScreenViewName = "LoadingScreen";

        // The view which controls elements of the loading screen 
        private LoadingScreenView m_LoadingView;

        // The time the load has started 
        private float m_LoadStartTime;

        // The current primary scene 
        private string m_CurrentScene;

        #endregion

        #region Unity Methods
        // Unity Methods

        private void Awake()
        {
            m_LoadingCamera = GetComponent<Camera>();
            m_LoadingCamera.enabled = false;
        }

        private void OnEnable()
        {
            m_LoadingScreenDocument = GetComponent<UIDocument>();
            SetupViews();
            SubscribeToEvents();
        }

        private void OnDisable()
        {
            UnsubscribeToEvents();
            if (m_LoadingView != null)
            {
                m_LoadingView.Dispose();
            }
        }

        #endregion

        #region UI

        private void SetupViews()
        {
            VisualElement root = m_LoadingScreenDocument.rootVisualElement;
            m_LoadingView = new LoadingScreenView(root.Q<VisualElement>(k_LoadingScreenViewName));
        }

        private void SubscribeToEvents()
        {
            ParrotSceneManager.OnBeforeTransition += OnBeforeSceneTransition;
            ParrotSceneManager.OnSceneReady += OnSceneReady;
        }

        private void UnsubscribeToEvents()
        {
            ParrotSceneManager.OnBeforeTransition -= OnBeforeSceneTransition;
            ParrotSceneManager.OnSceneReady -= OnSceneReady;
        }

        private void OnBeforeSceneTransition(string currentScene, string nextScene)
        {
            m_CurrentScene = currentScene;

            // Ignore scene transitions starting from the bootstrapping scene
            if (m_CurrentScene == BootStrapScene)
            {
                return;
            }

            m_LoadingCamera.enabled = true;
            m_LoadStartTime = Time.time;
            m_LoadingView.SetProgress(0.0f);
            m_LoadingView.Show();

            // Inform the game instance that we're loading now
            if (ParrotGameInstance.Instance != null)
            {
                ParrotGameInstance.Instance.SetLoadingScreenActive(true);
            }

            // Stop any active sounds being played that are not music
            if (ParrotAudioController.Instance != null)
            {
                ParrotAudioController.Instance.StopGameplaySFXSource();
                ParrotAudioController.Instance.StopUISFXSource();
            }
        }

        private void OnSceneReady(string newScene)
        {
            if (newScene == BootStrapScene || m_CurrentScene == BootStrapScene)
            {
                return;
            }

            // Start routine to make sure that the loading screen has been up for a minimum amount of time
            float coroutineStartTime = Time.time;
            var loadScreenBlockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();
            StartCoroutine(MinTimeRoutine(loadScreenBlockOp, coroutineStartTime));
        }

        private IEnumerator MinTimeRoutine(ProgressiveOperationManager.Operation loadScreenBlockOp, float coroutineStartTime)
        {
            float timeToWait = MinLoadHoldTime - (coroutineStartTime - m_LoadStartTime);
            if (timeToWait > 0)
            {
                float waitDuration = 0.0f;
                while (waitDuration < timeToWait)
                {
                    // Note that we use unscaled dela time here as the scene manager controls the time scale 
                    // Time scale will be zero at this point

                    // Update progress bar 
                    float progress = Mathf.MoveTowards(m_LoadingView.GetProgress(), 1.0f, Time.unscaledDeltaTime);
                    m_LoadingView.SetProgress(progress);

                    // Update wait duration 
                    waitDuration += Time.unscaledDeltaTime;
                    yield return null;
                }
            }
            else
            {
                // Update progress bar 
                m_LoadingView.SetProgress(1.0f);
            }

            // Stop blocking the scene manager
            ParrotSceneManager.Instance.BlockingOperations.Release(loadScreenBlockOp);

            // Clean up loading screen 
            m_LoadingView.Hide();
            m_LoadingView.SetProgress(0.0f);
            m_LoadingCamera.enabled = false;

            if (ParrotGameInstance.Instance != null)
            {
                ParrotGameInstance.Instance.SetLoadingScreenActive(false);
            }
        }

        #endregion
    }
}
