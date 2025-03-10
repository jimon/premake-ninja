; Basic assembly test with a function that returns a value.
; This code as-is will currently only work on x64 platform.

.code

TestAsm proc
	mov rax, [rsp-8h]
	ret
TestAsm endp
