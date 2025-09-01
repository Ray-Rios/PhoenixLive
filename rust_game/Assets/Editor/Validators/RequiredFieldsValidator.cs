///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Validates that all required fields have been set when attempting to exit edit mode in the editor 
    ///</summary>
    public static class RequiredFieldsValidator
    {
        // Called on editor load and after script compilation
        [InitializeOnLoadMethod]
        private static void Init()
        {
            // Bind to editor play mode state changes
            EditorApplication.playModeStateChanged += (state) =>
            {
                if (state == PlayModeStateChange.ExitingEditMode)
                {
                    DisplayDebugWarnings();
                }
            };
        }

        // Displays all warnings from required property attributes on all found monobehaviors 
        private static void DisplayDebugWarnings()
        {
            bool shouldPauseGame = false;
            MonoBehaviour[] monoBehaviours = GameObject.FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None);

            // Iterate through all mononbehaviours 
            foreach (MonoBehaviour monoBehaviour in monoBehaviours)
            {
                // Iterate through all fields 
                FieldInfo[] fields = monoBehaviour.GetType().GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                foreach (FieldInfo field in fields)
                {
                    // Find the required attribute 
                    Required requiredAttribute = field.GetCustomAttribute<Required>();

                    if (requiredAttribute != null)
                    {
                        // Get the field value and display error 
                        object fieldValue = field.GetValue(monoBehaviour);

                        if ((fieldValue == null || fieldValue.Equals(null)) && requiredAttribute.WarningType == RequiredPropertyWarningType.Error)
                        {
                            // Log out our error
                            Debug.LogError($"The field {field.Name} is required.", monoBehaviour);
                            shouldPauseGame = true;
                        }
                    }
                }
            }

            if (shouldPauseGame)
            {
                EditorApplication.ExitPlaymode();
            }
        }
    }
}
