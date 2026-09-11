using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace PSX
{
    [ExecuteInEditMode]
    public class DitheringController : MonoBehaviour
    {
        [SerializeField] protected VolumeProfile volumeProfile;
        [SerializeField] protected bool isEnabled = true;

        protected Dithering dithering;
        
        [SerializeField] protected int patternIndex = 0;
        [SerializeField] protected float ditherThreshold = 1;
        [SerializeField] protected float ditherStrength = 1;
        [SerializeField] protected float ditherScale = 2;
        
        protected void Update()
        {
            this.SetParams();
        }
        public void SetEnabled(bool enabled)
        {
            isEnabled = enabled;
        }

        protected void SetParams()
        {
            if (this.volumeProfile == null) return;
            if (this.dithering == null) volumeProfile.TryGet<Dithering>(out this.dithering);
            if (this.dithering == null) return;

            dithering.enabled.value = isEnabled;

            if (!this.isEnabled) return;

            this.dithering.patternIndex.value = this.patternIndex;
            this.dithering.ditherThreshold.value = this.ditherThreshold;
            this.dithering.ditherStrength.value = this.ditherStrength;
            this.dithering.ditherScale.value = this.ditherScale;

        }
    }
}