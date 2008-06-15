/*---------------------------------------------------------------------------------
	$Id: card.c,v 1.11 2007/07/09 15:54:33 wntrmute Exp $

	Copyright (C) 2005
		Michael Noland (joat)
		Jason Rogers (dovoto)
		Dave Murphy (WinterMute)

	This software is provided 'as-is', without any express or implied
	warranty.  In no event will the authors be held liable for any
	damages arising from the use of this software.

	Permission is granted to anyone to use this software for any
	purpose, including commercial applications, and to alter it and
	redistribute it freely, subject to the following restrictions:

	1.	The origin of this software must not be misrepresented; you
		must not claim that you wrote the original software. If you use
		this software in a product, an acknowledgment in the product
		documentation would be appreciated but is not required.
	2.	Altered source versions must be plainly marked as such, and
		must not be misrepresented as being the original software.
	3.	This notice may not be removed or altered from any source
		distribution.


---------------------------------------------------------------------------------*/
#include "u.h"
#include "mem.h"
#include "io.h"
#include <kern.h>
#include "arm7/jtypes.h"
#include "arm7/card.h"

#define DMA_SRC(ch)	((DmaReg*)(DMAREG + (ch)))->src
#define DMA_DEST(ch)	((DmaReg*)(DMAREG + (ch)))->dst
#define DMA_CR(ch)	((DmaReg*)(DMAREG + (ch)))->ctl

#define DMA_ENABLE	Dmaena
#define DMA_START_CARD	Dmastartcard
#define DMA_32_BIT	Dma32bit
#define DMA_REPEAT	Dmarepeat
#define DMA_SRC_FIX	Dmasrcfix

void
cardWriteCommand(const uint8 * cmd){
	int index;

	CARD_CR1H = CARD_CR1_ENABLE | CARD_CR1_IRQ;

	for (index = 0; index < 8; index++) {
		CARD_COMMAND[7-index] = cmd[index];
	}
}

void
cardPolledTransfer(uint32 flags, uint32 * dst, uint32 len, const uint8 * cmd){
	u32 data;
	uint32 * target;

	CARD_CR2 = flags;
	cardWriteCommand(cmd);
	target = dst + len;
	do {
		// Read data if available
		if (CARD_CR2 & CARD_DATA_READY) {
			data=CARD_DATA_RD;
			if (dst < target)
				*dst = data;
			dst++;
		}
	} while (CARD_CR2 & CARD_BUSY);
}

void
cardStartTransfer(const uint8 * cmd, uint32 * dst, int ch, uint32 flags){
	cardWriteCommand(cmd);

	// Set up a DMA channel to transfer a word every time the card makes one
	DMA_SRC(ch) = (uint32)&CARD_DATA_RD;
	DMA_DEST(ch) = (uint32)dst;
	DMA_CR(ch) = DMA_ENABLE | DMA_START_CARD | DMA_32_BIT | DMA_REPEAT | DMA_SRC_FIX | 0x0001;;

	CARD_CR2 = flags;
}


uint32
cardWriteAndRead(const uint8 * cmd, uint32 flags){
	cardWriteCommand(cmd);
	CARD_CR2 = flags | CARD_ACTIVATE | CARD_nRESET | 0x07000000;
	while (!(CARD_CR2 & CARD_DATA_READY)) ;
	return CARD_DATA_RD;
}


void
cardRead00(uint32 addr, uint32 * dst, uint32 len, uint32 flags){
	uint8 cmd[8];

	cmd[7] = 0;
	cmd[6] = (addr >> 24) & 0xff;
	cmd[5] = (addr >> 16) & 0xff;
	cmd[4] = (addr >> 8) & 0xff;
	cmd[3] = (addr >> 0) & 0xff;
	cmd[2] = 0;
	cmd[1] = 0;
	cmd[0] = 0;
	cardPolledTransfer(flags, dst, len, cmd);
}


void
cardReadHeader(uint8 * header){
	cardRead00(0, (uint32 *)header, 512, 0xA93F1FFF);
}


int
cardReadID(uint32 flags){
	uint8 command[8] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90};
	return cardWriteAndRead(command, flags);
}


static
void EepromWaitBusy(void){
	while (CARD_CR1 & /*BUSY*/0x80);
}

uint8
cardEepromReadID(uint8 i){
    return cardEepromCommand(/*READID*/0xAB, i&1);
}

