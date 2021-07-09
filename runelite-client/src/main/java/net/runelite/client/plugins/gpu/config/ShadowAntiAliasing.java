/*
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
package net.runelite.client.plugins.gpu.config;

import static com.jogamp.opengl.GL.GL_LINEAR;
import static com.jogamp.opengl.GL.GL_NEAREST;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public enum ShadowAntiAliasing
{
	NONE("None", Technique.NONE, false, 0),
	LINEAR("Linear", Technique.NONE, true, 0),
	PCF_3("PCF 3x3", Technique.PCF, true, 3),
	PCF_5("PCF 5x5", Technique.PCF, true, 5),
	PCF_7("PCF 7x7", Technique.PCF, true, 7),
	PCF_9("PCF 9x9", Technique.PCF, true, 9),
	PCF_11("PCF 11x11", Technique.PCF, true, 11),
	PCF_15("PCF 15x15", Technique.PCF, true, 15),
	PCF_21("PCF 21x21", Technique.PCF, true, 21),
	PCSS_4("PCSS 4x4", Technique.PCSS, false, 4),
	PCSS_16("PCSS 16x16", Technique.PCSS, false, 16),
	PCSS_32("PCSS 32x32", Technique.PCSS, false, 32),
	PCSS_64("PCSS 64x64", Technique.PCSS, false, 64),
	PCSS_128("PCSS 128x128", Technique.PCSS, false, 128),
	PCSS_256("PCSS 256x256", Technique.PCSS, false, 256);

	private final String name;
	public final Technique technique;
	public final boolean useLinearFiltering;
	public final int kernelSize;

	@RequiredArgsConstructor
	public enum Technique
	{
		NONE(0),
		PCF(1),
		PCSS(2);

		public final int id;
	}

	public int getTextureFilteringMode()
	{
		return useLinearFiltering ? GL_LINEAR : GL_NEAREST;
	}

	public boolean useShadowSampler()
	{
		return technique != Technique.PCSS;
	}

	@Override
	public String toString()
	{
		return name;
	}
}
