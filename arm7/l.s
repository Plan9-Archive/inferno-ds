#include "../mem.h"

TEXT _startup(SB), $-4
	MOVW		$setR12(SB), R12 	/* static base (SB) */

	MOVW		$(PsrMirq), R1		/* Switch to IRQ mode */
	MOVW		R1, CPSR
	MOVW		$Mach0(SB), R13
	ADD		$(KSTACK7-4), R13	/* leave 4 bytes for link */

	MOVW		$(PsrMsys), R1		/* Switch to System mode */
	MOVW		R1, CPSR
	MOVW		$Mach1(SB), R13
	ADD		$(KSTACK7-4), R13	/* leave 4 bytes for link */

	BL		main(SB)		/* jump to kernel */
dead:
	B		dead
	BL		_div(SB)			/* hack to get _div etc loaded */

GLOBL 		Mach0(SB), $KSTACK7
GLOBL 		Mach1(SB), $KSTACK7

TEXT swiSoftReset(SB), $-4
	SWI 0x000000
	RET

/* need to allow kernel to pass args on what to clear */	
TEXT	_clearregs(SB), $-4
	MOVW 	$0x4, R0
	SWI 	0x010000

TEXT swiDelay(SB), $-4
	SWI	0x030000
	RET

TEXT swiWaitForVBlank(SB), $-4
	SWI	0x050000
	RET

TEXT swiHalt(SB), $-4
	SWI	0x060000
	RET

TEXT swiSleep(SB), $-4
	SWI	0x070000
	RET

TEXT swiSetHaltCR(SB), $-4
	MOVW	R0, R2
	SWI	0x1F0000
	RET

TEXT swiDivide(SB), $-4
	SWI	0x090000
	RET

TEXT swiRemainder(SB), $-4
	SWI	0x090000
	MOVW	R1, R0
	RET

/* fixme will need to figure out more here */
TEXT swiDivMod(SB), $-4
	MOVM.DB.W	[R2-R3], (R13)
	SWI 0x090000
	MOVM.DB.W	(R13), [R2-R3]
	MOVW	R0, (R2)
	MOVW	R1, (R3)
	RET

TEXT swiCRC16(SB), $-4
	SWI	0x0E0000
	RET

/*
 *	swidebug: print debug string in R0
 */
TEXT	swidebug(SB), $-4
	SWI	0xFC0000
	RET
