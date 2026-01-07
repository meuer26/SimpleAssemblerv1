// Copyright (c) 2023-2026 Dan O’Malley
// This file is licensed under the MIT License. See LICENSE for details.


#include <stdlib.h>
#include <stdio.h>
#include "parserstack.h"


ParserStack *parserStackCreate() {
    ParserStack *parserStack = malloc(sizeof(ParserStack));
    parserStack->depth = 0;
    parserStack->element = 0;
    return parserStack;
}

void parserStackPush(ParserStack *parserStack, void *element) {
    parserStack->depth = parserStack->depth + 1;
    parserStack->element = realloc(parserStack->element, 
        (parserStack->depth * sizeof *parserStack->element));
    parserStack->element[parserStack->depth - 1] = element;
}

void * parserStackPop(ParserStack *parserStack) {
    // This function returns a void pointer to the element
    // This is important because the element can be of any type
    // A void pointer allows it to be a pointer to any type
    
    parserStack->depth = parserStack->depth - 1;
    void *element = parserStack->element[parserStack->depth];
    parserStack->element = realloc(parserStack->element, 
        (parserStack->depth * sizeof *parserStack->element));
    return element;
}