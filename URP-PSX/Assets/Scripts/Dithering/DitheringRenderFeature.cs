using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

namespace PSX
{
    public class DitheringRenderFeature : ScriptableRendererFeature
    {
        DitheringPass ditheringPass;
        Dithering dithering;

        public override void Create()
        {
            ditheringPass = new DitheringPass(RenderPassEvent.BeforeRenderingPostProcessing);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            dithering = stack.GetComponent<Dithering>();

            if (dithering == null || !dithering.IsActive())
            {
                Debug.Log("No Dithering. Deactivated.");
                return;
            }
            renderer.EnqueuePass(ditheringPass);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            ditheringPass.Setup(renderer.cameraColorTargetHandle);
        }
    }

    public class DitheringPass : ScriptableRenderPass
    {
        private static readonly string shaderPath = "PostEffect/Dithering";
        static readonly string k_RenderTag = "Render Dithering Effects";

        // IDs
        static readonly int PatternIndex = Shader.PropertyToID("_PatternIndex");
        static readonly int DitherThreshold = Shader.PropertyToID("_DitherThreshold");
        static readonly int DitherStrength = Shader.PropertyToID("_DitherStrength");
        static readonly int DitherScale = Shader.PropertyToID("_DitherScale");

        Material ditheringMaterial;
        RenderTargetIdentifier currentTarget;

        public DitheringPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
            var shader = Shader.Find(shaderPath);
            if (!shader)
            {
                Debug.LogError("[Dithering] Shader not found.");
                return;
            }
            ditheringMaterial = CoreUtils.CreateEngineMaterial(shader);
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
            var vol = stack.GetComponent<Dithering>();
            if (vol == null || !vol.IsActive() || ditheringMaterial == null || !ditheringMaterial.shader) return;

            // Push params
            var mat = ditheringMaterial;
            mat.SetInt(PatternIndex, vol.patternIndex.value);
            mat.SetFloat(DitherThreshold, vol.ditherThreshold.value);
            mat.SetFloat(DitherStrength, vol.ditherStrength.value);
            mat.SetFloat(DitherScale, Mathf.Max(1e-4f, vol.ditherScale.value));

            // Create dst & blit
            var src = res.activeColorTexture;
            var desc = rg.GetTextureDesc(src);
            desc.name = "Dithering-Output";
            desc.clearBuffer = false;
            var dst = rg.CreateTexture(desc);

            int passIndex = 0; // 0 = effect, 1 = pure copy (debug)
            var para = new RenderGraphUtils.BlitMaterialParameters(src, dst, mat, passIndex);
            rg.AddBlitPass(para, passName: passIndex == 0 ? "Dithering Effect" : "Dithering Copy");

            res.cameraColor = dst;
        }

        // If you keep the old Execute/Render path (not recommended together with RG),
        // you MUST bind the input color to _BlitTexture manually:
        /*
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!ditheringMaterial) return;
            if (!renderingData.cameraData.postProcessEnabled) return;

            var stack = VolumeManager.instance.stack;
            var vol   = stack.GetComponent<Dithering>();
            if (vol == null || !vol.IsActive()) return;

            var cmd = CommandBufferPool.Get(k_RenderTag);
            Render(cmd, ref renderingData, vol);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        static readonly int BlitTexId = Shader.PropertyToID("_BlitTexture");

        void Render(CommandBuffer cmd, ref RenderingData renderingData, Dithering vol)
        {
            var source = currentTarget;
            var w = renderingData.cameraData.camera.scaledPixelWidth;
            var h = renderingData.cameraData.camera.scaledPixelHeight;

            int tmp = Shader.PropertyToID("_TmpDither");
            cmd.GetTemporaryRT(tmp, w, h, 0, FilterMode.Point, RenderTextureFormat.Default);
            cmd.Blit(source, tmp); // input copy

            // bind to _BlitTexture since shader samples this
            cmd.SetGlobalTexture(BlitTexId, tmp);

            // push params
            ditheringMaterial.SetInt  (PatternIndex,    vol.patternIndex.value);
            ditheringMaterial.SetFloat(DitherThreshold, vol.ditherThreshold.value);
            ditheringMaterial.SetFloat(DitherStrength,  vol.ditherStrength.value);
            ditheringMaterial.SetFloat(DitherScale,     Mathf.Max(1e-4f, vol.ditherScale.value));

            cmd.Blit(tmp, source, ditheringMaterial, 0);
            cmd.ReleaseTemporaryRT(tmp);
        }
        */
    }
}
