///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEditor;
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Handles custom drawing of a property with the 'Required' attribute 
    ///</summary>
    [CustomPropertyDrawer(typeof(Required))]
    public class RequiredPropertyDrawer : PropertyDrawer
    {
        public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
        {
            EditorGUI.PropertyField(position, property, label);

            if (property.propertyType == SerializedPropertyType.ObjectReference && property.objectReferenceValue == null)
            {
                // Add some space below the property 
                GUILayout.Space(30);

                // Draw the warning underneath 
                Rect warningRect = new Rect(position.x, position.y + position.height * 1.3f, position.width, position.height * 1.3f);

                EditorGUI.HelpBox(warningRect, "This field is a required property and cannot be null!", MessageType.Error);
            }
        }
    }
}
