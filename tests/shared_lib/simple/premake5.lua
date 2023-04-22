require "ninja"

solution "ninjatestsln"
	location "build"
	configurations {"debug", "release"}

project "ninjatestprj"
	kind "SharedLib"
	location "build"
	language "C++"
	targetdir "build/bin_%{cfg.buildcfg}"

	files {"**.cpp", "**.c", "**.h"}
	defines {"DLL_EXPORT"}

	filter "configurations:debug"
		defines {"DEBUG"}
		symbols "On"

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"
