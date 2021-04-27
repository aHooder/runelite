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
#version 330

uniform sampler2DArray textures;
uniform sampler2DShadow shadowMap;
uniform sampler2DShadow shadowTranslucencyMap;
uniform sampler2D shadowTranslucencyColorTexture;

uniform int renderPass;

uniform vec2 textureOffsets[64];
uniform float brightness;
uniform float smoothBanding;
uniform vec4 fogColor;
uniform int colorBlindMode;
uniform float textureLightMode;

uniform bool enableShadows;
uniform bool enableShadowTranslucency;
uniform float shadowStrength;

in vec4 Color;
noperspective centroid in float fHsl;
flat in int textureId;
in vec2 fUv;
in float fogAmount;
in vec4 positionLightSpace;

out vec4 FragColor;

#include hsl_to_rgb.glsl
#include colorblind.glsl
#include shadows.glsl

void main() {
  vec4 c;

  if (textureId > 0) {
    int textureIdx = textureId - 1;

    vec2 animatedUv = fUv + textureOffsets[textureIdx];

    vec4 textureColor = texture(textures, vec3(animatedUv, float(textureIdx)));
    vec4 textureColorBrightness = pow(textureColor, vec4(brightness, brightness, brightness, 1.0f));

    // textured triangles hsl is a 7 bit lightness 2-126
    float light = fHsl / 127.f;
    vec3 mul = (1.f - textureLightMode) * vec3(light) + textureLightMode * Color.rgb;
    c = textureColorBrightness * vec4(mul, 1.f);
  } else {
    // pick interpolated hsl or rgb depending on smooth banding setting
    vec3 rgb = hslToRgb(int(fHsl)) * smoothBanding + Color.rgb * (1.f - smoothBanding);
    c = vec4(rgb, Color.a);
  }

  switch (renderPass) {
    case 0: // SCENE
      if (colorBlindMode > 0) {
        c.rgb = colorblind(colorBlindMode, c.rgb);
      }

      if (enableShadows) {
        c = applyShadows(c);
      }

      vec3 mixedColor = mix(c.rgb, fogColor.rgb, fogAmount);
      FragColor = vec4(mixedColor, c.a);
      break;
    case 1: // SHADOW_MAP_OPAQUE
      if (enableShadowTranslucency) {
        // Discard all non-opaque fragments
        if (c.a < .99f) {
          discard;
        }
      } else {
        // Let light pass through very translucent fragments, such as glass.
        // .12 doesn't produce flickering shadows for portals, while letting
        // light pass through very translucent glass.
        if (c.a < .12f) {
          discard;
        }
      }

      // gl_FragDepth is written to automatically
      break;
    case 2: // SHADOW_MAP_TRANSLUCENT
      if (c.a >= .99f) {
        discard;
      }

      // The more opaque the fragment is, the stronger the color should be
      FragColor.rgb = mix(vec3(1.f), c.rgb, c.a);
      // Make the color darker by the square of the opacity
      FragColor.rgb *= 1.f - c.a * c.a;

      // gl_FragDepth is written to automatically
      break;
  }
}
