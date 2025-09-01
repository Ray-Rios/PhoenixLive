using UnityEngine;

namespace SecretDimension
{
    // Credit to Aesthetician Labs
    // Modified from source available here: https://github.com/aestheticianlabs/com.aela.utilities/blob/main/Scripts/Singleton.cs

    /// <summary>
    /// A singleton implementation that can save some time.
    /// </summary>
    /// <typeparam name="T">Your singleton type</typeparam>
    public static class Singleton<T> where T : MonoBehaviour
    {
        private static T instance;

        /// <summary>
        /// Returns the instance if any
        /// </summary>
        /// <param name="find">Use FindObjectOfType to find an instance if null</param>
        /// <param name="create">Create a new GameObject for the instance if null</param>
        /// <param name="objectName">The name to use for the new GameObject instance. "[ TypeName ]" will be used if null.</param>
        /// <param name="hideFlags">HideFlags to use for the new GameObject instance</param>
        public static T GetInstance(
            bool find, bool create, bool includeInactive = false,
            string objectName = null, HideFlags hideFlags = HideFlags.None
        )
        {
            if (!instance && find)
            {
                instance = Object.FindAnyObjectByType<T>(includeInactive ? FindObjectsInactive.Include : FindObjectsInactive.Exclude);
            }

            if (!instance && create)
            {
                instance = new GameObject
                {
                    name = string.IsNullOrWhiteSpace(objectName) ? $"[ {typeof(T).Name} ]" : objectName,
                    hideFlags = hideFlags
                }.AddComponent<T>();
            }

            return instance;
        }

        /// <summary>
        /// Returns the instance if any
        /// </summary>
        public static T GetInstance() => GetInstance(false, false);

        /// <summary>
        /// Attempts to find the instance using FindObjectOfType if null
        /// </summary>
        public static T FindInstance(bool includeInactive = false) => GetInstance(true, false, includeInactive);

        /// <summary>
        /// Attempts to find the instance using FindObjectOfType if null,
        /// then falls back to creating a new object with the component attached
        /// </summary>
        public static T FindOrCreateInstance(bool includeInactive = false) => GetInstance(true, true, includeInactive);

        /// <summary>
        /// Checks if the provided object is the singleton instance. Will return true if the singleton instance is null.
        /// </summary>
        /// <param name="obj">The object to compare with the singleton instance</param>
        /// <param name="destroy">Should the object be destroyed if it isn't the instance?</param>
        /// <param name="destroyGameObject">Should the whole GameObject be destroyed?</param>
        public static bool CheckInstance(T obj, bool destroy = false, bool destroyGameObject = false)
        {
            if (!instance) return true;

            var match = obj == instance;

            if (!match && destroy)
            {
                Object.Destroy(destroyGameObject ? obj.gameObject : (Object)obj);
            }

            return match;
        }

        /// <summary>
        /// Sets the instance to the provided value
        /// </summary>
        /// <param name="instance"></param>
        /// <returns></returns>
        public static void SetInstance(T instance)
        {
            Singleton<T>.instance = instance;
        }
    }
}