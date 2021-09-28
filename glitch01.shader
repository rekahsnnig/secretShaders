Shader "Unlit/glitch01"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float random (in float2 st) {
                return frac(sin(dot(st.xy,
                                    float2(12.9898,78.233)))*
                    43758.5453123);
            }

            // Based on Morgan McGuire @morgan3d
            // https://www.shadertoy.com/view/4dS3Wd
            float noise (in float2 st) {
                float2 i = floor(st);
                float2 f = frac(st);

                // Four corners in 2D of a tile
                float a = random(i);
                float b = random(i + float2(1.0, 0.0));
                float c = random(i + float2(0.0, 1.0));
                float d = random(i + float2(1.0, 1.0));

                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(a, b, u.x) +
                        (c - a)* u.y * (1.0 - u.x) +
                        (d - b) * u.x * u.y;
            }

            #define OCTAVES 2
            float fbm (in float2 st) {
                // Initial values
                float value = 0.0;
                float amplitude = .5;
                float frequency = 0.;
                //
                // Loop of octaves
                for (int i = 0; i < OCTAVES; i++) {
                    value += amplitude * noise(st);
                    st *= 2.;
                    amplitude *= .5;
                }
                return value;
            }

            float3 shiftRGB(float2 uv,float shift)
            {
                uv += float2(1.,0.) * shift;
                float r = tex2D(_MainTex,uv ).r;
                uv += float2(1.,0.) * shift * random(uv);
                float g = tex2D(_MainTex,uv ).r;
                uv += float2(1.,0.) * shift;
                float b = tex2D(_MainTex,uv ).r;
                return float3(r,g,b);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float th = step(.8, random(floor(uv.y * lerp(100.,10.,random(floor(uv * float2(.5,1.) * 70.  )) ) + floor(sin(sin(_Time.y*2. + floor(sin(uv.y * 6.) * 40.) ))) ) ));
                uv.x += th * random( floor(uv.y * 10. + floor(frac(_Time.y * .8 + random(floor(uv.y * 100.) ) )*3.134) * 10.) )/35.;
                
                fixed4 color = tex2D(_MainTex, uv);
                uv = floor(uv * float2(10.,100.)) / float2(10.,100.);
                
                uv += float2(random(floor(i.uv * 10. + sin(uv * 10.) * 10.) ),random(uv) )/10.;
                float t = random(float2(1.,1.) * floor(_Time.y + random(uv + _Time.y) * 10.));
                float fbmnoise = fbm(uv * 10. + t * 100. + uv.y + _Time.y);
                uv.x += step(fbmnoise , .3) * fbmnoise/100.;
                if(fbmnoise < th)
                {
                    uv.x += noise(float2(1,1) * _Time.z * 10.)/60.;
                    color.rgb = shiftRGB(uv,0.02 * fbmnoise);
                }
                return color;
            }
            ENDCG
        }
    }
}
