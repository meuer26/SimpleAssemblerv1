# Copyright (c) 2023-2026 Dan O’Malley
# This file is licensed under the MIT License. See LICENSE for details.


default: build

debug: build debug

build:
	flex lex.l
	yacc -d -v parser.y
	clang -c parserstack.c
	clang -DYYDEBUG lex.yy.c y.tab.c parserstack.o -o assembler -lelf
	./assembler prog.s
	chmod -x prog.o
	objdump -b binary -D text.bin -m i386:x86-64
	xxd data.bin
	cat prog.s
	objdump -D -x -s prog.o
	ld -pie -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o prog prog.o -lc


clean:
	rm -f y.tab.c
	rm -f y.tab.h
	rm -f parserstack.o
	rm -f lex.yy.c
	rm -f y.output
	rm -f text.bin
	rm -f data.bin
	rm -f text.o
	rm -f prog.o
	rm -f myprog
	rm -f prog
	rm -f assembler
