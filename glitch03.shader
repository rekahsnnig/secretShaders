Shader "Unlit/glitch03"
{
    Properties
    {
        _Mask("_Mask",float) = 0
        [Toggle]_Bilboard("Bill board" , float)= 1
        _Fine("Fine",float) = 5
        _MainTex ("Texture", 2D) = "white" {}
        _Seed("Seed",float) = 123.45
    }
    SubShader
    {
        //Tags{ "RenderType" = "Transparent" "Queue" = "Transparent" }
        
        //GrabPass{"_MainTex"}
        ZTest off
        Tags 
        { 
            "RenderType" = "Opaque"
            "Queue" = "AlphaTest" 
        }

        Stencil 
        {
            Ref [_Mask]
            Comp Equal
        }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            //sampler2D _MainTex;
            //float4 _MainTex_ST;
            float4 _MainTex_ST;
            float _Fine;
            float _Seed;
            float _Bilboard;
            
            float Sq_distanse(float2 IN,float2 dotpos,float offset)
            {
                //オフセットを引数として渡している　それを加算して適した位置に原点を持ってくる
                IN += offset; 
                dotpos += offset;
                //四角形の関数で入力されたUV座標の点がどれだけの大きさの四角形の輪郭にのっているかを出す
                float indis = abs(IN.x + IN.y)+abs(IN.x - IN.y); 
                float uv_dotdis = abs(dotpos.x + dotpos.y)+abs(dotpos.x - dotpos.y);
                //一ドットを九つに区切ったものが入力されているが、果たしてこの入力点はどこに属するものなのかって　見る
                return step(indis,uv_dotdis);
            }            
            float sum3x3(float3x3 col,float3x3 dis){ //入力された行列の全要素をかけて足す
               return col._m00 * dis._m00 + 
                      col._m01 * dis._m01 + 
                      col._m02 * dis._m02 + 
                      col._m10 * dis._m10 + 
                      col._m11 * dis._m11 + 
                      col._m12 * dis._m12 + 
                      col._m20 * dis._m20 + 
                      col._m21 * dis._m21 + 
                      col._m22 * dis._m22;
            }
            
            float sum_sum3x3(float3x3 col){ //入力された行列の全要素をかけて足す
               return col._m00 + 
                      col._m01 + 
                      col._m02 + 
                      col._m10 + 
                      col._m11 + 
                      col._m12 + 
                      col._m20 + 
                      col._m21 + 
                      col._m22 ;
            }

            float random (in float2 st) {
                return frac(sin(dot(_Seed+st.xy,
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
                float2 dir = float2(1.,.03) * sign(sin(_Seed+_Time.z));
                //uv += dir * shift;
                float r = tex2D(_MainTex,uv ).r;
                uv += dir * shift ;
                float g = tex2D(_MainTex,uv ).g;
                uv += dir * shift;
                float b = tex2D(_MainTex,uv ).b;
                return float3(r,g,b);
            }

            float3 laplacian(float2  uv ,float Fine)
            {
                fixed4 col;
                col = tex2D(_MainTex,uv);
                
                float2 in_uv = uv;
                //座標を_Fineの値に応じて粗くする->ドット調になる
                float2 grab_uv = float2(floor(in_uv * Fine)/Fine);
                in_uv -= grab_uv;      //位置合わせ
                float pix = 1/_Fine; //どれだけの幅を1pixelとみなすか
                float pi = 3.141592;
                
                float Point = step( float(abs( sin((grab_uv.x ) * (Fine * (pi))) ) 
                                   * abs( sin((grab_uv.y ) * (Fine * (pi)))) ),sqrt(0));//0.25にすると一つの円の半径を0.5まで認めることになる
                

                float3x3 Laplacian4 = float3x3(0,1,0,1,-4,1,0,1,0);//四近傍
                float3x3 Laplacian8 = float3x3(1,1,1,1,-8,1,1,1,1);//八近傍

                float3x3 Laplas = Laplacian4;//今は四近傍を使用中
                
                //九つの上一列
                //〇〇〇
                //------
                //------
                float2 a_uv = float2(-pix,-pix);
                float2 b_uv = float2(0,-pix);
                float2 c_uv = float2(+pix,-pix);

                //九つの真ん中一列
                //------
                //〇〇〇
                //------
                float2 d_uv = float2(-pix,0);
                float2 e_uv = float2(0,0);
                float2 f_uv = float2(+pix,0);

                //九つの一番下一列
                //------
                //------
                //〇〇〇
                float2 g_uv = float2(-pix,+pix);
                float2 h_uv = float2(0,+pix);
                float2 i_uv = float2(+pix,+pix);

                //それぞれの中心点の色
                fixed4 a = tex2D(_MainTex, grab_uv+a_uv);
                fixed4 b = tex2D(_MainTex, grab_uv+b_uv);
                fixed4 c = tex2D(_MainTex, grab_uv+c_uv);
                
                fixed4 d = tex2D(_MainTex,grab_uv+d_uv);
                fixed4 e = tex2D(_MainTex,grab_uv+e_uv);
                fixed4 f = tex2D(_MainTex,grab_uv+f_uv);
               
                fixed4 g = tex2D(_MainTex,grab_uv+g_uv);
                fixed4 h = tex2D(_MainTex,grab_uv+h_uv);
                fixed4 i = tex2D(_MainTex,grab_uv+i_uv);
                
                //色成分ごとに3x3行列を作る
                float3x3 red =   float3x3(a.r, b.r, c.r, d.r , e.r, f.r, g.r, h.r, i.r);
                float3x3 green = float3x3(a.g, b.g, c.g, d.g , e.g, f.g, g.g, h.g, i.g);
                float3x3 blue =  float3x3(a.b, b.b, c.b, d.b , e.b, f.b, g.b, h.b, i.b);
                //全要素にstep(点,辺の長さ)をかけて全部加算
                //ある点がある四角から遠いのであればstep()は0を返す
                //step() * COLOR stepが0のときにこれを足したとしても値は増えない　結果的にその点が所属している四角形の中心の点の色だけ残る
                float3x3 red_mul = mul(Laplas,red);
                float3x3 green_mul = mul(Laplas,green);
                float3x3 blue_mul = mul(Laplas,blue);
                
                //計算しやすいように距離だけまとめて行列にしておく
                 float3x3 dist = float3x3(Sq_distanse(in_uv,grab_uv,a_uv),Sq_distanse(in_uv,grab_uv,b_uv),Sq_distanse(in_uv,grab_uv,c_uv),
                                          Sq_distanse(in_uv,grab_uv,d_uv),Sq_distanse(in_uv,grab_uv,e_uv),Sq_distanse(in_uv,grab_uv,f_uv),
                                          Sq_distanse(in_uv,grab_uv,g_uv),Sq_distanse(in_uv,grab_uv,h_uv),Sq_distanse(in_uv,grab_uv,i_uv)
                                          );
                //色要素ごとにラプラシアンフィルタをかけていく
                 col.r = sum_sum3x3(red_mul);
                 col.g = sum_sum3x3(green_mul);
                 col.b = sum_sum3x3(blue_mul);
                 //アルファ値はなんとなく平均をとってみた
                 col.a = ((col.r + col.g + col.b) /3);
                
                //なんか色が薄かったので10倍加算して光るようにした　アルファ値は変わらないように0を入れてある
                col += float4(col.xyz * 10,0);

                return col;
            }
            
            float3 zutomayoGlitch(float2 iuv)
            {
                float time = floor(_Time.x * 10.);
                float rand = random(floor(iuv * 10. + floor(_Seed + _Time.y * 2.)));
                fixed4 col = tex2D(_MainTex, iuv);
                float2 uv = iuv;
                col.rgb = shiftRGB(iuv , 0.012 * frac((sin(_Seed+_Time.z/10.) * 1.3) ) );
                //col.rgb = shiftRGB(iuv , 0.01 * frac(noise(_Time.y) / 10. ) * 10. );
                uv = floor(uv * 30.* ( rand ))/10.;

                float r = random(floor(uv * 1000. + _Time.y/10. ));
                float fnoise = fbm(uv * 6. + r);
                float t = step(.01,fnoise);
                t += step(sin(_Seed+_Time.y * 5.),.0);
                float t2 = step(.006,random(uv * 90 + time + sin(time + t) ));
                t2 += step(sin(_Seed+_Time.y * .3 + .7 + uv.y + uv.x * 100.),.5);
                col.rgb = min(t2 * t,1.) * col.rgb;

                return col;
            }

            float3 glitch01(float2 iuv)
            {
                float2 uv = iuv;

               // uv.x += random(floor(uv.y * 2.));

                float th = step(.8, random(floor(uv.y * lerp(100.,10.,random(floor(uv * float2(.5,1.) * 70.  )) ) + floor(sin(sin(_Time.y*2. + floor(sin(uv.y * 6.) * 40.) ))) ) ));
                uv.x += th * random( floor(uv.y * 10. + floor(frac(_Time.y * .8 + random(floor(uv.y * 100.) ) )*3.134) * 10.) )/35.;
                
                fixed4 color = tex2D(_MainTex, uv);
                uv = floor(uv * float2(10.,100.)) / float2(10.,100.);
                
                uv += float2(random(floor(uv * 10. + sin(uv * 10.) * 10.) ),random(uv) )/10.;
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

            float3 rgb2hsv(float3 hsv)
            {
                float h = hsv.x;
                float s = hsv.y;
                float v = hsv.z;
                return ((clamp(abs(frac(h+float3(0,2,1)/3.)*6.-3.)-1.,0.,1.)-1.)*s+1.)*v;
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
            
            
            v2f vert (appdata v)
            {
                v2f o;

                // v.vertex .y += tan(_Time.y/2. + _Seed);
                // v.vertex.zx += tan(sin(_Time.y /4.+ _Seed) * UNITY_PI + _Seed);

                float fnoise = fbm(_Seed + _Time.y/3.);
                float fnoise2 = fbm(_Seed * 1.45 + _Time.y/6.);
                float fnoise3 = fbm(_Seed * 3.4 + _Time.y/10.);
                float3 pos = v.vertex.xyz;
                float rand = random(_Seed);
                
                //pos.xyz = mul( RotMat(float3(0.,0.,1.) , _Seed + _Time.y/((rand + .1) * 30.) + _Seed) * sign(rand - .1) ,pos );
                pos.y += (fnoise-.5) * .7;
               // pos.x += sin(fnoise * UNITY_PI + _Seed)/1.; 
                pos.x += (fnoise2 - .5) * .4;
                pos.z += (fnoise3 - .5) * .6;
                v.vertex.xyz = pos;
                //v,vertex 
                if(_Bilboard > 0.)
                {
                    // Meshの原点をModelView変換
                    float3 viewPos = UnityObjectToViewPos(float3(0, 0, 0));
                    
                    // スケールと回転（平行移動なし）だけModel変換して、View変換はスキップ
                    float3 scaleRotatePos = mul((float3x3)unity_ObjectToWorld, v.vertex);
                    
                    // scaleRotatePosを右手系に変換して、viewPosに加算
                    // 本来はView変換で暗黙的にZが反転されているので、
                    // View変換をスキップする場合は明示的にZを反転する必要がある
                    viewPos += float3(scaleRotatePos.xy, -scaleRotatePos.z);
                    
                    o.vertex = mul(UNITY_MATRIX_P, float4(viewPos, 1));
                }else{
                    o.vertex = UnityObjectToClipPos(v.vertex);
                }
                
                o.uv = ComputeGrabScreenPos(o.vertex);
                o.uv = float4(v.uv,1,1);
                return o;
            }
            
            

            fixed4 frag (v2f IN) : SV_Target
            {
                float2 uv = IN.uv;
                float r = random(floor(IN.uv * float2(10. , 100.) + random(_Time.y/100. + floor(IN.uv * 10.) ) ));
                r = random(floor(IN.uv * float2(10.,100.)));
                float3 ocol = float3(0.,0.,0.);
                
                float3 laplas = 0;
                //if(r < .1)
                {
                    laplas = laplacian(IN.uv,_Fine * random(_Seed+uv) ) * 10.5;
                    laplas *= float3(0.5,1.,1.);
                   // laplas = pow(laplas,20.) * 10.5;
                }
                float3 inv = 1. - tex2D(_MainTex,uv).xyz;
                float3 zutomayo = zutomayoGlitch(IN.uv);
                float3 g01 = glitch01(IN.uv);

               // ocol = laplas + zutomayo;// + g01;
                ocol =  zutomayo + rgb2hsv(laplas + float3(0.,0.,1.)) * step(length(zutomayo) ,.001);
                ocol =  zutomayo + (laplas) * step(length(zutomayo) ,.001);
                ocol = clamp(ocol.xyz,0.,1.);
                return float4(ocol,1);
            }
            ENDCG
        }
    }
}
