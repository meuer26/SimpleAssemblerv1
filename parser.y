%{
// Copyright (c) 2023-2026 Dan O’Malley
// This file is licensed under the MIT License. See LICENSE for details.


#include "stdio.h"
#include <string.h>
#include "parsetree.c"
#include "codegen.c"
#include "parserstack.h"
#include "symboltable.h"
#include "constants.h"
#include <fcntl.h>
#include <unistd.h>
#include <libelf.h>
#include <gelf.h>


int yylex();
int yyparse();

void yyerror(const char *str) {
    //https://www.gnu.org/software/bison/manual/html_node/Error-Reporting-Function.html
    fprintf (stderr, "%s\n", str);
}

extern FILE *yyin;
ParserStack *parserStack;
ParserStack *parserStackReversed;
ParseTree *parseTree;
struct SymbolTable symbolTable[MAXSYMBOLS];
int symbolEntryIndex = 0;
int textOffset = 0;
int dataOffset = 0;
char currentSection[30];


void insertSymbol(struct SymbolTable * symbolTable, char * entryType, char * symbolType, char * symbolName, char * sectionName, int symbolLocation, int size)
{
    char *shortenedLabelName = malloc(30);
    strcpy(shortenedLabelName, symbolName);
    int length = strlen(shortenedLabelName);
    if (shortenedLabelName[length - 1] == ':')
    {
        shortenedLabelName[length - 1] = '\0';
    }
    
    int entryNumber = symbolTable->totalEntries;
    strcpy(symbolTable[entryNumber].entryType, entryType);
    strcpy(symbolTable[entryNumber].symbolType, symbolType);
    strcpy(symbolTable[entryNumber].symbolName, shortenedLabelName);
    strcpy(symbolTable[entryNumber].sectionName, sectionName);
    symbolTable[entryNumber].symbolLocation = symbolLocation;
    symbolTable[entryNumber].size = size;

    symbolTable->totalEntries++;

    free(shortenedLabelName);
}

void printSymbolTable(struct SymbolTable * symbolTable)
{
    printf("\n\n***** Symbol Table Dump *****\n");

    for (int entryNumber = 0; entryNumber < symbolTable->totalEntries; entryNumber++)
    {
        printf("--> ID: %d ENTRY TYPE: %-5s NAME: %-15s TYPE: %-8s SECTION: %-8s LOCATION: %-3d SIZE: %d\n", entryNumber,
            symbolTable[entryNumber].entryType,
            symbolTable[entryNumber].symbolName,
            symbolTable[entryNumber].symbolType,
            symbolTable[entryNumber].sectionName,
            symbolTable[entryNumber].symbolLocation,
            symbolTable[entryNumber].size);
}

    printf("\n\n");
}


int main(int argc, char *argv[])
{
    // #if YYDEBUG == 1
    // extern int yydebug;
    // yydebug = 1;
    // #endif
    
    yyin = fopen(argv[1], "r");
    parserStack = parserStackCreate();
    parserStackReversed = parserStackCreate();

    yyparse();

    // append in binary mode
    FILE *textFile = fopen("text.bin", "ab");
    FILE *dataFile = fopen("data.bin", "ab");

    while (parserStack->depth > 0)
    {
        printf("parserstack depth: %d\n", parserStack->depth);
        parseTree = parserStackPop(parserStack);
        parserStackPush(parserStackReversed, parseTree);

    }

    // I have to reverse the parsetree stack to get the codegen in the correct order
    while (parserStackReversed->depth > 0)
    {
        printf("parserstackReversed depth: %d\n", parserStackReversed->depth);
        parseTree = parserStackPop(parserStackReversed);
        codeGen(textFile, dataFile, parseTree, symbolTable);       
    }

    printSymbolTable(symbolTable);
    fclose(textFile);
    fclose(dataFile);

    textFile = fopen("text.bin", "rb");
    dataFile = fopen("data.bin", "rb");

    fseek(textFile, 0, SEEK_END);
    int textSize = ftell(textFile);
    fseek(dataFile, 0, SEEK_END);
    int dataSize = ftell(dataFile);
    fseek(textFile, 0, SEEK_SET);
    fseek(dataFile, 0, SEEK_SET);

    char *textBuffer = malloc(textSize + 1);
    char *dataBuffer = malloc(dataSize + 1);
    fread(textBuffer, 1, textSize, textFile);
    fread(dataBuffer, 1, dataSize, dataFile);

    int relocatableElfFD;
    Elf *elf;
    Elf_Scn *section;
    Elf_Data *data;
    GElf_Ehdr ehdr;
    GElf_Shdr textShdr;
    GElf_Shdr dataShdr; 
    GElf_Shdr strshdr;
    GElf_Shdr strtabShdr;
    GElf_Shdr symtabShdr;
    GElf_Shdr relaShdr;

    // Changing to .o for the output file
    char *fileName = argv[1];
    char *extension = strrchr(fileName, '.');
    *extension = '\0';
    char newFileName[50];
    snprintf(newFileName, sizeof(newFileName), "%s.o", fileName);
    relocatableElfFD = open(newFileName, O_RDWR | O_CREAT | O_TRUNC, 0755);

    // Find the number of relocations needed by searching symbol table for Extern keyword
    int relocationNumber = 0;
    int numberOfRelocationsNeeded = 0;
    for(int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
    {
        if(!strcmp(symbolTable[entryIterator].symbolType, (char*)"Extern"))
        {
            numberOfRelocationsNeeded++;
        }
    }

    int numberOfSymbolsNeeded = 1; // since 0 is the undefined symbol, we start at 1

    for(int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
    {
        if((!strcmp(symbolTable[entryIterator].symbolType, (char*)"Label")) || (!strcmp(symbolTable[entryIterator].symbolType, (char*)"Extern")))
        {
            numberOfSymbolsNeeded++;
        }

    }

    Elf64_Rela *relocations = malloc(numberOfRelocationsNeeded * sizeof(Elf64_Rela));

    // Search the symbol table to assign the offset where the external call references are
    for(int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
    {
        if(!strcmp(symbolTable[entryIterator].symbolType, (char*)"Extern"))
        {
            relocations[relocationNumber].r_offset = symbolTable[entryIterator].symbolLocation + 1;  // Offset to the 00 00 00 00
            // Since the external reference is the last to be read in the symbol table, it will be the 
            // last symbol number. 
            relocations[relocationNumber].r_info = ELF64_R_INFO(numberOfSymbolsNeeded-1, R_X86_64_PLT32); 
            relocations[relocationNumber].r_addend = -4;  // Adjustment for call instruction
            relocationNumber++;
        }
    }

    // Required to initialize
    elf_version(EV_CURRENT);
    elf = elf_begin(relocatableElfFD, ELF_C_WRITE, NULL);
    gelf_newehdr(elf, ELFCLASS64);
    gelf_getehdr(elf, &ehdr);

    ehdr.e_ident[EI_DATA] = ELFDATA2LSB;  
    ehdr.e_type = ET_REL;         
    ehdr.e_machine = EM_X86_64;   
    ehdr.e_version = EV_CURRENT;
    ehdr.e_shoff = sizeof(Elf64_Ehdr);             
    ehdr.e_shentsize = sizeof(Elf64_Shdr);
    ehdr.e_shnum = 7;   // null, .text, .data, .strtab, .symtab, .rela.text, .shstrtab      
    ehdr.e_shstrndx = 6;  // .shstrtab is index 6        

    gelf_update_ehdr(elf, &ehdr);

    // .text section (index 1)
    section = elf_newscn(elf);
    data = elf_newdata(section);

    data->d_align = 16;           
    data->d_buf = textBuffer;
    data->d_size = textSize;

    gelf_getshdr(section, &textShdr);

    textShdr.sh_name = 1;   // offset in string table for .text name             
    textShdr.sh_type = SHT_PROGBITS;
    textShdr.sh_flags = SHF_ALLOC | SHF_EXECINSTR; // Section Header Flag to load and make it executable
    textShdr.sh_offset = 0x1000;  // Making all of these 0x1000 apart for simplicity and clarity
    textShdr.sh_size = textSize;
    textShdr.sh_addralign = 16;

    gelf_update_shdr(section, &textShdr);

    // .data section (index 2)
    Elf_Scn *dataSection = elf_newscn(elf);  
    Elf_Data *dataData = elf_newdata(dataSection);  
    dataData->d_align = 16;  
    dataData->d_buf = dataBuffer;  
    dataData->d_size = dataSize; 

    gelf_getshdr(dataSection, &dataShdr);
    dataShdr.sh_name = 7; 
    dataShdr.sh_type = SHT_PROGBITS;  
    dataShdr.sh_flags = SHF_ALLOC | SHF_WRITE; // Section Header Flag load into memory and make it writeable
    dataShdr.sh_offset = 0x2000;   // Making all of these 0x1000 apart for simplicity and clarity
    dataShdr.sh_size = dataSize; 
    dataShdr.sh_addralign = 16;  
    gelf_update_shdr(dataSection, &dataShdr); 

    // .strtab section (index 3)
    Elf_Scn *strtabSection = elf_newscn(elf);
    Elf_Data *strtabData = elf_newdata(strtabSection);

    int symstrtabDataPtr = 0;
    char symstrtabData[1024];
    symstrtabDataPtr++;

    for(int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
    {
        if(!strcmp(symbolTable[entryIterator].symbolType, (char*)"Label"))
        {
            strcpy(symstrtabData + symstrtabDataPtr, symbolTable[entryIterator].symbolName);
            symstrtabDataPtr+= strlen(symbolTable[entryIterator].symbolName);
            symstrtabDataPtr++;
        }
    }

    for(int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
    {
        if(!strcmp(symbolTable[entryIterator].symbolType, (char*)"Extern"))
        {
            strcpy(symstrtabData + symstrtabDataPtr, symbolTable[entryIterator].symbolName);
            symstrtabDataPtr+= strlen(symbolTable[entryIterator].symbolName);
            symstrtabDataPtr++;
        }
    }

    strtabData->d_buf = symstrtabData;
    strtabData->d_size = sizeof(symstrtabData);
    strtabData->d_align = 1;

    gelf_getshdr(strtabSection, &strtabShdr);
    strtabShdr.sh_name = 23;  // offset in .shstrtab for ".strtab"
    strtabShdr.sh_type = SHT_STRTAB;
    strtabShdr.sh_offset = 0x3000;  // Making all of these 0x1000 apart for simplicity and clarity
    strtabShdr.sh_size = strtabData->d_size;
    gelf_update_shdr(strtabSection, &strtabShdr);

    // .symtab section (index 4)
    // Section Symbol Table
    Elf_Scn *symtabSection = elf_newscn(elf);
    Elf_Data *symtabData = elf_newdata(symtabSection);

    Elf64_Sym symbols[numberOfSymbolsNeeded];
    memset(symbols, 0, sizeof(symbols));
    symbols[0].st_name = 0;  // Undefined

    int symbolIterator = 1; // since zero is the undefined one
    int globalSymbolPtr = 1;
    for(int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
    {
        if(!strcmp(symbolTable[entryIterator].symbolType, (char*)"Label"))
        {
            symbols[symbolIterator].st_name = globalSymbolPtr; 
            // STB_GLOBAL = symbol table binding global
            // STT_FUNC = symbol table type function

            // I am making these all global as ELF wants local variables ordered first in the 
            // strtab and then globals. For simplicity, making everthing global at this point.
            // This is work to do later.
            symbols[symbolIterator].st_info = ELF64_ST_INFO(STB_GLOBAL, STT_FUNC);
            symbols[symbolIterator].st_shndx = 1;  // .text

            globalSymbolPtr+= strlen(symbolTable[entryIterator].symbolName);
            globalSymbolPtr++;
            symbolIterator++;
        }

    }

    for(int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
    {
        if(!strcmp(symbolTable[entryIterator].symbolType, (char*)"Extern"))
        {
            symbols[symbolIterator].st_name = globalSymbolPtr;  
            symbols[symbolIterator].st_info = ELF64_ST_INFO(STB_GLOBAL, STT_FUNC);
            symbols[symbolIterator].st_shndx = SHN_UNDEF;

            globalSymbolPtr+= strlen(symbolTable[entryIterator].symbolName);
            globalSymbolPtr++;
            symbolIterator++;
        }

    }

    symtabData->d_buf = symbols;
    symtabData->d_size = sizeof(symbols);
    symtabData->d_align = 8;

    gelf_getshdr(symtabSection, &symtabShdr);
    symtabShdr.sh_name = 31;  // offset in .shstrtab for ".symtab"
    symtabShdr.sh_type = SHT_SYMTAB;  // Section Header Type Symbol Table
    symtabShdr.sh_offset = 0x4000;   // Making all of these 0x1000 apart for simplicity and clarity
    symtabShdr.sh_size = symtabData->d_size;
    symtabShdr.sh_addralign = 8;
    symtabShdr.sh_link = elf_ndxscn(strtabSection);  // Link to .strtab (index 3)
    symtabShdr.sh_info = 1; 
    symtabShdr.sh_entsize = sizeof(Elf64_Sym);
    gelf_update_shdr(symtabSection, &symtabShdr);

    // .rela.text section (index 5)
    // Section Header Relocation Addend for the Text section
    Elf_Scn *relaSection = elf_newscn(elf);
    Elf_Data *relaData = elf_newdata(relaSection);
    relaData->d_buf = relocations;
    relaData->d_size = numberOfRelocationsNeeded * sizeof(Elf64_Rela);
    relaData->d_align = 8;

    gelf_getshdr(relaSection, &relaShdr);
    relaShdr.sh_name = 39;  // offset in .shstrtab for ".rela.text"
    relaShdr.sh_type = SHT_RELA;    // Section Header Type Relocation Addend
    relaShdr.sh_flags = SHF_INFO_LINK;  // Tells us it contain information for another section (the text section)
    relaShdr.sh_offset = 0x5000;  // Making all of these 0x1000 apart for simplicity and clarity
    relaShdr.sh_size = relaData->d_size;
    relaShdr.sh_addralign = 8;
    relaShdr.sh_link = elf_ndxscn(symtabSection);  // Link to .symtab (index 4)
    relaShdr.sh_info = elf_ndxscn(section);  // Link to .text (index 1)
    relaShdr.sh_entsize = sizeof(Elf64_Rela);
    gelf_update_shdr(relaSection, &relaShdr);

    // .shstrtab section (index 6)
    // Section Header String Table - contains the names (strings) of the sections 
    Elf_Scn *strSection = elf_newscn(elf);
    Elf_Data *strData = elf_newdata(strSection);

    int shstrtabDataPtr = 0;
    char shstrtabData[1024];
    shstrtabDataPtr++;

    strcpy(shstrtabData + shstrtabDataPtr, ".text");
    shstrtabDataPtr+= strlen(".text");
    shstrtabDataPtr++;

    strcpy(shstrtabData + shstrtabDataPtr, ".data");
    shstrtabDataPtr+= strlen(".data");
    shstrtabDataPtr++;

    strcpy(shstrtabData + shstrtabDataPtr, ".shstrtab");
    shstrtabDataPtr+= strlen(".shstrtab");
    shstrtabDataPtr++;

    strcpy(shstrtabData + shstrtabDataPtr, ".strtab");
    shstrtabDataPtr+= strlen(".strtab");
    shstrtabDataPtr++;

    strcpy(shstrtabData + shstrtabDataPtr, ".symtab");
    shstrtabDataPtr+= strlen(".symtab");
    shstrtabDataPtr++;

    strcpy(shstrtabData + shstrtabDataPtr, ".rela.text");
    shstrtabDataPtr+= strlen(".rela.text");
    shstrtabDataPtr++;

    strData->d_buf = shstrtabData;
    strData->d_size = sizeof(shstrtabData);
    strData->d_align = 1;

    gelf_getshdr(strSection, &strshdr);

    strshdr.sh_name = 13;  // offset to .shstrtab name         
    strshdr.sh_type = SHT_STRTAB;  // Section Header Type String Table
    strshdr.sh_offset = 0x6000;  // Making all of these 0x1000 apart for simplicity and clarity
    strshdr.sh_size = strData->d_size;
    strshdr.sh_addralign = 1;

    gelf_update_shdr(strSection, &strshdr);
    elf_flagelf(elf, ELF_C_SET, ELF_F_LAYOUT);
    elf_update(elf, ELF_C_NULL);
    elf_update(elf, ELF_C_WRITE);

    elf_end(elf);
    close(relocatableElfFD);

    fclose(textFile);
    fclose(dataFile);
    free(textBuffer);
    free(dataBuffer);
    free(relocations);

}

%}

%token TOK_COMMA TOK_MOV TOK_PUSH TOK_SUBTRACT TOK_JUMP TOK_LBRACKET TOK_RBRACKET TOK_LEA
%token TOK_DB TOK_SYSCALL TOK_RETURN TOK_LEAVE TOK_SECTION TOK_CALL TOK_EXTERN

%union
{
    int number;
    char *string;
}

%token <number> TOK_UINT64
%token <string> TOK_REG64
%token <string> TOK_LABEL
%token <string> TOK_STRING
%token <string> TOK_SECTION_TYPE

%%

program: 
	function
        ;
function:
        function stmt_list
        |
        function TOK_LABEL stmt_list
        {
            insertSymbol(symbolTable, (char *)"FUNC", (char *)"Label", (char *)$2, (char *)currentSection, 0, 0);
        }
        | /*support null */
        ;
stmt:
        TOK_MOV value TOK_COMMA value
        {
            ParseTree *rOperand = parserStackPop(parserStack);
            ParseTree *lOperand = parserStackPop(parserStack);

            if (lOperand->type == REG64 && rOperand->type == INT64)
            {
                parserStackPush(parserStack, movImmediate64(lOperand, rOperand));
                textOffset+= 10; // 1 byte for rex, 1 byte for opcode + 8 bytes for operand
            }
            else if (lOperand->type == REG64 && rOperand->type == REG64)
            {
                parserStackPush(parserStack, movRegReg(lOperand, rOperand));
                textOffset+= 3; // 1 byte for rex, 1 byte for mov opcode + 1 byte for Mod R/M
            }

        }
        |
        TOK_SUBTRACT value TOK_COMMA value
        {
            ParseTree *rOperand = parserStackPop(parserStack);
            ParseTree *lOperand = parserStackPop(parserStack);

            if (lOperand->type == REG64 && rOperand->type == INT64)
            {
                parserStackPush(parserStack, subtractImmediate64(lOperand, rOperand));
                textOffset+= 7; // 1 byte for rex, 1 byte for opcode group, 1 byte sub from rsp, 4 bytes for operand
            }
            
        }
        |
        TOK_PUSH TOK_REG64
        {
            parserStackPush(parserStack, pushReg64($2));
            textOffset++; // 1 byte opcode for reg pushes
        }
        |
        TOK_JUMP TOK_LABEL
        {
            parserStackPush(parserStack, jmpRelative32($2, textOffset));
            textOffset+= 5; // 1 byte opcode, 4 byte relative address
        }
        |
        TOK_LEA TOK_REG64 TOK_COMMA TOK_LBRACKET TOK_LABEL TOK_RBRACKET
        {
            if (!strcmp($2, (char*)"rsi"))
            {
                parserStackPush(parserStack, loadEffectiveAddressRSI($5, textOffset));
                textOffset+= 7; // 1 byte rex, 1 byte opcode, 1 byte Mod R/M, 4 byte relative address
            }
            else if (!strcmp($2, (char*)"rdi"))
            {
                parserStackPush(parserStack, loadEffectiveAddressRDI($5, textOffset));
                textOffset+= 7; // 1 byte rex, 1 byte opcode, 1 byte Mod R/M, 4 byte relative address
            }
        }
        |
        TOK_LABEL TOK_DB TOK_STRING
        {
            if (!strcmp(currentSection, (char*)".text"))
            {
                insertSymbol(symbolTable, (char *)"LVAL", (char *)"String", (char*)$1, (char *)currentSection, textOffset, strlen($3)-2); // sub 2 for the quotes
                parserStackPush(parserStack, loadString($3));
                textOffset+= strlen($3)-2;
            }
            
            else if (!strcmp(currentSection, (char*)".data"))
            {
                insertSymbol(symbolTable, (char *)"LVAL", (char *)"String", (char*)$1, (char *)currentSection, dataOffset, strlen($3)-2); // sub 2 for the quotes
                parserStackPush(parserStack, loadString($3));
                dataOffset+= strlen($3)-2;
            }

        }
        |
        TOK_SECTION TOK_SECTION_TYPE
        {
            strcpy(currentSection, $2);
        }
        |
        TOK_SYSCALL
        {
            parserStackPush(parserStack, syscallInstruction());
            textOffset+= 2;
        }
        |
        TOK_RETURN
        {
            parserStackPush(parserStack, returnInstruction());
            textOffset+= 1;
        }
        |
        TOK_LEAVE
        {
            parserStackPush(parserStack, leaveInstruction());
            textOffset+= 1;
        }
        |
        TOK_CALL TOK_LABEL
        {
            for (int entryIterator = 0; entryIterator < symbolTable->totalEntries; ++entryIterator)
            {
                if(!strcmp(symbolTable[entryIterator].symbolName, $2) && (!strcmp(symbolTable[entryIterator].symbolType, (char*)"Extern")))
                {
                    // If this is an external function call, record it in the symbol table for use when building ELF
                    insertSymbol(symbolTable, (char *)"CALL", (char *)"RELO", (char*)$2, (char *)currentSection, textOffset, 0);
                }
 
            }

            parserStackPush(parserStack, callNear($2, textOffset));
            textOffset+= 5; // 1 byte opcode, 4 byte relative address

        }
        |
        TOK_EXTERN TOK_LABEL
        {
            insertSymbol(symbolTable, (char *)"LVAL", (char *)"Extern", (char*)$2, (char *)"NONE", 0, 0);
        }
        |
        TOK_LABEL
        {
            insertSymbol(symbolTable, (char *)"LVAL", (char *)"Label", (char*)$1, (char *)currentSection, textOffset, 0);
        }
        ;
stmt_list:
        stmt
        |
        stmt_list stmt
        ;
value:
        TOK_LABEL
        {
            parserStackPush(parserStack, stringType($1));
        }
        |
        TOK_REG64
        {
            parserStackPush(parserStack, registerType64($1));
        }
        |
        number
        ;
number:
        TOK_UINT64
        {
            printf("*******parser.y uint push value: %d\n", $1);
            parserStackPush(parserStack, intType($1));
        }
        ;
