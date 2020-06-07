//
//  SwiftTermShaders.h
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 6/6/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

#ifndef SwiftTermShaders_h
#define SwiftTermShaders_h

struct Vertex2D
{
    float2 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct ProjectedVertex {
    float4 position [[position]];
    float2 texCoords;
};

struct Uniforms {
    float2    resolution;
    float     time;
    float     deltaTime;
    int       frameIndex;
};

#define iGlobalTime (uniforms.time)
#define iResolution (uniforms.resolution)
#define iTimeDelta (uniforms.deltaTime)
#define iTouches (uniforms.touches)

#endif /* SwiftTermShaders_h */
