///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System; 
using System.Collections; 
using UnityEngine;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.SceneManagement;
using UnityEngine.AddressableAssets; 
using Singleton = SecretDimension.Singleton<SecretDimension.ParrotSceneManager>;

namespace SecretDimension
{
    // Credit to Aesthetician Labs 
    // Modified from source available here: https://github.com/aestheticianlabs/com.aela.utilities.scene-transition/blob/main/SceneTransitionManager.cs

    ///<summary>
    /// Manages scenes. Runs with high execution order. 
    ///</summary>
    [DefaultExecutionOrder(-1000)]
    public class ParrotSceneManager : MonoBehaviour
    {
        public static ParrotSceneManager Instance => Singleton.FindOrCreateInstance();

        /// <summary>
		/// Operations that should block transition progress.
		/// Add operations during one of the provided callbacks and be sure to set progress.
		/// All operations must reach a progress of 1 for transition to continue.
		/// </summary>
		public readonly ProgressiveOperationManager BlockingOperations = new ProgressiveOperationManager();

        /// <summary>
		/// Called right before a transition starts
		/// Params: from scene, destination scene
		/// </summary>
		public static Action<string, string> OnBeforeTransition;

		/// <summary>
		/// Called before the old scene is unloaded
		/// </summary>
		public static Action<string> OnBeforeUnload;

		/// <summary>
		/// Called after the old scene is unloaded
		/// </summary>
		public static Action<string> OnAfterUnload;

		/// <summary>
		/// Called before the next scene starts to load
		/// </summary>
		public static Action<string> OnBeforeLoad;

		/// <summary>
		/// Called during loading to update progress
		/// </summary>
		public static Action<float> OnLoadProgress;

		/// <summary>
		/// Called before scene is activated
		/// </summary>
		public static Action<string> OnBeforeActivate;

		/// <summary>
		/// Called right before OnSceneReady or when the first scene is loaded
		/// (i.e. after hitting play in the editor). Always called for each scene during Start.
		/// </summary>
		public static Action<string> OnBeforeSceneReady;

		/// <summary>
		/// Called right before OnSceneTransitionComplete or when the first scene is loaded
		/// (i.e. after hitting play in the editor). Always called for each scene during Start.
		/// </summary>
		public static Action<string> OnSceneReady;

		/// <summary>
		/// Called once entire transition is complete
		/// </summary>
		/// <remarks>Blocking operations added during this callback will be ignored</remarks>
		public static Action<string> OnSceneTransitionComplete;

		/// <summary>
		/// Called once the logo train has completed
		/// </summary>
		public static Action OnLogoTrainComplete; 

        [Tooltip("When true, pauses the time scale based on load state")]
		public bool ControlTimeScale = true;

		private string currentScene, nextScene;
		private bool isLoading;

		public Scene ActiveScene { get; private set; }

		/// <summary>
		/// True if we are currently changing scenes
		/// </summary>
		public bool IsLoading => isLoading;

		public bool IsSceneReady { get; private set; }

		/// <summary>
		/// Begins transition from the current scene to the scene with the provided name
		/// </summary>
		public void ChangeScene(string path) => ChangeSceneInternal(path);

		/// <summary>
		/// Reloads the primary scene, including all dependencies
		/// </summary>
		public void ReloadScene(string path) => ReloadSceneInternal(path);

        private void Awake()
		{
			if (!Singleton.CheckInstance(this, true))
			{
				return;
			}

			Singleton.SetInstance(this);
		}

		private void Start()
		{
			DontDestroyOnLoad(this);

			if (!IsLoading) // first scene load
			{
				isLoading = true;
				currentScene = nextScene = SceneManager.GetActiveScene().path;
				StartCoroutine(ReadySceneRoutine());
			}
		}

		private void ChangeSceneInternal(string scenePath)
		{
			if (isLoading)
			{
				Log("Can't change scenes right now because we're already changing scenes!", LogType.Error);
				return;
			}

			currentScene = SceneManager.GetActiveScene().path;
			nextScene = scenePath;
			if (BlockingOperations.Operations.Count > 0)
			{
				Log($"Cleared {BlockingOperations.Operations.Count} invalid blocking operations", LogType.Warning);
				BlockingOperations.Clear();
			}

			StartCoroutine(ChangeSceneRoutine());
		}

