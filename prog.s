; testing comments

extern puts

section .data
msg:
   db "Hello World"

msg2:
   db "Hello assembler"

section .text

_start:
   lea rdi, [msg]
   call puts

   call exit

exit:
   mov rax, 60
   syscall
