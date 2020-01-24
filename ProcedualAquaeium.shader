Shader "Unlit/fish"
{
    Properties
    {
        _FishScale("Fish Scale",float) = 1.0
        _KelpScale("Kelp Scale",float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            #define OBJ true
            #define FISH 0
            #define KELP 1
            #define SHELL 2
            #define BUBBLE 3

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 ro :TEXCOORD0;
                float3 surf :TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _FishScale;
            float _KelpScale;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                if(OBJ){
                    o.ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));
                    o.surf = v.vertex;
                }else{
                    o.ro = _WorldSpaceCameraPos;
                    o.surf = mul(unity_ObjectToWorld,float4(v.vertex.xyz,1));
                }
                
                return o;
            }

            #define S(a) (sin(a) +1.)/2.
            #define DELTA 0.0001

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

            float smin( float a, float b, float k )
            {
                float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
                return lerp( b, a, h ) - k*h*(1.0-h);
            }

            float smax( float a, float b, float k )
            {
                float h = clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
                return lerp( a, b, h ) + k*h*(1.0-h);
            }

            float mod(float x , float y)
            {
                return x - y * floor(x / y);
            }

            float2 mod(float2 x , float2 y)
            {
                return x - y * floor(x / y);
            }

            float2 RepLim( float2 p, float s, float2 l )
            {
                return p-s*clamp(round(p/s),-l,l);
            }

            float RepLim( float p, float s, float l )
            {
                return p-s*clamp(round(p/s),-l,l);
            }

            float ssphere(float3 p,float3 scale,float s)
            {
                return (length(p/scale)-s)*min(scale.x,min(scale.y,scale.z));
            }

            float sscube(float3 p,float3 s)
            {
                p = abs(p) - s;
                return max(max(p.z,p.y),p.x);
            }

            float dispacement(float3 p)
            {
                return sin(p.x*20.)*sin(p.y*20.)*sin(p.z*20.);
            }

            float c(float x, float f)
            {
                return x - (x - x * x) * -f;
            }

            float rand(float2 co){
                return frac(sin(dot(co.xy ,float2(12.9898,78.233))) * 43758.5453);
            }

            float vnoise(float2 p )
            {
                 float2 i = floor( p );
                 float2 f = frac( p );
                
                 float2 u = f*f*(3.0-2.0*f);

                return lerp( lerp( rand( i +  float2(0.0,0.0) ), 
                                rand( i +  float2(1.0,0.0) ), u.x),
                            lerp( rand( i +  float2(0.0,1.0) ), 
                                rand( i +  float2(1.0,1.0) ), u.x), u.y);
            }

            float2 random2(float2 c) {
                float j = 4096.0*sin(dot(c,float3(17.0, 59.4, 15.0)));
                float2 r;
                r.x = frac(512.0*j);
                j *= .125;
                r.y = frac(512.0*j);
                return r-0.5;
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

            float perlinNoise(float2 st) 
            {
                float2 p = floor(st);
                float2 f = frac(st);
                float2 u = f*f*(3.0-2.0*f);

                float v00 = rand(p+float2(0,0));
                float v10 = rand(p+float2(1,0));
                float v01 = rand(p+float2(0,1));
                float v11 = rand(p+float2(1,1));

                return lerp( lerp( dot( v00, f - fixed2(0,0) ), dot( v10, f - fixed2(1,0) ), u.x ),
                             lerp( dot( v01, f - fixed2(0,1) ), dot( v11, f - fixed2(1,1) ), u.x ), 
                             u.y)+0.5f;
            }
            
            float fBm (fixed2 st) 
            {
                float f = 0;
                fixed2 q = st;
                [unroll]
                for(int i = 1 ;i < 4;i++){
                    f += perlinNoise(q)/pow(2,i);
                    q = q * (2.00+i/100);
                }

                return f;
            }

            float3 celler2D(float2 i,float2 sepc)
            {
                float2 sep = i * sepc;
                float2 fp = floor(sep);
                float2 sp = frac(sep);
                float dist = 5.;
                float2 mp = 0.;

                [unroll]
                for (int y = -1; y <= 1; y++)
                {
                    [unroll]
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 pos = float2(random2(fp+neighbor));
                        pos = sin( (pos*6. +_Time.y/2.) )* 0.5 + 0.5;
                        float divs = length(neighbor + pos - sp);
                        mp = (dist >divs)?pos:mp;
                        dist = (dist > divs)?divs:dist;
                    }
                }
                return float3(mp,dist);
            }
            
            float4 celler3D(float3 i,float3 sepc)
            {
                float3 sep = i * sepc;
                float3 fp = floor(sep);
                float3 sp = frac(sep);
                float dist = 5.;
                float3 mp = 0.;

                [unroll]
                for (int z = -1; z <= 1; z++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        [unroll]
                        for (int x = -1; x <= 1; x++)
                        {
                            float3 neighbor = float3(x, y ,z);
                            float3 pos = float3(random33(fp+neighbor));
                            pos = sin( (pos*6. +_Time.y/2.) )* 0.5 + 0.5;
                            float divs = length(neighbor + pos - sp);
                            mp = (dist >divs)?pos:mp;
                            dist = (dist > divs)?divs:dist;
                        }
                    }
                }
                return float4(mp,dist);
            }

            
            float2 Polar(float2 i)
            {
                float2 pl = 0.;
                pl.y = sqrt(i.x*i.x+i.y*i.y)*2+1;
                pl.x = atan2(i.y,i.x)/acos(-1.);
                return pl;
            }
            
            float2x2 rot(float a)
            {
                return float2x2(cos(a),sin(a),-sin(a),cos(a));
            }

            float eq(float a, float b)
            {
                return 1. - abs(sign(a - b));
            }

            struct data{
                float d; //distance
                float m; //material
                float p; //parts
                float bump; //bump
                float depth; //other
            };


            data Fish(float3 p,float scale)
            {
                p = p/scale;
                data o = (data)100;
                o.m = FISH;
                p.z += sin(_Time.y + p.x * 7.)/25.; // swim
                float3 body = p;
                float3 spscale = float3(0.6,.3,1.11);
                spscale.z -= clamp(pow(1./(p.x+1.),0.17),0,1.05);
                spscale.y -= clamp(frac(-p.x + .5) * frac(-p.x + .5) /3,0.,0.2 );

                o.d = ssphere(body,spscale ,0.3);
                o.p = 0.;
                float3 erap = p;
                erap.z = -abs(erap.z);
                erap -= float3(.15,-0.01,-0.051) ;
                erap = mul(RotMat(float3(0.,0.5,0.),1.),erap);
                float era = ssphere(erap,float3(0.2,0.3,0.09) ,0.8 );


                float3 facep = p;
                facep.x -= 0.13 ;
                float3 facescale = float3(0.2,0.195,0.11);
                facescale.y -= clamp(frac(p.x * p.x*2.),0.,.09);
                facescale.z -= clamp(p.x * p.x,0.,0.06);
                float face = ssphere(facep,facescale,0.37);
                o.d = max(o.d,-era);
                o.d = min(o.d,face);
                o.p = step(o.d,face);

                //o = (o.d > face)? faced:o;

                float3 eyep = p;
                
                eyep.z = abs(eyep.z);
                eyep -= float3(0.15,0.015,0.026);
                eyep.zy = mul(rot(0.2),eyep.zy);
                float eye = ssphere(eyep,float3(0.5,0.5,0.2),0.03);
                o.d = min(o.d,eye);
                o.p = step(o.d,eye) * 2.;


                float3 bfl = p;
                bfl.xy -= float2(0.01,0.05);
                bfl.xy = mul(rot(0.2),bfl.xy);
                float l = ssphere(bfl,float3(0.2,0.07,0.01),0.51);
                float3 backfin = p;
                backfin.x -= 0.01;
                backfin.y -= 0.06;
                backfin = mul(RotMat(float3(0.,0.,1.),-4*(0.-backfin.x + backfin.y)),backfin);
                backfin.x = RepLim(backfin.x,0.02,4.);
                float bf = ssphere(backfin,float3(0.005,0.13,0.005),0.3); 
                bf = smin(l,bf,0.015);
                o.d =min(o.d,bf);
                o.p = step(o.d,bf) * 3.;

                float3 handp = p;
                handp.z = -abs(handp.z); 
                handp += float3(-0.07,0.04,0.05);
                handp = mul(RotMat(float3(0.1,0.,0.),-UNITY_PI/3.),handp);
                
                handp = mul(RotMat(float3(1,1,1.),-8*(0 - handp.x + handp.y + handp.z)),handp);
                //handp.x = RepLim(handp.x,0.02,2.);
                float hand = ssphere(handp,float3(0.06,0.1,0.03),0.33); 
                o.d = min(o.d,hand) + 0.001;
                o.p = step(o.d,bf) * 4.;
                
                float3 finp = p;
                float3 finscale = float3(0.2,0.6,0.04);
                finscale.x += clamp(finp.y ,-0.09,10.);
                finp = mul(RotMat(float3(0.,0.,1.),-finp.y*4.),finp);
                finp.x += 0.14;
                
                finp.z = abs(finp.z);
                finp.z -= clamp(sin(Polar(finp.xy - float2(0.05,0.)).x*100.)/550.,-.5,0.);
                float fin = ssphere(finp,finscale,0.2); 
                o.d = min(o.d,fin) * scale;
                o.p = step(o.d,fin) * 5.;
                return o ;
            }

            data Kelp(float3 p,float scale,float offset)
            {
                p /= scale;
                data o = (data)100;
                o.m = KELP;

                float time = _Time.y/2. + offset;
                p = mul(RotMat(float3(0.,0.1,0.),(p.y)*10.),p);
                p.xz += float2(sin(p.y*10.+p.x*3.),cos(p.y*10.+p.z*3.))/30.;
                p.xz += float2(sin(p.y* 20. + time ),cos(p.y * 20. + time))/20. * c((p.y + 0.8),-1);
                float3 zikup = p;
                
                zikup.y += 0.05;
                zikup.y = RepLim(zikup.y,0.02,24.);
                float3 zikuscale = float3(0.05,0.25,0.05);

                float ziku = ssphere(zikup,zikuscale,0.3);
                o.d = ziku;
                o.p = 0.; 

                float3 hap = p;
                hap.y = RepLim(hap.y,0.02,24.);
                float3 hascale = float3(0.1,.2,0.04);
                hascale.x += S(p.y*40.)*hascale.x; 
                float ha = ssphere(hap,hascale,0.3);
                o.d = min(ha,o.d);
                o.p = step(o.d,ha);
                o.d *= scale;
                return o;
            }
            
            data Shell(float3 p,float scale)
            {
                p /= scale;
                data o = (data)100;
                o.m = SHELL;
                
                //0~-2
                float oc = c(sin(_Time.y),.3)-1.;

                data shelld = (data)100;
                
                float3 shellpu = p-float3(0.,0.1,0.1);
                //float3 shellscale = float3(.2,.08,.2);
                //shellscale.x = clamp(shellscale.x + c(shellpo.z,-.5),0.1,1.);
                float3 shellscaleu = float3(.2,.08,.2);
                shellscaleu.x = clamp(shellscaleu.x + c(shellpu.z,-.5),0.1,1.);
                shellpu.x = abs(shellpu.x);
                shellpu.xy = mul(rot(UNITY_PI),shellpu.xy);
                
                float3 inspu = shellpu;
                inspu.y += -sin( 60. * Polar(mul(rot(-UNITY_PI/2.),shellpu.xz) - float2(.15,0.)).x ) *0.01;
                float inso = ssphere(inspu + float3(0.,0.04,0.),shellscaleu,0.6);
                
                float3 shellpo = shellpu;
                shellpo.y += sin( 70. * Polar(mul(rot(-UNITY_PI/2.),shellpo.xz) - float2(.15,0.)).x ) *0.01;
                
                shellpo.y = (shellpo.y-0.01);

                shellpu.y = (shellpu.y+0.03);
                
                float shello = ssphere(shellpo,shellscaleu,0.6);
                
                shellpu = mul(RotMat(float3(1.0,.0,.0),oc),shellpu + float3(0.,0.,0.1)) - float3(0.,0.,0.1);
                shellpu.y += sin( 70. * Polar(mul(rot(-UNITY_PI/2.),shellpu.xz) - float2(.15,0.)).x ) *0.01;
                float3 shellscaleo = float3(.2,.08,.2);
                shellscaleo.x = clamp(shellscaleo.x + c(shellpu.z,-.5),0.1,1.);
                float shellu = ssphere(shellpu,shellscaleo,0.6);
                float insu = ssphere(shellpu - float3(0.,0.04,0.),shellscaleo,0.6);
                shello = max(shello,-inso);
                shellu = max(shellu,-insu);

                float shell = min(shello,shellu);
                shelld.d = shell;
                shelld.p = 0;
                
                o = shelld;
                return o;
            }

            data Bubble(float3 p,float scale,float speed)
            {
                p /= scale;
                data o = (data)100.;
                o.m = BUBBLE;
                
                float t = _Time.y/10.;
                
                p.y -= t * speed;
                
                float freq = 3.;
                float id = rand( float2(0.7,0.3) * floor(p.y*freq));
                p.y = (frac(p.y*freq)-.5);
                t += id * 6.;
                
                float onoff = step(0.5,sin(id * UNITY_PI));
                p.xz += float2(1.,-1.) * sin(t + id *3.)/7.;

                float3 bscale = float3(0.1,0.1,0.1)*float3(1.,freq,1.) + dispacement(p/1.1 + _Time.y/10. + id * 6.)/50.;
                float  s = 0.5 - S(id * 10.) * 0.3;
                s *= onoff;
                o.d = ssphere(p,bscale,s) * scale;
                return o;
            }

            data comp(data a,data b)
            {
                data o;
                o = a;
                o.d = min(a.d,b.d);
                o.m = eq(a.d,o.d) * a.m + eq(b.d,o.d) * b.m;
                o.p = eq(a.d,o.d) * a.p + eq(b.d,o.d) * b.p;
                return o;
            }

            data map(float3 p)
            {
                //p.zy = mul(rot(-UNITY_PI/2.),p.zy);
                float3 sand = p;
                float3 fish = p;
                float3 kelp = p;
                float3 shellp = p;
                float3 bubble = p;
                float scale = _FishScale;
                float kelpScale = _KelpScale;
                float ShellScale = .8;
                float bubbleScale = 1.;

                data o = (data)100;
                sand.y += 0.7;
                sand.y += (0.5-vnoise(sand.xz * 3.))/10.;
                sand.y += (0.7-vnoise(sand.xz * 6.))/10.;
                sand.y += (0.7-vnoise(sand.xz * 500.))/200.;
                //sand.y += (0.5 - vnoise(float2(-1.6,1.) * vnoise(float2(1.,-1.5) * vnoise(sand.xz*10. +_Time.y * float2(1.,0.)) )))/1.;
               // sand.y += simplex3d(sand.xyz);
                o.d = sscube(sand,float3(10.,0.3,10.));


                float2 id = floor(fish.xy);
               // fish.y += (rand(id)-0.5);
                //fish.xz = mod(fish.xz,1.) - 0.5;
                //fish.x += + _Time.y/3.;
           //     fish = mul(RotMat(float3(0.,1.,0.),-_Time.y/3.),fish)- float3(0.,0.,0.6);
                
                data fishd = Fish(fish,scale);

                data kelpd = (data)100;
                float ofs = rand(floor(kelp.xz/.3)) * 15.*0.;

                //kelp.xz = mod(kelp.xz,.3) - 0.15;
                //kelp.xz = sin(kelp.xz);
                kelp.y += 0.4;
                kelp.y -= _KelpScale/2.;
                kelp.z += 1.2;
                kelpd = Kelp(kelp,kelpScale ,ofs);
                
                //kelpd.d = (ofs > 10) * kelpd.d + (ofs < 10) * 100.;
                //o = (o.d < kelpd.d)?o:kelpd;
                
                data shelld = (data)100;
                shellp.y += 0.5;
                shelld = Shell(shellp,ShellScale);

                data bubbled = (data)100.;
                bubbled = Bubble(bubble,bubbleScale,1.1);

                o = comp(o,fishd);
                o = comp(o,kelpd);
                o = comp(o,shelld);
                o = comp(o,bubbled);
                

                return o;
            }

            float3 calcNormal(float3 p)
            {
                float2 e = float2(0.001,0.);
                return normalize(map(p).d - float3(map(p - e.xyy).d,map( p - e.yxy).d,map( p - e.yyx).d));
            }

            bool bindbox(float3 p)
            {
                return all(max(0.5 - abs(p),float3(0.,0.,0.)));
            }

            data marching(float3 ro,float3 rd)
            {
                float depth = 0.0;
                for(int i = 0 ; i< 90; i++)
                {
                    float3 rp = ro + rd * depth;
                    data d = map(rp);
                    if(d.d < DELTA + depth/1000.)
                    {
                        d.d = 1.0;
                        d.depth = depth;
                        return d;
                    }
                    if(d.d > 10.){break;}
                    depth += d.d;
                }
                data o = (data)-1.;
                o.depth = depth;
                return o;
            }

            float wsurf(float3 p,float3 n)
            {
                float up = saturate(dot(n,float3(0.,1.,0.)));
                p.xz += fBm(p.xz*2. + _Time.y/10.);
                //float wsurfray = clamp( celler2D(p.xz,6.).z,0.5,1.) * 2.;
                float wsurfray = clamp( celler3D(float3(p.x,1.,p.z),6.).w,0.5,1.) * 2.;
                return wsurfray * smoothstep(0.,1.,c(up,1.));  
            }

            float3 bg(float3 d)
            {
                float up = saturate(dot(d,float3(0.,1.,0.)));
                return up;
            }

            float3 render(data d,float3 ro,float3 rd,float3 cd)
            {
                float3 color = .3;
                float3 p = rd * d.depth + ro;
                float3 sun = normalize(float3(0.2,0.4,0.8));
                float3 normal = calcNormal(ro + rd * d.depth);
                float3 r = reflect(rd,normal); 
                float3 view = saturate(dot(cd,normal));
                
                float surf = wsurf(p,normal);
                float3 shadowray = normalize( sun -  p * (surf - .25));
                data sh = marching(p,shadowray);
                float shadow = sh.depth;
                
                float softshadow = lerp(smoothstep(0.,1.,shadow),1.,.0);
                
                float diff = 0.5 + 0.5 * saturate(dot(sun,normal));
                
                color *= diff * softshadow;
                color += surf/2. * float3(.5,1.,1.) ;
                //color = softshadow;
                //color = normal;
                return color;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 ro = i.ro;
                float3 rd = normalize(i.surf - ro);
                float3 cd = -UNITY_MATRIX_V[2].xyz;

                float3 color = 0;
                data d = marching(ro,rd);
                
                clip(d.d);
                if(abs(d.d) > 0)
                {
                    color = render(d,ro,rd,cd);
                }
                return float4(color,1);
            }
            ENDCG
        }
    }
}
