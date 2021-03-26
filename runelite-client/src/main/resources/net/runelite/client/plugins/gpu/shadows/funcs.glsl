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
#define PI 3.1415926535897932384626433832795f

float nightTransitionThreshold = PI / 5.f;

// TODO: once settled on a number of kernel sizes for PCF, we could consider unroll them for better performance

float sampleDepthMap(sampler2D tex, vec3 coords) {
    switch (shadowMappingTechnique) {
        case 0: // Basic
            return coords.z > texture(tex, coords.xy).r ? 1.0 : 0.0;
        case 1: // PCF
            int n = shadowMappingKernelSize;
            int to = n / 2;
            int from = to - n + 1;

            float shadow = 0;
            vec2 size = textureSize(tex, 0);
            float xSize = 1.0 / size.x;
            float ySize = 1.0 / size.y;
            for (int x = from; x <= to; ++x) {
                for (int y = from; y <= to; ++y) {
                    float pcfDepth = texture(tex, coords.xy + vec2(x * xSize, y * ySize)).r;
                    shadow += coords.z > pcfDepth ? 1.0 : 0.0;
                }
            }
            return shadow / pow(n, 2);
        default:
            return 0.f;
    }
}

vec4 applyShadows(vec4 c) {
    vec3 coords = fragPosLightSpace.xyz / fragPosLightSpace.w * .5 + .5;
    if (coords.z <= 1 && coords.x >= 0 && coords.x <= 1 && coords.y >= 0 && coords.y <= 1) {
        // Apply bias to prevent flat surfaces casting shadows on themselves
        // TODO: would be handy with surface normals here, but not necessary
        float bias = 0.00002;
        if (shadowMappingTechnique == 1) {
            switch (shadowMappingKernelSize) {
                case 2:
                    bias = 0.00011;
                    break;
                case 3:
                case 5:
                    bias = 0.00013 + 0.0002 * shadowDistance;
                    break;
                case 7:
                    bias = 0.00015 + 0.0004 * shadowDistance;
                    break;
                case 9:
                    bias = 0.00020 + 0.0005 * shadowDistance;
                    break;
            }
        }
        coords.z -= bias;

        float distanceFadeOpacity = 1.f;
        if (distanceFadeMode > 0) {
            vec2 fadeCoords = abs(coords.xy) * 2 - 1;
            // a bit of duplicate code for readability
            if (distanceFadeMode == 1) {
                fadeCoords = pow(fadeCoords, vec2(2));
                distanceFadeOpacity = max(0.f, 1.f - sqrt(pow(fadeCoords.x, 2) + pow(fadeCoords.y, 2)));
            } else if (distanceFadeMode == 2) {
                fadeCoords = pow(fadeCoords, vec2(2));
                distanceFadeOpacity = max(0.f, 1.f - max(fadeCoords.x, fadeCoords.y));
            } else if (distanceFadeMode == 3) {
                distanceFadeOpacity = max(0.f, 1.f - sqrt(pow(fadeCoords.x, 2) + pow(fadeCoords.y, 2)));
            }
        }

        if (distanceFadeOpacity == 0)
            return c;

        float shadow = sampleDepthMap(shadowDepthMap, coords);
        float effectiveHardShadow = shadow * shadowOpacity * distanceFadeOpacity;

        if (enableShadowTranslucency && shadow < 1) {
            float translucentShadow = sampleDepthMap(shadowColorDepthMap, coords);
            vec3 translucentShadowColor = texture(shadowColorMap, coords.xy).rgb;

            float opacity = translucentShadow * distanceFadeOpacity;
            vec3 shadowColor = translucentShadowColor;

            // Invert hue due to blend function inverting color initially
            // If reducing intensity, multiply HSL saturation by intensity
            // If increasing intensity, multiply HSV value by intensity
            if (shadowColorIntensity <= 1) {
                vec3 hsl = rgbToHsl(shadowColor);
                hsl.x = mod(hsl.x + .5, 1);
                hsl.y *= shadowColorIntensity;
                shadowColor = hslToRgb(hsl);
            } else {
                vec3 hsv = rgbToHsv(shadowColor);
                hsv.x = mod(hsv.x + .5, 1);
                hsv.z *= shadowColorIntensity;
                shadowColor = hsvToRgb(hsv);
            }

            // Multiplying by the effective hard shadow somewhat fixes edges between
            // translucent and hard shadows, but it's still not perfect
            c.rgb *= mix(vec3(1), shadowColor, opacity * shadowOpacity * (1 - effectiveHardShadow));
        }

        if (effectiveHardShadow > 0) {
            c.rgb *= 1 - effectiveHardShadow;
        }
    }

    if (enableDebug) {
        float tileSize = 300;
        float offsetLeft = 0;
        float offsetBottom = 0;

        float overlayAlpha = 1;
        vec2 preOffset = vec2(0.00, 0.00);
        vec2 postOffset = vec2(0.00, 0.00);
        float zoom = 1; // applied after offset

        vec2 uv = gl_FragCoord.xy - vec2(offsetLeft, offsetBottom);
        int tileX = int(floor(uv.x / tileSize));
        int tileY = int(floor(uv.y / tileSize));
        vec2 uvTileOffset = vec2(tileX, tileY);

        // scale uv to 0-1 and apply transformations
        uv = uv / vec2(tileSize) - uvTileOffset;
        uv += preOffset;
        uv -= .5; // Move 0 to center
        uv *= vec2(1 / zoom);
        uv += .5; // Move 0 back
        uv += postOffset;

        if (tileX == 0) {
            if (tileY == 0 ) {
                return vec4(vec3(texture(shadowDepthMap, uv).r), overlayAlpha);
            } else if (tileY == 1) {
                float translucentDepth = texture(shadowColorDepthMap, uv).r;
                return FragColor = vec4(vec3(translucentDepth), overlayAlpha);
            } else if (tileY == 2) {
                vec4 color = texture(shadowColorMap, uv);
                return FragColor = vec4(color.rgb, overlayAlpha);
            } else if (tileY == 3) {
                vec4 color = texture(shadowColorMap, uv);
                return FragColor = vec4(vec3(color.a), overlayAlpha);
            }
        }
    }

    return c;
}