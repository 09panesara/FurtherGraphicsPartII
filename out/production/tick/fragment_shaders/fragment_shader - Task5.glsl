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


float torus(vec3 p, vec3 center, float majorR, float minorR) {
     p = p - center;
     vec3 rotatedP = vec3(p.x, p.z, p.y);
     return length(vec2(length(rotatedP.xz) - majorR, rotatedP.y)) - minorR;
}


float fScene(vec3 p) {
    return torus(p, vec3(0, 3, 0), 3.0, 1.0);
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