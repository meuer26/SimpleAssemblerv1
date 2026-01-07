// Copyright (c) 2023-2026 Dan O’Malley
// This file is licensed under the MIT License. See LICENSE for details.

#include <stdint.h>


#define MAXSYMBOLS 100

#define MOD_RM_TO_RSI_RIP_RELATIVE (uint8_t)0x35
#define MOD_RM_TO_RDI_RIP_RELATIVE (uint8_t)0x3D
#define REX (uint8_t)0x48
#define PUSHRAX (uint8_t)0x50
#define PUSHRBP (uint8_t)0x55
#define OPCODE_GROUP_ADD_SUB_CMP (uint8_t)0x81
#define MOV_REG_TO_REG_OR_MEM (uint8_t)0x89
#define LOAD_EFFECTIVE_ADDRESS (uint8_t)0x8d
#define MOV_IMM_TO_EAX (uint8_t)0xb8
#define MOV_IMM_TO_EDX (uint8_t)0xba
#define MOV_IMM_TO_EDI (uint8_t)0xbf
#define MOV_IMM_TO_ESI (uint8_t)0xbe
#define RETURN_NEAR (uint8_t)0xc3
#define LEAVE_OPCODE (uint8_t)0xc9
#define MOD_RM_REG_RSP_TO_RBP (uint8_t)0xe5
#define CALL_NEAR (uint8_t)0xe8
#define JMP_32_BIT_RELATIVE (uint8_t)0xe9
#define MOD_RM_REG_SUB_FROM_RSP (uint8_t)0xec
#define SYSCALL_OPCODE (uint16_t)0x050f  // In reverse order for little endien