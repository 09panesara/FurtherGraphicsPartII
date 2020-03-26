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


float fScene(vec3 p) {
     vec3 dim = vec3(1, 1, 1);
     float cube1 = cube(p, dim, vec3(-3, 0, -3));
     float sphere1 = sphere(p, vec3(-2, 0, -2));

     float cube2 = cube(p, dim, vec3(3, 0, -3));
     float sphere2 = sphere(p, vec3(4, 0, -2));

     float cube3 = cube(p, dim, vec3(-3, 0, 3));
     float sphere3 = sphere(p, vec3(-2, 0, 4));

     float cube4 = cube(p, dim, vec3(3, 0, 3));
     float sphere4 = sphere(p, vec3(4, 0, 4));

     float uni = min(cube1, sphere1);
     float diff = max(cube2, -sphere2);
     float intersection = max(cube4, sphere4);


     return min(uni, min(diff, min(blend(cube3, sphere3), intersection)));

}



bool isOnPlane(vec3 pt) {
    return (pt.y > -1 + CLOSE_ENOUGH && pt.y < -1 - CLOSE_ENOUGH);
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

float shade(vec3 eye, vec3 pt, vec3 n) {
  float val = 0;

  val += 0.1;

  for (int i = 0; i < LIGHT_POS.length(); i++) {
    vec3 l = normalize(LIGHT_POS[i] - pt);
    val += max(dot(n, l), 0);
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