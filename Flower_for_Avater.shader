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
        _AMOUNT("Amount",range(0.,1.)) = 1.
        _FINE("Fine" , float) = 1.
        _TessFactor("Tess Factor",Vector) = (2,2,2,2)
        _SPREAD("SPREAD",float) = 100
        _A("A",float) = 0
        _MOVE("Move Speed",float) = 0.
        _ROT("ROT Speed",float) = 0.
		_FSPAN("floating span",float) = 1.
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
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #pragma hull HS
            #pragma domain DS

            #pragma target 5.0
            #define INPUT_PATCH_SIZE 3
            #define OUTPUT_PATCH_SIZE 3
            
            #include "UnityCG.cginc"
            
            #define CYCLE 6
            #define LAYER 4

            uniform vector _TessFactor;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal :NORMAL;
            };

            struct v2h
            {
                float4 vertex : POS;
                float3 normal : NORMAL;
                float2 uv :TEXCOORD0;
            };

            struct h2d_main
            {
                float3 vertex :POS;
                float3 normal :NORMAL;
                float2 uv :TEXCOORD0;
            };

            struct h2d_const
            {
                float tess_factor[3] :SV_TessFactor;
                float InsideTessFactor:SV_InsideTessFactor;
            };

            struct d2g
            {
                float4 vertex :POSITION;
                float3 normal :NORMAL;
                float2 uv :TEXCOORD0;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal :NORMAL;
                float3 obj :TEXCOORD1;
                float near :TEXCOORD2;
            };
            
            
            v2h vert (appdata v)
            {
                v2h o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                o.uv = v.uv;
                return o;
            }

            h2d_const HSConst(InputPatch<v2h, INPUT_PATCH_SIZE> i) {
                h2d_const o = (h2d_const)0;
                o.tess_factor[0] = _TessFactor.x;
                o.tess_factor[1] = _TessFactor.y;
                o.tess_factor[2] = _TessFactor.z;
                o.InsideTessFactor = _TessFactor.w;
                return o;
            }

            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(OUTPUT_PATCH_SIZE)]
            [patchconstantfunc("HSConst")]
            h2d_main HS(InputPatch<v2h, INPUT_PATCH_SIZE> i, uint id:SV_OutputControlPointID) {
                h2d_main o = (h2d_main)0;
                o.vertex.xyz = i[id].vertex;
                o.normal = i[id].normal;
                o.uv = i[id].uv;
                return o;
            }

            [domain("tri")]
            d2g DS(h2d_const hs_const_data, const OutputPatch<h2d_main, OUTPUT_PATCH_SIZE> i, float3 bary:SV_DomainLocation) {
                d2g o = (d2g)0;
                float3 pos = i[0].vertex * bary.x + i[1].vertex * bary.y + i[2].vertex * bary.z;
                float3 normal = i[0].normal * bary.x + i[1].normal * bary.y + i[2].normal * bary.z;
                float2 uv = i[0].uv * bary.x + i[1].uv * bary.y + i[2].uv * bary.z;
                o.vertex = float4(pos, 1);
                o.normal = normal;
                o.uv = uv;
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

            float3 random33(float3 st)
            {
                st = float3(dot(st, float3(127.1, 311.7,811.5)),
                            dot(st, float3(269.5, 183.3,211.91)),
                            dot(st, float3(511.3, 631.19,431.81))
                            );
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
            }

            float random31(float3 p)
            {
                p  = frac( p*0.3183099+.1 );
                p *= 17.0;
                return frac( p.x*p.y*p.z*(p.x+p.y+p.z) );
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

			float c(float x, float f)
            {
                return x - (x - x * x) * -f;
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
            float _AMOUNT;
            float _FINE;
            float _SPREAD;

            float _A;
            float _MOVE;
            float _ROT;
			float _FSPAN;

            [maxvertexcount(78) ]
            void geom(triangleadj d2g input[6], inout TriangleStream<g2f> OutputStream)
            {
                g2f v = (g2f)0;
                float4 po = float4(( input[0].vertex.xyz + input[1].vertex.xyz + input[2].vertex.xyz)/3.,1.);
                float3 n = -normalize((input[0].normal.xyz + input[1].normal.xyz + input[2].normal.xyz)/3.);
                //float4 iv[3] = { p , p + float4(0.5,0.,1.,0.),p + float4(-0.5,0.,1.,0.) };
                
                float near = length(input[0].vertex.xyz - input[1].vertex.xyz - input[2].vertex.xyz
                                   +input[3].vertex.xyz - input[4].vertex.xyz - input[5].vertex.xyz); 

                float4 p = po;
                
                float3 s = normalize( cross(n,float3(1.,1.,0.)));
                float3 sn = mul(RotMat(normalize(s - po),UNITY_PI/2.),n );
                po.xy = (input[0].uv - input[1].uv - input[2].uv
                                   +input[3].uv - input[4].uv - input[5].uv) * 15.;
                po.z = max(po.x,po.y); 
               // po.xyz += n * simplex3d(po)/10.;
                float3 r3 = random3(po);
				float r31 = random31(po);
                p.xyz +=  (max(r3.x , max(r3.z,r3.y))-.2) * _RR * sin(_Time.y/10. + r3 * 3.) *  (sn + s);
                p.xyz += n * _RH * sin(_Time.y/5. * 7.)  *p.y + n *  c( (sin((_Time.y+p.y*23.)*_FSPAN ) + .7) * (cos((_Time.y+p.x*23.)*_FSPAN ) + .7) ,-1.) * _RH/10.;
                
                float4 vvs = p;
                
                
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
                float3 d = s * (dn[3] + dn[3])*dnns + n * dn[3]*dns + sn * ds[3]*dss  + vvs.xyz + n * _PTARE/1000.;
                    
                float3 na[2] = {calcNormal(a,b,c),calcNormal(b,c,d)};
                
                [unroll]
                for(int h = 0; h < LAYER ;h++)
                {
                    [unroll]
                    for(int j = 0; j < CYCLE  ; j++)
                    {
                        float rad = (360./CYCLE + _A * ((_Time.y + length(po.xyz - po.zxy)*15. ) * _ROT)) * (j + 1.) * (UNITY_PI/180.) + _PESL * (h + 1.);
                        float layerA = ((100./LAYER + _A * sin((_Time.y + length(po.xyz - po.zxy)*15. ) * _MOVE)) * (h + 1.)) * (UNITY_PI/180.);
                        [unroll]
                        for(int i = 0; i < 4; i++)
                        {
                            float3 pd = mul( RotMat(sn,layerA),(s * (dn[i] + dn[i]) * dnns + n * dn[i] * dns + sn * ds[i] * dss  + (i == 3) * n * _PTARE/1000.)* size );
                            pd = mul( RotMat(n,rad),pd ) + vvs.xyz;
                            v.vertex = UnityObjectToClipPos(float4(pd,1.));
                            v.normal = mul(RotMat(sn,layerA),na[fmod(i,2)]);
                            v.normal = mul(RotMat(n,rad),v.normal);
                            v.obj = po - frac(po*10);
                            v.uv = float2(uv[i % 2.],uv[floor(i/2)]);
                            v.near = pow((1/near),2);
                            OutputStream.Append(v);
                        }
                        OutputStream.RestartStrip();
                    }
                    
                }
            }

            float3 hsv(float h,float s,float v)
            {
                return ((clamp(abs(frac(h+float3(0,2,1)/3.)*6.-3.)-1.,0.,1.)-1.)*s+1.)*v;
            }

            fixed4 frag (g2f i) : SV_Target
            {
            
                i.uv += float2(_PUVS,_PUVS);
                float c = simplex3d(i.obj * _FINE);
                clip(( length(i.uv )>_TH || (c) < ((1 - _AMOUNT) + 1/(i.near*2.))) * -1.);
                
                //i.uv = (i.uv + float2(1.,1.)) /2.; 
                float3 lp = mul(unity_WorldToObject,float4(_WorldSpaceLightPos0.xyz,1.)).xyz;
                float3 light = normalize(lp - i.obj); 
               // fixed3 col = random33(floor(i.obj*100.)) * 1. + .5;
                float h = random31(floor((i.obj.zyx)*_SPREAD));
                float s = 1. * length(i.uv+float2(1.,1.));
                float v = 1.;
                fixed3 col = hsv(h,s,v);
                col = lerp(col,float3(.3,.5,1),float3(.7,.5,.3));
                col.g = 1;
                float diff = .5 + max(.5 * dot(light,i.normal),.0);
                col *= diff;
               // col = i.normal;
              // col = pow(col,float3(.4545,.4545,.4545));
                col = normalize(col);
                return float4(col,.5 + length(i.uv) * .5);
            }
            ENDCG
        }
        
    }
}
