//  DigitalBrain.metal
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/11/20.
// by struss 2013, Shader Toy, modified to move less, and have fewer highlights, no input noise and ported to Metal by Miguel
//
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "SwiftTermShaders.h"
#define iTime iGlobalTime

// by srtuss, 2013

// rotate position around axis
float2 rotate(float2 p, float a)
{
    return float2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a));
}

// 1D random numbers
float rand(float n)
{
    return fract(sin(n) * 43758.5453123);
}

// 2D random numbers
float2 rand2(float2 p)
{
    return fract(float2(sin(p.x * 591.32 + p.y * 154.077), cos(p.x * 391.32 + p.y * 49.077)));
}

// 1D noise
float noise1(float p)
{
    float fl = floor(p);
    float fc = fract(p);
    return mix(rand(fl), rand(fl + 1.0), fc);
}

// voronoi distance noise, based on iq's articles
float voronoi(float2 x)
{
    float2 p = floor(x);
    float2 f = fract(x);
    
    float2 res = float2(8.0);
    for(int j = -1; j <= 1; j ++)
    {
        for(int i = -1; i <= 1; i ++)
        {
            float2 b = float2(i, j);
            float2 r = float2(b) - f + rand2(p + b);
            
            // chebyshev distance, one of many ways to do this
            float d = max(abs(r.x), abs(r.y));
            
            if(d < res.x)
            {
                res.y = res.x;
                res.x = d;
            }
            else if(d < res.y)
            {
                res.y = d;
            }
        }
    }
    return res.y - res.x;
}



fragment half4 digitalbrain_fragment_texture(ProjectedVertex in [[stage_in]], constant Uniforms &uniforms [[buffer(0)]])
{
    float flicker = noise1(iTime * 0.1) * 0.8 + 0.4;
    
    float2 uv = in.texCoords; // / iResolution.xy;
    uv = (uv - 0.5) * 2.0;
    float2 suv = uv;
    uv.x *= iResolution.x / iResolution.y;
    float v = 0.0;
    
    // that looks highly interesting:
    //v = 1.0 - length(uv) * 1.3;
    // a bit of camera movement
    uv *= 0.6 + sin(iTime * 0.1) * 0.4;
    uv = rotate(uv, sin(iTime * 0.1) * 1.0);
    uv += iTime * 0.1;
    
    // add some noise octaves
    float a = 0.6, f = 1.0;
    
    for(int i = 0; i < 3; i ++) // 4 octaves also look nice, its getting a bit slow though
    {
        float v1 = voronoi(uv * f + 5.0);
        float v2 = 0.0;
        
        // make the moving electrons-effect for higher octaves
        if(i > 0)
        {
            // of course everything based on voronoi
            v2 = voronoi(uv * f * 0.5 + 50.0 + iTime*0.1);
            
            float va = 0.0, vb = 0.0;
            va = 1.0 - smoothstep(0.0, 0.1, v1);
            vb = 1.0 - smoothstep(0.0, 0.08, v2);
            v += a * pow(va * (0.5 + vb), 2.0);
        }
        
        // make sharp edges
        v1 = 0.5 - smoothstep(0.0, 0.3, v1);
        
        // noise is used as intensity map
        v2 = a * (noise1(v1 * 5.5 + 0.1));
        
        // octave 0's intensity changes a bit
        if(i == 0)
            v += v2 * flicker;
        else
            v += v2;
        
        f *= 3.0;
        a *= 0.7;
    }
    
    // slight vignetting
    v *= exp(-0.6 * length(suv)) * 1.2;
    
    // use texture channel0 for color? why not.
    //float3 cexp = texture(iChannel0, uv * 0.001).xyz * 3.0 + texture(iChannel0, uv * 0.01).xyz;//float3(1.0, 2.0, 4.0);
    
    
    // old blueish color set
    float3 cexp = float3(6.0, 4.0, 2.0);
    
    
    //float3 col = float3(pow(v, cexp.x), pow(v, cexp.y), pow(v, cexp.z)) * 2.0;
    float3 col = float3(pow(v, cexp.x), pow(v, cexp.y), pow(v, cexp.z)) * 0.5;
    //col = float3(v,v,v)*0.4;
    return half4 (float4(col, 1.0));
}
