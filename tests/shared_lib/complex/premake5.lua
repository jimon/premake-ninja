require "ninja"

solution "ninjatestsln"
	location "build"
	configurations {"debug", "release"}

project "ninjatestprj"
	kind "SharedLib"
	location "build"
	language "C++"
	cppdialect "C++20"
	targetdir "build/bin_%{cfg.buildcfg}"

	architecture "x86_64"
	platforms "x64"

	files {"**.cpp", "**.c", "**.h", "**.asm"}
	defines {"DLL_EXPORT"}

	linkoptions { "/pdbaltpath:%_PDB%" }
	targetextension ".aes"

	filter "configurations:debug"
		defines {"DEBUG"}
		symbols "On"

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"
