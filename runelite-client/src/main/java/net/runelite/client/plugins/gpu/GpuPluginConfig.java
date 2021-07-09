/*
 * Copyright (c) 2018, Adam <Adam@sigterm.info>
 * Copyright (c) 2021, Hooder <https://github.com/aHooder>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
package net.runelite.client.plugins.gpu;

import net.runelite.client.config.Config;
import net.runelite.client.config.ConfigGroup;
import net.runelite.client.config.ConfigItem;
import net.runelite.client.config.ConfigSection;
import net.runelite.client.config.Range;
import net.runelite.client.config.Units;
import static net.runelite.client.plugins.gpu.GpuPlugin.MAX_DISTANCE;
import static net.runelite.client.plugins.gpu.GpuPlugin.MAX_FOG_DEPTH;
import net.runelite.client.plugins.gpu.config.AntiAliasingMode;
import net.runelite.client.plugins.gpu.config.ColorBlindMode;
import net.runelite.client.plugins.gpu.config.ShadowAntiAliasing;
import net.runelite.client.plugins.gpu.config.ShadowResolution;
import net.runelite.client.plugins.gpu.config.UIScalingMode;

@ConfigGroup("gpu")
public interface GpuPluginConfig extends Config
{
	@ConfigSection(
		name = "Shadows",
		description = "Options that configure shadows",
		position = 10
	)
	String shadowSection = "shadowSection";

	@ConfigSection(
		name = "Debug Shadows",
		description = "Options that configure debugging of shadows",
		position = 11
	)
	String shadowDebugSection = "shadowDebugSection";

	@Range(
		max = MAX_DISTANCE
	)
	@ConfigItem(
		keyName = "drawDistance",
		name = "Draw Distance",
		description = "Draw distance",
		position = 1
	)
	default int drawDistance()
	{
		return 25;
	}

	@ConfigItem(
		keyName = "smoothBanding",
		name = "Remove Color Banding",
		description = "Smooths out the color banding that is present in the CPU renderer",
		position = 2
	)
	default boolean smoothBanding()
	{
		return false;
	}

	@ConfigItem(
		keyName = "antiAliasingMode",
		name = "Anti-Aliasing",
		description = "Configures the anti-aliasing mode",
		position = 3
	)
	default AntiAliasingMode antiAliasingMode()
	{
		return AntiAliasingMode.DISABLED;
	}

	@ConfigItem(
		keyName = "uiScalingMode",
		name = "UI scaling mode",
		description = "Sampling function to use for the UI in stretched mode",
		position = 4
	)
	default UIScalingMode uiScalingMode()
	{
		return UIScalingMode.LINEAR;
	}

	@Range(
		max = MAX_FOG_DEPTH
	)
	@ConfigItem(
		keyName = "fogDepth",
		name = "Fog depth",
		description = "Distance from the scene edge the fog starts",
		position = 5
	)
	default int fogDepth()
	{
		return 0;
	}

	@ConfigItem(
		keyName = "useComputeShaders",
		name = "Compute Shaders",
		description = "Offloads face sorting to GPU, enabling extended draw distance. Requires plugin restart.",
		warning = "This feature requires OpenGL 4.3 to use. Please check that your GPU supports this.\nRestart the plugin for changes to take effect.",
		position = 6
	)
	default boolean useComputeShaders()
	{
		return true;
	}

	@Range(
		min = 0,
		max = 16
	)
	@ConfigItem(
		keyName = "anisotropicFilteringLevel",
		name = "Anisotropic Filtering",
		description = "Configures the anisotropic filtering level.",
		position = 7
	)
	default int anisotropicFilteringLevel()
	{
		return 0;
	}

	@ConfigItem(
		keyName = "colorBlindMode",
		name = "Colorblindness Correction",
		description = "Adjusts colors to account for colorblindness",
		position = 8
	)
	default ColorBlindMode colorBlindMode()
	{
		return ColorBlindMode.NONE;
	}

	@ConfigItem(
		keyName = "brightTextures",
		name = "Bright Textures",
		description = "Use old texture lighting method which results in brighter game textures",
		position = 9
	)
	default boolean brightTextures()
	{
		return false;
	}

	@ConfigItem(
		keyName = "enableShadows",
		name = "Enable Shadows",
		description = "Draw shadows in the scene.",
		section = shadowSection,
		position = 1
	)
	default boolean enableShadows()
	{
		return false;
	}

	@ConfigItem(
		keyName = "enableShadowTranslucency",
		name = "Enable Translucency",
		description = "Let light pass through translucent objects. Can have a large performance impact.",
		section = shadowSection,
		position = 2
	)
	default boolean enableShadowTranslucency()
	{
		return true;
	}

	@ConfigItem(
		keyName = "shadowResolution",
		name = "Resolution",
		description = "Higher resolution gives higher quality shadows, but lower performance.",
		section = shadowSection,
		position = 3
	)
	default ShadowResolution shadowResolution()
	{
		return ShadowResolution.RES_2048x2048;
	}

	@ConfigItem(
		keyName = "shadowAntiAliasing",
		name = "Anti-Aliasing",
		description = "Smoothing of shadow edges. High values have a considerable performance impact.",
		section = shadowSection,
		position = 4
	)
	default ShadowAntiAliasing shadowAntiAliasing()
	{
		return ShadowAntiAliasing.PCF_3;
	}

	@Units(Units.PERCENT)
	@Range(
		min = 1,
		max = 100,
		slider = true
	)
	@ConfigItem(
		keyName = "shadowStrength",
		name = "Strength",
		description = "Determines how dark shadows should be.",
		section = shadowSection,
		position = 5
	)
	default int shadowStrength()
	{
		return 75;
	}

	@Units(Units.DEGREES)
	@Range(
		max = 360,
		slider = true,
		wrapAround = true
	)
	@ConfigItem(
		keyName = "shadowAngleHorizontal",
		name = "Angle Horizontal",
		description = "Controls the shadow angle in the horizontal direction.",
		section = shadowSection,
		position = 6
	)
	default int shadowAngleHorizontal()
	{
		return 120;
	}

	@Units(Units.DEGREES)
	@Range(
		max = 360,
		slider = true,
		wrapAround = true
	)
	@ConfigItem(
		keyName = "shadowAngleVertical",
		name = "Angle Vertical",
		description = "Controls the shadow angle in the vertical direction.",
		section = shadowSection,
		position = 7
	)
	default int shadowAngleVertical()
	{
		return 60;
	}

	@Units(Units.PERCENT)
	@Range(
		max = 2000,
		slider = true
	)
	@ConfigItem(
		keyName = "shadowSunScale",
		name = "PCSS Sun Scale",
		description = "Determines the size of the sun, which affects soft shadows with PCSS. Larger needs more samples.",
		section = shadowSection,
		position = 8
	)
	default int shadowSunScale()
	{
		return 100;
	}

	@ConfigItem(
		keyName = "freezeFrame",
		name = "Freeze frame",
		description = "Freeze the current frame.",
		section = shadowDebugSection
	)
	default boolean freezeFrame()
	{
		return false;
	}

	@Range(
		min = Integer.MIN_VALUE
	)
	@ConfigItem(
		keyName = "debugView",
		name = "Debug View ID",
		description = "Which debug view to render. Debug view -10 is what I currently prefer, though it still has issues. Others are random debug stuff.",
		section = shadowDebugSection
	)
	default int shadowDebugView()
	{
		return -10;
	}

	@ConfigItem(
		keyName = "shadowMapDebug",
		name = "Debug Shadow Maps",
		description = "Whether to render debug views for shadow maps.",
		section = shadowDebugSection
	)
	default boolean shadowMapDebug()
	{
		return false;
	}

	@Units(Units.PIXELS)
	@Range(
		min = 50,
		max = 2048,
		slider = true
	)
	@ConfigItem(
		keyName = "shadowMapDebugSize",
		name = "Debug Shadow Map Size",
		description = "Set the dimensions for each shadow map debug tile.",
		section = shadowDebugSection
	)
	default int shadowMapDebugSize()
	{
		return 256;
	}

	@Units(Units.PERCENT)
	@Range(
		min = 100,
		max = 4000,
		slider = true
	)
	@ConfigItem(
		keyName = "shadowMapDebugZoom",
		name = "Debug Shadow Map Zoom",
		description = "Zoom into the shadow map.",
		section = shadowDebugSection
	)
	default int shadowMapDebugZoom()
	{
		return 100;
	}

	@Units(Units.PERCENT)
	@Range(
		min = -100,
		max = 100,
		slider = true
	)
	@ConfigItem(
		keyName = "shadowMapDebugOffsetX",
		name = "Debug Shadow Map X Offset",
		description = "Offset the shadow map.",
		section = shadowDebugSection
	)
	default int shadowMapDebugOffsetX()
	{
		return 0;
	}

	@Units(Units.PERCENT)
	@Range(
		min = -100,
		max = 100,
		slider = true
	)
	@ConfigItem(
		keyName = "shadowMapDebugOffsetY",
		name = "Debug Shadow Map Y Offset",
		description = "Offset the shadow map.",
		section = shadowDebugSection
	)
	default int shadowMapDebugOffsetY()
	{
		return 0;
	}
}
