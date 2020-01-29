Shader "geometry/Flower"
{
    Properties
    {
        _DNS("Length",float) = 1
        _DNNS("Sharpness",float) = 1
        _DSS("W",float) = 1
        _PESL("Per slide",float) = 0.
        _PUVS("Petal uv slide",float) = 0.
        _PTARE("Petal TARE",float) = 0.
        _SIZE("Size",float) = 1.
        _RH("random height",float) = 1
        _RR("random range",float) = 1
        _TH("threshold",range(0.,1.5)) = .5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent"}
        LOD 100
        Cull off
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 because it uses wrong array syntax (type[size] name)
#pragma exclude_renderers d3d11
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            
            #include "UnityCG.cginc"
            
            #define CYCLE 6
            #define LAYER 5

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal :NORMAL;
            };

            struct v2g
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal :NORMAL;
                float3 obj :TEXCOORD1;
            };
            
            
            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                return o;
            }
            
            float3 random3(float3 c) {
                float j = 4096.0*sin(dot(c,float3(17.0, 59.4, 15.0)));
                float3 r;
                r.z = frac(512.0*j);
                j *= .125;
                r.x = frac(512.0*j);
                j *= .125;
                r.y = frac(512.0*j);
                return r-0.5;
            }

            //https://www.shadertoy.com/view/XsX3zB
            /* skew constants for 3d simplex functions */
            const float F3 =  0.3333333;
            const float G3 =  0.1666667;
            
            /* 3d simplex noise */
            float simplex3d(float3 p) {
                /* 1. find current tetrahedron T and it's four vertices */
                /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
                /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/
                
                /* calculate s and x */
                float3 s = floor(p + dot(p, float3(F3,F3,F3)));
                float3 x = p - s + dot(s, float3(G3,G3,G3));
                
                /* calculate i1 and i2 */
                float3 e = step(float3(0.,0.,0.), x - x.yzx);
                float3 i1 = e*(1.0 - e.zxy);
                float3 i2 = 1.0 - e.zxy*(1.0 - e);
                    
                /* x1, x2, x3 */
                float3 x1 = x - i1 + G3;
                float3 x2 = x - i2 + 2.0*G3;
                float3 x3 = x - 1.0 + 3.0*G3;
                
                /* 2. find four surflets and store them in d */
                float4 w, d;
                
                /* calculate surflet weights */
                w.x = dot(x, x);
                w.y = dot(x1, x1);
                w.z = dot(x2, x2);
                w.w = dot(x3, x3);
                
                /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
                w = max(0.6 - w, 0.0);
                
                /* calculate surflet components */
                d.x = dot(random3(s), x);
                d.y = dot(random3(s + i1), x1);
                d.z = dot(random3(s + i2), x2);
                d.w = dot(random3(s + 1.0), x3);
                
                /* multiply d by w^4 */
                w *= w;
                w *= w;
                d *= w;
                
                /* 3. return the sum of the four surflets */
                return dot(d, float4(52.0,52.0,52.0,52.0));
            }

            
            float3x3 RotMat(float3 axis, float angle)
            {
                // http://www.neilmendoza.com/glsl-rotation-about-an-arbitrary-axis/
                axis = normalize(axis);
                float s = sin(angle);
                float c = cos(angle);
                float oc = 1.0 - c;
                
                return float3x3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s, 
                                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s, 
                                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c          );
            }
            
            float3 calcNormal(float3 a,float3 b,float3 c)
            {
                float3 ab = normalize(b - a);
                float3 ac = normalize(c - a);
                return normalize(cross(ab,ac));
            }
            
            float _DNS;
            float _DNNS;
            float _DSS;
            float _PESL;
            float _PUVS;
            float _PTARE;
            float _SIZE;
            float _RR;
            float _RH;
            float _TH;

            [maxvertexcount(81) ]
             void geom(triangle v2g input[3], inout TriangleStream<g2f> OutputStream)
            {
                g2f v = (g2f)0;
                float4 po = float4(( input[0].vertex.xyz + input[1].vertex.xyz + input[2].vertex.xyz)/3.,1.);
                float3 n = normalize((input[0].normal.xyz + input[1].normal.xyz + input[2].normal.xyz)/3.);
                //float4 iv[3] = { p , p + float4(0.5,0.,1.,0.),p + float4(-0.5,0.,1.,0.) };
                
                float3 s = normalize( cross(n,float3(1.,1.,0.)));
                float3 sn = mul(RotMat(normalize(s - po),UNITY_PI/2.),n );
               // po.xyz += n * simplex3d(po)/10.;
                float3 r3 = random3(po);
                po.xyz += (max(r3.x , max(r3.z,r3.y))-.2) * (sn + s) * _RR;
                po.xyz += r3.y * n * _RH;
                
                float4 vvs = po;
                
                
                float dnns = _DNNS/100.;
                float dns = _DNS/100.;
                float dss = _DSS/100.;
                float size = _SIZE * (random3(po)*.5 + .5);
                
                float ds[4] = {0.,.7,-.7,0.};
                float dn[4] = {0.,.7,.7,2.};
                float uv[2] = {-1,1};
                
                float3 a = s * (dn[0] + dn[0])*dnns + n * dn[0]*dns + sn * ds[0]*dss + vvs.xyz ;
                float3 b = s * (dn[1] + dn[1])*dnns + n * dn[1]*dns + sn * ds[1]*dss  + vvs.xyz;
                float3 c = s * (dn[2] + dn[2])*dnns + n * dn[2]*dns + sn * ds[2]*dss  + vvs.xyz;
                float3 d = s * (dn[3] + dn[3])*dnns + n * dn[3]*dns + sn * ds[3]*dss  + vvs.xyz + sn * _PTARE;
                    
                float3 na[2] = {calcNormal(a,b,c),calcNormal(b,c,d)};
                
                [unroll]
                for(int h = 0; h < LAYER ;h++)
                {
                    [unroll]
                    for(int j = 0; j < CYCLE  ; j++)
                    {
                        float rad = (360./CYCLE) * (j + 1) * (UNITY_PI/180.) + _PESL * (h + 1.);
                        float layerA = ((140./LAYER) * (h + 1.)) * (UNITY_PI/180.);
                        [unroll]
                        for(int i = 0; i < 4; i++)
                        {
                            float4 p = po;
                            float3 pd = mul( RotMat(sn,layerA),(s * (dn[i] + dn[i]) * dnns + n * dn[i] * dns + sn * ds[i] * dss  + (i == 3) * sn * _PTARE)* size );
                            pd = mul( RotMat(n,rad),pd ) + vvs.xyz;
                            v.vertex = UnityObjectToClipPos(float4(pd,1.));
                            v.normal = mul(RotMat(sn,layerA),na[fmod(i,2)]);
                            v.normal = mul(RotMat(n,rad),v.normal);
                            v.obj = p;
                            v.uv = float2(uv[i % 2.],uv[floor(i/2)]);
                            OutputStream.Append(v);
                        }
                        OutputStream.RestartStrip();
                    }
                    
                }
            }
            fixed4 frag (g2f i) : SV_Target
            {
            
                i.uv += float2(_PUVS,_PUVS);
               // float c = simplex3d(i.obj * 100.);
                clip(( length(i.uv )>_TH) * -1.);
                //i.uv = (i.uv + float2(1.,1.)) /2.; 
                float3 lp = mul(unity_WorldToObject,float4(_WorldSpaceLightPos0.xyz,1.)).xyz;
                float3 light = normalize(lp - i.obj); 
                fixed3 col = frac(i.obj*3.) * .7 + .3;
                float diff = .5 + max(.5 * dot(light,i.normal),.0);
                col *= diff;
               // col = i.normal;
                return float4(col,.5 + length(i.uv) * .5);
            }
            ENDCG
        }
        
    }
}
