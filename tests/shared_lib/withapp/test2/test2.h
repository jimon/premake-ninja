#pragma once

#ifdef _WIN32
	#ifdef DLL_EXPORT2
		#define TESTLIB2 __declspec(dllexport)
	#else
		#define TESTLIB2 __declspec(dllimport)
	#endif
#else
	#define TESTLIB2
#endif

TESTLIB2 void test2();