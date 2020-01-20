Shader "Unlit/fish"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));
                o.surf = v.vertex;
                return o;
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

            float dispacement(float3 p)
            {
                return sin(p.x*20.)*sin(p.y*20.)*sin(p.z*20.);
            }

            struct data{
                float d;
                float info;
            };

            data Fish(float3 p,float scale)
            {
                data o;
                 p.z += sin(_Time.y + p.x * 7.)/25.; // swim
                float3 body = p;
                float3 spscale = float3(0.6,.3,1.11);
                spscale.z -= clamp(pow(1./(p.x+1.),0.17),0,1.05);
                spscale.y -= clamp(frac(-p.x + .5) * frac(-p.x + .5) /3,0.,0.2 );

               // spscale.z -= (p.x < 0.1 + abs(p.y*p.y)) * (p.x > 0.09 + abs(p.y*p.y))/10.*saturate(-(p.y)*2.+.3);

                o.d = ssphere(body,spscale*scale,0.3 * scale);
                float3 erap = p;
                erap.z = -abs(erap.z);
                erap -= float3(.15,-0.01,-0.051);
                erap = mul(RotMat(float3(0.,0.5,0.),1.),erap);
                float era = ssphere(erap,float3(0.2,0.3,0.09),0.8);


                float3 facep = p;
                facep.x -= 0.13;
              //  facep = mul(RotMat(float3(0.,0.1,0.13),-0.2),facep);
                float3 facescale = float3(0.2,0.195,0.11);
                facescale.y -= clamp(frac(p.x * p.x*2.),0.,.09);
                facescale.z -= clamp(p.x * p.x,0.,0.06);
                float face = ssphere(facep,facescale * scale,0.37);
                o.d = max(o.d,-era);
                o.d = min(o.d,face);
                o.info = 1;

                float3 eyep = p;
                
                eyep.z = abs(eyep.z);
                eyep -= float3(0.15,0.015,0.03);
                float eye = ssphere(eyep,0.5,0.03 * scale);
                o.d = min(o.d,eye);

                float3 backfin = p;
                backfin.x -= 0.01;
                backfin.y -= 0.06;
                backfin = mul(RotMat(float3(0.,0.,1.),-4*(0.-backfin.x + backfin.y)),backfin);
                backfin.x = RepLim(backfin.x,0.02,4.);
                //p-c*clamp(round(p/c),-l,l);
                //backfin.x = mod(backfin.x,0.014) - 0.007;
                float bf = ssphere(backfin,float3(0.011,0.27,0.011)*scale,0.3); 
                o.d =min(o.d,bf);

                float3 handp = p;
                handp.z = -abs(handp.z); 
                handp.z += 0.05; 
                handp.x -= 0.07;
                handp.y += 0.04;
                handp = mul(RotMat(float3(0.1,0.,0.),-UNITY_PI/3.),handp);
                
                handp = mul(RotMat(float3(1,1,1.),-8*(0 - handp.x + handp.y + handp.z)),handp);
                //handp.x = RepLim(handp.x,0.02,2.);
                float hand = ssphere(handp,float3(0.06,0.1,0.03)*scale,0.33); 
                o.d = min(o.d,hand) + 0.001;
                
                float3 finp = p;
                float3 finscale = float3(0.2,0.6,0.03);
                //finscale.y = clamp(finp.y,-.1,1.);
                finscale.x += clamp(finp.y ,-0.09,10.);
                finp = mul(RotMat(float3(0.,0.,1.),-finp.y*4.),finp);
                finp.x += 0.14;

                float fin = ssphere(finp,finscale*scale,0.2); 
                o.d = min(o.d,fin);
                return o ;
            }

            data map(float3 p)
            {
                float3 fish = p;
                float scale = 1.;
                data o;
                o = Fish(fish,scale);
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
                    if(d.d < 0.001)
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
