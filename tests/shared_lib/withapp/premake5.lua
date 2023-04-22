require "ninja"

solution "ninjatestsln"
	location "build"
	configurations {"debug", "release"}

project "ninjatestprj_app"
	kind "ConsoleApp"
	location "build"
	language "C++"
	targetdir "build/bin_%{cfg.buildcfg}"

	files {"main.cpp"}
	includedirs {"test1", "test2"}
	links {"ninjatestprj_lib_test1", "ninjatestprj_lib_test2"}

	filter "configurations:debug"
		defines {"DEBUG"}
		symbols "On"

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"

project "ninjatestprj_lib_test1"
	kind "SharedLib"
	location "build"
	language "C++"
	targetdir "build/bin_%{cfg.buildcfg}"

	files {"test1/**.cpp", "test1/**.c", "test1/**.h"}
	includedirs {"test1"}
	defines {"DLL_EXPORT"}

	filter "configurations:debug"
		defines {"DEBUG"}
		symbols "On"

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"

project "ninjatestprj_lib_test2"
	kind "SharedLib"
	location "build"
	language "C++"
	targetdir "build/bin_%{cfg.buildcfg}"

	files {"test2/**.cpp", "test2/**.c", "test2/**.h"}
	includedirs {"test2"}
	defines {"DLL_EXPORT2"}

	filter "configurations:debug"
		defines {"DEBUG"}
		symbols "On"

	filter "configurations:release"
		defines {"NDEBUG"}
		optimize "On"
