.section .UserEnter.text,"ax"
.org 0
.literal_position
	.literal .l_text_start, _text_start
	.literal .l_dispatch_table, 0x3fffc000

.global call_user_start
call_user_start:
	j call_user_start_local

/*
exceptions share the use of two exception vectors. These two vector addresses,
UserExceptionVector and KernelExceptionVector are both configuration options. The exception-handling process saves the address of the instruction causing the
exception into special register EPC[1] and the cause code for the exception into special
register EXCCAUSE. Interrupts and exceptions are precise, so that on returning from the
exception handler, program execution can continue exactly where it left off.
*/

.begin no-transform

.org 0x10
.global _DebugExceptionVector
_DebugExceptionVector:
	/* PS.EXCM == 1, Level 2 Exception */
	addi	a1,  a1, -0x60  /* Reserve 0x60 for exception frame */
	s32i.n	a0,  a1, 0x0c
	addi	a0,  a1, 0x60
	s32i.n	a0,  a1, 0x10
	s32i.n	a2,  a1, 0x14
	j _DebugExceptionCont

.org 0x20
/* A configured Xtensa LX processor can have as many as 6 level-sensitive or edge-triggered high-priority interrupts. One NMI or non-maskable interrupt can also be configured. The processor can have as many as six high-priority interrupt levels and each
high-priority interrupt level has its own interrupt vector. Each high-priority interrupt level
also has its own dedicated set of three special registers (EPC, EPS, and EXCSAVE) used
to save the processor state */
.global _NMIExceptionVector
_NMIExceptionVector:
	/* Level 3 Exception */
	wsr	a3, EXCSAVE3
	j _NMILevelVector

.org 0x30
.global _KernelExceptionVector
_KernelExceptionVector:
	/* Exceptions with PS.UM == 0, PS.EXCM == 0, Level 1 */
	/* The following should be compatible with the rom handlers */
	addmi	a1, a1, -0x100   /* reserve stack space, must match rom impl _xtos_return_from_exc  */
	s32i.n	a2, a1, 0x14
	s32i.n	a3, a1, 0x18
	s32i.n	a4, a1, 0x1c
	rsr	a2, EXCCAUSE     /* read into a2 since it is also the first handler argument */
	l32r	a3, .l_dispatch_table
	addx4	a3, a2, a3       /* calculate address of handler in dispatch table */
	l32i.n	a3, a3, 0        /* load handler address */
	jx	a3               /* jump to handler */

.org 0x50
.global _UserExceptionVector
_UserExceptionVector:
	/* Exceptions with PS.UM == 1, PS.EXCM == 0, Level 1 */
	/* The following should be compatible with the rom handlers */
	addmi	a1, a1, -0x100   /* reserve stack space, must match rom impl _xtos_return_from_exc  */
	s32i.n	a2, a1, 0x14
	s32i.n	a3, a1, 0x18
	s32i.n	a4, a1, 0x1c
	rsr	a2, EXCCAUSE     /* read into a2 since it is also the first handler argument */
	l32r	a3, .l_dispatch_table
	addx4	a3, a2, a3       /* calculate address of handler in dispatch table */
	l32i.n	a3, a3, 0        /* load handler address */
	jx	a3               /* jump to handler */

.org 0x70
.global _DoubleExceptionVector
_DoubleExceptionVector:
	movi.n a2, 7
	j _panic

.org 0x80
_ResetVector: /* really unused here, since reset should jump to ROM directly */
	movi.n a2, 8
	j _panic

.end no-transform

.section .text,"ax"
.literal_position
	.literal .l_user_start, relib_user_start
	.literal .l_ets_run, ets_run
	.literal .l_panic_stack, 0x40000000
	.literal .l_panic_handler, panic_handler
	.literal .l_handle_debug_exception, handle_debug_exception

_panic:
	movi.n a1, 0
	wsr a1, LITBASE
	esync
	l32r a1, .l_panic_stack
	rsr  a3, EPC1
	rsr  a4, DEPC
	l32r a0, .l_panic_handler
	jx a0

_DebugExceptionCont:
	/* continue storing registers, a0-a2 already saved on stack */
	s32i.n	a3,  a1, 0x18
	s32i.n	a4,  a1, 0x1c
	s32i.n	a5,  a1, 0x20
	s32i.n	a6,  a1, 0x24
	s32i.n	a7,  a1, 0x28
	s32i.n	a8,  a1, 0x2c
	s32i.n	a9,  a1, 0x30
	s32i.n	a10, a1, 0x34
	s32i.n	a11, a1, 0x38
	s32i.n	a12, a1, 0x3c
	s32i	a13, a1, 0x40
	s32i	a14, a1, 0x44
	s32i	a15, a1, 0x48

	rsr	a0,  EPC2
	rsr	a2,  EPS2
	rsr	a3,  SAR
	s32i	a0,  a1, 0x00
	s32i	a2,  a1, 0x04
	s32i	a3,  a1, 0x08

	/* Clear EXCM, so unaligned access in C code can be handled by the regular exception handlers */
	rsr	a2,  ps
	addi	a2,  a2, -0x10  /* EXCM bit */
	wsr	a2,  ps
	rsync

	rsr	a3,  DEBUGCAUSE
	s32i	a3,  a1, 0x4c
	mov.n   a2,  a1
	l32r	a0, .l_handle_debug_exception
	callx0	a0

	l32i	a3,  a1, 0x08
	l32i	a2,  a1, 0x04
	l32i	a0,  a1, 0x00
	wsr	a3,  SAR
	wsr	a2,  EPS2
	wsr	a0,  EPC2
	rsync

	l32i	a15, a1, 0x48
	l32i	a14, a1, 0x44
	l32i	a13, a1, 0x40
	l32i.n	a12, a1, 0x3c
	l32i.n	a11, a1, 0x38
	l32i.n	a10, a1, 0x34
	l32i.n	a9,  a1, 0x30
	l32i.n	a8,  a1, 0x2c
	l32i.n	a7,  a1, 0x28
	l32i.n	a6,  a1, 0x24
	l32i.n	a5,  a1, 0x20
	l32i.n	a4,  a1, 0x1c
	l32i.n	a3,  a1, 0x18
	l32i.n	a2,  a1, 0x14
	l32i.n	a0,  a1, 0x0c
	l32i.n	a1,  a1, 0x10  /* Allows modifying a1 (stack pointer) from debug exception handler */
	rfi 2

call_user_start_local:
	l32r	a0, .l_text_start
	wsr	a0, VECBASE

	/* Load some constants we need */
	movi	a0, 1
	slli	a3, a0, 29  /* 0x2000000 as increment */
	add.n	a1, a3, a3  /* set SP to 0x40000000 to maximise stack size */
	add.n	a2, a1, a1  /* 0x8000000 as base */

	/* re-confgiure region protect for addresses >= 0x80000000 to fault on access */
	/* ROM has already set up good values for the other ranges */
	movi.n	a4, 0xf
_region_protect_loop:
	or	a0, a2, a4  /* 0x?00000f as value */
	witlb	a0, a2
	wdtlb	a0, a2
	add	a2, a2, a3  /* increment base */
	bnez	a2, _region_protect_loop
	isync

	l32r	a0, .l_user_start
	callx0	a0

	l32r	a0, .l_ets_run
	jx	a0
