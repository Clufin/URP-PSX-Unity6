using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

namespace PSX
{
    public class FogRenderFeature : ScriptableRendererFeature
    {
        FogPass fogPass;
        Fog fog;

        public override void Create()
        {
            fogPass = new FogPass(RenderPassEvent.BeforeRenderingPostProcessing);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            fog = stack.GetComponent<Fog>();

            if (fog == null || !fog.IsActive())
            {
                Debug.Log("No fog. Deactivated.");
                return;
            }
            renderer.EnqueuePass(fogPass);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            fogPass.Setup(renderer.cameraColorTargetHandle);
        }
    }

    public class FogPass : ScriptableRenderPass
    {
        private static readonly string shaderPath = "PostEffect/Fog";

        // Property IDs
        static readonly int FogDensity = Shader.PropertyToID("_FogDensity");
        static readonly int FogDistance = Shader.PropertyToID("_FogDistance");
        static readonly int FogColor = Shader.PropertyToID("_FogColor");
        static readonly int AmbientColor = Shader.PropertyToID("_AmbientColor");
        static readonly int FogNear = Shader.PropertyToID("_FogNear");
        static readonly int FogFar = Shader.PropertyToID("_FogFar");
        static readonly int FogAltScale = Shader.PropertyToID("_FogAltScale");
        static readonly int FogThinning = Shader.PropertyToID("_FogThinning");
        static readonly int NoiseScale = Shader.PropertyToID("_NoiseScale");
        static readonly int NoiseStrength = Shader.PropertyToID("_NoiseStrength");

        Material fogMaterial;
        RenderTargetIdentifier currentTarget;

        public FogPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
            var shader = Shader.Find(shaderPath);
            if (!shader)
            {
                Debug.LogError("[Fog] Shader not found.");
                return;
            }
            fogMaterial = CoreUtils.CreateEngineMaterial(shader);
        }

        public void Setup(in RenderTargetIdentifier currentTarget)
        {
            this.currentTarget = currentTarget;
        }

        public override void RecordRenderGraph(RenderGraph rg, ContextContainer frameData)
        {
            var res = frameData.Get<UniversalResourceData>();
            if (res.isActiveTargetBackBuffer || !res.activeColorTexture.IsValid()) return;

            var stack = VolumeManager.instance.stack;
            var vol = stack.GetComponent<Fog>();
            if (vol == null || !vol.IsActive() || fogMaterial == null || !fogMaterial.shader) return;

            // Push parameters
            var mat = fogMaterial;
            mat.SetFloat(FogDensity, vol.fogDensity.value);
            mat.SetFloat(FogDistance, vol.fogDistance.value);
            mat.SetColor(FogColor, vol.fogColor.value);
            mat.SetColor(AmbientColor, vol.ambientColor.value);
            mat.SetFloat(FogNear, vol.fogNear.value);
            mat.SetFloat(FogFar, vol.fogFar.value);
            mat.SetFloat(FogAltScale, vol.fogAltScale.value);
            mat.SetFloat(FogThinning, vol.fogThinning.value);
            mat.SetFloat(NoiseScale, Mathf.Max(1e-4f, vol.noiseScale.value));
            mat.SetFloat(NoiseStrength, vol.noiseStrength.value);

            // Create output & blit
            var src = res.activeColorTexture;
            var desc = rg.GetTextureDesc(src);
            desc.name = "Fog-Output";
            desc.clearBuffer = false;
            var dst = rg.CreateTexture(desc);

            int passIndex = 0; // 0 = fog, 1 = pure copy (debug)
            var para = new RenderGraphUtils.BlitMaterialParameters(src, dst, mat, passIndex);
            rg.AddBlitPass(para, passName: passIndex == 0 ? "Fog Effect" : "Fog Copy");

            res.cameraColor = dst;
        }

        // If you insist on keeping the old Execute/Render path, make sure to bind _BlitTexture manually.
        // Recommended: use RG only (above) to avoid double-processing.
    }
}
