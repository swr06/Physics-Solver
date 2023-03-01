#version 450 core 

#define PI 3.14159265359 

layout(local_size_x = 16, local_size_y = 1, local_size_z = 1) in;
layout(rgba16f, binding = 0) uniform image2D o_OutputData;

uniform float u_Dt;
uniform float u_Time;

float remap(float x, float a, float b, float c, float d)
{
    return (((x - a) / (b - a)) * (d - c)) + c;
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

void main() {

	int Index = int(gl_GlobalInvocationID.x);
}
