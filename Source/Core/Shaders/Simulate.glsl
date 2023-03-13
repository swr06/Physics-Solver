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
	vec2 Dx;
    vec2 Dv;
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

void Collide(int index, inout Object object, float mult) {
	float CoefficientOfRestitution = 1.0f;

	for (int i = 0 ; i < u_ObjectCount ; i++) {

		if (i == index) {
			continue;
		}

		vec2 ToObject = object.Position.xy - SimulationObjects[i].Position.xy;
		float Length = length(ToObject);
		vec2 Normal = ToObject / Length;

		//float ConstrainingRadius = max(SimulationObjects[i].MassRadius.y, object.MassRadius.y);
		float ConstrainingRadius = max(SimulationObjects[i].MassRadius.y + object.MassRadius.y, 0.);

		if (Length < ConstrainingRadius) {
			vec2 RelativeVelocity = object.Velocity - SimulationObjects[i].Velocity.xy; // The constraining sphere remains at rest 
			vec2 Delta = -Normal * (ConstrainingRadius - Length) * 0.5f * mult;

			// Calculate impulse 
			float ImpluseM = max(dot(Normal, RelativeVelocity) * CoefficientOfRestitution * mult * 1.0f, 0.0f);
			ImpluseM /= (1.0f / object.MassRadius.x) + (1.0f / SimulationObjects[i].MassRadius.x);
			vec2 Impulse = -Normal * ImpluseM;

			object.Dx.xy -= Delta; // constrain position 
			SimulationObjects[i].Dx.xy += Delta; // constrain position 

			object.Dv.xy += Impulse / object.MassRadius.x;
			SimulationObjects[i].Dv.xy += Impulse / SimulationObjects[i].MassRadius.x;
		}
	}
}

void ApplyConstraint(inout Object object, float mult) {
	float CoefficientOfRestitution = 1.0f;
	vec2 ToObject = object.Position.xy - vec2(0.0f);
	float Length = length(ToObject);
	vec2 Normal = ToObject / Length;

	float ConstrainingRadius = 350.0f - object.MassRadius.y;

	if (Length > ConstrainingRadius) {
		vec2 RelativeVelocity = object.Velocity - vec2(0.0f); // The constraining sphere remains at rest 
		object.Dx.xy -= -Normal * (ConstrainingRadius - Length) * mult; // constrain position 
		object.Dv.xy += -Normal * max(mult * dot(Normal, RelativeVelocity) * CoefficientOfRestitution * min((1.0f / object.MassRadius.x), 1.0f), 0.0f); // impulse only depends on velocity along the normal
	}

}

const vec2 G = vec2(0.0f, -9.8f) * 400.0f;

void main() {

	int Index = int(gl_GlobalInvocationID.x);

	if (Index > u_ObjectCount) {
		return;
	}

	int Substeps = 1;
	float dt = u_Dt / float(Substeps);
	float mult = 1.0f / float(Substeps);

	for (int i = 0 ; i < Substeps; i++) {

		Object CurrentObject = SimulationObjects[Index];

		CurrentObject.Position += CurrentObject.Dx;
		CurrentObject.Velocity += CurrentObject.Dv;
		CurrentObject.Dx = vec2(0.0f);
		CurrentObject.Dv = vec2(0.0f);
		
		CurrentObject.Force += CurrentObject.MassRadius.x * G;

		vec2 OldVel = CurrentObject.Velocity;
		CurrentObject.Velocity += (CurrentObject.Force / CurrentObject.MassRadius.x) * dt;

		// Average velocty is more accurate 
		CurrentObject.Position += ((CurrentObject.Velocity + OldVel) * 0.5f) * dt;
		CurrentObject.Force = vec2(0.0f);
	
		//ApplyConstraint(CurrentObject, mult);
		//Collide(Index, CurrentObject, mult);
		SimulationObjects[Index] = CurrentObject;

		//for (int i = 0 ; i < u_ObjectCount ; i++) {
		//	Collide(i, SimulationObjects[i]);
		//}

	}

	
}
