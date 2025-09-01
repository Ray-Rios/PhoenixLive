///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Loads the bootstrap scene
    ///</summary>
    ///
    [DefaultExecutionOrder(-10)] // Execute before the video player
    public class ParrotApplicationInitializer : MonoBehaviour
    {
        #region Attributes
        // Attributes

        [SerializeField]
        private SceneField BootstrapScene;

        #endregion

        #region Unity Methods
        // Unity Methods

        /// <summary>
        /// Awake is called when the script instance is being loaded.
        /// </summary>
        private void Awake()
        {
            // Load our bootstrapping scene immediately
            ParrotSceneManager.Instance.ChangeScene(BootstrapScene);
        }

        #endregion

    }
}
