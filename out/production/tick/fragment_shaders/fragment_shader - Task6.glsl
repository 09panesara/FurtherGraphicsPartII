#version 330

uniform vec2 resolution;
uniform float currentTime;
uniform vec3 camPos;
uniform vec3 camDir;
uniform vec3 camUp;
uniform sampler2D tex;
uniform bool showStepDepth;

in vec3 pos;

out vec3 color;

#define PI 3.1415926535897932384626433832795
#define RENDER_DEPTH 800
#define CLOSE_ENOUGH 0.00001

#define BACKGROUND -1
#define BALL 0
#define BASE 1

#define GRADIENT(pt, func) vec3(func(vec3(pt.x + 0.0001, pt.y, pt.z)) - func(vec3(pt.x - 0.0001, pt.y, pt.z)), func(vec3(pt.x, pt.y + 0.0001, pt.z)) - func(vec3(pt.x, pt.y - 0.0001, pt.z)), func(vec3(pt.x, pt.y, pt.z + 0.0001)) - func(vec3(pt.x, pt.y, pt.z - 0.0001)))

const vec3 LIGHT_POS[] = vec3[](vec3(5, 18, 10));

///////////////////////////////////////////////////////////////////////////////

vec3 getBackground(vec3 dir) {
  float u = 0.5 + atan(dir.z, -dir.x) / (2 * PI);
  float v = 0.5 - asin(dir.y) / PI;
  vec4 texColor = texture(tex, vec2(u, v));
  return texColor.rgb;
}

vec3 getRayDir() {
  vec3 xAxis = normalize(cross(camDir, camUp));
  return normalize(pos.x * (resolution.x / resolution.y) * xAxis + pos.y * camUp + 5 * camDir);
}

///////////////////////////////////////////////////////////////////////////////


float blend(float a, float b) {
 float k = 0.2;
 float h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1);
 return mix(b, a, h) - k * h * (1 - h);
}


float sphere(vec3 pt, vec3 center) {
  return length(pt - center) - 1;
}

float cube(vec3 p, vec3 dim, vec3 center) {
  vec3 d = abs(p - center) - dim;
  return min(max(d.x,
  max(d.y, d.z)), 0.0)
  + length(max(d, 0.0));
}

float torus(vec3 p, float majorR, float minorR) {
     return length(vec2(length(p.xz) - majorR, p.y)) - minorR;
}


float fScene(vec3 p) {
    p = vec3(mod(p.x - 4, 8) - 4, p.y, mod(p.z, 8)); // repeating with distance 8 units separating centers

    vec3 p_hor = vec3(p.x, p.y, p.z - 4); // horixontal XZ centered (0, 0, 4)
    vec3 p_v1 = vec3(p.x + 4, p.z - 4, p.y); // upright YZ
    vec3 p_v2 = vec3(p.x - 4, p.z - 4, p.y); // upright YZ
    vec3 p_v3 = vec3(p.y, p.x, p.z); // upright tori XY centered (0, 0, 0)
    vec3 p_v4 = vec3(p.y, p.x, p.z - 8);

    float majorR = 3;
    float minorR = 0.5;

    return min(torus(p_hor, majorR, minorR), min(torus(p_v1, majorR, minorR), min(torus(p_v2, majorR, minorR), min(torus(p_v3, majorR, minorR), torus(p_v4, majorR, minorR)))));
}



bool isOnPlane(vec3 pt) {
    return (pt.y > -1 - CLOSE_ENOUGH && pt.y < -1 + CLOSE_ENOUGH);
}

vec3 getNormal(vec3 pt) {
  if (isOnPlane(pt)) return vec3(0,1,0);
  return normalize(GRADIENT(pt, fScene));
}

vec3 getColor(vec3 pt) {
  if (isOnPlane(pt)) {
    float distance = fScene(pt);
    if (mod(distance, 5) > 4.75) return vec3(0,0,0); // in every 5 units of distance, texture should show clear black line 0.35 units wide
    return mix(vec3(0.4,1,0.4), vec3(0.4,0.4,1), mod(distance,1));
  }
  return vec3(1);
}

///////////////////////////////////////////////////////////////////////////////

float softShadow(vec3 pt, vec3 lightPos) {
 vec3 lightDir = normalize(lightPos - pt);
 float kd = 1;
 int step = 0;

 for (float t = 0.1; t < length(lightPos - pt) && step < RENDER_DEPTH && kd > 0.001; ) {
     float d = abs(fScene(pt + t * lightDir));

     if (d < 0.001) {
        kd = 0;
     } else {
        kd = min(kd, 16 * d / t);
     }
     t += d;
     step++;
 }

 return kd;
}

float shade(vec3 eye, vec3 pt, vec3 n) {
  float val = 0;

  val += 0.1;  // ambient

  for (int i = 0; i < LIGHT_POS.length(); i++) {
    vec3 l = normalize(LIGHT_POS[i] - pt);
    vec3 lightPos = LIGHT_POS[i];
    float kd = softShadow(pt, lightPos);
    float diffuse = kd * max(dot(n, l), 0); // diffuse component
    int specularShininess = 256;
    vec3 r = 2 * dot(n, l) * n - l;
    val = 0.1 + diffuse +  pow(max(dot(r, normalize(eye-pt)), 0), specularShininess); // max with 0 is more computationally efficient
  }
  return val;
}

vec3 illuminate(vec3 camPos, vec3 rayDir, vec3 pt) {
  vec3 c, n;
  n = getNormal(pt);
  c = getColor(pt);
  return shade(camPos, pt, n) * c;
}

///////////////////////////////////////////////////////////////////////////////

vec3 raymarch(vec3 camPos, vec3 rayDir) {
  int step = 0;
  float t = 0;


  for (float d = 1000; step < RENDER_DEPTH && abs(d) > CLOSE_ENOUGH; t += abs(d)) {
    vec3 pt = camPos + t * rayDir;
    d = min(pt.y + 1, fScene(pt)); // compute union here as want plane to be separate of rest of geometry
    step++;
  }


  if (step == RENDER_DEPTH) {
    return getBackground(rayDir);
  } else if (showStepDepth) {
    return vec3(float(step) / RENDER_DEPTH);
  } else {
    return illuminate(camPos, rayDir, camPos + t * rayDir);
  }
}

///////////////////////////////////////////////////////////////////////////////

void main() {
  color = raymarch(camPos, getRayDir());
}