// Copyright (c) 2023-2026 Dan O’Malley
// This file is licensed under the MIT License. See LICENSE for details.


#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "constants.h"

#ifndef COMPILER_PARSETREE
#define COMPILER_PARSETREE

typedef enum { STRING, BINOP, REG64, INT64, PUSH, JMP_REL_32, LEA_RSI, LOAD_STRING, 
    SYSCALL, RETURN, LEAVE, LEA_RDI, CALL_INS } ParseTreeType;
    
typedef enum { MOV_IMM_64, MOV_REG_REG, SUB_IMM_64 } ParseTreeBinOp;

typedef struct parseTree ParseTree;

typedef struct BinOpExpr {
    ParseTreeBinOp BinOpType;
    ParseTree *lOperand;
    ParseTree *rOperand;
} BinOpExpr;    


struct parseTree {
    ParseTreeType type;
    int64_t secondaryValue;
    union {
        int64_t constantValue;
        char *string;
        BinOpExpr *binExpr;
    };
};

ParseTree *intType(int constantValue) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = INT64;
    parseTree->constantValue = constantValue;
    return parseTree;
}

ParseTree *stringType(char *string) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = STRING;
    parseTree->string = string;
    return parseTree;
}


ParseTree *registerType64(char *registerValue) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = REG64;
    parseTree->string = registerValue;
    return parseTree;
}

ParseTree *pushReg64(char *registerValue) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = PUSH;
    parseTree->string = registerValue;
    return parseTree;
}

ParseTree *loadString(char *stringValue) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = LOAD_STRING;
    parseTree->string = stringValue;
    return parseTree;
}

ParseTree *syscallInstruction() {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = SYSCALL;
    return parseTree;
}

ParseTree *returnInstruction() {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = RETURN;
    return parseTree;
}

ParseTree *leaveInstruction() {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = LEAVE;
    return parseTree;
}

ParseTree *jmpRelative32(char *string, int currentLocation) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = JMP_REL_32;
    parseTree->string = string;
    parseTree->secondaryValue = currentLocation;
    return parseTree;
}

ParseTree *callNear(char *string, int currentLocation) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = CALL_INS;
    parseTree->string = string;
    parseTree->secondaryValue = currentLocation;
    return parseTree;
}

ParseTree *loadEffectiveAddressRSI(char *targetLabel, int currentLocation) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = LEA_RSI;
    parseTree->string = targetLabel;
    parseTree->secondaryValue = currentLocation;
    return parseTree;
}

ParseTree *loadEffectiveAddressRDI(char *targetLabel, int currentLocation) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    parseTree->type = LEA_RDI;
    parseTree->string = targetLabel;
    parseTree->secondaryValue = currentLocation;
    return parseTree;
}


ParseTree *movImmediate64(ParseTree *lOperand, ParseTree *rOperand) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    BinOpExpr *binOpExpr = malloc(sizeof(binOpExpr));
    binOpExpr->BinOpType = MOV_IMM_64;
    // the operands need to be flipped due to the last one was popped first
    binOpExpr->lOperand = rOperand;
    binOpExpr->rOperand = lOperand;
    parseTree->type = BINOP;
    parseTree->binExpr = binOpExpr;
    return parseTree;
}

ParseTree *movRegReg(ParseTree *lOperand, ParseTree *rOperand) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    BinOpExpr *binOpExpr = malloc(sizeof(binOpExpr));
    binOpExpr->BinOpType = MOV_REG_REG;
    // the operands need to be flipped due to the last one was popped first
    binOpExpr->lOperand = rOperand;
    binOpExpr->rOperand = lOperand;
    parseTree->type = BINOP;
    parseTree->binExpr = binOpExpr;
    return parseTree;
}

ParseTree *subtractImmediate64(ParseTree *lOperand, ParseTree *rOperand) {
    ParseTree *parseTree = malloc(sizeof(parseTree));
    BinOpExpr *binOpExpr = malloc(sizeof(binOpExpr));
    binOpExpr->BinOpType = SUB_IMM_64;
    // the operands need to be flipped due to the last one was popped first
    binOpExpr->lOperand = rOperand;
    binOpExpr->rOperand = lOperand;
    parseTree->type = BINOP;
    parseTree->binExpr = binOpExpr;
    return parseTree;
}

#endif