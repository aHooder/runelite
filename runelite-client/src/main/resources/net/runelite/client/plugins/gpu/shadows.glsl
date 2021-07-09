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
#include PCF_DEPTH_LOOKUP
#include PCF_RGB_LOOKUP

#if USE_PCSS
  #include pcss.glsl
#endif

float lookupPCFNormalOffset(sampler2DShadow m, vec3 c, vec2 planeBias, vec2 texelSize) {
  int n = PCF_KERNEL_SIZE;
  float sum = 0.f;
  for (int x = -n / 2; x <= n / 2; x++) {
    for (int y = -n / 2; y <= n / 2; y++) {
      vec2 offset = vec2(x, y) * texelSize;
      sum += texture(m, c + vec3(offset, planeBias.x * offset.x + planeBias.y * offset.y));
    }
  }
  return sum / float(n * n);
}

vec3 lookupPCFColor(sampler2D m, vec2 c, vec2 texelSize) {
  int n = PCF_KERNEL_SIZE;
  vec3 color = vec3(0.f);
  for (int x = -n / 2; x <= n / 2; x++) {
    for (int y = -n / 2; y <= n / 2; y++) {
      color += texture(m, c + vec2(x, y) * texelSize).rgb;
    }
  }
  return color / float(n * n);
}

vec4 applyShadows(vec4 c) {
  // Get the fragment position in light space in the range 0 to 1
  vec3 lightPos = lightSpacePosition.xyz / lightSpacePosition.w;
  vec3 coords = lightPos * .5f + .5f;

  const float eps = .001f;

  // Return early if the point lies outside the shadow map texture to avoid unnecessary lookups
  if (coords.x < -eps || coords.x > 1.f + eps ||
      coords.y < -eps || coords.y > 1.f + eps ||
      coords.z < -eps || coords.z > 1.f + eps) {
    return c;
  }

  float angleCos = dot(lightSpaceNormal, vec3(0.f, 0.f, 1.f));

  if (c.a > .99f && angleCos > 0.f) {
    c.rgb = mix(c.rgb, vec3(0.f), shadowStrength);
    return c;
  }

  ivec2 texSize = textureSize(shadowMap, 0);
  vec2 texelSize = 1.f / texSize;

  vec2 texelUv = mod(coords.xy, texelSize);

  vec2 toCenter = texelSize / 2.f - texelUv;
  vec2 offset = toCenter;

  #if SHADOW_LINEAR_FILTERING
    // Which direction will the linear filtering sample in
    vec2 bottomLeftSampleOffset = min(vec2(0), -sign(toCenter));
    // Which quadrant around the sampling point is closest to the light
    vec2 closestQuadrantOffset = max(vec2(0), sign(lightSpaceNormal.zz * lightSpaceNormal.xy));
    // Combine the above two to get the texel offset for the texel closest to the light
    vec2 closestTexelOffset = bottomLeftSampleOffset + closestQuadrantOffset;
    // Move offset to the center of the nearest texel
    offset += closestTexelOffset * texelSize;
  #endif

  // Partially fix projective aliasing by shifting the fragment into the surface
//  float slope = clamp(mix(1.f, -2.f, -angleCos), 0.f, 1.f);
  float slope = 1.f - pow(max(0.f, -angleCos), .5f);
//  offset -= lightSpaceNormal.xy * slope * texelSize * 1.5f;

  float texelMin = min(texelSize.x, texelSize.y);
  float dist = min(min(lightSpaceDist.x, lightSpaceDist.y), lightSpaceDist.z) / texelMin;

  if (shadowDebugView == 2) {
    return vec4(slope, -slope, 0, 1.f);
  } else if (shadowDebugView == 4) {
    return vec4(angleCos, -angleCos, 0, 1);
  } else if (shadowDebugView == 5) {
    if (c.a < .01f) {
      discard;
    }
//    return vec4(0.f, 1.f - min(1.f, dist), 0.f, 1.f);
    float v = 1.f - min(1.f, dist);
    return vec4(v, 0.f, v, 1.f);
  } else if (shadowDebugView == 6) {
    return vec4(vec3(dist - PCF_KERNEL_SIZE / 2.f), 1.f);
  } else if (shadowDebugView == 7) {
    float shift = -min(0.f, dist - PCF_KERNEL_SIZE / 2.f);
//    return vec4(shift / 20.f, 0, 0, 1);
    vec2 dir = lightSpaceCenter.xy - lightPos.xy;
    coords.xy += normalize(dir) * texelSize * shift;
  } else if (shadowDebugView == 8) {
    return vec4(lightSpaceCenter.xy - lightPos.xy, 0.f, 1);
  }

  // Bias the Z value to the depth of the closest texel being sampled from
  vec2 planeBias = lightSpaceNormal.xy / -lightSpaceNormal.z;

  // idea based on the following papers:
  // http://jcgt.org/published/0003/04/08/paper-lowres.pdf
  // https://w3-o.cs.hm.edu/users/nischwit/public_html/AdaptiveDepthBias_WSCG.pdf
  // plane: ax + by + cz = d
  // Z on plane: (ax + by - d) / -c = z
  // d = 0

  // Add depth bias to make the depth equal to the nearest center of a sample
  coords.z += planeBias.x * offset.x + planeBias.y * offset.y;
  // Prevent Z-fighting
//  coords.z -= .0001f;
  coords.z -= .0001f + .0015f * abs(slope);

  // Used to move fragments in a cone around the center fragment in PCF
  vec2 zScale = shadowFrustum.z / shadowFrustum.xy;

  if (shadowDebugView == 14) {
    coords.z -= .001f;
  }

  if (shadowDebugView == 16) {
    return vec4(coords.z, -coords.z, 0, 1);
  }

  #if USE_PCSS
    float shadowFactor = PCSS(shadowMap, coords, planeBias, zScale, texelSize);
  #elif USE_PCF
    float shadowFactor = PCF_DEPTH_LOOKUP(shadowMap, coords, planeBias, zScale);
  #elif USE_SHADOW_SAMPLER
    float shadowFactor = texture(shadowMap, coords);
  #else
    float shadowFactor = coords.z < texture(shadowMap, coords.xy).r ? 0.f : 1.f;
  #endif

  // Fade surfaces to complete shadow when they are parallel to the light
  if (shadowDebugView == 13) {
    if (c.a > .99f) {
      shadowFactor = max(slope, shadowFactor);
    }
  }

  if (shadowDebugView == 1) {
    if (c.a > .99f) {
      shadowFactor = max(pow(slope, 1.f), shadowFactor);
    }
  } else if (shadowDebugView == 10) {
    angleCos = dot(faceNormal, shadowDirection);
    float slope = pow(1.f - abs(angleCos * angleCos), 4.f);
    shadowFactor = shadowFactor * (1.f - slope) + slope;
  } else if (shadowDebugView == 11) {
    float slope = sign(angleCos) * (1.f - abs(angleCos));
    return vec4(slope, -slope, 0.f, 1.f);
  } else if (shadowDebugView == 12) {
    angleCos = dot(faceNormal, shadowDirection);
    float slope = sign(angleCos) * (1.f - abs(angleCos));
    return vec4(slope, -slope, 0.f, 1.f);
  }

  vec3 shadow = c.rgb * (1.f - shadowFactor);

  #if SHADOW_TRANSLUCENCY_ENABLED
    if (shadowFactor < 1.f) {
      // Skip fragments that aren't opaque to work around an issue where all translucent objects
      // that receive shadow share the same shadow colors, meaning colors from fragments behind
      // get projected onto the shadow of fragments in front. Opaque fragments don't suffer from
      // this because of the separate shading step. To properly solve this for translucent fragments
      // a controlled render order and different blend function is required.
      if (c.a < .99f) {
        return c;
      }

      #if USE_PCSS
        float translucentShadowFactor = PCSS(shadowTranslucencyMap, coords, planeBias, zScale, texelSize);
      #elif USE_PCF
        float translucentShadowFactor = PCF_DEPTH_LOOKUP(shadowTranslucencyMap, coords, planeBias, zScale);
      #elif USE_SHADOW_SAMPLER
        float translucentShadowFactor = texture(shadowTranslucencyMap, coords);
      #else
        float translucentShadowFactor = coords.z < texture(shadowTranslucencyMap, coords.xy).r ? 0.f : 1.f;
      #endif

      if (translucentShadowFactor > 0.f) {
  //      translucentShadowFactor = pow(translucentShadowFactor, 2.f);
        #if USE_PCSS
          vec3 shadowColor = texture(shadowTranslucencyColorTexture, coords.xy).rgb;
//          vec3 shadowColor = vec3(1.f, 0.f, 1.f);
        #elif USE_PCF
          vec3 shadowColor = PCF_RGB_LOOKUP(shadowTranslucencyColorTexture, coords.xy);
        #else
          vec3 shadowColor = texture(shadowTranslucencyColorTexture, coords.xy).rgb;
        #endif
        // Because light passes through both sides, take the square root of the color
        shadow *= sqrt(shadowColor);
      }
    }
  #endif

  // Blend between the resulting shadow color and the normal color based on shadow strength
  c.rgb = mix(c.rgb, shadow, shadowStrength);

  return c;
}