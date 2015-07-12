#include <stdio.h>
#include "test1.h"
#include "test2.h"

#ifdef _WIN32
#include <Windows.h>
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PSTR lpCmdLine, INT nCmdShow)
#else
int main()
#endif
{
	printf("hello world !\n");
	test1();
	test2();
	return 0;
}