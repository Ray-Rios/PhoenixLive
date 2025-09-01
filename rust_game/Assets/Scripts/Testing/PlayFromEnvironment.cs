///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;

#if UNITY_EDITOR
using UnityEditor.SceneManagement;
#endif


namespace SecretDimension
{
    ///<summary>
    /// Loads application dependencies when attempting to test in a non-primary level 
    ///</summary>
    ///

#if UNITY_EDITOR
    [InitializeOnLoad]
    static class PlayFromEnvironment
    {
        // The initialization scene used in the game 
        static string InitScene = "Assets/Scenes/Application/_Init.unity";

        // The bootstrapping scene used in the game
        static string BootstrapScene = "Assets/Scenes/Primary/_Bootstrap.unity";
        // Resource scene that's typically loaded from bootstrap
        static string PersistentResourcesScene = "Assets/Scenes/Utility/PersistentResources.unity";

        public static int LevelDataIndex;

        public static bool UsingCustomIndex;

        static PlayFromEnvironment()
        {
            EditorApplication.playModeStateChanged += OnPlayModeChanged;
        }

        public static void OnPlayModeChanged(PlayModeStateChange state)
        {
            string targetScene = EditorSceneManager.GetActiveScene().name;
            string targetScenePath = EditorSceneManager.GetActiveScene().path;

            if (targetScenePath == InitScene)
            {
                // Nothing to do, expected game flow
                return;
            }

            ParrotLevelData LevelData = AssetDatabase.LoadAssetAtPath<ParrotLevelData>("Assets/Data/Levels/ParrotLevelData.asset");
            if (state == PlayModeStateChange.EnteredPlayMode)
            {
                // Cannot launch from bootstrap 
                if (targetScenePath == BootstrapScene)
                {
                    Debug.LogWarning("Cannot play bootstrap scene. Meant to be used only for application initialization.");
                    EditorApplication.ExitPlaymode();
                    return;
                }

                if (targetScenePath == LevelData.mainMenuLevel)
                {
                    // Reload the current scene through the scene manager
                    ParrotSceneManager.Instance.ReloadScene(targetScenePath);
                    LoadPersistentResources();
                    return;
                }

                // Check if we're attempting to load a primary scene 
                for (int iScene = 0; iScene < LevelData.singlePlayerLevels.Length; iScene++)
                {
                    string scene = LevelData.singlePlayerLevels[iScene];

                    if (scene == targetScenePath)
                    {
                        LevelDataIndex = iScene;
                        UsingCustomIndex = true;

                        // Reload the current scene through the scene manager
                        ParrotSceneManager.Instance.ReloadScene(targetScenePath);
                        LoadPersistentResources();
                        return;
                    }
                }

                // Find and load appropriate primary scene as this will have all the required dependencies
                targetScene = targetScene.Replace("_", "");
                targetScene = targetScene.Replace("Environment", "");

                bool sceneFound = false;
                for (int iScene = 0; iScene < LevelData.singlePlayerLevels.Length; iScene++)
                {
                    string scene = LevelData.singlePlayerLevels[iScene];

                    if (scene.Contains(targetScene))
                    {
                        LevelDataIndex = iScene;
                        UsingCustomIndex = true;
                        targetScenePath = scene;
                        sceneFound = true;
                        break;
                    }
                }

                // Check if we're attempting to load from the main menu environment 
                if (!sceneFound)
                {
                    string scene = LevelData.mainMenuLevel;

                    if (scene.Contains(targetScene))
                    {
                        LevelDataIndex = -1;
                        LoadPersistentResources();
                        ParrotSceneManager.Instance.ChangeScene(scene);
                        return;
                    }
                }

                // When we have not found the scene, warn the developer and attempt to enter play mode anyway
                if (sceneFound == false)
                {
                    Debug.LogWarning("Entering playmode from a scene not in the level data! Additional scene resources are not loaded and may not play as expected.");
                    return;
                }

                // Load into the primary scene
                LoadPersistentResources();
                ParrotSceneManager.Instance.ChangeScene(targetScenePath);
            }
        }

        public static void LoadPersistentResources()
        {
            // Load the persistent resources scene and block the scene manager until it's loaded
            var sceneBlockOp = ParrotSceneManager.Instance.BlockingOperations.StartOperation();

            var resourcesOp = EditorSceneManager.LoadSceneAsyncInPlayMode(PersistentResourcesScene, new LoadSceneParameters(LoadSceneMode.Additive));

            resourcesOp.completed += (resourcesOp) =>
            {
                ParrotGameInstance.Instance.SetLogoTrainDisplayed();
                ParrotSceneManager.Instance.BlockingOperations.Release(sceneBlockOp);
            };
        }
    }
#endif
}
