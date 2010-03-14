#include "mem.h"

#define	CPWAIT	MRC	CpMPU, 0, R2, C(2), C(0), 0; MOVW R2, R2; SUB $4, R15

/*
 * 		Entered from the boot loader with
 *		supervisor mode, interrupts disabled;
 */

TEXT _startup(SB), $-4
	MOVW		$setR12(SB), R12 	/* static base (SB) */
	MOVW		$Mach0(SB), R13
	ADD			$(KSTACK-4), R13	/* leave 4 bytes for link */
	

	MOVW		$(PsrDirq|PsrDfiq|PsrMsvc), R1	/* Switch to SVC mode */
	MOVW		R1, CPSR

	BL		main(SB)		/* jump to kernel */
dead:
	B		dead
	BL		_div(SB)			/* hack to get _div etc loaded */

GLOBL 		Mach0(SB), $KSTACK

TEXT setr13(SB), $-4
	MOVW		4(FP), R1

	MOVW		CPSR, R2
	BIC		$PsrMask, R2, R3
	ORR		R0, R3
	MOVW		R3, CPSR

	MOVW		R13, R0
	MOVW		R1, R13

	MOVW		R2, CPSR
	RET

TEXT vectors(SB), $-4
	MOVW	0x18(R15), R15			/* reset */
	MOVW	0x18(R15), R15			/* undefined */
	MOVW	0x18(R15), R15			/* SWI */
	MOVW	0x18(R15), R15			/* prefetch abort */
	MOVW	0x18(R15), R15			/* data abort */
	MOVW	0x18(R15), R15			/* reserved */
	MOVW	0x18(R15), R15			/* IRQ */
	MOVW	0x18(R15), R15			/* FIQ */

TEXT vtable(SB), $-4
	WORD	$_vsvccall(SB)			/* reset, in svc mode already */
	WORD	$_vundcall(SB)			/* undefined, switch to svc mode */
	WORD	$_vsvccall(SB)			/* swi, in svc mode already */
	WORD	$_vpabcall(SB)			/* prefetch abort, switch to svc mode */
	WORD	$_vdabcall(SB)			/* data abort, switch to svc mode */
	WORD	$_vsvccall(SB)			/* reserved */
	WORD	$_virqcall(SB)			/* IRQ, switch to svc mode */
	WORD	$_vfiqcall(SB)			/* FIQ, switch to svc mode */

TEXT _vundcall(SB), $-4			
_vund:
	MOVM.DB		[R0-R3], (R13)
	MOVW		$PsrMund, R0
	B		_vswitch

TEXT _vsvccall(SB), $-4				
_vsvc:
	MOVW.W		R14, -4(R13)
	MOVW		CPSR, R14
	MOVW.W		R14, -4(R13)
	BIC		$PsrMask, R14
	ORR		$(PsrDirq|PsrDfiq|PsrMsvc), R14
	MOVW		R14, CPSR
	MOVW		$PsrMsvc, R14
	MOVW.W		R14, -4(R13)
	B		_vsaveu

TEXT _vpabcall(SB), $-4			
_vpab:
	MOVM.DB		[R0-R3], (R13)
	MOVW		$PsrMabt, R0
	B		_vswitch

TEXT _vdabcall(SB), $-4	
_vdab:
	MOVM.DB		[R0-R3], (R13)
	MOVW		$(PsrMabt+1), R0
	B		_vswitch

TEXT _vfiqcall(SB), $-4				/* IRQ */
_vfiq:		/* FIQ */
	MOVM.DB		[R0-R3], (R13)
	MOVW		$PsrMfiq, R0
	B		_vswitch

TEXT _virqcall(SB), $-4				/* IRQ */
_virq:
	MOVM.DB		[R0-R3], (R13)
	MOVW		$PsrMirq, R0

_vswitch:					/* switch to svc mode */
	MOVW		SPSR, R1
	MOVW		R14, R2
	MOVW		R13, R3

	MOVW		CPSR, R14
	BIC		$PsrMask, R14
	ORR		$(PsrDirq|PsrDfiq|PsrMsvc), R14
	MOVW		R14, CPSR

	MOVM.DB.W 	[R0-R2], (R13)
	MOVM.DB	  	(R3), [R0-R3]

_vsaveu:						/* Save Registers */
	MOVW.W		R14, -4(R13)			/* save link */
/*	MCR		CpMMU, 0, R0, C(0), C(0), 0 */	

	SUB		$8, R13
	MOVM.DB.W 	[R0-R12], (R13)

	MOVW		R0, R0				/* gratuitous noop */

	MOVW		$setR12(SB), R12		/* static base (SB) */
	MOVW		R13, R0				/* argument is ureg */
	SUB		$8, R13				/* space for arg+lnk*/
	BL		trap(SB)


