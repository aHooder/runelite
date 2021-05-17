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
#include GENERATED_SHADOW_LOOKUP

vec4 applyShadows(vec4 c) {
  // Get the fragment position in light space in the range 0 to 1
  vec3 coords = positionLightSpace.xyz / positionLightSpace.w * .5f + .5f;

  // Return early if the point lies outside the shadow map texture to avoid unnecessary lookups
  if (coords.x < 0.f || coords.x > 1.f ||
      coords.y < 0.f || coords.y > 1.f ||
      coords.z < 0.f || coords.z > 1.f) {
    return c;
  }

  float shadow = GENERATED_SHADOW_LOOKUP(shadowMap, coords);

  vec3 result = c.rgb * (1.f - shadow);

  if (enableShadowTranslucency && shadow < 1.f) {
    // Skip fragments that aren't opaque to work around an issue where all translucent objects
    // that receive shadow share the same shadow colors, meaning colors from fragments behind
    // get projected onto the shadow of fragments in front. Opaque fragments don't suffer from
    // this because of the separate shading step. To properly solve this for translucent fragments
    // a controlled render order and different blend function is required.
    if (c.a < .99f) {
      return c;
    }

    float shadowTranslucency = GENERATED_SHADOW_LOOKUP(shadowTranslucencyMap, coords);
    // Prevent duplicate shadows resulting in too dark shadows
//    shadowTranslucency *= 1.f - shadow;

    if (shadowTranslucency > 0.f) {
      vec4 shadowColor = texture(shadowTranslucencyColorTexture, coords.xy);
      // Because light passes through both sides, take the square root of the color
      shadowColor.rgb = sqrt(shadowColor.rgb);
      result *= shadowColor.rgb;
    }
  }

  // Blend between the resulting shadow color and the normal color based on shadow strength
  c.rgb = mix(c.rgb, result, shadowStrength);

  return c;
}