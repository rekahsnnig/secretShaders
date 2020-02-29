Shader "Unlit/umi"
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
            
            #define OCTAVES 4
            #define FAR 1000.

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
            
            float2 rot(float2 p, float a)
            {
                return mul(float2x2(cos(a),sin(a),-sin(a),cos(a)),p);
            }
            
            //http://nn-hokuson.hatenablog.com/entry/2017/01/27/195659#fBmノイズ
             fixed2 random2(fixed2 st){
                st = fixed2( dot(st,fixed2(127.1,311.7)),
                               dot(st,fixed2(269.5,183.3)) );
                return -1.0 + 2.0*frac(sin(st)*43758.5453123);
            }
            
            float c(float x,float f)
            {
                return x - (x - x * x) * -f;
            }
            
            float noise(fixed2 st) 
            {
                fixed2 p = floor(st);
                fixed2 f = frac(st);
                fixed2 u = f*f*(3.0-2.0*f);

                float v00 = random2(p+fixed2(0,0));
                float v10 = random2(p+fixed2(1,0));
                float v01 = random2(p+fixed2(0,1));
                float v11 = random2(p+fixed2(1,1));

                return lerp( lerp( dot( v00, f - fixed2(0,0) ), dot( v10, f - fixed2(1,0) ), u.x ),
                             lerp( dot( v01, f - fixed2(0,1) ), dot( v11, f - fixed2(1,1) ), u.x ), 
                             u.y)+0.5f;
            }
            
            float sea_octave(float2 uv, float choppy)
            {
                uv += noise(uv);        
                float2 wv = 1.0 - abs(sin(uv));
                float2 swv = abs(cos(uv));    
                wv = lerp(wv, swv, wv);
                return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
            }
            
            float wave(float2 p)
            {
                float SEA_TIME = sin(_Time.y); 
                float freq = 0.16; // => 0.16
                float amp = 0.6; // => 0.6
                float choppy = 4.0; // => 4.0

                // XZ plane.
                float2 uv = p.xy;

                float d, h = 0.0;    

                // ITER_GEOMETRY => 3
                for (int i = 0; i < 3; i++)
                {       
                    d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);
                    h += d * amp;
                    uv *= 1.3;
                    freq *= 2.0;
                    amp *= 0.2;
                    choppy = lerp(choppy, 1.0, 0.2);
                }

                return h;
            }

            float map(float3 p)
            {
                 float s = p.y - 1.5;
                 //p.xz += 0.9;
               //  p.xz = float2(sin(Noise(p.xz) * 10. + _Time.x),cos(_Time.y + Noise(p.zx) * 14.));
                 float waves;// = wave(p.xz);
                 waves = noise(p.xz + float2(1,-1) * _Time.y);
                 return s - waves;
            }

            float3 calcNormal(float3 p)
            {
                float2 e = float2(0.001,0.);
                return normalize(map(p) - float3(map(p - e.xyy),map( p - e.yxy),map( p - e.yyx)));
            }

            float marching(float3 ro,float3 rd)
            {
                float hx = map(ro + rd * FAR);
                float tx = FAR;
                if(hx > 0.)
                {
                    return -1;
                }
                float tm = 0.0;
                
                float tmid = 0.;
                float hm = ro;
                
                for(int i = 0 ; i< 8; i++)
                {
                    float f = hm / (hm - hx);
                    
                    tmid = lerp(tm,tx,f);
                    float3 rp = ro + rd * tmid;
                    float hmid = map(rp);
                    if(hmid < 0.)
                    {
                        tx = tmid;
                        hx = hmid;
                    }
                    else
                    {
                        tm = tmid;
                        hm = hmid;
                    }
                }
                return tmid;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 ro = i.ro;
                float3 rd = normalize(i.surf - ro);

                float3 color = 0;
                float d = marching(ro,rd);
                if(d < 0.001)
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
