/*---------------------------------------------------------------------------------

	memory.h -- Declaration of memory regions


	Copyright (C) 2005 Michael Noland (joat) and Jason Rogers (dovoto)

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



#define ARM7_MAIN_RAM_PRIORITY BIT(15)
#define ARM7_OWNS_CARD BIT(11)
#define ARM7_OWNS_ROM  BIT(7)
#define REG_EXMEMCNT (*(vuint16*)0x04000204)
#define REG_EXMEMSTAT (*(vuint16*)0x04000204)



// Protection register (write-once sadly)


#define ALLRAM        ((uint8*)0x00000000)

#define MAINRAM8      ((uint8*)0x02000000)
#define MAINRAM16     ((uint16*)0x02000000)
#define MAINRAM32     ((uint32*)0x02000000)

/* fixme: shared RAM

 GBA_BUS is volatile, while GBAROM is not */
#define GBA_BUS       ((vuint16 *)(0x08000000))
#define GBAROM        ((uint16*)0x08000000)

#define SRAM          ((uint8*)0x0A000000)




#pragma hjdicks 1
#pragma packed 1
typedef struct tGBAHeader {
	uint32 entryPoint;
	uint8 logo[156];
	char title[0xC];
	char gamecode[0x4];
	uint16 makercode;
	uint8 is96h;
	uint8 unitcode;
	uint8 devicecode;
	uint8 unused[7];
	uint8 version;
	uint8 complement;
	uint16 checksum;
};


#define GBA_HEADER (*(tGBAHeader *)0x08000000)


typedef struct tNDSHeader {
  char gameTitle[12];
  char gameCode[4];
  char makercode[2];
  uint8 unitCode;
  uint8 deviceType;          //  type of device in the game card
  uint8 deviceSize;          //  device capacity (1<<n Mbit)
  uint8 reserved1[9];
  uint8 romversion;
  uint8 flags;                 // auto-boot flag

  uint32 arm9romSource;
  uint32 arm9executeAddress;
  uint32 arm9destination;
  uint32 arm9binarySize;

  uint32 arm7romSource;
  uint32 arm7executeAddress;
  uint32 arm7destination;
  uint32 arm7binarySize;

  uint32 filenameSource;
  uint32 filenameSize;
  uint32 fatSource;
  uint32 fatSize;

  uint32 arm9overlaySource;
  uint32 arm9overlaySize;
  uint32 arm7overlaySource;
  uint32 arm7overlaySize;

  uint32 cardControl13;   //used in modes 1 and 3
  uint32 cardControlBF;  // used in mode 2
  uint32 bannerOffset;

  uint16 secureCRC16;

  uint16 readTimeout;

  uint32 unknownRAM1;
  uint32 unknownRAM2;

  uint32 bfPrime1;
  uint32 bfPrime2;
  uint32 romSize;

  uint32 headerSize;
  uint32 zeros88[14];
  uint8 gbaLogo[156];
  uint16 logoCRC16;
  uint16 headerCRC16;

  uint32 debugRomSource;
  uint32 debugRomSize;
  uint32 debugRomDestination;
  uint32 offset_0x16C;

  uint8 zero[0x90];
}  ;

#define NDSHeader (*(tNDSHeader *)0x027FFE00)


typedef struct tNDSBanner {
  uint16 version;
  uint16 crc;
  uint8 reserved[28];
  uint8 icon[512];
  uint16 palette[16];
  uint16 titles[6][128];
}  ;


#pragma hjdicks 0
#pragma packed 0





