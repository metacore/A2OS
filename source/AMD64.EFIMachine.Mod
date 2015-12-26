MODULE EFIMachine; (** AUTHOR ""; PURPOSE ""; *)

IMPORT SYSTEM, EFI;

VAR p0, p1: ADDRESS;

(*  I386.Machine.Mod uses following registers as arguments:
	eax	: bootFlag (= address of boot table)
	esi	: ?
	edi	: address of frame buffer
*)

PROCEDURE JumpTo*(adr : ADDRESS; rax, rsi, rdi, rcx, rdx: HUGEINT);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}

	MOV RDI, [RBP+rdi];  fbAddr
	MOV RSI,  [RBP+rsi]; kernelSize
	MOV RAX, [RBP+rax]; btAddr
	MOV RCX, [RBP+rcx];
	MOV RDX, [RBP+rdx];
	
	MOV RBX, [RBP+adr]
	CALL RBX

END JumpTo;
(*
	MOV R15, [RBP+fbAddr];  fbAddr
	MOV R14, [RBP+kernelSize]; kernelSize
	MOV R13, [RBP+btAddr]; btAddr
	MOV R12, [RBP+kernelAddr]; kernelAddr

NT:	CALL NZ
NZ: 	POP RCX
	MOV RDI, 0
	MOV RSI, RCX
	MOV RCX, 512
	CLD
	REP MOVSQ
	MOV RCX, 0
	ADD RCX, NX-NZ

	JMP RCX


NX:

	MOV RCX, R14
	MOV RDI, 1000H
	MOV RSI, R12
	CLD
	REP MOVSB


	XOR RCX,RCX
	XOR RDX,RDX
	MOV RDI, R15;
	MOV RSI, R14;
	MOV RAX, R13;
	MOV RBX, 1000H;
	CALL RBX
END JumpTo;
*)

PROCEDURE {NOPAF, FIXED(401000H)} EntryPoint;
CODE {SYSTEM.AMD64}
	MOV QWORD EFI.imageHandle, RCX;
	MOV QWORD EFI.table, RDX
END EntryPoint;

END EFIMachine.


