using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace PSX
{
    [ExecuteInEditMode]
    public class FogController : MonoBehaviour
    {
        [SerializeField] protected VolumeProfile volumeProfile;
        [SerializeField] protected bool isEnabled = true;

        protected Fog fog;
        
        [Range(0,0.02f)]
        [SerializeField] protected float fogDensity = 0.01f;
        [Range(0,1000)]
        [SerializeField] protected float fogDistance = 10.0f;
        [Range(0,100)]
        [SerializeField] protected float fogNear = 1.0f;
        [Range(0,100)]
        [SerializeField] protected float fogFar = 100.0f;
        [Range(0,100)]
        [SerializeField] protected float fogAltScale = 10.0f;
        [Range(0,1000)]
        [SerializeField] protected float fogThinning = 100.0f;
        [Range(0,1000)]
        [SerializeField] protected float noiseScale = 100.0f;
        [Range(0,1)]
        [SerializeField] protected float noiseStrength = 0.05f;
        
        [SerializeField] protected Color fogColor;
        [SerializeField] protected Color ambientColor;

        public float FogDistance
        {
            get => fogDistance;
            set => fogDistance = value;
        }

        void OnEnable() => Apply();
        void OnDisable() => Apply();
        void OnValidate() => Apply();
        protected void Update() => Apply();

        public void SetEnabled(bool enabled)
        {
            isEnabled = enabled;
            Apply();
        }

        void Apply()
        {
            if (!volumeProfile) return;
            if (fog == null && !volumeProfile.TryGet(out fog)) return;

            fog.enabled.value = isEnabled;
            if (!isEnabled) return;

            if (fogFar <= fogNear + 1e-5f) fogFar = fogNear + 1f;

            fog.fogDensity.value = Mathf.Clamp(fogDensity, 0f, 0.1f);
            fog.fogDistance.value = Mathf.Clamp(fogDistance, 0f, 10f);

            fog.fogNear.value = Mathf.Max(0f, fogNear);
            fog.fogFar.value = Mathf.Max(fog.fogNear.value + 1e-3f, fogFar);

            fog.noiseScale.value = Mathf.Max(1f, noiseScale);
            fog.noiseStrength.value = Mathf.Clamp01(noiseStrength);

            fog.fogColor.value = fogColor;
            fog.ambientColor.value = ambientColor;

        }
    }
}