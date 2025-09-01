///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.ResourceManagement.ResourceLocations;
using UnityEngine.SceneManagement;

#if UNITY_EDITOR
using UnityEditor.SceneManagement;
#endif

namespace SecretDimension
{
    ///<summary>
    /// Async loads all scene dependencies and blocks the scene manager until complete
    ///</summary>
    [DefaultExecutionOrder(-99)]
    public class ParrotSceneResources : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Header("Required Dependency Scenes")]
        [Tooltip("Additive scenes that must be activated when all other additive scenes are loaded")]
        [SerializeField]
        private SceneField[] DelayedScenes;

        [Tooltip("Additive scenes that must be loaded and activated immediately")]
        [SerializeField]
        private SceneField[] ImmediateScenes;

        [Tooltip("When true, will unload all this scene's loaded resources whenever this scene reloads. Should probably only be used on primary scenes.")]
        [SerializeField]
        private bool AlwaysUnloadResourcesOnSceneChange = false;

        private string m_parentScene;
        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            // Cache the scene that this script belongs to 
            m_parentScene = gameObject.scene.path;

            // Bind to transition calls
            // Check when the scene is ready
            ParrotSceneManager.OnBeforeSceneReady += CheckLoadDependencies;

            // Check when transitioning from one scene to another 
            ParrotSceneManager.OnBeforeTransition += CheckUnloadDependencies;
        }

        void OnDestroy()
        {
            ParrotSceneManager.OnBeforeSceneReady -= CheckLoadDependencies;
            ParrotSceneManager.OnBeforeTransition -= CheckUnloadDependencies;
        }
        #endregion

        private void CheckLoadDependencies(string nextScene)
        {
            // Check if we just loaded into this game object's scene 
            if (nextScene == m_parentScene)
            {
                var sceneManagerBlockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();
                LoadDependencies(sceneManagerBlockOp);
            }
        }

        private void CheckUnloadDependencies(string currentScene, string nextScene)
        {
            // If the current scene is the parent game object scene, we must be going to a different scene and need to unload 
            if (currentScene == m_parentScene || AlwaysUnloadResourcesOnSceneChange)
            {
                var sceneManagerBlockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();
                UnloadDependencies(sceneManagerBlockOp);
            }
        }

        // Loads up all dependent scenes
        private async void LoadDependencies(ProgressiveOperationManager.Operation sceneManagerBlockOp)
        {
            int numScenesToLoad = ImmediateScenes.Length + DelayedScenes.Length;

            if (numScenesToLoad < 1)
            {
                // No additional dependencies to load
                sceneManagerBlockOp.Progress = 1.0f;
                ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
                return;
            }

            float progressIncrement = 1.0f / numScenesToLoad;

            // Load and activate immediate scenes
            for (int iScene = 0; iScene < ImmediateScenes.Length; iScene++)
            {
                string sceneName = ImmediateScenes[iScene];
                Scene scene = SceneManager.GetSceneByName(sceneName);

                // Scene is already loaded
                if (scene.isLoaded)
                {
                    sceneManagerBlockOp.Progress += progressIncrement;
                    continue;
                }

                await LoadSceneTask(sceneName, true);

                sceneManagerBlockOp.Progress += progressIncrement;
            }

            // Load and activate delayed scenes
            for (int iScene = 0; iScene < DelayedScenes.Length; iScene++)
            {
                string sceneName = DelayedScenes[iScene];
                Scene scene = SceneManager.GetSceneByName(sceneName);

                // Scene is already loaded
                if (scene.isLoaded)
                {
                    sceneManagerBlockOp.Progress += progressIncrement;
                    continue;
                }

                await LoadSceneTask(sceneName, false);

                sceneManagerBlockOp.Progress += progressIncrement;
            }

            // Set to 1 in case the fraction is off 
            sceneManagerBlockOp.Progress = 1.0f;

            ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
        }

        // Async loads a scene, if it can find it, in the best code path available
        private async Awaitable LoadSceneTask(string sceneName, bool isImmediate)
        {
            // Check if the scene is addressable
            AsyncOperationHandle<IList<IResourceLocation>> sceneCheckHandle = Addressables.LoadResourceLocationsAsync(sceneName);
            await sceneCheckHandle.Task;

            bool canUseAddressable = sceneCheckHandle.Result.Count > 0;

            if (canUseAddressable)
            {
                var sceneOp = Addressables.LoadSceneAsync(sceneName, LoadSceneMode.Additive, isImmediate);

                // Wait for the task to finish - could optionally update progress of the task load here
                await sceneOp.Task;

                if (sceneOp.Status == AsyncOperationStatus.Succeeded)
                {
                    if (!isImmediate)
                    {
                        await sceneOp.Result.ActivateAsync();
                    }

                    return;
                }

                // throw scene load exception if we can't fall back to SceneManager
                if (!Application.isEditor && sceneOp.OperationException != null)
                {
                    throw sceneOp.OperationException;
                }
            }

            string activeSceneName = SceneManager.GetActiveScene().name;
            string sceneType = isImmediate ? "immediate" : "delayed";
            Debug.LogWarning($"Failed to load <b> {sceneType} </b> additive scene <b> {sceneName} </b> from Addressables while loading scene dependencies of <b> {activeSceneName} </b>. Falling back to SceneManager (editor).");

            // Check if scene is available in scene lists 
            bool isSceneInBuildSettings = SceneUtility.GetBuildIndexByScenePath(sceneName) == -1 ? false : true;

            // Scene was found in the scene list
            if (isSceneInBuildSettings)
            {
                // failed to load from addressables, fall back to SceneManager load (in editor)
                // this lets us load scenes in the editor that we don't necessarily want in the build profile
                AsyncOperation sceneManagerOp = SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
                sceneManagerOp.allowSceneActivation = isImmediate;
                await sceneManagerOp;
                sceneManagerOp.allowSceneActivation = true;
            }
            else
            {
                Debug.LogWarning($"Failed to load <b> {sceneType} </b> additive scene <b> {sceneName} </b> using fallback SceneManager (editor). Applying workaround but please make your scene addressable.");

#if UNITY_EDITOR
                AsyncOperation sceneManagerOp = EditorSceneManager.LoadSceneAsyncInPlayMode(sceneName, new LoadSceneParameters(LoadSceneMode.Additive));
                sceneManagerOp.allowSceneActivation = isImmediate;
                await sceneManagerOp;
                sceneManagerOp.allowSceneActivation = true;
#endif
            }

        }

        // Unloads any scene dependencies
        // NOTE: This does NOT unload nested dependencies! 
        // If one of these scenes has dependencies, they need to listen for the scene transition manager and clean up on their own! 
        private async void UnloadDependencies(ProgressiveOperationManager.Operation sceneManagerBlockOp)
        {
            int numScenesToUnload = ImmediateScenes.Length + DelayedScenes.Length;

            if (numScenesToUnload < 1)
            {
                // No additional dependencies to unload
                sceneManagerBlockOp.Progress = 1.0f;
                ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
                return;
            }

            float progressIncrement = 1.0f / numScenesToUnload;

            // Unload immediate scenes
            for (int iScene = 0; iScene < ImmediateScenes.Length; iScene++)
            {
                string sceneName = ImmediateScenes[iScene];
                Scene scene = SceneManager.GetSceneByPath(sceneName);
                if (scene != null && scene.isLoaded)
                {
                    await SceneManager.UnloadSceneAsync(sceneName);
                }
                sceneManagerBlockOp.Progress += progressIncrement;
            }

            // Unload delayed scenes
            for (int iScene = 0; iScene < DelayedScenes.Length; iScene++)
            {
                string sceneName = DelayedScenes[iScene];
                Scene scene = SceneManager.GetSceneByPath(sceneName);
                if (scene != null && scene.isLoaded)
                {
                    await SceneManager.UnloadSceneAsync(sceneName);
                }
                sceneManagerBlockOp.Progress += progressIncrement;
            }

            // Set to 1 in case the fraction is off 
            sceneManagerBlockOp.Progress = 1.0f;

            ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
        }
    }
}
