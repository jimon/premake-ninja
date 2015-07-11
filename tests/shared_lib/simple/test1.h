#pragma once

#ifdef DLL_EXPORT
#define TESTLIB __declspec(dllexport)
#else
#define TESTLIB __declspec(dllimport)
#endif

TESTLIB void test1();
