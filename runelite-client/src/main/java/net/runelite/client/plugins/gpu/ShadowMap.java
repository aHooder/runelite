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
package net.runelite.client.plugins.gpu;

import static com.jogamp.opengl.GL.GL_COLOR_ATTACHMENT0;
import static com.jogamp.opengl.GL.GL_DEPTH_ATTACHMENT;
import static com.jogamp.opengl.GL.GL_DEPTH_COMPONENT16;
import static com.jogamp.opengl.GL.GL_DRAW_FRAMEBUFFER;
import static com.jogamp.opengl.GL.GL_FRAMEBUFFER;
import static com.jogamp.opengl.GL.GL_GREATER;
import static com.jogamp.opengl.GL.GL_NONE;
import static com.jogamp.opengl.GL.GL_RGB;
import static com.jogamp.opengl.GL.GL_TEXTURE_2D;
import static com.jogamp.opengl.GL.GL_TEXTURE_MAG_FILTER;
import static com.jogamp.opengl.GL.GL_TEXTURE_MIN_FILTER;
import static com.jogamp.opengl.GL.GL_UNSIGNED_BYTE;
import static com.jogamp.opengl.GL.GL_UNSIGNED_SHORT;
import static com.jogamp.opengl.GL2ES2.GL_COMPARE_REF_TO_TEXTURE;
import static com.jogamp.opengl.GL2ES2.GL_DEPTH_COMPONENT;
import static com.jogamp.opengl.GL2ES2.GL_TEXTURE_COMPARE_FUNC;
import static com.jogamp.opengl.GL2ES2.GL_TEXTURE_COMPARE_MODE;
import static com.jogamp.opengl.GL2GL3.GL_RGB4;
import com.jogamp.opengl.GL4;
import lombok.extern.slf4j.Slf4j;
import static net.runelite.client.plugins.gpu.GLUtil.glDeleteFrameBuffer;
import static net.runelite.client.plugins.gpu.GLUtil.glDeleteTexture;
import static net.runelite.client.plugins.gpu.GLUtil.glGenFrameBuffer;
import static net.runelite.client.plugins.gpu.GLUtil.glGenTexture;
import static net.runelite.client.plugins.gpu.GLUtil.glGetInteger;
import net.runelite.client.plugins.gpu.config.ShadowResolution;

@Slf4j
public class ShadowMap
{
	private final GL4 gl;
	private final int maxTextureSize;

	public enum Type
	{
		OPAQUE,
		TRANSLUCENT
	}

	public int fbo, texDepth, texColor;
	public int width, height;

	public ShadowMap(GL4 gl, Type type, ShadowResolution resolution, int textureFiltering)
	{
		this.gl = gl;
		maxTextureSize = glGetInteger(gl, gl.GL_MAX_TEXTURE_SIZE);

		fbo = glGenFrameBuffer(gl);

		initDepthTexture(textureFiltering);
		if (type == Type.TRANSLUCENT)
		{
			initColorTexture(textureFiltering);
		}

		// Initialize textures with resolution
		setResolution(resolution);

		// Bind the texture as a depth attachment to the FBO
		gl.glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		gl.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, texDepth, 0);
		if (type == Type.TRANSLUCENT)
		{
			gl.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texColor, 0);
		}
		else
		{
			// We're only using the depth attachment, so disable draw & read for color attachments
			gl.glDrawBuffer(GL_NONE);
			gl.glReadBuffer(GL_NONE);
		}

		gl.glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	public void shutdown()
	{
		if (fbo != 0)
		{
			glDeleteFrameBuffer(gl, fbo);
			fbo = 0;
		}
		shutdownDepthTexture();
		shutdownColorTexture();
	}

	public void setResolution(ShadowResolution resolution)
	{
		updateResolution(resolution);
		if (texDepth != 0)
		{
			gl.glBindTexture(GL_TEXTURE_2D, texDepth);
			gl.glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT16, width, height, 0,
				GL_DEPTH_COMPONENT, GL_UNSIGNED_SHORT, null);
		}
		if (texColor != 0)
		{
			gl.glBindTexture(GL_TEXTURE_2D, texColor);
			gl.glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB4, width, height, 0,
				GL_RGB, GL_UNSIGNED_BYTE, null);
		}
	}

	public void setTextureFiltering(int textureFiltering)
	{
		if (texDepth != 0)
		{
			gl.glBindTexture(GL_TEXTURE_2D, texDepth);
			gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, textureFiltering);
			gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, textureFiltering);
		}
		if (texColor != 0)
		{
			gl.glBindTexture(GL_TEXTURE_2D, texColor);
			gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, textureFiltering);
			gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, textureFiltering);
		}
	}

	public void bind()
	{
		gl.glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo);
		gl.glViewport(0, 0, width, height);
	}

	private void initDepthTexture(int textureFiltering)
	{
		texDepth = glGenTexture(gl);
		gl.glBindTexture(GL_TEXTURE_2D, texDepth);

		// Enable depth comparison for use with shadow2DSampler
		gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
		gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_FUNC, GL_GREATER);

		// Enable linear filtering which is effectively hardware accelerated PCF 2x2 when used with a shadow sampler
		// Anti-aliasing settings are applied on top of this because shadow edges look a lot smoother,
		gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, textureFiltering);
		gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, textureFiltering);
	}

	private void shutdownDepthTexture()
	{
		if (texDepth != 0)
		{
			glDeleteTexture(gl, texDepth);
			texDepth = 0;
		}
	}

	private void initColorTexture(int textureFiltering)
	{
		texColor = glGenTexture(gl);
		gl.glBindTexture(GL_TEXTURE_2D, texColor);

		// Enable linear filtering
		gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, textureFiltering);
		gl.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, textureFiltering);
	}

	private void shutdownColorTexture()
	{
		if (texColor != 0)
		{
			glDeleteTexture(gl, texColor);
			texColor = 0;
		}
	}

	private void updateResolution(ShadowResolution resolution)
	{
		width = Math.min(maxTextureSize, resolution.getWidth());
		height = Math.min(maxTextureSize, resolution.getHeight());

		if (width != resolution.getWidth() || height != resolution.getHeight())
		{
			log.debug("Can't apply selected shadow resolution: {}x{}. Using {}x{} instead.",
				resolution.getWidth(), resolution.getHeight(), width, height);
		}
	}
}
