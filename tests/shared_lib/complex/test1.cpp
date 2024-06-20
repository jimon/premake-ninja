#include "test1.h"
#include <stdio.h>

// to test properly setting up C++ version
#include <filesystem>

extern "C"
{
	extern size_t TestAsm();
}

TESTLIB void test1()
{
	std::filesystem::path p{ "test1" };
	printf("hello from %s!\nAssembly return value: %llu\n", p.string().c_str(), TestAsm());
}