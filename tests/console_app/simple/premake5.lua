require "ninja"

solution "ninjatestsln"
	location "build"
	configurations {"debug", "release"}

project "ninjatestprj"
	kind "ConsoleApp"
	location "build"
	language "C++"
	targetdir "build/bin_%{cfg.buildcfg}"

	files {"**.cpp", "**.c", "**.h"}

	filter "configurations:debug"
		defines {"DEBUG"}
		flags {"Symbols"}

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"