uint8
cardEepromCommand(uint8 command, uint32 address){
    uint8 retval;
    int k;
    CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;

    CARD_CR1 = 0xFFFF;
    CARD_EEPDATA = command;

    EepromWaitBusy();

    CARD_EEPDATA = (address >> 16) & 0xFF;
    EepromWaitBusy();

    CARD_EEPDATA = (address >> 8) & 0xFF;
    EepromWaitBusy();

    CARD_EEPDATA = (address) & 0xFF;
    EepromWaitBusy();

    for(k=0;k<256;k++)
    {
        retval = CARD_EEPDATA;
        if(retval!=0xFF)
            break;
        EepromWaitBusy();
    }

    CARD_CR1 = /*MODE*/0x40;
    return retval;
}

int
cardEepromGetType(void)
{
        uint8 c00;
        uint8 c05;
        uint8 c9f;
        uint8 c03;

#ifdef ARM9
        sysSetBusOwners(BUS_OWNER_ARM9, BUS_OWNER_ARM9);
#endif

        c03=cardEepromCommand(0x03,0);
        c05=cardEepromCommand(0x05,0);
        c9f=cardEepromCommand(0x9f,0);
        c00=cardEepromCommand(0x00,0);

        if((c00==0x00) && (c9f==0x00)) return 0; // PassMe? 
        if((c00==0xff) && (c05==0xff) && (c9f==0xff))return -1;

        if((c00==0xff) &&  (c05 & 0xFD) == 0xF0 && (c9f==0xff))return 1;
        if((c00==0xff) &&  (c05 & 0xFD) == 0x00 && (c9f==0xff))return 2;
        if((c00==0xff) &&  (c05 & 0xFD) == 0x00 && (c9f==0x00))return 3;
        if((c00==0xff) &&  (c05 & 0xFD) == 0x00 && (c9f==0x12))return 3;        //      NEW TYPE 3
        if((c00==0xff) &&  (c05 & 0xFD) == 0x00 && (c9f==0x13))return 3;        //      NEW TYPE 3+  4Mbit
        if((c00==0xff) &&  (c05 & 0xFD) == 0x00 && (c9f==0x14))return 3;        //      NEW TYPE 3++ 8Mbit MK4-FLASH Memory

        return 0;
}

uint32
cardEepromGetSize(void){

    int type = cardEepromGetType();

    if(type == -1)
        return 0;
    if(type == 0)
        return 8192;
    if(type == 1)
        return 512;
    if(type == 2) {
        static const uint32 offset0 = (8*1024-1);        //      8KB
        static const uint32 offset1 = (2*8*1024-1);      //      16KB
        u8 buf1;     //      +0k data        read -> write
        u8 buf2;     //      +8k data        read -> read
        u8 buf3;     //      +0k ~data          write
        u8 buf4;     //      +8k data new    comp buf2
        cardReadEeprom(offset0,&buf1,1,type);
        cardReadEeprom(offset1,&buf2,1,type);
        buf3=~buf1;
        cardWriteEeprom(offset0,&buf3,1,type);
        cardReadEeprom (offset1,&buf4,1,type);
        cardWriteEeprom(offset0,&buf1,1,type);
        if(buf4!=buf2)      //      +8k
            return 8*1024;  //       8KB(64kbit)
        else
            return 64*1024; //      64KB(512kbit)
    }
    if(type == 3) {
        uint8 c9f;
        c9f=cardEepromCommand(0x9f,0);

        if(c9f==0x14)         
            return 1024*1024; //   NEW TYPE 3++ 8Mbit(1024KByte)

        if(c9f==0x13)         
            return 512*1024;  //   NEW TYPE 3+ 4Mbit(512KByte)

        return 256*1024;      //   TYPE 3  2Mbit(256KByte)
    }

    return 0;
}


void
cardReadEeprom(uint32 address, uint8 *data, uint32 length, uint32 addrtype){

    CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;
    CARD_EEPDATA = 0x03 | ((addrtype == 1) ? address>>8<<3 : 0);
    EepromWaitBusy();

    if (addrtype == 3) {
        CARD_EEPDATA = (address >> 16) & 0xFF;
	    EepromWaitBusy();
    } 
    
    if (addrtype >= 2) {
        CARD_EEPDATA = (address >> 8) & 0xFF;
	    EepromWaitBusy();
    }


	CARD_EEPDATA = (address) & 0xFF;
    EepromWaitBusy();

    while (length > 0) {
        CARD_EEPDATA = 0;
        EepromWaitBusy();
        *data++ = CARD_EEPDATA;
        length--;
    }

    EepromWaitBusy();
    CARD_CR1 = /*MODE*/0x40;
}


