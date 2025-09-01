///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Activates specific game objects when appropriate on level start
    ///</summary>
    public class MainMenuActivator : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [Tooltip("Game Objects that need to be activated directly in this scene as part of scene loading")]
        [SerializeField]
        private GameObject[] ObjectsToActivate;

        [Tooltip("Components that need to be activated directly in this scene as part of scene loading")]
        [SerializeField]
        private MonoBehaviour[] ComponentsToActivate;

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            // Edge case - this can happen when testing from different scenes in editor
            if (ParrotGameInstance.Instance == null)
            {
                return;
            }

            if (!ParrotGameInstance.Instance.GetLogoTrainDisplayed())
            {
                ParrotSceneManager.OnLogoTrainComplete += OnStartScene;
            }
            else
            {
                ParrotSceneManager.OnSceneTransitionComplete += OnStartScene;
            }
        }

        void OnDestroy()
        {
            ParrotSceneManager.OnLogoTrainComplete -= OnStartScene;
            ParrotSceneManager.OnSceneTransitionComplete -= OnStartScene;
        }

        private void OnStartScene(string scene)
        {
            OnStartScene();
        }

        private void OnStartScene()
        {
            foreach (GameObject targetGameObject in ObjectsToActivate)
            {
                if (targetGameObject == null)
                {
                    continue;
                }

                targetGameObject.SetActive(true);
            }

            foreach (MonoBehaviour targetComponent in ComponentsToActivate)
            {
                if (targetComponent == null)
                {
                    continue;
                }

                // Enable script 
                targetComponent.enabled = true;

                // Activate the game object too if it's disabled so that this component actually runs
                if (!targetComponent.gameObject.activeInHierarchy)
                {
                    targetComponent.gameObject.SetActive(true);
                }
            }
        }
        #endregion

    }
}
