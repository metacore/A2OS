(**
	AUTHOR: "Alexey Morozov";
	PURPOSE: "ActiveCells AXI-4 Stream input/output interface for Xilinx Zynq platform";
*)
MODULE Channels;

IMPORT
	SYSTEM;

CONST
	MasterAxiGp0Base = 07F000000H; (* base address for Master AXI General Purpose interface 0 *)
	MasterAxiGp1Base = 0BF000000H; (* base address for Master AXI General Purpose interface 1 *)

	ChanOffset  = 256*4; (* ActiveCells AXI4 Stream channel offset in bytes *)
(*
	OutDataOffset = 0;
	OutReadyOffset = SIZEOF(LONGINT);

	InpAvailableOffset = 0;
	InpDataOffset = 2*SIZEOF(LONGINT);
*)

TYPE
	(* AXI4 Stream logical port descriptor *)
	PortDesc = RECORD
		lockAddr: ADDRESS; (** address of the associated spin lock *)
		portAddr: ADDRESS; (** address of the logical channel port;  *)
	END;

	Output* = PORT OUT; (** AXI4 Stream output port *)
	Input* = PORT IN; (** AXI4 Stream input port *)

VAR
	inputs: ARRAY 2 OF ARRAY 256 OF PortDesc;
	outputs: ARRAY 2 OF ARRAY 256 OF PortDesc;

	locks: ARRAY 2 OF LONGINT; (* locks for each physical channel *)

