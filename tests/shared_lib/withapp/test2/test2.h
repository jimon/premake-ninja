#pragma once

#ifdef DLL_EXPORT2
#define TESTLIB2 __declspec(dllexport)
#else
#define TESTLIB2 __declspec(dllimport)
#endif

TESTLIB2 void test2();