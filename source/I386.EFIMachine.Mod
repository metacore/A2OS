MODULE EFIMachine; (** AUTHOR ""; PURPOSE ""; *)

IMPORT SYSTEM, EFI;

(* BIOS.I386.Machine.Mod uses following registers as arguments:
	eax	: bootFlag (= address of boot table)
	esi	: ?
	edi	: address of frame buffer
*)
PROCEDURE JumpTo*(adr : ADDRESS; eax,esi,edi, ecx, edx: SIGNED32);
CODE {SYSTEM.i386}
	XOR ECX,ECX
	XOR EDX,EDX

	MOV EDI, [EBP+edi];
	MOV ESI, [EBP+esi];
	MOV EAX, [EBP+eax];
	MOV ECX, [EBP+ecx];
	MOV EDX, [EBP+edx];

	MOV EBX, [EBP+adr];
	CALL EBX
END JumpTo;

PROCEDURE  Portin8*(port: SIGNED32; VAR val: CHAR);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN AL, DX
	MOV ECX, [EBP+val]
	MOV [ECX], AL
END Portin8;

PROCEDURE  Portin16*(port: SIGNED32; VAR val: SIGNED16);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN AX, DX
	MOV ECX, [EBP+val]
	MOV [ECX], AX
END Portin16;

PROCEDURE  Portin32*(port: SIGNED32; VAR val: SIGNED32);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN EAX, DX
	MOV ECX, [EBP+val]
	MOV [ECX], EAX
END Portin32;

PROCEDURE  Portout8*(port: SIGNED32; val: CHAR);
CODE{SYSTEM.i386}
	MOV AL,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,AL
END Portout8;

PROCEDURE  Portout16*(port: SIGNED32; val: SIGNED16);
CODE{SYSTEM.i386}
	MOV AX,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,AX
END Portout16;

PROCEDURE  Portout32*(port: SIGNED32; val: SIGNED32);
CODE{SYSTEM.i386}
	MOV EAX,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,EAX
END Portout32;

PROCEDURE -GetParameter (offset: SIGNED32): SIGNED32;
CODE {SYSTEM.i386}
	POP EAX
	MOV EAX, [EBP+EAX]
END GetParameter;

BEGIN
	SYSTEM.PUT32 (ADDRESSOF (EFI.imageHandle), GetParameter (12));
	SYSTEM.PUT32 (ADDRESSOF (EFI.table), GetParameter (16));
END EFIMachine.
