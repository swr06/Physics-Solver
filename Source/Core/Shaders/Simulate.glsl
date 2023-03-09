#version 450 core 

#define PI 3.14159265359 

layout(local_size_x = 16, local_size_y = 1, local_size_z = 1) in;
layout(rgba16f, binding = 0) uniform image2D o_OutputData;

uniform float u_Dt;
uniform float u_Time;
uniform int u_ObjectCount;

struct Object {
	vec2 Position;
	vec2 Velocity; 
	vec2 Force;
	vec2 MassRadius;
};

layout (std430, binding = 0) buffer ObjectSSBO {
	Object SimulationObjects[];
};

float remap(float x, float a, float b, float c, float d)
{
    return (((x - a) / (b - a)) * (d - c)) + c;
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

void ApplyConstraint(inout Object object) {
	float CoefficientOfRestitution = 0.9f;
	vec2 ToObject = object.Position.xy - vec2(0.0f);
	float Length = length(ToObject);
	vec2 Normal = ToObject / Length;

	float ConstrainingRadius = 350.0f - object.MassRadius.y;

	if (Length > ConstrainingRadius) {
		vec2 RelativeVelocity = object.Velocity - vec2(0.0f); // The constraining sphere remains at rest 
		object.Position.xy -= -Normal * (ConstrainingRadius - Length);
		object.Velocity.xy += -Normal * max(dot(Normal, RelativeVelocity) * CoefficientOfRestitution, 0.0f); // impulse only depends on velocity 
	}

}

const vec2 G = vec2(0.0f, -9.8f) * 400.0f;

void main() {

	int Index = int(gl_GlobalInvocationID.x);

	if (Index > u_ObjectCount) {
		return;
	}

	float dt = u_Dt;

	Object CurrentObject = SimulationObjects[Index];
	Object Unupdated = SimulationObjects[Index];
	
	CurrentObject.Force += CurrentObject.MassRadius.x * G;
	CurrentObject.Velocity += (CurrentObject.Force / CurrentObject.MassRadius.x) * dt;
	CurrentObject.Position += CurrentObject.Velocity * dt;
	CurrentObject.Force = vec2(0.0f);
	
	ApplyConstraint(CurrentObject);

	SimulationObjects[Index] = CurrentObject;
}
