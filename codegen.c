// Copyright (c) 2023-2026 Dan O’Malley
// This file is licensed under the MIT License. See LICENSE for details.


#include "stdio.h"
#include "parsetree.c"
#include <string.h>
#include "symboltable.h"
#include <stdint.h>
#include "constants.h"


void codeGen(FILE *textFile, FILE *dataFile, ParseTree *parseTree, struct SymbolTable * symbolTable) 
{

    if (parseTree->type == INT64) {
        printf("codegen.c constantValue: %ld\n", parseTree->constantValue);
        int64_t value = parseTree->constantValue;
        fwrite(&value, sizeof(int64_t), 1, textFile);

    }
    else if (parseTree->type == SYSCALL) {

        uint16_t value = SYSCALL_OPCODE;
        fwrite(&value, sizeof(uint16_t), 1, textFile);

    }
    else if (parseTree->type == RETURN) {

        uint8_t value = RETURN_NEAR;
        fwrite(&value, sizeof(uint8_t), 1, textFile);

    }
    else if (parseTree->type == LEAVE) {

        uint8_t value = LEAVE_OPCODE;
        fwrite(&value, sizeof(uint8_t), 1, textFile);

    }
    else if (parseTree->type == REG64) {
        printf("codegen.c regValue: %s\n", parseTree->string);

        if(!strcmp(parseTree->string, (const char *)"rax"))
        {
            char rex = REX;
            fwrite(&rex, sizeof(uint8_t), 1, textFile);

            char reg = MOV_IMM_TO_EAX;
            fwrite(&reg, sizeof(uint8_t), 1, textFile);
        }
        else if(!strcmp(parseTree->string, (const char *)"rdx"))
        {
            char rex = REX;
            fwrite(&rex, sizeof(uint8_t), 1, textFile);

            char reg = MOV_IMM_TO_EDX;
            fwrite(&reg, sizeof(uint8_t), 1, textFile);
        }
        else if(!strcmp(parseTree->string, (const char *)"rdi"))
        {
            char rex = REX;
            fwrite(&rex, sizeof(uint8_t), 1, textFile);

            char reg = MOV_IMM_TO_EDI;
            fwrite(&reg, sizeof(uint8_t), 1, textFile);
        }
        else if(!strcmp(parseTree->string, (const char *)"rsi"))
        {
            char rex = REX;
            fwrite(&rex, sizeof(uint8_t), 1, textFile);

            char reg = MOV_IMM_TO_ESI;
            fwrite(&reg, sizeof(uint8_t), 1, textFile);
        }

    }
    else if (parseTree->type == PUSH) {
        printf("codegen.c regValue: %s\n", parseTree->string);

        if(!strcmp(parseTree->string, (const char *)"rax"))
        {
            char reg = PUSHRAX;
            fwrite(&reg, sizeof(uint8_t), 1, textFile);
        }
        else if(!strcmp(parseTree->string, (const char *)"rbp"))
        {
            char reg = PUSHRBP;
            fwrite(&reg, sizeof(uint8_t), 1, textFile);
        }

    }
    else if (parseTree->type == JMP_REL_32) {
       
        for(int x = 0; x < symbolTable->totalEntries; ++x)
        {
            
            if(!strcmp(symbolTable[x].symbolName, parseTree->string))
            {
                char opcode = JMP_32_BIT_RELATIVE;
                fwrite(&opcode, sizeof(uint8_t), 1, textFile);

                int relativeAddress = symbolTable[x].symbolLocation - parseTree->secondaryValue - 5; // minus 5 (size of this instruction)
                fwrite(&relativeAddress, sizeof(int32_t), 1, textFile);
            }
        }

    }
    else if (parseTree->type == CALL_INS) {
       
        for(int x = 0; x < symbolTable->totalEntries; ++x)
        {
            
            if(!strcmp(symbolTable[x].symbolName, parseTree->string) && !strcmp(symbolTable[x].symbolType, (char*)"Label"))
            {
                char opcode = CALL_NEAR;
                fwrite(&opcode, sizeof(uint8_t), 1, textFile);

                int relativeAddress = symbolTable[x].symbolLocation - parseTree->secondaryValue - 5; // minus 5 (size of this instruction)
                fwrite(&relativeAddress, sizeof(int32_t), 1, textFile);
            }
            else if(!strcmp(symbolTable[x].symbolName, parseTree->string) && !strcmp(symbolTable[x].symbolType, (char*)"Extern"))
            {
                // Update symbol table where the call extern label was so I can use it in the 
                // ELF relocation code in parser.y
                symbolTable[x].symbolLocation = parseTree->secondaryValue;

                char opcode = CALL_NEAR;
                fwrite(&opcode, sizeof(uint8_t), 1, textFile);

                int relativeAddress = 0; // This 
                fwrite(&relativeAddress, sizeof(int32_t), 1, textFile);

            }
        }

    }
    else if (parseTree->type == LEA_RSI) {
       
        for(int x = 0; x < symbolTable->totalEntries; ++x)
        {
            
            if(!strcmp(symbolTable[x].symbolName, parseTree->string))
            {
                char rex = REX;
                fwrite(&rex, sizeof(uint8_t), 1, textFile);
                
                char opcode = LOAD_EFFECTIVE_ADDRESS;
                fwrite(&opcode, sizeof(uint8_t), 1, textFile);

                char modrm = MOD_RM_TO_RSI_RIP_RELATIVE;
                fwrite(&modrm, sizeof(uint8_t), 1, textFile);

                if (!strcmp(symbolTable[x].sectionName, (char*)".text"))
                {
                    int relativeAddress = symbolTable[x].symbolLocation - parseTree->secondaryValue - 7; // minus 5 (size of this instruction)
                    fwrite(&relativeAddress, sizeof(int32_t), 1, textFile);
                }

                else if (!strcmp(symbolTable[x].sectionName, (char*)".data"))
                {
                    int relativeAddress = (0x1000 - parseTree->secondaryValue - 7) + symbolTable[x].symbolLocation; // minus 5 (size of this instruction)
                    fwrite(&relativeAddress, sizeof(int32_t), 1, textFile);
                }

            }
        }

    }
    else if (parseTree->type == LEA_RDI) {
       
        for(int x = 0; x < symbolTable->totalEntries; ++x)
        {
            
            if(!strcmp(symbolTable[x].symbolName, parseTree->string))
            {
                char rex = REX;
                fwrite(&rex, sizeof(uint8_t), 1, textFile);
                
                char opcode = LOAD_EFFECTIVE_ADDRESS;
                fwrite(&opcode, sizeof(uint8_t), 1, textFile);

                char modrm = MOD_RM_TO_RDI_RIP_RELATIVE;
                fwrite(&modrm, sizeof(uint8_t), 1, textFile);

                if (!strcmp(symbolTable[x].sectionName, (char*)".text"))
                {
                    int relativeAddress = symbolTable[x].symbolLocation - parseTree->secondaryValue - 7; // minus 5 (size of this instruction)
                    fwrite(&relativeAddress, sizeof(int32_t), 1, textFile);
                }

                else if (!strcmp(symbolTable[x].sectionName, (char*)".data"))
                {
                    // data segment is 0x2000 away from text
                    int relativeAddress = (0x2000 - parseTree->secondaryValue - 7) + symbolTable[x].symbolLocation; // minus 5 (size of this instruction)
                    fwrite(&relativeAddress, sizeof(int32_t), 1, textFile);
                }

            }
        }

    }
    else if (parseTree->type == LOAD_STRING) {

        char *literalString = parseTree->string;
        int stringLength = strlen(literalString) - 2; // This is the remove the begin and end quote
        literalString[strlen(literalString)-1] = '\0'; //Remove end quote
        literalString++; // Move the pointer forward to remove first quote

        while (*literalString != '\0')
        {
            if (*literalString == '\\' && *(literalString+1) == 'n')
            {
                uint8_t newLine = 0xa;
                fwrite(&newLine, 1, 1, dataFile);
                literalString++; //consume the escape byte and the increment below takes care of the 'n'
            }
            else
            {
                fwrite(literalString, 1, 1, dataFile);
            }

            literalString++;
        }

        // Add null terminator
        uint8_t nullTerminator = 0x0;
        fwrite(&nullTerminator, 1, 1, dataFile);

    }  
    else if (parseTree->type == STRING) {
        printf("codegen.c stringValue: %s\n", parseTree->string);

        for(int x = 0; x < symbolTable->totalEntries; ++x)
        {
            if(!strcmp(symbolTable[x].symbolName, parseTree->string))
            {
                printf("codegen.c found variable in symbol table: %d\n", x);
            }
        }

    }  
    else if (parseTree->type == BINOP) {
        BinOpExpr *binOpExpr = parseTree->binExpr;

        if (binOpExpr->BinOpType == MOV_IMM_64) {

            codeGen(textFile, dataFile, binOpExpr->rOperand, symbolTable);
            codeGen(textFile, dataFile, binOpExpr->lOperand, symbolTable);
        }
        else if (binOpExpr->BinOpType == MOV_REG_REG) {

            ParseTree *reg1 = binOpExpr->rOperand;
            ParseTree *reg2 = binOpExpr->lOperand;

            if (!strcmp((char*)reg1->string, (char*)"rbp") && !strcmp((char*)reg2->string, (char*)"rsp"))
            {
                
                char rex = REX;
                fwrite(&rex, sizeof(uint8_t), 1, textFile);

                char opcode = MOV_REG_TO_REG_OR_MEM;
                fwrite(&opcode, sizeof(uint8_t), 1, textFile);

                char modrm = MOD_RM_REG_RSP_TO_RBP;
                fwrite(&modrm, sizeof(uint8_t), 1, textFile);

            }
            
        }
        else if (binOpExpr->BinOpType == SUB_IMM_64) {

            ParseTree *reg1 = binOpExpr->rOperand;
            ParseTree *value = binOpExpr->lOperand;

            if (!strcmp((char*)reg1->string, (char*)"rsp"))
            {
                char rex = REX;
                fwrite(&rex, sizeof(uint8_t), 1, textFile);

                char opcode = OPCODE_GROUP_ADD_SUB_CMP;
                fwrite(&opcode, sizeof(uint8_t), 1, textFile);

                char modrm = MOD_RM_REG_SUB_FROM_RSP;
                fwrite(&modrm, sizeof(uint8_t), 1, textFile);

                // forcing a 32-bit value to write since subtracting 64-bit value from
                // RSP isn't really supported in x86.
                int32_t valueToWrite = value->constantValue;
                fwrite(&valueToWrite, sizeof(int32_t), 1, textFile);

            }
            
        }

    }

}
