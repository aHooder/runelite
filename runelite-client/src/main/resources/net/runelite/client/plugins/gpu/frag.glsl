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

#define PI 3.1415926535897932384626433832795

#include SHADOW_CONSTANTS

#if USE_SHADOW_SAMPLER
  #define SHADOW_SAMPLER_TYPE sampler2DShadow
#else
  #define SHADOW_SAMPLER_TYPE sampler2D
#endif

uniform sampler2DArray textures;

uniform int renderPass;

uniform vec2 textureOffsets[128];
uniform float brightness;
uniform float smoothBanding;
uniform vec4 fogColor;
uniform int colorBlindMode;
uniform float textureLightMode;

#if SHADOWS_ENABLED
  uniform SHADOW_SAMPLER_TYPE shadowMap;

  #if SHADOW_TRANSLUCENCY_ENABLED
    uniform SHADOW_SAMPLER_TYPE shadowTranslucencyMap;
    uniform sampler2D shadowTranslucencyColorTexture;
  #endif

  uniform float shadowStrength;
  uniform float shadowSunScale;
  uniform vec3 shadowDirection;
  uniform mat4 shadowProjectionMatrix;
  uniform vec3 shadowFrustum;

  uniform int shadowDebugView;
  uniform int shadowMapDebugSize;
  uniform float shadowMapDebugZoom;
  uniform float shadowMapDebugOffsetX;
  uniform float shadowMapDebugOffsetY;

  uniform float shadowPcssNearPlane;
  uniform float shadowPcssLightWorldSize;
  uniform float shadowPcssLightFrustumWidth;
#endif

in VertexData {
  vec4 Color;
  noperspective centroid float fHsl;
  flat int textureId;
  vec2 fUv;
  float fogAmount;

  #if SHADOWS_ENABLED
    vec3 faceNormal;
    vec4 lightSpacePosition;
    vec3 lightSpaceNormal;
    noperspective vec3 lightSpaceDist;
    noperspective vec2 lightSpaceCenter;
  #endif
};

out vec4 FragColor;

#include hsl_to_rgb.glsl
#include colorblind.glsl

#if SHADOWS_ENABLED
  #include shadows.glsl
#endif

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

  const float eps = .001f;

  switch (renderPass) {
    case 0: // SCENE
      #if SHADOWS_ENABLED && DEBUG_SHADOW_MAPS
        vec2 screen = gl_FragCoord.xy;
        float tile = shadowMapDebugSize;
        int tileBorderThickness = 1;

        #if SHADOW_TRANSLUCENCY_ENABLED
          int numTiles = 3;
        #else
          int numTiles = 1;
        #endif

        for (int i = 0; i < numTiles; i++) {
          if (screen.x < shadowMapDebugSize && screen.y < shadowMapDebugSize) {
            vec2 uv = screen / tile;
            vec2 offset = vec2(shadowMapDebugOffsetX, shadowMapDebugOffsetY);
            uv -= .5f; // Center
            uv += offset * .5f; // Shift by offset
            uv /= shadowMapDebugZoom; // Zoom in
//            uv -= .5f; // Reset origin

            switch (i) {
              case 0:
                FragColor = vec4(vec3(texture(shadowMap, uv).r), 1.f);
                return;
              #if SHADOW_TRANSLUCENCY_ENABLED
              case 1:
                FragColor = vec4(vec3(texture(shadowTranslucencyMap, uv).r), 1.f);
                return;
              case 2:
                FragColor = vec4(texture(shadowTranslucencyColorTexture, uv).rgb, 1.f);
                return;
              #endif
            }
          } else if (screen.x - shadowMapDebugSize < tileBorderThickness &&
                     screen.y - shadowMapDebugSize < tileBorderThickness) {
            FragColor = vec4(1.f, 0.f, 1.f, 1.f);
            return;
          }

          screen.y -= shadowMapDebugSize + tileBorderThickness; // Shift screen origin down one debug tile
        }
      #endif

      if (colorBlindMode > 0) {
        c.rgb = colorblind(colorBlindMode, c.rgb);
      }

      #if SHADOWS_ENABLED
        c = applyShadows(c);
      #endif

      vec3 mixedColor = mix(c.rgb, fogColor.rgb, fogAmount);
      FragColor = vec4(mixedColor, c.a);
      break;
    #if SHADOWS_ENABLED
    case 1: // SHADOW_MAP_OPAQUE
      // Discard all water-textured fragments
      if (textureId == 2) {
        discard;
      }

      #if SHADOW_TRANSLUCENCY_ENABLED
        // Discard all non-opaque fragments
        if (c.a < .99f) {
          discard;
        }
      #else
        // Let light pass through very translucent fragments, such as glass.
        // .12 doesn't produce flickering shadows for portals, while letting
        // light pass through very translucent glass.
        if (c.a < .12f) {
          discard;
        }
      #endif

      // gl_FragDepth is written to automatically
      break;
    case 2: // SHADOW_MAP_TRANSLUCENT
      // Discard all opaque fragments, and all essentially invisible fragments
      // which are sometimes used by clickboxes and textured objects
      if (c.a >= .99f || c.a < .01f) {
        discard;
      }

      // Output the color premultiplied with opacity, making the color darker the greater its opacity
      FragColor.rgb = (1 - c.a) + c.rgb * c.a;

      // gl_FragDepth is written to automatically
      break;
    #endif
  }
}
