#version 330 core

layout (location = 0) in vec2 a_Position;
layout (location = 1) in vec2 a_TexCoords;

// yes
out vec2 v_TexCoords;

uniform mat4 u_Projection;

struct Object {
	vec4 Position; // w component has radius 
	vec4 Velocity; 
	vec4 Acceleration;
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
    // SRT Order of transformations 
    vec4 FinalPosition = vec4(a_Position, 0.0f, 1.0f);
    vec4 Position = SimulationObjects[gl_InstanceID].Position;
    mat4 TranslateMatrix = Translate(Position.xyz);
    mat4 ScaleMatrix = Scale(Position.www);

    FinalPosition = ScaleMatrix * FinalPosition;
    FinalPosition = TranslateMatrix * FinalPosition;
    gl_Position = u_Projection * FinalPosition;

	v_TexCoords = a_TexCoords;
}