		private IEnumerator ChangeSceneRoutine()
		{
			isLoading = true;

			Log("OnBeforeTransition");
			OnBeforeTransition?.Invoke(currentScene, nextScene);
			yield return WaitForBlockingOperations();

			Log("OnBeforeLoad");
			OnBeforeLoad?.Invoke(nextScene);
			yield return WaitForBlockingOperations(true);

			if (ControlTimeScale) Time.timeScale = 0;
			IsSceneReady = false;

			Log("Loading next scene...");
			// load next scene
			AsyncOperation op = null;

			var sceneOp = Addressables.LoadSceneAsync(nextScene, LoadSceneMode.Additive, false);

			while (sceneOp is { Status: AsyncOperationStatus.None, IsDone: false })
			{
				OnLoadProgress?.Invoke(sceneOp.PercentComplete);
				yield return null;
			}

			// throw scene load exception if we can't fall back to SceneManager
			if (!Application.isEditor && sceneOp.OperationException != null)
			{
				throw sceneOp.OperationException;
			}

			// otherwise, log a warning in the editor
			if (sceneOp.Status == AsyncOperationStatus.Failed)
			{
				Log(
					$"Failed to load scene {nextScene} from Addressables. Falling back to SceneManager (editor).",
					LogType.Warning
				);
			}

			// failed to load from addressables, fall back to SceneManager load (in editor)
			// this lets us load scenes in the editor that we don't necessarily want in the build
			if (sceneOp.Status == AsyncOperationStatus.Failed)
			{
				op = SceneManager.LoadSceneAsync(nextScene, LoadSceneMode.Additive);
				op.allowSceneActivation = false;
				while (op.progress < 0.9f) // scene load progress stops at 0.9 when allowSceneActivation = false
				{
					OnLoadProgress?.Invoke(op.progress);
					yield return null;
				}
			}

			Log("OnBeforeActivate");
			OnBeforeActivate?.Invoke(nextScene);
			yield return WaitForBlockingOperations(true);

			Log("Activating new scene...");
			// activate and integrate new scene

			if (sceneOp.Status == AsyncOperationStatus.Succeeded)
			{
				op = sceneOp.Result.ActivateAsync();
			}
			else
			{
				op.allowSceneActivation = true;
			}

			while (!op.isDone) yield return null;
			SceneManager.SetActiveScene(SceneManager.GetSceneByPath(nextScene));

			Log("OnBeforeUnload");
			OnBeforeUnload?.Invoke(currentScene);
			yield return WaitForBlockingOperations();

			Log("Unloading previous...");

			// unload previous scene
			yield return SceneManager.UnloadSceneAsync(currentScene);

			// Because we are using additive scene loading, unload any unused assets 
			yield return Resources.UnloadUnusedAssets();

			Log("OnAfterUnload");
			OnAfterUnload?.Invoke(currentScene);
			yield return WaitForBlockingOperations();

			yield return ReadySceneRoutine();
		}

		private IEnumerator ReadySceneRoutine()
		{
			// set again here in case this was started outside of the main load routine (i.e. Start)
			if (ControlTimeScale) Time.timeScale = 0;

			ActiveScene = SceneManager.GetActiveScene();

			Log("OnBeforeSceneReady");
			OnBeforeSceneReady?.Invoke(nextScene);
			yield return WaitForBlockingOperations();

			IsSceneReady = true;
			Log("OnSceneReady");
			OnSceneReady?.Invoke(nextScene);
			yield return WaitForBlockingOperations();

			if (ControlTimeScale) Time.timeScale = 1;

			Log("OnSceneTransitionComplete");
			isLoading = false;
			OnSceneTransitionComplete?.Invoke(nextScene);
		}

		private IEnumerator WaitForBlockingOperations(bool reportProgress = false)
		{
			var completeCount = 0;
			while (BlockingOperations.Operations.Count > 0)
			{
				var progress = 0f;
				for (int i = BlockingOperations.Operations.Count - 1; i >= 0; i--)
				{
					var op = BlockingOperations.Operations[i];
					if (op.IsComplete)
					{
						BlockingOperations.Release(op);
						completeCount++;
					}
					else
					{
						progress += op.Progress;
					}
				}

				progress += completeCount;
				progress /= BlockingOperations.Operations.Count + completeCount;

				if (reportProgress)
				{
					OnLoadProgress?.Invoke(progress);
				}

				yield return null;
			}
		}

		private void ReloadSceneInternal(string scenePath)
        {
            if (isLoading)
			{
				Log("Can't reload scene right now because we're already changing scenes!", LogType.Error);
				return;
			}

			// This can happen if we're loading from an environment level for testing in editor
			if(currentScene != scenePath)
			{
				currentScene = scenePath;
			}

			SceneManager.SetActiveScene(SceneManager.GetSceneByPath(currentScene));
			nextScene = currentScene; 
			
			if (BlockingOperations.Operations.Count > 0)
			{
				Log($"Cleared {BlockingOperations.Operations.Count} invalid blocking operations", LogType.Warning);
				BlockingOperations.Clear();
			}

			StartCoroutine(ReloadSceneRoutine());
        }

		private IEnumerator ReloadSceneRoutine()
		{
			yield return ChangeSceneRoutine(); 
			SceneManager.SetActiveScene(SceneManager.GetSceneByPath(currentScene));
			Log($"OnSceneReloadComplete successful.");
		}
		
		private void Log(string message, LogType type = LogType.Log)
		{
            switch(type)
            {
                case LogType.Error:
                    Debug.LogError($"[ParrotSceneManager] {message} (Active: {SceneManager.GetActiveScene().name})"); 
                    break;
                case LogType.Warning:
                    Debug.LogWarning($"[ParrotSceneManager] {message} (Active: {SceneManager.GetActiveScene().name})"); 
                    break;
                default:
                    Debug.Log($"[ParrotSceneManager] {message} (Active: {SceneManager.GetActiveScene().name})"); 
                    break; 
            }
		}
    }
}
