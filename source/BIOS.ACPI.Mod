(* Runtime support for ACPI *)
(* Copyright (C) Florian Negele *)

MODULE ACPI;

CONST HPETSignature* = 54455048H;
CONST RDSPSignature* = 2052545020445352H;

TYPE Address* = RECORD
	value: SIGNED32;
END;

TYPE Header* = RECORD
	signature-: SIGNED32;
	length-: SIGNED32;
	revision-: SIGNED8;
	checksum-: SIGNED8;
	oemID-: ARRAY 6 OF CHAR;
	oemTableID-: ARRAY 8 OF CHAR;
	oemRevision-: SIGNED32;
	creatorID-: SIGNED32;
	creatorRevision-: SIGNED32;
END;

TYPE HPET* = RECORD (Header)
	eventTimerBlockID-: SIGNED32;
	baseAddress-: RECORD
		addressSpaceID-: SIGNED8;
		registerBitWidth-: SIGNED8;
		registerBitOffset-: SIGNED8;
		reserved-: SIGNED8;
		addressLow-: Address;
		addressHigh-: Address;
	END;
	hpetNumber-: SIGNED8;
	mainCounterMinimum-: SIGNED16;
	oemAttribute-: SIGNED8;
END;

TYPE RDSP* = RECORD
	signature-: SIGNED64;
	checksum-: SIGNED8;
	oemID-: ARRAY 6 OF CHAR;
	revision-: SIGNED8;
	rsdtAddress-: Address;
END;

TYPE RSDT* = RECORD (Header)
	entry-: ARRAY 1024 OF Address;
END;

VAR rdsp- {UNTRACED} := NIL: POINTER {UNSAFE} TO RDSP;

PROCEDURE Checksum (address: ADDRESS; size: SIZE): SIGNED8;
VAR checksum := 0: SIGNED8; block {UNTRACED}: POINTER {UNSAFE} TO ARRAY MAX (SIZE) OF SIGNED8;
BEGIN {UNCOOPERATIVE, UNCHECKED} block := address; WHILE size # 0 DO DEC (size); INC (checksum, block[size]) END; RETURN checksum;
END Checksum;

PROCEDURE Convert- (CONST address: Address): ADDRESS;
VAR result: ADDRESS; masked {UNTRACED}: POINTER {UNSAFE} TO RECORD value: SET END;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result := address.value; masked := ADDRESS OF result;
	masked.value := masked.value * {0 .. SIZE OF SIGNED32 * 8 - 1};
	RETURN result;
END Convert;

PROCEDURE GetTable- (signature: SIGNED32): ADDRESS;
VAR address: ADDRESS; rsdt {UNTRACED}: POINTER {UNSAFE} TO RSDT; header {UNTRACED}: POINTER {UNSAFE} TO Header; i: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (rdsp # NIL);
	address := Convert (rdsp.rsdtAddress); rsdt := address;
	ASSERT (Checksum (rsdt, rsdt.length) = 0);
	FOR i := 0 TO (rsdt.length - 36) DIV 4 DO
		address := Convert (rsdt.entry[i]); header := address;
		IF (header.signature = signature) & (Checksum (header, header.length) = 0) THEN RETURN header END;
	END;
	RETURN NIL;
END GetTable;

PROCEDURE Initialize-;
TYPE BiosEBDA = POINTER {UNSAFE} TO RECORD val: SIGNED16 END;
VAR address := 0E0000H: ADDRESS; size := 020000H: SIZE; biosEBDA {UNTRACED}: BiosEBDA;

BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE size # 0 DO
		rdsp := address;
		IF (rdsp.signature = RDSPSignature) & (Checksum (address, 20) = 0) THEN RETURN END;
		INC (address, 16); DEC (size, 16);
	END;

	biosEBDA := 40EH;
	(* try Extended Bios Data Area EBDA *)
	address := ADDRESS(biosEBDA.val) MOD 10000H * 16;
	size := 1024;
	WHILE size # 0 DO
		rdsp := address;
		IF (rdsp.signature = RDSPSignature) & (Checksum (address, 20) = 0) THEN RETURN END;
		INC (address, 16); DEC (size, 16);
	END;
	rdsp := NIL;
END Initialize;


END ACPI.
