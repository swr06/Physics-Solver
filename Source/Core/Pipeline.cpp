#include "Pipeline.h"

#include "Utils/Random.h"

#include "Object.h"

namespace Simulation {

	float CurrentTime = glfwGetTime();
	float Frametime = 0.0f;
	float DeltaTime = 0.0f;

	std::vector<Object> Objects;

	class RayTracerApp : public Simulation::Application
	{
	public:

		bool vsync;

		RayTracerApp()
		{
			m_Width = 800;
			m_Height = 600;
		}

		void OnUserCreate(double ts) override
		{

		}

		void OnUserUpdate(double ts) override
		{
			glfwSwapInterval((int)vsync);

			GLFWwindow* window = GetWindow();

		}

		void OnImguiRender(double ts) override
		{
			ImGuiIO& io = ImGui::GetIO();
			if (ImGui::Begin("Debug/Edit Mode")) {


			
			} ImGui::End();
		}

		void OnEvent(Simulation::Event e) override
		{
			ImGuiIO& io = ImGui::GetIO();

			if (e.type == Simulation::EventTypes::MousePress && !ImGui::GetIO().WantCaptureMouse && GetCurrentFrame() > 32)
			{

			}

			if (e.type == Simulation::EventTypes::MouseMove && GetCursorLocked())
			{
			}


			if (e.type == Simulation::EventTypes::MouseScroll && !ImGui::GetIO().WantCaptureMouse)
			{
			}

			if (e.type == Simulation::EventTypes::WindowResize)
			{
			}

			if (e.type == Simulation::EventTypes::KeyPress && e.key == GLFW_KEY_ESCAPE) {
				exit(0);
			}

			if (e.type == Simulation::EventTypes::KeyPress && e.key == GLFW_KEY_F1)
			{
				this->SetCursorLocked(!this->GetCursorLocked());
			}

			if (e.type == Simulation::EventTypes::KeyPress && e.key == GLFW_KEY_F2 && this->GetCurrentFrame() > 5)
			{
				Simulation::ShaderManager::RecompileShaders();
			}

			if (e.type == Simulation::EventTypes::KeyPress && e.key == GLFW_KEY_F3 && this->GetCurrentFrame() > 5)
			{
				Simulation::ShaderManager::ForceRecompileShaders();
			}

			if (e.type == Simulation::EventTypes::KeyPress && e.key == GLFW_KEY_V && this->GetCurrentFrame() > 5)
			{
				vsync = !vsync;
			}



		}


	};

