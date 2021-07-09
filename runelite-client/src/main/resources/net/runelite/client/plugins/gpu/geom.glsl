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
#version 330

uniform mat4 shadowProjectionMatrix;

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in VertexData {
  vec4 Color;
  noperspective centroid float fHsl;
  flat int textureId;
  vec2 fUv;
  float fogAmount;

  ivec3 vertex;
  vec4 lightSpacePosition;
} inputs[3];

out VertexData {
  vec4 Color;
  noperspective centroid float fHsl;
  flat int textureId;
  vec2 fUv;
  float fogAmount;

  vec3 faceNormal;
  vec4 lightSpacePosition;
  vec3 lightSpaceNormal;
  noperspective vec3 lightSpaceDist;
  noperspective vec2 lightSpaceCenter;
} outputs;

void main() {
  // Calculate unnormalized face normal
  vec3 vecA = inputs[1].vertex.xyz - inputs[0].vertex.xyz;
  vec3 vecB = inputs[2].vertex.xyz - inputs[0].vertex.xyz;
  vec3 faceNormal = normalize(cross(vecA, vecB));
//  faceNormal.y *= -1; // Flip normal such that positive is up

  // http://www.lighthouse3d.com/tutorials/glsl-12-tutorial/the-normal-matrix/
  mat3 shadowNormalMatrix = transpose(inverse(mat3(shadowProjectionMatrix)));

  // http://strattonbrazil.blogspot.com/2011/09/single-pass-wireframe-rendering_11.html
  vec2 p0 = inputs[0].lightSpacePosition.xy / inputs[0].lightSpacePosition.w;
  vec2 p1 = inputs[1].lightSpacePosition.xy / inputs[1].lightSpacePosition.w;
  vec2 p2 = inputs[2].lightSpacePosition.xy / inputs[2].lightSpacePosition.w;
//  const vec2 winSize = 300.f / vec2(1920, 1080);
//  vec2 p0 = winSize * gl_in[0].gl_Position.xy / gl_in[0].gl_Position.w;
//  vec2 p1 = winSize * gl_in[1].gl_Position.xy / gl_in[1].gl_Position.w;
//  vec2 p2 = winSize * gl_in[2].gl_Position.xy / gl_in[2].gl_Position.w;
  vec2 v0 = p2 - p1;
  vec2 v1 = p2 - p0;
  vec2 v2 = p1 - p0;
  float area = abs(v1.x * v2.y - v1.y * v2.x);

  for (int i = 0; i < 3; i++) {
    // Pass forward all vertices and inputs unchanged
    gl_Position = gl_in[i].gl_Position;
    outputs.Color = inputs[i].Color;
    outputs.fHsl = inputs[i].fHsl;
    outputs.textureId = inputs[i].textureId;
    outputs.fUv = inputs[i].fUv;
    outputs.fogAmount = inputs[i].fogAmount;
    outputs.lightSpacePosition = inputs[i].lightSpacePosition;

    // Define the faceNormal
    outputs.faceNormal = faceNormal;

    // Calculate light space normal
    outputs.lightSpaceNormal = normalize(shadowNormalMatrix * faceNormal);

    switch (i) {
      case 0:
        outputs.lightSpaceDist = vec3(area / length(v0), 0.f, 0.f);
        break;
      case 1:
        outputs.lightSpaceDist = vec3(0.f, area / length(v1), 0.f);
        break;
      case 2:
        outputs.lightSpaceDist = vec3(0.f, 0.f, area / length(v2));
        break;
    }

    outputs.lightSpaceCenter = (p0 + p1 + p2) / 3.f;

    EmitVertex();
  }
  EndPrimitive();
}