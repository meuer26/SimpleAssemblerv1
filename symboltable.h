// Copyright (c) 2023-2026 Dan O’Malley
// This file is licensed under the MIT License. See LICENSE for details.


#ifndef SYMBOLTABLE_HEADER
#define SYMBOLTABLE_HEADER

#define MAXSYMBOLS 100

struct SymbolTable {
    int totalEntries;
    char entryType[30];
    char symbolType[20];
    char symbolName[30];
    char sectionName[30];
    int symbolLocation;
    int size;
    int symIndex;    // index assigned in the ELF .symtab (0 = not emitted)
    int strOffset;   // offset of this symbol's name in the ELF .strtab
} symbolTable[MAXSYMBOLS];

#endif