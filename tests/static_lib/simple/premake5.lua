require "ninja"

solution "ninjatestsln"
	location "build"
	configurations {"debug", "release"}

project "ninjatestprj"
	kind "StaticLib"
	location "build"
	language "C++"
	targetdir "build/bin_%{cfg.buildcfg}"

	files {"**.cpp", "**.c", "**.h"}

	filter "configurations:debug"
		defines {"DEBUG"}
		symbols "On"

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"
