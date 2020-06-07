//
//  PlasmaGlobe.metal
//  SwiftTermApp
//
// Plasma Globe by nimitz (twitter: @stormoid), extracted from the
// MIT licensed github.com/warrenm/Shadertweak by Warren Moore

#include <metal_stdlib>
using namespace metal;
#include "SwiftTermShaders.h"

// Here starts the shader
constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);

//Plasma Globe by nimitz (twitter: @stormoid)

//looks best with around 25 rays
#define NUM_RAYS 13.

#define VOLUMETRIC_STEPS 19

#define MAX_ITER 35
#define FAR 6.

static float2x2 mm2(float a)
{
    float c = cos(a), s = sin(a);
    return float2x2(float2(c,-s),float2(s,c));
}

static float noise( float x, texture2d<float, access::sample> tex2d )
{
    return tex2d.sample(sampler2d, float2(x * 0.01, 1.0)).x;
    //return texture2D(iChannel0, vec2(x*.01,1.)).x;
}

static float hash( float n ) {
    return fract(sin(n)*43758.5453);
}

//iq's ubiquitous 3d noise
static float noise(float3 p, texture2d<float, access::sample> tex2d)
{
   float3 ip = floor(p);
   float3 f = fract(p);
   f = f*f*(3.0-2.0*f);
   
   float2 uv = (ip.xy+float2(37.0,17.0)*ip.z) + f.xy;
   //float2 rg = texture2D( iChannel0, (uv+ 0.5)/256.0, -100.0 ).yx;
   float2 rg = tex2d.sample(sampler2d, (uv+ 0.5)/256.).yx;
      return mix(rg.x, rg.y, f.z);
}

constant float3x3 m3(
  float3(0.00,  0.80,  0.60),
  float3(-0.80,  0.36, -0.48),
  float3(-0.60, -0.48,  0.64));

//See: https://www.shadertoy.com/view/XdfXRj
static float flow(float3 p, float t, float time, texture2d<float, access::sample> tex2d)
{
   float z=2.;
   float rz = 0.;
   float3 bp = p;
   for (float i= 1.;i < 5.;i++ )
   {
       p += time*.1;
       rz+= (sin(noise(p+t*0.8, tex2d)*6.)*0.5+0.5) /z;
       p = mix(bp,p,0.6);
       z *= 2.;
       p *= 2.01;
       p*= m3;
   }
   return rz;
}

//could be improved
static float sins(float x, float time)
{
   float rz = 0.;
   float z = 2.;
   for (float i= 0.;i < 3.;i++ )
   {
       rz += abs(fract(x*1.4)-0.5)/z;
       x *= 1.3;
       z *= 1.15;
       x -= time*.65*z;
   }
   return rz;
}

static float segm( float3 p, float3 a, float3 b)
{
   float3 pa = p - a;
   float3 ba = b - a;
   float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1. );
   return length( pa - ba*h )*.5;
}

static float3 path(float i, float d, float time)
{
   float3 en = float3(0.,0.,1.);
   float sns2 = sins(d+i*0.5, time)*0.22;
   float sns = sins(d+i*.6, time)*0.21;
   en.xz = mm2((hash(i*10.569)-.5)*6.2+sns2) * en.xz;
   en.xy = mm2((hash(i*4.732)-.5)*6.2+sns) * en.xy;
   return en;
}

static float2 map(float3 p, float i, float time)
{
   float lp = length(p);
   float3 bg = float3(0.);
   float3 en = path(i,lp, time);

   float ins = smoothstep(0.11,.46,lp);
   float outs = .15+smoothstep(.0,.15,abs(lp-1.));
   p *= ins*outs;
   float id = ins*outs;

   float rz = segm(p, bg, en)-0.011;
   return float2(rz,id);
}

static float march(float3 ro, float3 rd, float startf, float maxd, float j, float time)
{
   float precis = 0.001;
   float h=0.5;
   float d = startf;
   for( int i=0; i<MAX_ITER; i++ )
   {
       if( abs(h)<precis||d>maxd ) break;
       d += h*1.2;
       float res = map(ro+rd*d, j, time).x;
       h = res;
   }
   return d;
}

