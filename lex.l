/* Copyright (c) 2023-2026 Dan O’Malley */
/* This file is licensed under the MIT License. See LICENSE for details. */


%{
#include <stdio.h>
#include "y.tab.h"
%}

%%
";"[^\n]*              { /* consume //-comment */ }
[ \t\n]+                { /* consume whitespace characters */ }
"rax"                   { yylval.string=strdup(yytext); return TOK_REG64; }
"rdi"                   { yylval.string=strdup(yytext); return TOK_REG64; }
"rdx"                   { yylval.string=strdup(yytext); return TOK_REG64; }
"rbp"                   { yylval.string=strdup(yytext); return TOK_REG64; }
"rsi"                   { yylval.string=strdup(yytext); return TOK_REG64; }
"rsp"                   { yylval.string=strdup(yytext); return TOK_REG64; }
"_start:"               { yylval.string=strdup(yytext); return TOK_LABEL;}
"mov"		            { return TOK_MOV;}
"push"		            { return TOK_PUSH;}
"sub"		            { return TOK_SUBTRACT;}
"jmp"		            { return TOK_JUMP;}
"lea"		            { return TOK_LEA;}
"db"		            { return TOK_DB;}
"syscall"		        { return TOK_SYSCALL;}
"ret"		            { return TOK_RETURN;}
"leave"		            { return TOK_LEAVE;}
"call"		            { return TOK_CALL;}
"section"		        { return TOK_SECTION;}
"extern"		        { return TOK_EXTERN;}
".data"		            { yylval.string=strdup(yytext); return TOK_SECTION_TYPE;}
".text"		            { yylval.string=strdup(yytext); return TOK_SECTION_TYPE;}
"["                     { return TOK_LBRACKET; }
"]"                     { return TOK_RBRACKET; }
","                     { return TOK_COMMA; }
[0-9]+       		    { yylval.number=atoi(yytext); return TOK_UINT64; }
[A-Za-z]*[0-9]* 	    { yylval.string=strdup(yytext); return TOK_LABEL; }
[A-Za-z]*[0-9]*: 	    { yylval.string=strdup(yytext); return TOK_LABEL; }
["]([^"]|\\(.|\n))*["] 	{ yylval.string=strdup(yytext); return TOK_STRING; }

%%

int yywrap() {
	return 1;
}