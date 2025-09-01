///<copyright> Secret Dimension Inc. 2025, All rights reserved <copyright>
using UnityEngine;

namespace SecretDimension
{
    ///<summary>
    /// Utility functions for easing.
    ///</summary>
    public static class EasingFunctions
    {
        public enum EasingFunctionType { EaseIn, EaseOut, EaseInOut }

        public static float Ease(float A, float B, float Alpha, EasingFunctionType EaseType, float BlendExp)
        {
            return Mathf.Lerp(A, B, GetEasingValue(Alpha, EaseType, BlendExp));
        }

        public static Vector3 Ease(Vector3 A, Vector3 B, float Alpha, EasingFunctionType EaseType, float BlendExp)
        {
            return Vector3.Lerp(A, B, GetEasingValue(Alpha, EaseType, BlendExp));
        }

        private static float GetEasingValue(float InAlpha, EasingFunctionType EaseType, float BlendExp)
        {
            switch (EaseType)
            {
                case EasingFunctionType.EaseIn:
                    return InterpEaseIn(0.0f, 1.0f, InAlpha, BlendExp);
                case EasingFunctionType.EaseOut:
                    return InterpEaseOut(0.0f, 1.0f, InAlpha, BlendExp);
                case EasingFunctionType.EaseInOut:
                    return InterpEaseInOut(0.0f, 1.0f, InAlpha, BlendExp);
            }
            return InAlpha;
        }

        private static float InterpEaseIn(float A, float B, float Alpha, float Exp)
        {
            float ModifiedAlpha = Mathf.Pow(Alpha, Exp);
            return Mathf.Lerp(A, B, ModifiedAlpha);
        }

        private static float InterpEaseOut(float A, float B, float Alpha, float Exp)
        {
            float ModifiedAlpha = 1.0f - Mathf.Pow(1.0f - Alpha, Exp);
            return Mathf.Lerp(A, B, ModifiedAlpha);
        }

        private static float InterpEaseInOut(float A, float B, float Alpha, float Exp)
        {
            return Mathf.Lerp(A, B, Alpha < 0.5f ?
                InterpEaseIn(0.0f, 1.0f, Alpha * 2.0f, Exp) * 0.5f :
                InterpEaseOut(0.0f, 1.0f, Alpha * 2.0f - 1.0f, Exp) * 0.5f + 0.5f);
        }
    }
}