_vrfe:							/* Restore Regs */
	MOVW		CPSR, R0			/* splhi on return */
	ORR		$(PsrDirq|PsrDfiq), R0, R1
	MOVW		R1, CPSR
	ADD		$(8+4*15), R13		/* [r0-R14]+argument+link */
	MOVW		(R13), R14			/* restore link */
	MOVW		8(R13), R0
	MOVW		R0, SPSR
	MOVM.DB.S 	(R13), [R0-R14]		/* restore user registers */
	MOVW		R0, R0				/* gratuitous nop */
	ADD		$12, R13		/* skip saved link+type+SPSR*/
	RFE					/* MOVM.IA.S.W (R13), [R15] */
	
TEXT splhi(SB), $-4					
	MOVW		CPSR, R0
	ORR		$(PsrDirq), R0, R1
	MOVW		R1, CPSR
	RET

TEXT spllo(SB), $-4
	MOVW		CPSR, R0
	BIC		$(PsrDirq|PsrDfiq), R0, R1
	MOVW		R1, CPSR
	RET

TEXT splx(SB), $-4
	MOVW	$(MACHADDR), R6
	MOVW	R14, (R6)	/* m->splpc */

TEXT splxpc(SB), $-4
	MOVW		R0, R1
	MOVW		CPSR, R0
	MOVW		R1, CPSR
	RET

TEXT islo(SB), $-4
	MOVW		CPSR, R0
	AND		$(PsrDirq), R0
	EOR		$(PsrDirq), R0
	RET

TEXT splfhi(SB), $-4					
	MOVW		CPSR, R0
	ORR		$(PsrDfiq|PsrDirq), R0, R1
	MOVW		R1, CPSR
	RET

TEXT splflo(SB), $-4
	MOVW		CPSR, R0
	BIC		$(PsrDfiq), R0, R1
	MOVW		R1, CPSR
	RET

TEXT cpsrr(SB), $-4
	MOVW		CPSR, R0
	RET

TEXT spsrr(SB), $-4
	MOVW		SPSR, R0
	RET

TEXT getcallerpc(SB), $-4
	MOVW		0(R13), R0
	RET

TEXT _tas(SB), $-4
	MOVW		R0, R1
	MOVW		$0xDEADDEAD, R2
	SWPW		R2, (R1), R0
	RET

TEXT setlabel(SB), $-4
	MOVW		R13, 0(R0)		/* sp */
	MOVW		R14, 4(R0)		/* pc */
	MOVW		$0, R0
	RET

TEXT gotolabel(SB), $-4
	MOVW		0(R0), R13		/* sp */
	MOVW		4(R0), R14		/* pc */
	MOVW		$1, R0
	BX			(R14)

TEXT outs(SB), $-4
	MOVW	4(FP),R1
	WORD	$0xe1c010b0	/* STR H R1,[R0+0] */
	RET

TEXT ins(SB), $-4
	WORD	$0xe1d000b0	/* LDRHU R0,[R0+0] */
	RET

/* for devboot */
TEXT	gotopc(SB), $-4
/*
	MOVW	R0, R1
	MOVW	bootparam(SB), R0
	MOVW	R1, PC
*/
	RET

/* used by dldi to save/restore R12 (SB) */
TEXT	getr12(SB), $-4
	MOVW	R12, R0
	RET
TEXT	setr12(SB), $-4
	MOVW	R0, R12
	RET

TEXT	getcpuid(SB), $-4
	MRC		CpMPU, 0, R0, C(CpCPUID), C(0)
	RET

TEXT rdtcm(SB), $-4
 	MRC		CpMPU, 0, R0, C(CpTCM), C(1), 0
 	RET
 
TEXT wdtcm(SB), $-4
 	MCR		CpMPU, 0, R0, C(CpTCM), C(1), 0
 	RET

TEXT ritcm(SB), $-4
	MRC		CpMPU, 0, R0, C(CpTCM), C(1), 1
 	RET
 
TEXT witcm(SB), $-4
	MCR		CpMPU, 0, R0, C(CpTCM), C(1), 1
	RET

TEXT rcpctl(SB), $-4
	MRC		CpMPU, 0, R0, C(CpControl), C(0), 0
 	RET
 
TEXT wcpctl(SB), $-4
	MCR		CpMPU, 0, R0, C(CpControl), C(0), 0
	RET

