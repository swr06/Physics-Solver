#version 330 core

layout (location = 0) in vec2 a_Position;
layout (location = 1) in vec2 a_TexCoords;

out vec2 v_TexCoords;
out vec3 v_Position;
out vec3 v_RawPosition;
out float v_Radius;

uniform mat4 u_Projection;
uniform vec2 u_Dimensions;

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

mat4 Scale(vec3 scale) 
{
  return mat4(
    scale.x, 0.0, 0.0, 0.0,
    0.0, scale.y, 0.0, 0.0,
    0.0, 0.0, scale.z, 0.0,
    0.0, 0.0, 0.0, 1.0
  );
}

mat4 Translate(vec3 v) {
  return mat4(
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    v.x, v.y, v.z, 1.0
  );
}

void main()
{
    float Aspect = u_Dimensions.y / u_Dimensions.x;

    // SRT Order of transformations 
    vec4 FinalPosition = vec4(a_Position, 0.0f, 1.0f);
    vec2 Position = SimulationObjects[gl_InstanceID].Position;
    vec2 MassRadius = SimulationObjects[gl_InstanceID].MassRadius;
    mat4 TranslateMatrix = Translate(vec3(Position.xy, 0.0f));
    mat4 ScaleMatrix = Scale(vec3(MassRadius.y * Aspect, MassRadius.y, MassRadius.y));

    FinalPosition = ScaleMatrix * FinalPosition;
    FinalPosition = TranslateMatrix * FinalPosition;
    
    // Set outs 
    v_Radius = MassRadius.y;
    v_RawPosition = vec3(Position.xy, 0.0f);
	v_TexCoords = a_TexCoords;
    v_Position = FinalPosition.xyz;

    gl_Position = u_Projection * FinalPosition;

}