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
                o.ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));
                o.surf = v.vertex;
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

            struct data{
                float d; //distance
                float m; //material
                float bump; //bump
                float info; //other
            };

            data Fish(float3 p,float scale)
            {
                p = p/scale;
                data o = (data)100;
                 p.z += sin(_Time.y + p.x * 7.)/25.; // swim
                float3 body = p;
                float3 spscale = float3(0.6,.3,1.11);
                spscale.z -= clamp(pow(1./(p.x+1.),0.17),0,1.05);
                spscale.y -= clamp(frac(-p.x + .5) * frac(-p.x + .5) /3,0.,0.2 );

                o.d = ssphere(body,spscale ,0.3);
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
                o.info = 1;

                //o = (o.d > face)? faced:o;

                float3 eyep = p;
                
                eyep.z = abs(eyep.z);
                eyep -= float3(0.15,0.015,0.03);
                float eye = ssphere(eyep,0.5,0.03);
                o.d = min(o.d,eye);

                float3 backfin = p;
                backfin.x -= 0.01;
                backfin.y -= 0.06;
                backfin = mul(RotMat(float3(0.,0.,1.),-4*(0.-backfin.x + backfin.y)),backfin);
                backfin.x = RepLim(backfin.x,0.02,4.);
                float bf = ssphere(backfin,float3(0.011,0.27,0.011),0.3); 
                o.d =min(o.d,bf);

                float3 handp = p;
                handp.z = -abs(handp.z); 
                handp += float3(-0.07,0.04,0.05);
                handp = mul(RotMat(float3(0.1,0.,0.),-UNITY_PI/3.),handp);
                
                handp = mul(RotMat(float3(1,1,1.),-8*(0 - handp.x + handp.y + handp.z)),handp);
                //handp.x = RepLim(handp.x,0.02,2.);
                float hand = ssphere(handp,float3(0.06,0.1,0.03),0.33); 
                o.d = min(o.d,hand) + 0.001;
                
                float3 finp = p;
                float3 finscale = float3(0.2,0.6,0.03);
                //finscale.y = clamp(finp.y,-.1,1.);
                finscale.x += clamp(finp.y ,-0.09,10.);
                finp = mul(RotMat(float3(0.,0.,1.),-finp.y*4.),finp);
                finp.x += 0.14;

                float fin = ssphere(finp,finscale,0.2); 
                o.d = min(o.d,fin) * scale;
                return o ;
            }

            data Kelp(float3 p,float scale,float offset)
            {
                p /= scale;
                data o = (data)100;
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

                float3 hap = p;
                hap.y = RepLim(hap.y,0.02,24.);
                float3 hascale = float3(0.1,.2,0.04);
                hascale.x += S(p.y*40.)*hascale.x; 
                float ha = ssphere(hap,hascale,0.3);
                o.d = min(ha,o.d);
                o.d *= scale;
                return o;
            }
            
            data Shell(float3 p,float scale)
            {
                p /= scale;
                data o = (data)100;
                
                data shelld = (data)100;
                
                float3 shellp = p;
                float3 shellscale = float3(.2,.08,.2);
                shellscale.x = clamp(shellscale.x + c(shellp.z,-.5),0.1,1.);
                
                shellp.x = abs(shellp.x);
                
                shellp.xy = mul(rot(UNITY_PI),shellp.xy);
                shellp.y += sin( 70. * Polar(mul(rot(-UNITY_PI/2.),shellp.xz) - float2(.15,0.)).x ) *0.01;
                float shello = ssphere(shellp,shellscale,0.6);
                shellp.y += 0.01;
                
                //shellscale = mul(RotMat(float3(1.,0.,0.),UNITY_PI/2.),shellscale);
                //shellscale = shellscale.xzy;
               // shellscale.yz = abs( mul(rot(UNITY_PI/2.),shellscale.yz) );
               // shellp.yz = abs( mul(rot(-UNITY_PI/2.),shellp.yz) );
              //  shellp = mul(RotMat(float3(1.,0.,0.),UNITY_PI/2.),shellp);
                float shellu = ssphere(shellp,shellscale,0.6);
                float shell = min(shellu,shello);
                
                //shell = max(shell , -ssphere(shellp,1.,0.5));
                shelld.d = shell;
                
                o = shelld;
                return o;
            }

            data map(float3 p)
            {
                float3 fish = p;
                float3 kelp = p;
                float scale = _FishScale;
                float kelpScale = _KelpScale;
                float ShellScale = 1.;
                data o = (data)100;

                float2 id = floor(fish.xy);
               // fish.y += (rand(id)-0.5);
                //fish.xz = mod(fish.xz,1.) - 0.5;
                //fish.x += + _Time.y/3.;
                fish = mul(RotMat(float3(0.,1.,0.),-_Time.y/3.),fish)- float3(0.,0.,0.6);
                
                //o = Fish(fish,scale);

                data kelpd = (data)100;
                float ofs = rand(floor(kelp.xz/.3)) * 15.*0.;

                //kelp.xz = mod(kelp.xz,.3) - 0.15;
                
                //kelpd = Kelp(kelp,kelpScale ,ofs);
                
                //kelpd.d = (ofs > 10) * kelpd.d + (ofs < 10) * 100.;
                //o = (o.d < kelpd.d)?o:kelpd;
                
                data shelld = (data)100;
                float3 shellp = p;
                
                shelld = Shell(shellp,ShellScale);
                if(o.d > kelpd.d)
                {
                    o = kelpd;
                }
                if(o.d > shelld.d)
                {
                    o = shelld;
                }
                return o;
            }

            float3 calcNormal(float3 p)
            {
                float2 e = float2(0.001,0.);
                return normalize(map(p).d - float3(map(p - e.xyy).d,map( p - e.yxy).d,map( p - e.yyx).d));
            }

            float marching(float3 ro,float3 rd)
            {
                float depth = 0.0;
                for(int i = 0 ; i< 99; i++)
                {
                    float3 rp = ro + rd * depth;
                    data d = map(rp);
                    if(d.d < DELTA)
                    {
                        return depth;
                    }
                    depth += d.d;
                }
                return -1;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 ro = i.ro;
                float3 rd = normalize(i.surf - ro);

                float3 color = 0;
                float d = marching(ro,rd);
                
                clip(d);
                if(d > 0)
                {
                    float3 light = normalize(float3(0.2,0.4,0.8));
                    color = 1;
                    float3 normal = calcNormal(ro + rd * d);
                    float diff = 0.5 + 0.5 * saturate(dot(light,normal));
                    color = color * diff;
                   // color = normal;
                }
                return float4(color,1);
            }
            ENDCG
        }
    }
}