	void Pipeline::StartPipeline()
	{
		// Application
		RayTracerApp app;
		app.Initialize();
		app.SetCursorLocked(false);

		// Create VBO and VAO for drawing the screen-sized quad.
		GLClasses::VertexBuffer ScreenQuadVBO;
		GLClasses::VertexArray ScreenQuadVAO;

		// Setup screensized quad for rendering
		{
			unsigned long long CurrentFrame = 0;
			float QuadVertices_NDC[] =
			{
				-1.0f,  1.0f,  0.0f, 1.0f, -1.0f, -1.0f,  0.0f, 0.0f,
				 1.0f, -1.0f,  1.0f, 0.0f, -1.0f,  1.0f,  0.0f, 1.0f,
				 1.0f, -1.0f,  1.0f, 0.0f,  1.0f,  1.0f,  1.0f, 1.0f
			};

			ScreenQuadVAO.Bind();
			ScreenQuadVBO.Bind();
			ScreenQuadVBO.BufferData(sizeof(QuadVertices_NDC), QuadVertices_NDC, GL_STATIC_DRAW);
			ScreenQuadVBO.VertexAttribPointer(0, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), 0);
			ScreenQuadVBO.VertexAttribPointer(1, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
			ScreenQuadVAO.Unbind();
		}

		// Create Shaders 
		ShaderManager::CreateShaders();

		// Shaders
		GLClasses::Shader& BlitShader = ShaderManager::GetShader("BLIT");
		GLClasses::Shader& RenderShader = ShaderManager::GetShader("RENDER");
		GLClasses::ComputeShader& SimulateShader = ShaderManager::GetComputeShader("SIMULATE");
		GLClasses::ComputeShader& CollisionShader = ShaderManager::GetComputeShader("COLLIDE");

		// Matrices
		float OrthographicRange = 400.0f;
		OrthographicCamera Orthographic(-400.0f, 400.0f, -400.0f, 400.0f);

		// Create Random Objects 
		Random RNG;

		int ObjectCount = 4;
		Objects.resize(ObjectCount);

		//Objects[0].Position = glm::vec4(0.0f, 0.0f, 0.0f, 32.0f);
		//Objects[0].Velocity = glm::vec4(0.0f);
		//Objects[0].Acceleration = glm::vec4(0.0f);

		for (int i = 0; i < ObjectCount; i++) {
		
			glm::vec2& Pos = Objects[i].Position;
		
			do {
				Pos.x = (RNG.Float() * 2.0f - 1.0f) * (OrthographicRange - 1.0f);
				Pos.y = (RNG.Float() * 2.0f - 1.0f) * (OrthographicRange - 1.0f);
			}

			while (glm::distance(glm::vec2(Pos), glm::vec2(0.0f)) > 250.0f);
			
			float r = (RNG.Float() * 24.0f) + 8.;
			Objects[i].MassRadius = glm::vec2(10.0f, 32.0f);
			Objects[i].Velocity = glm::vec2(0.0f);
			Objects[i].Force = glm::vec2(0.0f);
		}

		// Object SSBO
		GLuint ObjectSSBO = 0;
		glGenBuffers(1, &ObjectSSBO);
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, ObjectSSBO);
		glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(Object) * ObjectCount, (void*)Objects.data(), GL_DYNAMIC_DRAW);
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

		// Clear simulation map
		glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
		glClear(GL_COLOR_BUFFER_BIT);

		while (!glfwWindowShouldClose(app.GetWindow())) {

			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);

			app.OnUpdate();

			if (app.GetCurrentFrame() > 16) {
				// Simulate 
				SimulateShader.Use();
				SimulateShader.SetFloat("u_Dt", DeltaTime);
				SimulateShader.SetFloat("u_Time", glfwGetTime());
				SimulateShader.SetInteger("u_ObjectCount", ObjectCount);

				glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ObjectSSBO);
				glDispatchCompute((ObjectCount / 16) + 1, 1, 1);
				glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
				glFinish();

				// Collide 
				CollisionShader.Use();
				CollisionShader.SetFloat("u_Dt", DeltaTime);
				CollisionShader.SetFloat("u_Time", glfwGetTime());
				CollisionShader.SetInteger("u_ObjectCount", ObjectCount);

				glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ObjectSSBO);
				glDispatchCompute((ObjectCount / 16) + 1, 1, 1);
				glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
				glFinish();
			}

			// Blit Final Result 
			glBindFramebuffer(GL_FRAMEBUFFER,0);
			glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
			glClear(GL_COLOR_BUFFER_BIT);

			RenderShader.Use();

			RenderShader.SetMatrix4("u_Projection", Orthographic.GetProjectionMatrix());
			RenderShader.SetVector2f("u_Dimensions", glm::vec2(app.GetWidth(), app.GetHeight()));
			RenderShader.SetVector2f("u_Dims", glm::vec2(app.GetWidth(), app.GetHeight()));

			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ObjectSSBO);

			ScreenQuadVAO.Bind();
			glDrawArraysInstanced(GL_TRIANGLES, 0, 6, ObjectCount);
			ScreenQuadVAO.Unbind();

			glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
			glFinish();

			glUseProgram(0);

			glFinish();
			app.FinishFrame();

			CurrentTime = glfwGetTime();
			DeltaTime = CurrentTime - Frametime;
			Frametime = glfwGetTime();

			GLClasses::DisplayFrameRate(app.GetWindow(), "Simulation ");
		}
	}
}