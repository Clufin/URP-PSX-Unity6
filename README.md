# URP-PSX-Unity6 (URP 17)

A fork of **[URP-PSX](https://github.com/Kodrin/URP-PSX)** (via
**[Math-Man's fork](https://github.com/Math-Man/URP-PSX-FORKED)**) with
compatibility fixes for Unity 6.

#### Compatibility
Unity 6000.0.83f1 / URP 17. For older versions use the upstream forks:
- [URP-PSX-FORKED](https://github.com/Math-Man/URP-PSX-FORKED) — Unity 2022, URP 14
- [URP-11](https://github.com/Math-Man/URP-PSX-FORKED/tree/URP-11) — Unity 2021, URP 11

## Changes in this fork
- Rewrote the four post-process shaders (CRT, Dithering, Fog, Pixelation)
  from CG to HLSL against the URP shader library.
- Ported the render features to the Render Graph API
  (`RecordRenderGraph` / `BlitMaterialParameters` instead of `cmd.Blit`).
- Fixed bugs surfaced by the rewrite: dithering luminance and pattern
  normalization, fog depth linearization and skybox exclusion, CRT
  scanline/noise blending and grille math.

#### Notes
- Depth textures must be enabled on the Render Pipeline Asset for fog to work.
- The post-process shaders are located by name via `Shader.Find`, so add them
  to *Project Settings → Graphics → Always Included Shaders* or they may be
  stripped from player builds.
- Render features must be added to the renderer asset's feature list, and the
  matching Volume component enabled on a Volume Profile.

## Inherited from Math-Man's fork
- Upgraded for Shadergraph 14.
- CRT render feature (screen bending, vignette, scan lines, noise,
  chromatic aberration).
- Unlit shader with affine texture warping and vertex locking, in regular
  and PolyBrush variants. No custom lighting support.
- Random color picker and voronoi center subgraphs.
- Transparent variant of the PBR shader.

<img src="Media/poly1.gif" width=100%>
<img src="Media/crt1.gif" width=100%>

# Original Description:
## URP-PSX

Playstation 1 era retro graphics plugin optimized for Unity's Universal Rendering Pipeline with Shadergraph. The aim of this plugin was to use Unity's new pipeline to create NPR (non-photorealistic) PSX-style retro graphics with the shadergraph as the basis for materials and URP's render features as the basis for post processing effects.

#### Features

The plugin comes fully-featured with a single lit/unlit graph where you can enable/disable features according to your needs (and even modify them). I segmented every feature into a subgraph to hopefully make it easier to just plug n' play. 

<img src="Media/01.gif" width=100%>
<img src="Media/02.gif" width=100%>

#### Shadergraph:
- Lit/Unlit shader variants
- Specular Lit variant
- Camera-based vertex clipping
- Vertex snapping/Jittering
- Texture Pixelation for crushing texture resolution
- Color Precision for lower or higher color Fidelity


#### URP Render Features:
- Screen-space fog 
- Screen-space pixelation/color precision adjustments
- Screen-space dithering 

*Note: Make sure you set the render features in the pipeline asset*

<img src="Media/04.PNG" width=25%>


#### The Graph
<img src="Media/03.PNG" width=100%>

#### Compatibility

Unity 2019.3.7f1
Universal Rendering Pipeline/Shadergraph (7.1.8)

#### Known Issues

- Unity's Shadergraph still has a long way to go when it comes to creating NPR effects. You might experience some lighting clipping issues if you are using the PBR master node. To fix it, I tweaked some settings in the URP pipeline asset settings so they are barely noticeable. 

#### References

- [Models open-source from sketchfab](https://sketchfab.com/)
- [t-macnaga for render feature post-process](https://github.com/t-macnaga/UniversalRPPostProcessing)
- [Alex Lindman for custom lighting nodes](https://blogs.unity3d.com/2019/07/31/custom-lighting-in-shader-graph-expanding-your-graphs-in-2019/)
- [UnityRenderingExamples for render feature implementation](https://github.com/Unity-Technologies/UniversalRenderingExamples)
- [Ciro Continision for PBR master node custom lighting implementation](https://connect.unity.com/p/zelda-inspired-toon-shading-in-shadergraph)

#### License 

Open-source, use for whatever you want!!! Software is about freedom :) 

#### Support 

I developed this plugin out of passion/nostalgia for retro ps1-style horror games. But, if you found this plugin useful and want to show your support, consider sharing it,[buying me a ko-fi](https://ko-fi.com/kodrin). 
