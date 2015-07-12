#pragma once

#ifdef _WIN32
	#ifdef DLL_EXPORT
		#define TESTLIB __declspec(dllexport)
	#else
		#define TESTLIB __declspec(dllimport)
	#endif
#else
	#define TESTLIB
#endif

TESTLIB void test1();
