///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Collections.Generic;
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
    /// Loads persistent resources and then transitions to the next scene
    ///</summary>
    public class Bootstrapper : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Header("Bootstrap Resources")]
        [Tooltip("Any persistent resources that the bootstrapper needs to load before transitioning scenes")]
        [SerializeField]
        private SceneField[] ResourceScenes;

        [Header("Initializaiton")]
        [Tooltip("The first primary scene to load into")]
        [SerializeField]
        private SceneField PrimaryScene;

        private string m_parentScene;

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            m_parentScene = gameObject.scene.path;
            ParrotSceneManager.OnBeforeSceneReady += CheckLoadDependencies;
            ParrotSceneManager.OnSceneTransitionComplete += OnSceneTransitionComplete;
        }

        void OnDestroy()
        {
            ParrotSceneManager.OnBeforeSceneReady -= CheckLoadDependencies;
            ParrotSceneManager.OnSceneTransitionComplete -= OnSceneTransitionComplete;
        }

        #endregion

        private void OnSceneTransitionComplete(string scene)
        {
            if (scene == m_parentScene)
            {
                ParrotSceneManager.Instance.ChangeScene(PrimaryScene);
            }
        }

        private void CheckLoadDependencies(string nextScene)
        {
            if (nextScene == m_parentScene)
            {
                var sceneManagerBlockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();
                LoadDependencies(sceneManagerBlockOp);
            }
        }

        // Loads up all dependent scenes
        private async void LoadDependencies(ProgressiveOperationManager.Operation sceneManagerBlockOp)
        {
            int numScenesToLoad = ResourceScenes.Length;

            if (numScenesToLoad < 1)
            {
                // No additional deps to load 
                sceneManagerBlockOp.Progress = 1.0f;
                ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
                return;
            }

            float progressIncrement = 1.0f / numScenesToLoad;

            // Load and activate immediate scenes
            for (int iScene = 0; iScene < ResourceScenes.Length; iScene++)
            {
                string sceneName = ResourceScenes[iScene];
                Scene scene = SceneManager.GetSceneByName(sceneName);

                // Scene is already loaded
                if (scene.isLoaded)
                {
                    sceneManagerBlockOp.Progress += progressIncrement;
                    continue;
                }

                await LoadSceneTask(sceneName);

                sceneManagerBlockOp.Progress += progressIncrement;
            }

            // Set to 1 in case the fraction is off 
            sceneManagerBlockOp.Progress = 1.0f;

            ParrotSceneManager.Instance.BlockingOperations.Release(sceneManagerBlockOp);
        }

        private async Awaitable LoadSceneTask(string sceneName)
        {
            // Check if the scene is addressable
            AsyncOperationHandle<IList<IResourceLocation>> sceneCheckHandle = Addressables.LoadResourceLocationsAsync(sceneName);
            await sceneCheckHandle.Task;

            bool canUseAddressable = sceneCheckHandle.Result.Count > 0;

            if (canUseAddressable)
            {
                var sceneOp = Addressables.LoadSceneAsync(sceneName, LoadSceneMode.Additive, true);

                // Wait for the task to finish - could optionally update progress of the task load here
                await sceneOp.Task;

                if (sceneOp.Status == AsyncOperationStatus.Succeeded)
                {
                    return;
                }

                // throw scene load exception if we can't fall back to SceneManager
                if (!Application.isEditor && sceneOp.OperationException != null)
                {
                    throw sceneOp.OperationException;
                }
            }

            string activeSceneName = SceneManager.GetActiveScene().name;
            string sceneType = "immediate";
            Debug.LogWarning($"Failed to load <b> {sceneType} </b> additive scene <b> {sceneName} </b> from Addressables while loading scene dependencies of <b> {activeSceneName} </b>. Falling back to SceneManager (editor).");

            // Check if scene is available in scene lists 
            bool isSceneInBuildSettings = SceneUtility.GetBuildIndexByScenePath(sceneName) == -1 ? false : true;

            // Scene was found in the scene list
            if (isSceneInBuildSettings)
            {
                // failed to load from addressables, fall back to SceneManager load (in editor)
                // this lets us load scenes in the editor that we don't necessarily want in the build profile
                AsyncOperation sceneManagerOp = SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
                sceneManagerOp.allowSceneActivation = true;
                await sceneManagerOp;
            }
            else
            {
                Debug.LogWarning($"Failed to load <b> {sceneType} </b> additive scene <b> {sceneName} </b> using fallback SceneManager (editor). Applying workaround but please make your scene addressable.");

#if UNITY_EDITOR
                AsyncOperation sceneManagerOp = EditorSceneManager.LoadSceneAsyncInPlayMode(sceneName, new LoadSceneParameters(LoadSceneMode.Additive));
                sceneManagerOp.allowSceneActivation = true;
                await sceneManagerOp;
#endif
            }
        }
    }
}
