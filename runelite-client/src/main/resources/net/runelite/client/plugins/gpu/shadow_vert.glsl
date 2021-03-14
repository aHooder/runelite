/*
 * Copyright (c) 2018, Adam <Adam@sigterm.info>
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

#version 330

layout (location = 0) in ivec4 VertexPosition;
layout (location = 1) in vec4 uv;

uniform float brightness;
uniform mat4 lightSpaceProjectionMatrix;

//out float alpha;
//flat out int textureId;
//out vec2 fUv;
//out vec4 Color;
//noperspective centroid out float fHsl;

out vec4 Color;
noperspective centroid out float fHsl;
flat out int textureId;
out vec2 fUv;
out float fogAmount;

#include hsl_to_rgb.glsl

void main()
{
  ivec3 vertex = VertexPosition.xyz;
  int ahsl = VertexPosition.w;
  int hsl = ahsl & 0xffff;
  float a = float(ahsl >> 24 & 0xff) / 255.f;

  vec3 rgb = hslToRgb(hsl);

  gl_Position = lightSpaceProjectionMatrix * vec4(vertex, 1.f);
  Color = vec4(rgb, 1.f - a);
  fHsl = float(hsl);
  textureId = int(uv.x);
  fUv = uv.yz;



//  gl_Position = lightSpaceProjectionMatrix * vec4(pos.xyz, 1.f);
//
//  alpha = 1.f - float(pos.w >> 24 & 0xff) / 255.f;
//
//  textureId = int(uv.x);
//  fUv = uv.yz;



  //  int ahsl = pos.w;
  //  int hsl = ahsl & 0xffff;
  //  float a = float(ahsl >> 24 & 0xff) / 255.f;
//
//  vec3 rgb = hslToRgb(hsl);
//
//  Color = vec4(rgb, 1.f - a);
//  fHsl = float(hsl);
}