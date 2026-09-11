using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

namespace PSX
{
    public class PixelationRenderFeature : ScriptableRendererFeature
    {
        PixelationPass pixelationPass;
        Pixelation pixelation;

        public override void Create()
        {
            pixelationPass = new PixelationPass(RenderPassEvent.BeforeRenderingPostProcessing);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            pixelation = stack.GetComponent<Pixelation>();

            if (pixelation == null || !pixelation.IsActive())
            {
                Debug.Log("No Pixelation. Deactivated.");
                return;
            }
            renderer.EnqueuePass(pixelationPass);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            pixelationPass.Setup(renderer.cameraColorTargetHandle);
        }
    }

    public class PixelationPass : ScriptableRenderPass
    {
        private const string kShaderPath = "PostEffect/Pixelation";

        // property IDs
        static readonly int WidthPixelation = Shader.PropertyToID("_WidthPixelation");
        static readonly int HeightPixelation = Shader.PropertyToID("_HeightPixelation");
        static readonly int ColorPrecision = Shader.PropertyToID("_ColorPrecision");

        Material pixelationMaterial;
        RenderTargetIdentifier currentTarget;

        public PixelationPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
            var shader = Shader.Find(kShaderPath);
            if (!shader)
            {
                Debug.LogError("[Pixelation] Shader not found.");
                return;
            }
            pixelationMaterial = CoreUtils.CreateEngineMaterial(shader);
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
            var vol = stack.GetComponent<Pixelation>();
            if (vol == null || !vol.IsActive() || pixelationMaterial == null || !pixelationMaterial.shader) return;

            // push params
            var mat = pixelationMaterial;
            mat.SetFloat(WidthPixelation, Mathf.Max(1f, vol.widthPixelation.value));
            mat.SetFloat(HeightPixelation, Mathf.Max(1f, vol.heightPixelation.value));
            mat.SetFloat(ColorPrecision, Mathf.Max(1f, vol.colorPrecision.value));

            // create output & blit
            var src = res.activeColorTexture;
            var desc = rg.GetTextureDesc(src);
            desc.name = "Pixelation-Output";
            desc.clearBuffer = false;
            var dst = rg.CreateTexture(desc);

            int passIndex = 0; // 0 = effect, 1 = pure copy
            var para = new RenderGraphUtils.BlitMaterialParameters(src, dst, mat, passIndex);
            rg.AddBlitPass(para, passName: passIndex == 0 ? "Pixelation Effect" : "Pixelation Copy");

            res.cameraColor = dst;
        }
    }
}
