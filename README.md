## Simple Assembler v1

Dan O’Malley

A basic flex and yacc-based x86 64-bit assembler. This code is largely based on [SimpleCompilerv1](https://github.com/meuer26/SimpleCompilerv1) but using the symbol table from [SimpleCompilerv3](https://github.com/meuer26/SimpleCompilerv3_Student). It was adapted from a compiler-based project to an assembler-based project as flex and yacc are easy to create the parsing needed for complex assembly files.


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## Features

- Supports basic x86-64 instructions: mov, push, sub, jmp, lea, syscall, ret, leave, call, REX prefixes, etc. These were needed to support basic Linux syscalls and calling external LibC functions.
- Assembler directives: extern, section, db, etc.
- Outputs ELF relocatable objects suitable to link with ld (including .text, .data, .strtab, .symbtab, .rela.text, .shstrtab).
- Only global objects supported currently.