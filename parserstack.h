// Copyright (c) 2023-2026 Dan O’Malley
// This file is licensed under the MIT License. See LICENSE for details.


#ifndef PARSERSTACK_HEADER
#define PARSERSTACK_HEADER

typedef struct ParserStack {
    int depth;
    void **element;
} ParserStack;

ParserStack *parserStackCreate();

void parserStackPush(ParserStack *parserStack, void *element);
void *parserStackPop(ParserStack *parserStack);

#endif