(**
	Writing to and reading from a port can be described by the following high-level code:

	PROCEDURE WriteToPort(out: Output; data: LONGINT);
	VAR
		portDesc: POINTER {UNSAFE} TO PortDesc;
		outDesc: OutputDesc;
	BEGIN
		portDesc := SYSTEM.VAL(ADDRESS,out);
		outDesc := portDesc.portAddr;
		outDesc.data := data;
	END WriteToPort;

	PROCEDURE ReadFromPort(inp: Input; VAR data: LONGINT);
	VAR
		portDesc: POINTER {UNSAFE} TO PortDesc;
		inpDesc: InputDesc;
	BEGIN
		portDesc := SYSTEM.VAL(ADDRESS,inp);
		inpDesc := portDesc.portAddr;
		data := inpDesc.data;
	END ReadFromPort;
	
	where OutputDesc and InputDesc are defined as follows:
	
	(** AXI4 Stream output port descriptor *)
	OutputDesc* = POINTER{UNSAFE,UNTRACED} TO RECORD
		data: LONGINT; (** output data, write only *)
		ready: BOOLEAN; (** TRUE when output is available for sending data *)
		padding: ARRAY 3 OF CHAR;
	END;
	
	(** AXI4 Stream input port descriptor *)
	InputDesc* = POINTER{UNSAFE,UNTRACED} TO RECORD
		available: BOOLEAN; (** TRUE when input data is available *)
		padding: ARRAY 7 OF CHAR;
		data: LONGINT; (** input data, read only *)
	END;
*)

	(**
		Get AXI4 Stream input port

		physicalPortNum: physical port number
		logicalPortNum: logical port number
	*)
	PROCEDURE GetInput*(physicalPortNum, logicalPortNum: LONGINT; VAR port: Input): BOOLEAN;
	VAR
		portDesc: POINTER {UNSAFE} TO PortDesc;
		portAddr: ADDRESS;
	BEGIN
		CASE physicalPortNum OF
			|0: portAddr := MasterAxiGp0Base + logicalPortNum*ChanOffset;
			|1: portAddr := MasterAxiGp1Base + logicalPortNum*ChanOffset;
		ELSE
			RETURN FALSE;
		END;

		portDesc := ADDRESSOF(inputs[physicalPortNum,logicalPortNum]);
		portDesc.portAddr := portAddr;
		portDesc.lockAddr := ADDRESSOF(locks[physicalPortNum]);
		port := SYSTEM.VAL(Input,portDesc);

		RETURN TRUE;
	END GetInput;

	(**
		Get AXI4 Stream output port

		physicalPortNum: physical port number
		logicalPortNum: logical port number
	*)
	PROCEDURE GetOutput*(physicalPortNum, logicalPortNum: LONGINT; VAR port: Output): BOOLEAN;
	VAR
		portDesc: POINTER {UNSAFE} TO PortDesc;
		portAddr: ADDRESS;
	BEGIN
		CASE physicalPortNum OF
			|0: portAddr := MasterAxiGp0Base + logicalPortNum*ChanOffset;
			|1: portAddr := MasterAxiGp1Base + logicalPortNum*ChanOffset;
		ELSE
			RETURN FALSE;
		END;

		portDesc := ADDRESSOF(outputs[physicalPortNum,logicalPortNum]);
		portDesc.portAddr := portAddr;
		portDesc.lockAddr := ADDRESSOF(locks[physicalPortNum]);
		port := SYSTEM.VAL(Output,portDesc);

		RETURN TRUE;
	END GetOutput;

	PROCEDURE GetOutputDataAddr*(out: Output): ADDRESS;
	VAR portDesc: POINTER {UNSAFE} TO PortDesc;
	BEGIN
		portDesc := SYSTEM.VAL(ADDRESS,out);
		ASSERT(portDesc # NIL);
		RETURN portDesc.portAddr;
	END GetOutputDataAddr;

	PROCEDURE GetInputDataAddr*(inp: Input): ADDRESS;
	VAR portDesc: POINTER {UNSAFE} TO PortDesc;
	BEGIN
		portDesc := SYSTEM.VAL(ADDRESS,inp);
		ASSERT(portDesc # NIL);
		RETURN portDesc.portAddr+8;
	END GetInputDataAddr;

	(*
		Acquire exclusive access to a resource

		R1: lock address

		R0, R5 are used in addition

		Based on the code presented in "Barrier Litmus Tests and Cookbook" by Richard Grisenthwaite, ARM, 26.11.2009,
	*)
	PROCEDURE {NOPAF} -AcquireResource;
	CODE
		MOV R0, #1
	Loop:
		LDREX R5, R1 ; read lock
		CMP R5, #0 ; check if 0
		WFENE ; sleep if the lock is held

		STREXEQ R5, R0, R1 ; attempt to store new value
		CMPEQ R5, #0 ; test if store suceeded
		BNE Loop ; retry if not

		DMB ; ensures that all subsequent accesses are observed after the gaining of the lock is observed

		; loads and stores in the critical region can now be performed
	END AcquireResource;

	(*
		Release exclusive access to a resource

		R1: lock address

		R0 is used in addition

		Based on the code presented in "Barrier Litmus Tests and Cookbook" by Richard Grisenthwaite, ARM, 26.11.2009,
	*)
	PROCEDURE {NOPAF} -ReleaseResource;
	CODE
		MOV R0, #0
		DMB ; ensure all previous accesses are observed before the lock is cleared
		STR R0, [R1, #0]
		; clear the lock.
		DSB ; ensure completion of the store that cleared the lock before sending the event
		SEV
	END ReleaseResource;

	(*PROCEDURE AcquireObject(lockAddr: ADDRESS);
	BEGIN
		CODE
			LDR R1, [FP, #lockAddr] ; R1 := address of lock
		END;
		AcquireResource;
	END AcquireObject;

	PROCEDURE ReleaseObject(lockAddr: ADDRESS);
	BEGIN
		CODE
			LDR R1, [FP, #lockAddr] ; R1 := address of lock
		END;
		ReleaseResource
	END ReleaseObject;*)

	(**
		Returns TRUE if the given output port is ready to accept new data
	*)
	PROCEDURE Ready*(out: Output): BOOLEAN;
	VAR b: BOOLEAN;
	(*VAR p: POINTER {UNSAFE} TO PortDesc;*)
	BEGIN
		CODE
			LDR R3, [FP, #out] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #4] ; R4 := out.Ready
			STRB R4, [FP, #b] ; b := R4
		END;
		ReleaseResource;

		(*p := SYSTEM.VAL(ADDRESS,out);
		AcquireObject(p.lockAddr);
		b := SYSTEM.VAL(BOOLEAN,SYSTEM.GET32(p.portAddr+OutReadyOffset));
		ReleaseObject(p.lockAddr);*)

		RETURN b;
	END Ready;

	(** Returns number of data elements available to read from an input port *)
	PROCEDURE Available*(inp: Input): LONGINT;
	VAR available: LONGINT;
	(*VAR p: POINTER {UNSAFE} TO PortDesc;*)
	BEGIN
		CODE
			LDR R3, [FP, #inp] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #0] ; R4 := inp.Available
			STR R4, [FP, #available] ; available := R4
		END;
		ReleaseResource;

		(*p := SYSTEM.VAL(ADDRESS,inp);
		AcquireObject(p.lockAddr);
		available := SYSTEM.GET32(p.portAddr+InpAvailableOffset);
		ReleaseObject(p.lockAddr);*)

		RETURN available;
	END Available;

	(** Send data to an output port (blocking version) *)
	PROCEDURE Send*(out: Output; x: LONGINT);
	(*VAR p: POINTER {UNSAFE} TO PortDesc;*)
	BEGIN
		CODE
			LDR R3, [FP, #out] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R2, [FP, #x] ; R2 := x
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			STR R2, [R3, #0] ; out.Data := R2
		END;
		ReleaseResource;

		(*p := SYSTEM.VAL(ADDRESS,out);
		AcquireObject(p.lockAddr);
		SYSTEM.PUT32(p.portAddr+OutDataOffset,x);
		ReleaseObject(p.lockAddr);*)
	END Send;

	(** Send data to an output port (non-blocking version) *)
	PROCEDURE SendNonBlocking*(out: Output; x: LONGINT): BOOLEAN;
	VAR b: BOOLEAN;
	(*VAR p: POINTER {UNSAFE} TO PortDesc;*)
	BEGIN
		CODE
			LDR R3, [FP, #out] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R2, [FP, #x] ; R2 := x
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #4] ; R4 := out.Ready
			STRB R4, [FP, #b] ; b := R4

			CMP R4, #0
			BEQ Exit

			STR R2, [R3, #0] ; out.Data := R2
		Exit:
		END;
		ReleaseResource;

		(*p := SYSTEM.VAL(ADDRESS,out);
		AcquireObject(p.lockAddr);
		b := SYSTEM.VAL(BOOLEAN,SYSTEM.GET32(p.portAddr+OutReadyOffset));
		IF b THEN SYSTEM.PUT32(p.portAddr+OutDataOffset,x); END;
		ReleaseObject(p.lockAddr);*)

		RETURN b;
	END SendNonBlocking;

	OPERATOR "<<"*(out: Output; x: LONGINT);
	BEGIN
		Send(out,x);
	END "<<";

	OPERATOR ">>"*(x: LONGINT; out: Output);
	BEGIN
		Send(out,x);
	END ">>";

	OPERATOR "<<?"*(out: Output; x: LONGINT): BOOLEAN;
	BEGIN
		RETURN SendNonBlocking(out,x);
	END "<<?";

	OPERATOR ">>?"*(x: LONGINT; out: Output): BOOLEAN;
	BEGIN
		RETURN SendNonBlocking(out,x);
	END ">>?";

	(** Receive data from an input port (blocking version) *)
	PROCEDURE Receive*(inp: Input; VAR x: LONGINT);
	(*VAR p: POINTER {UNSAFE} TO PortDesc;*)
	BEGIN
		CODE
			LDR R3, [FP, #inp] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R2, [FP, #x] ; R2 := address of x
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #8] ; R4 := inp.Data
			STR R4, [R2, #0] ; x := R4
		END;
		ReleaseResource;

		(*p := SYSTEM.VAL(ADDRESS,inp);
		AcquireObject(p.lockAddr);
		x := SYSTEM.GET32(p.portAddr+InpDataOffset);
		ReleaseObject(p.lockAddr);*)
	END Receive;

	(** Receive data from an input port (non-blocking version) *)
	PROCEDURE ReceiveNonBlocking*(inp: Input; VAR x: LONGINT): BOOLEAN;
	VAR b: BOOLEAN;
	(*VAR p: POINTER {UNSAFE} TO PortDesc;*)
	BEGIN
		CODE
			LDR R3, [FP, #inp] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #0] ; R4 := inp.Available
			STRB R4, [FP, #b] ; b := R4

			CMP R4, #0
			BEQ Exit

			LDR R2, [FP, #x] ; R2 := address of x
			LDR R4, [R3, #8] ; R4 := inp.Data
			STR R4, [R2, #0] ; x := R4
		Exit:
		END;
		ReleaseResource;

		(*p := SYSTEM.VAL(ADDRESS,inp);
		AcquireObject(p.lockAddr);
		b := SYSTEM.VAL(BOOLEAN,SYSTEM.GET32(p.portAddr+InpAvailableOffset));
		IF b THEN x := SYSTEM.GET32(p.portAddr+InpDataOffset); END;
		ReleaseObject(p.lockAddr);*)

		RETURN b;
	END ReceiveNonBlocking;

	OPERATOR ">>"*(inp: Input; VAR x: LONGINT);
	BEGIN
		Receive(inp,x);
	END ">>";

	OPERATOR "<<"*(VAR x: LONGINT; inp: Input);
	BEGIN
		Receive(inp,x);
	END "<<";

	OPERATOR ">>?"*(inp: Input; VAR x: LONGINT): BOOLEAN;
	BEGIN
		RETURN ReceiveNonBlocking(inp,x);
	END ">>?";

	OPERATOR "<<?"*(VAR x: LONGINT; inp: Input): BOOLEAN;
	BEGIN
		RETURN ReceiveNonBlocking(inp,x);
	END "<<?";

	PROCEDURE SendMultiple(portAddr, dataAddr: ADDRESS; numElements: LONGINT);
	CODE
		LDR R0, [FP,#portAddr]
		LDR R1, [FP,#dataAddr]
		LDR R2, [FP,#numElements]

		CMP R2, #8
		BLT CheckLoop4

	Loop8: ; numElements >= 8, coalescing of 8 transfers
		LDR R3, [R1,#0]
		LDR R4, [R1,#4]
		LDR R5, [R1,#8]
		LDR R6, [R1,#12]
		LDR R7, [R1,#16]
		LDR R8, [R1,#20]
		LDR R9, [R1,#24]
		LDR R10, [R1,#28]

		STR R3, [R0,#0]
		STR R4, [R0,#0]
		STR R5, [R0,#0]
		STR R6, [R0,#0]
		STR R7, [R0,#0]
		STR R8, [R0,#0]
		STR R9, [R0,#0]
		STR R10, [R0,#0]

		ADD R1, R1, #32
		SUBS R2, R2, #8
		BGT Loop8

	CheckLoop4:
		CMP R2, #4
		BLT CheckLoop1

	Loop4: ; numElements >= 4, coalescing of 4 transfers
		LDR R3, [R1,#0]
		LDR R4, [R1,#4]
		LDR R5, [R1,#8]
		LDR R6, [R1,#12]

		STR R3, [R0,#0]
		STR R4, [R0,#0]
		STR R5, [R0,#0]
		STR R6, [R0,#0]

		ADD R1, R1, #16
		SUBS R2, R2, #4
		BGT Loop4

	CheckLoop1:
		CMP R2, #1
		BLT Exit

	Loop1: ; numElements >= 1, transfer element by element
		LDR R3, [R1,#0]
		STR R3, [R0,#0]

		ADD R1, R1, #4
		SUBS R2, R2, #1
		BGT Loop1

	Exit:

	END SendMultiple;

	PROCEDURE ReceiveMultiple(portAddr, dataAddr: ADDRESS; numElements: LONGINT);
	CODE
		LDR R0, [FP,#portAddr]
		ADD R0, R0, #8
		LDR R1, [FP,#dataAddr]
		LDR R2, [FP,#numElements]

		CMP R2, #8
		BLT CheckLoop4

	Loop8: ; numElements >= 8, coalescing of 8 transfers
		LDR R3, [R0,#0]
		LDR R4, [R0,#0]
		LDR R5, [R0,#0]
		LDR R6, [R0,#0]
		LDR R7, [R0,#0]
		LDR R8, [R0,#0]
		LDR R9, [R0,#0]
		LDR R10, [R0,#0]

		STR R3, [R1,#0]
		STR R4, [R1,#4]
		STR R5, [R1,#8]
		STR R6, [R1,#12]
		STR R7, [R1,#16]
		STR R8, [R1,#20]
		STR R9, [R1,#24]
		STR R10, [R1,#28]

		ADD R1, R1, #32
		SUBS R2, R2, #8
		BGT Loop8

	CheckLoop4:
		CMP R2, #4
		BLT CheckLoop1

	Loop4: ; numElements >= 4, coalescing of 4 transfers
		LDR R3, [R0,#0]
		LDR R4, [R0,#0]
		LDR R5, [R0,#0]
		LDR R6, [R0,#0]

		STR R3, [R1,#0]
		STR R4, [R1,#4]
		STR R5, [R1,#8]
		STR R6, [R1,#12]

		ADD R1, R1, #16
		SUBS R2, R2, #4
		BGT Loop4

	CheckLoop1:
		CMP R2, #1
		BLT Exit

	Loop1: ; numElements >= 1, transfer element by element
		LDR R3, [R0,#0]
		STR R3, [R1,#0]

		ADD R1, R1, #4
		SUBS R2, R2, #1
		BGT Loop1

	Exit:

	END ReceiveMultiple;

	OPERATOR "<<"*(port: Output; x: SET); BEGIN Send(port,SYSTEM.VAL(LONGINT,x)); END "<<";
	OPERATOR ">>"*(x: SET; port: Output); BEGIN Send(port,SYSTEM.VAL(LONGINT,x)); END ">>";
	OPERATOR "<<?"*(port: Output; x: SET): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END "<<?";
	OPERATOR ">>?"*(x: SET; port: Output): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END ">>?";
	OPERATOR ">>"*(port: Input; VAR x: SET); BEGIN Receive(port,SYSTEM.VAL(LONGINT,x)); END ">>";
	OPERATOR "<<"*(VAR x: SET; port: Input); BEGIN Receive(port,SYSTEM.VAL(LONGINT,x)); END "<<";
	OPERATOR ">>?"*(port: Input; VAR x: SET): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END ">>?";
	OPERATOR "<<?"*(VAR x: SET; port: Input): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END "<<?";

	OPERATOR "<<"*(port: Output; x: REAL); BEGIN Send(port,SYSTEM.VAL(LONGINT,x)); END "<<";
	OPERATOR ">>"*(x: REAL; port: Output); BEGIN Send(port,SYSTEM.VAL(LONGINT,x)); END ">>";
	OPERATOR "<<?"*(port: Output; x: REAL): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END "<<?";
	OPERATOR ">>?"*(x: REAL; port: Output): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END ">>?";
	OPERATOR ">>"*(port: Input; VAR x: REAL); BEGIN Receive(port,SYSTEM.VAL(LONGINT,x)); END ">>";
	OPERATOR "<<"*(VAR x: REAL; port: Input); BEGIN Receive(port,SYSTEM.VAL(LONGINT,x)); END "<<";
	OPERATOR ">>?"*(port: Input; VAR x: REAL): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END ">>?";
	OPERATOR "<<?"*(VAR x: REAL; port: Input): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(LONGINT,x)); END "<<?";

END Channels.