TEXT mpuinit(SB), $-4
	/* turn the power on for M3 */
	MOVW	$0x04000304, R0
	MOVW	$0x8203, R1
	MOVW	R1, (R0)
	
	/* enable arm9 iwram */
	MOVW	$(VRAM + 7), R0
	MOVW	$0, R1
	MOVW	R1, (R0)

	/* disable DTCM and protection unit */
	MOVW	$(CpCaltivec|CpClateabt|CpCd32|CpCi32|CpCwb), R1
	MCR		CpMPU, 0, R1, C(CpControl), C0, 0
	
	/* Protection unit Setup added by Sasq */
	
	/* Disable cache */
	MOVW	0, R0
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C5, 0		/* Instruction cache */
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C6, 0		/* Data cache */
	
	/* Wait for write buffer to empty */
	MCR	CpMPU, 0, R0, C(CpCacheCtl), C10, 4

	/* Setup memory regions similar to Release Version */

	/* Region 0 - IO registers */
	MOVW	$(Pagesz64M | SFRZERO | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C0, 0

	/* Region 1 - Main Memory */
	MOVW	$(Pagesz4M | EWRAMZERO | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C1, 0

	/* Region 2 - iwram */
	MOVW	$(Pagesz32K | 0x037F8000 | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C2, 0

	/* Region 3 - DS Accessory (GBA Cart) */
	MOVW	$(Pagesz128M | ROMZERO | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C3, 0

	/* Region 4 - DTCM */
	MOVW	$(Pagesz16K | DTCMZERO | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C4, 0

	/* Region 5 - ITCM */
	MOVW	$(Pagesz32K | IWRAMZERO9 | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C5, 0

	/* Region 6 - System ROM */
	MOVW	$(Pagesz32K | 0x00000000 | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C6, 0

	/* Region 7 - non cacheable main ram */
	MOVW	$(Pagesz4M  | 0x02400000 | 1), R0
	MCR		CpMPU, 0, R0, C(CpPerm), C7, 0

	/* Write buffer enable */
	MOVW	$(1<<1), R0
	MCR		CpMPU, 0, R0, C(CpWBops), C0, 0

	/* DCache & ICache enable */
	MOVW	$(1<<1), R0
	MCR		CpMPU, 0, R0, C(CpCachebit), C0, 0
	MCR		CpMPU, 0, R0, C(CpCachebit), C0, 1

	/* IAccess */
	MOVW	$0x33333333, R0
	MCR		CpMPU, 0, R0, C(CpAccess), C0, 3

	/* DAccess */
	MOVW	$0x33333333, R0
	MCR		CpMPU, 0, R0, C(CpAccess), C0, 2

	/* enable icache, dcache and mpu */
	MRC		CpMPU, 0, R0, C(CpControl), C0, 0
	ORR		$(CpCrrob|CpCicache|CpCdcache),	R0
	BIC		$(CpCaltivec), R0
	MCR		CpMPU, 0, R0, C(CpControl), C0, 0

	/* enable dcache for GBA ROM */
	MOVW		$0x82, R0
	MCR		CpMPU, 0, R0, C(CpCachebit), C0, 0

	RET

/*
 * flush (invalidate) the whole icache
 */
TEXT icflushall(SB), $-4
_icflushall:
	MOVW	$0, R0
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(5), 0 /* clean icache and branch buffer */
	CPWAIT
	RET

/*
 * icache: invalidate part of icache and invalidate branch target buffer
 */
TEXT icflush(SB), $-4
	MOVW		4(FP), R1
	CMP		$(ICACHESZ/2), R1
	BGE		_icflushall
	ADD		R0, R1
	BIC		$(CACHELINESZ-1), R0
icflush1:
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(5), 1	/* clean entry */
	ADD		$CACHELINESZ, R0
	CMP		R0, R1
	BLO		icflush1
	MOVW		$0, R0
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(13), 1	/* invalidate branch target buffer */
	CPWAIT
	RET

/*
 * write back the whole data cache and drain write buffer
 */
TEXT dcflushall(SB), $-4
_dcflushall:
	MOVW		$(DCACHESZ), R0
dcflushall1:
	SUB		$CACHELINESZ, R0
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(14), 1	/* clean entry */
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(14), 2	/* flush entry */
	ADD.S	$0x4000000, R0
	BNE		dcflushall1
	MOVW		$0, R0
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(10), 4	/* drain write buffer */
	CPWAIT
	RET

/*
 *	dcache: clean and invalidate a range
 */
TEXT dcflush(SB), $-4
	CMP		$(DCACHESZ/2), R1
	BGE		_dcflushall
	ADD		R0, R1
	BIC		$(CACHELINESZ-1), R0
dcflush1:
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(14), 1	/* clean entry */
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(6), 1	/* invalidate entry */
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(10), 1
	ADD		$CACHELINESZ, R0
	CMP		R0, R1
	BLO		dcflush1
	MOVW		$0, R0
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(10), 4	/* drain write buffer */
	CPWAIT
	RET

/*
 *	dcache: invalidate a range
 */
TEXT dcinval(SB), $-4
	ADD		R0, R1, R1
	BIC		$(CACHELINESZ - 1), R0, R0
dcinval1:
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(6), 1
	ADD		$CACHELINESZ, R0
	CMP		R0, R1
	BLT		dcinval1
	CPWAIT
	RET
/*
 *	idle: enter low power mode
 */
TEXT	idle(SB), $-4
	MOVW		$0, R0
	MCR		CpMPU, 0, R0, C(CpCacheCtl), C(0), 4 /* wait for interrupt */
	RET

/*
 *	swidebug: print debug string in R0
 */
TEXT	swidebug(SB), $-4
	SWI	0xFC0000
	RET