//volumetric marching
static float3 vmarch(float3 ro, float3 rd, float j, float3 orig, float time, texture2d<float, access::sample> tex2d)
{
   float3 p = ro;
   float2 r(0.);
   float3 sum(0);
   //float w = 0.;
   for( int i=0; i<VOLUMETRIC_STEPS; i++ )
   {
       r = map(p,j,time);
       p += rd*.03;
       float lp = length(p);

       float3 col = sin(float3(1.05,2.5,1.52)*3.94+r.y)*.85+0.4;
       col.rgb *= smoothstep(.0,.015,-r.x);
       col *= smoothstep(0.04,.2,abs(lp-1.1));
       col *= smoothstep(0.1,.34,lp);
       sum += abs(col)*5. * (1.2-noise(lp*2.+j*13.+time*5., tex2d)*1.1) / (log(distance(p,orig)-2.)+.75);
   }
   return sum;
}

//returns both collision dists of unit sphere
static float2 iSphere2(float3 ro, float3 rd)
{
   float3 oc = ro;
   float b = dot(oc, rd);
   float c = dot(oc,oc) - 1.;
   float h = b*b - c;
   if(h <0.0) return float2(-1.);
   else return float2((-b - sqrt(h)), (-b + sqrt(h)));
}

//static void mainImage( thread float4 &fragColor, float2 fragCoord )

fragment half4 plasma_fragment_texture(
    ProjectedVertex in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]],
    texture2d<float, access::sample> texture0 [[texture(0)]],
    texture2d<float, access::sample> texture1 [[texture(1)]],
    texture2d<float, access::sample> texture2 [[texture(2)]],
    texture2d<float, access::sample> texture3 [[texture(3)]])
{
   float time = iGlobalTime;
   
   float2 p = in.position.xy/iResolution.xy-0.5;
   p.x*=iResolution.x/iResolution.y;
   float2 um = 0 / iResolution.xy-.5;

   //camera
   float3 ro(0.,0.,5.);
   float3 rd = normalize(float3(p*.7,-1.5));
   float2x2 mx = mm2(time*.4+um.x*6.);
   float2x2 my = mm2(time*0.3+um.y*6.);
   ro.xz = ro.xz * mx;
   rd.xz = rd.xz * mx;
   ro.xy = ro.xy * my;
   rd.xy = rd.xy * my;

   float3 bro = ro;
   float3 brd = rd;
   
   float3 col = float3(0.0125,0.,0.025);
   #if 1
   for (float j = 1.;j<NUM_RAYS+1.;j++)
   {
       ro = bro;
       rd = brd;
       float2x2 mm = mm2((time*0.1+((j+1.)*5.1))*j*0.25);
       ro.xy = ro.xy * mm;
       rd.xy = rd.xy * mm;
       ro.xz = ro.xz * mm;
       rd.xz = rd.xz * mm;
       float rz = march(ro,rd,2.5,FAR,j, time);
       if ( rz >= FAR)continue;
       float3 pos = ro+rz*rd;
       col = max(col,vmarch(pos,rd,j, bro, time, texture0));
   }
   #endif

   ro = bro;
   rd = brd;
   float2 sph = iSphere2(ro,rd);

   if (sph.x > 0.)
   {
       float3 pos = ro+rd*sph.x;
       float3 pos2 = ro+rd*sph.y;
       float3 rf = reflect( rd, pos );
       float3 rf2 = reflect( rd, pos2 );
       float nz = (-log(abs(flow(rf*1.2,time,time,texture0)-.01)));
       float nz2 = (-log(abs(flow(rf2*1.2,-time,time,texture0)-.01)));
       col += (0.1*nz*nz* float3(0.12,0.12,.5) + 0.05*nz2*nz2*float3(0.55,0.2,.55))*0.8;
   }

   
   half4 fragColor = half4(half3(col*1.3), 1.0);

    return fragColor;
}
