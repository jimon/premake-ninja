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
	includedirs {"test1", "test2"}

	filter "configurations:debug"
		defines {"DEBUG"}
		symbols "On"

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"
