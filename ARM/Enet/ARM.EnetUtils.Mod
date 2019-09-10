MODULE EnetUtils;

IMPORT
	S := SYSTEM;

TYPE
	Int8 = SIGNED8;
	Int16 = SIGNED16;
	Int32 = SIGNED32;

	UnalignedInt32* = ARRAY 4 OF Int8;

	(** Switch endianness of a 16-bit integer *)
	PROCEDURE -SwitchEndianness16*(x: Int16): Int16;
	CODE
		LDRH R0, [SP,#x]
		REV16 R0, R0
		ADD SP, SP, #4 ; account for 4-byte alignment done by the compiler
	(*TYPE Byte16 = ARRAY 2 OF Int8;
	VAR xx, yy: Byte16;
	BEGIN
		xx := S.VAL(Byte16,x);
		yy[0] := xx[1]; yy[1] := xx[0];
		RETURN S.VAL(Int16,yy);*)
	END SwitchEndianness16;

	(** Switch endianness of a 32-bit integer *)
	PROCEDURE -SwitchEndianness32*(x: Int32): Int32;
	CODE
		LDR R0, [SP,#x]
		REV R0, R0
		ADD SP, SP, #4
	(*TYPE Byte32 = ARRAY 4 OF Int8;
	VAR xx, yy: Byte32;
	BEGIN
		xx := S.VAL(Byte32,x);
		yy[0] := xx[3]; yy[1] := xx[2]; yy[2] := xx[1]; yy[3] := xx[0];
		RETURN S.VAL(Int32,yy);*)
	END SwitchEndianness32;

	OPERATOR -":="*(VAR y: Int32; x: UnalignedInt32);
	CODE

		LDR R0, [SP,#y]

		LDRB R1, [SP,#x]
		LDRB R2, [SP,#x+1]
		LDRB R3, [SP,#x+2]
		LDRB R4, [SP,#x+3]

		ADD R1, R1, R2, LSL #8
		ADD R1, R1, R3, LSL #16
		ADD R1, R1, R4, LSL #24

		STR R1, [R0,#0]

		ADD SP, SP, 8
	(*BEGIN
		S.MOVE(ADDRESSOF(x),ADDRESSOF(y),SIZEOF(Int32));*)
	END ":=";

	OPERATOR -":="*(VAR y: UnalignedInt32; x: Int32);
	CODE
		LDR R0, [SP,#y]

		LDR R1, [SP,#x]
		LSR R2, R1, #8
		LSR R3, R1, #16
		LSR R4, R1, #24
		
		STRB R1, [R0,#0]
		STRB R2, [R0,#1]
		STRB R3, [R0,#2]
		STRB R4, [R0,#3]

		ADD SP, SP, 8
	(*BEGIN
		S.MOVE(ADDRESSOF(x),ADDRESSOF(y),SIZEOF(Int32));*)
	END ":=";

	OPERATOR "="*(x: Int32; y: UnalignedInt32): BOOLEAN;
	VAR y1: Int32;
	BEGIN
		S.MOVE(ADDRESSOF(y),ADDRESSOF(y1),SIZEOF(Int32));
		RETURN x = y1;
	END "=";

	OPERATOR "="*(x: UnalignedInt32; y: Int32): BOOLEAN;
	VAR x1: Int32;
	BEGIN
		S.MOVE(ADDRESSOF(x),ADDRESSOF(x1),SIZEOF(Int32));
		RETURN x1 = y;
	END "=";

END EnetUtils.