void
cardWriteEeprom(uint32 address, uint8 *data, uint32 length, uint32 addrtype){

	uint32 address_end = address + length;
	int i;
    int maxblocks = 32;
    if(addrtype == 1) maxblocks = 16;
    if(addrtype == 2) maxblocks = 32;
    if(addrtype == 3) maxblocks = 256;

	while (address < address_end) {
		// set WEL (Write Enable Latch)
		CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;
		CARD_EEPDATA = 0x06; EepromWaitBusy();
		CARD_CR1 = /*MODE*/0x40;

		// program maximum of 32 bytes
		CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;

        if(addrtype == 1) {
        //  WRITE COMMAND 0x02 + A8 << 3
            CARD_EEPDATA = 0x02 | (address & BIT(8)) >> (8-3) ;
            EepromWaitBusy();
            CARD_EEPDATA = address & 0xFF;
            EepromWaitBusy();
        }
        else if(addrtype == 2) {
            CARD_EEPDATA = 0x02;
            EepromWaitBusy();
            CARD_EEPDATA = address >> 8;
            EepromWaitBusy();
            CARD_EEPDATA = address & 0xFF;
            EepromWaitBusy();
        }
        else if(addrtype == 3) {
            CARD_EEPDATA = 0x02;
            EepromWaitBusy();
            CARD_EEPDATA = (address >> 16) & 0xFF;
            EepromWaitBusy();
            CARD_EEPDATA = (address >> 8) & 0xFF;
            EepromWaitBusy();
            CARD_EEPDATA = address & 0xFF;
            EepromWaitBusy();
        }

		for (i=0; address<address_end && i<maxblocks; i++, address++) { 
            CARD_EEPDATA = *data++; 
            EepromWaitBusy(); 
        }
		CARD_CR1 = /*MODE*/0x40;

		// wait programming to finish
		CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;
		CARD_EEPDATA = 0x05; EepromWaitBusy();
		do { CARD_EEPDATA = 0; EepromWaitBusy(); } while (CARD_EEPDATA & 0x01);	// WIP (Write In Progress) ?
        EepromWaitBusy();
        CARD_CR1 = /*MODE*/0x40;
	}
}


//  Chip Erase : clear FLASH MEMORY (TYPE 3 ONLY)
void
cardEepromChipErase(void) {
    int sz;
    sz=cardEepromGetSize();
    cardEepromSectorErase(0x00000);
    cardEepromSectorErase(0x10000);
    cardEepromSectorErase(0x20000);
    cardEepromSectorErase(0x30000);
    if(sz==512*1024)
    {
        cardEepromSectorErase(0x40000);
        cardEepromSectorErase(0x50000);
        cardEepromSectorErase(0x60000);
        cardEepromSectorErase(0x70000);
    }
}

//  COMMAND Sec.erase 0xD8
void
cardEepromSectorErase(uint32 address)
{
        // set WEL (Write Enable Latch)
        CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;
        CARD_EEPDATA = 0x06;
        EepromWaitBusy();

        CARD_CR1 = /*MODE*/0x40;

        // SectorErase 0xD8
        CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;
        CARD_EEPDATA = 0xD8;
        EepromWaitBusy();
        CARD_EEPDATA = (address >> 16) & 0xFF;
        EepromWaitBusy();
        CARD_EEPDATA = (address >> 8) & 0xFF;
        EepromWaitBusy();
        CARD_EEPDATA = address & 0xFF;
        EepromWaitBusy();

        CARD_CR1 = /*MODE*/0x40;

        // wait erase to finish
        CARD_CR1 = /*E*/0x8000 | /*SEL*/0x2000 | /*MODE*/0x40;
        CARD_EEPDATA = 0x05;
        EepromWaitBusy();

        do
        {
            CARD_EEPDATA = 0;
            EepromWaitBusy();
        } while (CARD_EEPDATA & 0x01);  // WIP (Write In Progress) ?
        CARD_CR1 = /*MODE*/0x40;
}
