module app.main;

extern(C) nothrow
{
	import derelict.glfw3.glfw3;
	void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mode)
	{
		switch(action)
		{
			case GLFW_PRESS:
				switch(key)
				{
					case GLFW_KEY_ESCAPE:
						glfwSetWindowShouldClose(window, true);
						break;
					default:
						break;
				}
				break;
			default:
				break;
		}
	}
}

enum bool checkErrors = false;

void main()
{
	import derelict.opengl3.gl3;
	// Load the OpenGL shared library
	DerelictGL3.load();

	import derelict.glfw3.glfw3;
	// Load the GLFW3 shared library
	DerelictGLFW3.load();

	// Initialize GLFW
	glfwInit();
	scope(exit)
	{
		glfwTerminate();
	}

	// Set the OpenGL context options
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	// Create a window
	auto window = glfwCreateWindow(800, 600, "LearnOpenGL", null, null);

	glfwMakeContextCurrent(window);

	// Reload required after context creation
	DerelictGL3.reload();
	glEnable(GL_MULTISAMPLE);
	glfwWindowHint(GLFW_SAMPLES, 16);

	// Set the callback for keyboard events, in this case, closing on ESC
	glfwSetKeyCallback(window, &keyCallback);

	// Set the viewport size;
	glViewport(0, 0, 800, 600);

	GLfloat[9] vertices = [
	-1.0, -1.0, 0.0,
	 1.0, -1.0, 0.0,
	 0.0,  1.0, 0.0];

	// Set up the vertex array object
	GLuint vao;
	glGenVertexArrays(1, &vao);
	scope(exit)
	{
		glDeleteVertexArrays(1, &vao);
	}
	glBindVertexArray(vao);

	// Set up the vertex buffer object
	GLuint vbo;
	glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);

	glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr,  GL_STREAM_DRAW);

	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * GLfloat.sizeof, null);
	glEnableVertexAttribArray(0);

	void checkShaderCompileError(GLuint shader)
	{
		enum BufferSize = 512;
		GLint success;
		GLchar[BufferSize] infoLog;
		shader.glGetShaderiv(GL_COMPILE_STATUS, &success);
		if(!success)
		{
			shader.glGetShaderInfoLog(BufferSize, null, &infoLog[0]);
			import core.exception : Exception;
			string msg = "Shader compilation failed:\n" ~ cast(string)infoLog;
			throw new Exception(msg);
		}
	}

	static const(char*)[] str2src(string str)
	{
		import std.array : split;
		import std.algorithm : map;
		import std.array : array;
		return str.split("\n").map!(a => a.ptr).array;
	}

	auto vsSrc = str2src(import("shaders/vs.glsl"));
	GLuint vs = glCreateShader(GL_VERTEX_SHADER);
	scope(exit)
	{
		vs.glDeleteShader();
	}
	vs.glShaderSource(1, vsSrc.ptr, null);
	vs.glCompileShader();
	static if (checkErrors)
		checkShaderCompileError(vs);

	// Set up the fragment shader
	auto fsSrc = str2src(import("shaders/fs.glsl"));
	GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
	scope(exit)
	{
		fs.glDeleteShader();
	}
	fs.glShaderSource(1, fsSrc.ptr, null);
	fs.glCompileShader();
	static if (checkErrors)
		checkShaderCompileError(fs);


	void checkProgramLinkError(GLuint program)
	{
		enum BufferSize = 512;
		GLint success;
		GLchar[BufferSize] infoLog;
		program.glGetProgramiv(GL_LINK_STATUS, &success);
		if(!success)
		{
			program.glGetProgramInfoLog(BufferSize, null, &infoLog[0]);
			import core.exception : Exception;
			string msg = "Program linking failed:\n" ~ cast(string)infoLog;
			throw new Exception(msg);
		}
	}

	// Set up the shader program
	GLuint pr = glCreateProgram();
	pr.glAttachShader(vs);
	pr.glAttachShader(fs);
	pr.glLinkProgram();
	static if (checkErrors)
		checkProgramLinkError(pr);

	glUseProgram(pr);

	import core.time : MonoTime;
	auto prev = MonoTime.currTime.ticks;
	auto tps = MonoTime.ticksPerSecond;
	auto fps = 60UL;
	auto targetDelta = tps / fps;
	long lag;

	import gfm.math.vector : Vector;
	alias Coord = Vector!(GLfloat, 2);
	auto bz1 = Coord(-1, 0);
	auto bz2 = Coord(-0.5, 1);
	auto bz3 = Coord(0.5, -1);
	auto bz4 = Coord(1, 0);

	auto start = Coord(-1, 0);
	auto end = Coord(1, 1);
	import std.experimental.math.rational : rational;
	auto speed = rational(1, 2 ^^ 1);
	bool reversed;

	import std.experimental.math.rational : Rational;
	auto progress = Rational!false(0, tps);

	while(!glfwWindowShouldClose(window))
	{

		// Clear
		glClearColor(0.2, 0.3, 0.3, 1);
		glClear(GL_COLOR_BUFFER_BIT);

		/+ Only one target, no need to rebind
		glUseProgram(pr);
		glBindVertexArray(vao);

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		+/
		glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr,  GL_STREAM_DRAW);

		glDrawArrays(GL_TRIANGLES, 0, 3);
// 		glBindVertexArray(0);

		glfwSwapBuffers(window);

		glfwPollEvents();

		auto curr = MonoTime.currTime.ticks;
		auto delta = curr - prev;
		lag += delta;

		while (lag > targetDelta)
		{
			auto progressDelta = cast(ulong)(targetDelta * speed);
			if (reversed)
			{
				if (progressDelta > progress.num)
				{
					progress.num = 0;
				}
				else
				{
					progress.num -= progressDelta;
				}
			}
			else
			{
				progress.num += progressDelta;
				if (progress.num > progress.denom)
				{
					progress.num = progress.denom;
				}
			}

			if (0 < progress && progress < 1)
			{
				import std.experimental.anim.easing;
				static if (false)
				{
					auto precisioned = progress.atPrecision(1_000);
					auto terpd = easeOut!(power!3)(start, end - start, cast(real)precisioned);
				}
				else
				{
					auto bz = [bz1, bz2, bz3, bz4];
					import std.experimental.geom;
					auto terpd = bezier(bz, easeCombined!(power!5)(cast(real)progress));
				}
				vertices[6] = cast(GLfloat)terpd[0];
				vertices[7] = cast(GLfloat)terpd[1];
			}
			else if (progress >= 1)
			{
				reversed = true;
			}
			else if (progress <= 0)
			{
				reversed = false;
			}

			lag -= targetDelta;
		}

		prev = curr;
	}
}
