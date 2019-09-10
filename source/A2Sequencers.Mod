MODULE A2Sequencers;	(** AUTHOR "negelef"; PURPOSE "Generic A2 Sequencer"; *)

(*
This module provides a generic sequencer base class  that allows deriving active objects to communicate sequentially over messages.
Messages are handled sequentially and provide atomic and exclusive access to the state of a sequencer. Requests are special messages
which allow the caller to block and wait for the sequencer to handle the request. This is useful to retrieve a set of states of the sequencer.
Code in procedures of a sequencer must make sure that they are called by their own sequencer object (using the SequencerCalledThis
procedure) and have to add a corresponding message otherwise. If sequencers share variables, they can also put it into property objects
which support atomic access to their values and a registration mechanism for notification handlers.
*)

IMPORT Machine, Streams, Objects, Kernel;

CONST
	NoDelay* = 0;

	MaxHandlers = 10;

TYPE
	(* generic property object that provides lock-free access to its value *)
	Property* = OBJECT
	VAR
		locks: INTEGER;
		container*: OBJECT;

		PROCEDURE &InitProperty;
		BEGIN locks := 0; container := NIL;
		END InitProperty;

		PROCEDURE AcquireRead;
		VAR locks: INTEGER;
		BEGIN
			LOOP
				locks := SELF.locks;
				IF (locks >= 0) & (Machine.AtomicCAS (SELF.locks, locks, locks + 1) = locks) THEN EXIT END;
				Objects.Yield;
			END;
		END AcquireRead;

		PROCEDURE ReleaseRead;
		BEGIN Machine.AtomicDec (locks);
		END ReleaseRead;

		PROCEDURE AcquireWrite;
		VAR locks: INTEGER;
		BEGIN
			LOOP
				locks := SELF.locks;
				IF (locks = 0) & (Machine.AtomicCAS (SELF.locks, locks, locks - 1) = locks) THEN EXIT END;
				Objects.Yield;
			END;
		END AcquireWrite;

		PROCEDURE ReleaseWrite;
		BEGIN Machine.AtomicInc (locks);
		END ReleaseWrite;

		PROCEDURE ToStream*(w : Streams.Writer);
		END ToStream;	(* abstract *)

		PROCEDURE FromStream*(r : Streams.Reader);
		END FromStream;	(* abstract *)

	END Property;

	Boolean* = OBJECT (Property)
	VAR
		value: BOOLEAN;
		handlers: ARRAY MaxHandlers OF BooleanHandler;

		PROCEDURE &InitBoolean* (value: BOOLEAN);
		BEGIN InitProperty; SELF.value := value;
		END InitBoolean;

		PROCEDURE Get* (): BOOLEAN;
		VAR value: BOOLEAN;
		BEGIN AcquireRead; value := SELF.value; ReleaseRead; RETURN value;
		END Get;

		PROCEDURE Set* (value: BOOLEAN);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := SELF.value # value; SELF.value := value; ReleaseWrite; IF changed THEN Changed (value) END;
		END Set;

		PROCEDURE Changed (value: BOOLEAN);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO handlers[i] (SELF, value); INC (i) END;
		END Changed;

		PROCEDURE AddHandler* (handler: BooleanHandler);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO INC (i) END; handlers[i] := handler;
		END AddHandler;

	END Boolean;

	Integer* = OBJECT (Property)
	VAR
		value: INTEGER;
		handlers: ARRAY MaxHandlers OF IntegerHandler;

		PROCEDURE &InitInteger* (value: INTEGER);
		BEGIN InitProperty; SELF.value := value;
		END InitInteger;

		PROCEDURE Get* (): INTEGER;
		VAR value: INTEGER;
		BEGIN AcquireRead; value := SELF.value; ReleaseRead; RETURN value;
		END Get;

		PROCEDURE Set* (value: INTEGER);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := SELF.value # value; SELF.value := value; ReleaseWrite; IF changed THEN Changed (value) END;
		END Set;

		PROCEDURE Inc* (step: INTEGER);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := step # 0; INC (value, step); ReleaseWrite; IF changed THEN Changed (value) END;
		END Inc;

		PROCEDURE Dec* (step: INTEGER);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := step # 0; DEC (value, step); ReleaseWrite; IF changed THEN Changed (value) END;
		END Dec;

		PROCEDURE Changed (value: INTEGER);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO handlers[i] (SELF, value); INC (i) END;
		END Changed;

		PROCEDURE AddHandler* (handler: IntegerHandler);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO INC (i) END; handlers[i] := handler;
		END AddHandler;

	END Integer;

	Real* = OBJECT (Property)
	VAR
		value: FLOAT32;
		handlers: ARRAY MaxHandlers OF RealHandler;

		PROCEDURE &InitReal* (value: FLOAT32);
		BEGIN InitProperty; SELF.value := value;
		END InitReal;

		PROCEDURE Get* (): FLOAT32;
		VAR value: FLOAT32;
		BEGIN AcquireRead; value := SELF.value; ReleaseRead; RETURN value;
		END Get;

		PROCEDURE Set* (value: FLOAT32);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := SELF.value # value; SELF.value := value; ReleaseWrite; IF changed THEN Changed (value) END;
		END Set;

		PROCEDURE Changed (value: FLOAT32);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO handlers[i] (SELF, value); INC (i) END;
		END Changed;

		PROCEDURE AddHandler* (handler: RealHandler);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO INC (i) END; handlers[i] := handler;
		END AddHandler;

	END Real;

	Set* = OBJECT (Property)
	VAR
		value: SET;
		handlers: ARRAY MaxHandlers OF SetHandler;

		PROCEDURE &InitSet* (value: SET);
		BEGIN InitProperty; SELF.value := value;
		END InitSet;

		PROCEDURE Get* (): SET;
		VAR value: SET;
		BEGIN AcquireRead; value := SELF.value; ReleaseRead; RETURN value;
		END Get;

		PROCEDURE Set* (value: SET);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := SELF.value # value; SELF.value := value; ReleaseWrite; IF changed THEN Changed (value) END;
		END Set;

		PROCEDURE Incl* (element: INTEGER);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := ~(element IN value); INCL (value, element); ReleaseWrite; IF changed THEN Changed (value) END;
		END Incl;

		PROCEDURE Excl* (element: INTEGER);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := element IN value; EXCL (value, element); ReleaseWrite; IF changed THEN Changed (value) END;
		END Excl;

		PROCEDURE Changed (value: SET);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO handlers[i] (SELF, value); INC (i) END;
		END Changed;

		PROCEDURE AddHandler* (handler: SetHandler);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO INC (i) END; handlers[i] := handler;
		END AddHandler;

	END Set;

	String* = OBJECT (Property)
	VAR
		value: POINTER TO ARRAY OF CHAR;
		handlers: ARRAY MaxHandlers OF StringHandler;

		PROCEDURE &InitString* (CONST value: ARRAY OF CHAR; length: SIZE);
		BEGIN InitProperty; NEW (SELF.value, length); COPY (value, SELF.value^);
		END InitString;

		PROCEDURE Get* (VAR value: ARRAY OF CHAR);
		BEGIN AcquireRead; COPY (SELF.value^, value); ReleaseRead;
		END Get;

		PROCEDURE Set* (CONST value: ARRAY OF CHAR);
		VAR changed: BOOLEAN;
		BEGIN AcquireWrite; changed := SELF.value^ # value; COPY (value, SELF.value^); ReleaseWrite; IF changed THEN Changed (value) END;
		END Set;

		PROCEDURE Changed (CONST value: ARRAY OF CHAR);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO handlers[i] (SELF, value); INC (i) END;
		END Changed;

		PROCEDURE AddHandler* (handler: StringHandler);
		VAR i: SIZE;
		BEGIN i := 0; WHILE handlers[i] # NIL DO INC (i) END; handlers[i] := handler;
		END AddHandler;

	END String;

	(* generic message to be handled by the sequencer *)
	Message* = OBJECT
	VAR
		next: Message; time: SIGNED32;

		PROCEDURE &InitMessage*;
		BEGIN SELF.next := NIL; time := NoDelay;
		END InitMessage;

		PROCEDURE Handle*;
		END Handle;	(* abstract *)

	END Message;

	TYPE ProcedureMessage*  = OBJECT (Message)
	VAR
		procedure: Procedure;

		PROCEDURE &InitProcedureMessage* (procedure: Procedure);
		BEGIN InitMessage; SELF.procedure := procedure;
		END InitProcedureMessage;

		PROCEDURE Handle*;
		BEGIN procedure;
		END Handle;

	END ProcedureMessage;

	TYPE BooleanMessage*  = OBJECT (Message)
	VAR
		value: BOOLEAN;
		procedure: BooleanProcedure;

		PROCEDURE &InitBooleanMessage* (value: BOOLEAN; procedure: BooleanProcedure);
		BEGIN InitMessage; SELF.value := value; SELF.procedure := procedure;
		END InitBooleanMessage;

		PROCEDURE Handle*;
		BEGIN procedure (value);
		END Handle;

	END BooleanMessage;

	TYPE IntegerMessage*  = OBJECT (Message)
	VAR
		value: INTEGER;
		procedure: IntegerProcedure;

		PROCEDURE &InitIntegerMessage* (value: INTEGER; procedure: IntegerProcedure);
		BEGIN InitMessage; SELF.value := value; SELF.procedure := procedure;
		END InitIntegerMessage;

		PROCEDURE Handle*;
		BEGIN procedure (value);
		END Handle;

	END IntegerMessage;

	TYPE IntegerIntegerMessage*  = OBJECT (Message)
	VAR
		value0, value1: INTEGER;
		procedure: IntegerIntegerProcedure;

		PROCEDURE &InitIntegerIntegerMessage* (value0, value1: INTEGER; procedure: IntegerIntegerProcedure);
		BEGIN InitMessage; SELF.value0 := value0; SELF.value1 := value1; SELF.procedure := procedure;
		END InitIntegerIntegerMessage;

		PROCEDURE Handle*;
		BEGIN procedure (value0, value1);
		END Handle;

	END IntegerIntegerMessage;

	TYPE RealMessage*  = OBJECT (Message)
	VAR
		value: FLOAT32;
		procedure: RealProcedure;

		PROCEDURE &InitRealMessage* (value: FLOAT32; procedure: RealProcedure);
		BEGIN InitMessage; SELF.value := value; SELF.procedure := procedure;
		END InitRealMessage;

		PROCEDURE Handle*;
		BEGIN procedure (value);
		END Handle;

	END RealMessage;

	TYPE SetMessage*  = OBJECT (Message)
	VAR
		value: SET;
		procedure: SetProcedure;

		PROCEDURE &InitSetMessage* (value: SET; procedure: SetProcedure);
		BEGIN InitMessage; SELF.value := value; SELF.procedure := procedure;
		END InitSetMessage;

		PROCEDURE Handle*;
		BEGIN procedure (value);
		END Handle;

	END SetMessage;

	TYPE StringMessage*  = OBJECT (Message)
	VAR
		value: POINTER TO ARRAY OF CHAR;
		procedure: StringProcedure;

		PROCEDURE &InitStringMessage* (CONST value: ARRAY OF CHAR; procedure: StringProcedure);
		VAR length: SIZE;
		BEGIN
			InitMessage; length := 0;
			WHILE value[length] # 0X DO INC (length); END;
			NEW (SELF.value, length); COPY (value, SELF.value^); SELF.procedure := procedure;
		END InitStringMessage;

		PROCEDURE Handle*;
		BEGIN procedure (value^);
		END Handle;

	END StringMessage;

	(* generic request that allows to wait for the message to be handled*)
	Request* = OBJECT (Message)
	VAR
		handled: BOOLEAN;

		PROCEDURE &InitRequest*;
		BEGIN InitMessage; handled := FALSE;
		END InitRequest;

		(* IMPORTANT: to be called at the end of overriding procedures *)
		PROCEDURE Handle*;
		BEGIN {EXCLUSIVE} handled := TRUE
		END Handle;

		(* awaits handling by sequencer  *)
		PROCEDURE Await;
		BEGIN {EXCLUSIVE} AWAIT (handled);
		END Await;

	END Request;

	IntegerRequest* = OBJECT (Request)
	VAR
		value: INTEGER;
		procedure: IntegerProcedure;

		PROCEDURE &InitIntegerRequest* (value: INTEGER; procedure: IntegerProcedure);
		BEGIN InitRequest; SELF.value := value; SELF.procedure := procedure;
		END InitIntegerRequest;

		PROCEDURE Handle*;
		BEGIN procedure (value); Handle^;
		END Handle;

	END IntegerRequest;

	RequestBoolean* = OBJECT (Request)
	VAR
		procedure: ProcedureBoolean;
		result-: BOOLEAN;

		PROCEDURE &InitRequestBoolean* (procedure: ProcedureBoolean);
		BEGIN InitRequest; SELF.procedure := procedure;
		END InitRequestBoolean;

		PROCEDURE Handle*;
		BEGIN result := procedure (); Handle^;
		END Handle;

	END RequestBoolean;

	RequestInteger* = OBJECT (Request)
	VAR
		procedure: ProcedureInteger;
		result-: INTEGER;

		PROCEDURE &InitRequestInteger* (procedure: ProcedureInteger);
		BEGIN InitRequest; SELF.procedure := procedure;
		END InitRequestInteger;

		PROCEDURE Handle*;
		BEGIN result := procedure (); Handle^;
		END Handle;

	END RequestInteger;

	RequestReal* = OBJECT (Request)
	VAR
		procedure: ProcedureReal;
		result-: FLOAT32;

		PROCEDURE &InitRequestReal* (procedure: ProcedureReal);
		BEGIN InitRequest; SELF.procedure := procedure;
		END InitRequestReal;

		PROCEDURE Handle*;
		BEGIN result := procedure (); Handle^;
		END Handle;

	END RequestReal;

	IntegerRequestBoolean* = OBJECT (Request)
	VAR
		value: INTEGER;
		procedure: IntegerProcedureBoolean;
		result-: BOOLEAN;

		PROCEDURE &InitIntegerRequestBoolean* (value: INTEGER; procedure: IntegerProcedureBoolean);
		BEGIN InitRequest; SELF.value := value; SELF.procedure := procedure;
		END InitIntegerRequestBoolean;

		PROCEDURE Handle*;
		BEGIN result := procedure (value); Handle^;
		END Handle;

	END IntegerRequestBoolean;

	RealRequestInteger* = OBJECT (Request)
	VAR
		value: FLOAT32;
		procedure: RealProcedureInteger;
		result-: INTEGER;

		PROCEDURE &InitRealRequestInteger* (value: FLOAT32; procedure: RealProcedureInteger);
		BEGIN InitRequest; SELF.value := value; SELF.procedure := procedure;
		END InitRealRequestInteger;

		PROCEDURE Handle*;
		BEGIN result := procedure (value); Handle^;
		END Handle;

	END RealRequestInteger;

	(* generic base message sequencer class *)
	Sequencer* = OBJECT
	VAR
		handling, woken: BOOLEAN; first: Message; timer: Objects.Timer;

		PROCEDURE &InitSequencer*;
		BEGIN handling := TRUE; woken := FALSE; first := NIL; NEW (timer);
		END InitSequencer;

		(* check wether current procedure was called by sequencer or by other active objects *)
		PROCEDURE SequencerCalledThis* (): BOOLEAN;
		BEGIN RETURN Objects.ActiveObject() = SELF;
		END SequencerCalledThis;

		PROCEDURE HandleMessages;
		VAR message: Message;
		BEGIN {EXCLUSIVE}
			WHILE first # NIL DO
				IF (first.time # NoDelay) & (first.time - Kernel.GetTicks () > 0) THEN RETURN END;
				message := first; first := message.next; message.next := NIL; message.Handle;
			END;
		END HandleMessages;

		PROCEDURE Add*(message: Message; time: SIGNED32);
		VAR prev, next: Message;
		BEGIN
			BEGIN {EXCLUSIVE}
				ASSERT (~SequencerCalledThis ());
				ASSERT (message.next = NIL);
				prev := NIL; next := first;
				WHILE (next # NIL) & (next.time <= time) DO prev := next; next := next.next END;
				IF prev = NIL THEN first := message; woken := time # NoDelay; ELSE prev.next := message END;
				message.next := next; message.time := time;
			END;
			IF message IS Request THEN message(Request).Await END;
		END Add;

		PROCEDURE AddMessage* (procedure: Procedure);
		VAR message: ProcedureMessage;
		BEGIN NEW (message, procedure); Add (message, NoDelay);
		END AddMessage;

		PROCEDURE AddBooleanMessage* (value: BOOLEAN; procedure: BooleanProcedure);
		VAR message: BooleanMessage;
		BEGIN NEW (message, value, procedure); Add (message, NoDelay);
		END AddBooleanMessage;

		PROCEDURE AddIntegerMessage* (value: INTEGER; procedure: IntegerProcedure);
		VAR message: IntegerMessage;
		BEGIN NEW (message, value, procedure); Add (message, NoDelay);
		END AddIntegerMessage;

		PROCEDURE AddRealMessage* (value: FLOAT32; procedure: RealProcedure);
		VAR message: RealMessage;
		BEGIN NEW (message, value, procedure); Add (message, NoDelay);
		END AddRealMessage;

		PROCEDURE AddSetMessage* (value: SET; procedure: SetProcedure);
		VAR message: SetMessage;
		BEGIN NEW (message, value, procedure); Add (message, NoDelay);
		END AddSetMessage;

		PROCEDURE AddStringMessage* (CONST value: ARRAY OF CHAR; procedure: StringProcedure);
		VAR message: StringMessage;
		BEGIN NEW (message, value, procedure); Add (message, NoDelay);
		END AddStringMessage;

		PROCEDURE AddIntegerIntegerMessage* (value0, value1: INTEGER; procedure: IntegerIntegerProcedure);
		VAR message: IntegerIntegerMessage;
		BEGIN NEW (message, value0, value1, procedure); Add (message, NoDelay);
		END AddIntegerIntegerMessage;

		PROCEDURE AddIntegerRequest* (value: INTEGER; procedure: IntegerProcedure);
		VAR request: IntegerRequest;
		BEGIN NEW (request, value, procedure); Add (request, NoDelay);
		END AddIntegerRequest;

		PROCEDURE AddRequestBoolean* (procedure: ProcedureBoolean): BOOLEAN;
		VAR request: RequestBoolean;
		BEGIN NEW (request, procedure); Add (request, NoDelay); RETURN request.result;
		END AddRequestBoolean;

		PROCEDURE AddRequestInteger* (procedure: ProcedureInteger): INTEGER;
		VAR request: RequestInteger;
		BEGIN NEW (request, procedure); Add (request, NoDelay); RETURN request.result;
		END AddRequestInteger;

		PROCEDURE AddRequestReal* (procedure: ProcedureReal): FLOAT32;
		VAR request: RequestReal;
		BEGIN NEW (request, procedure); Add (request, NoDelay); RETURN request.result;
		END AddRequestReal;

		PROCEDURE AddIntegerRequestBoolean* (value: INTEGER; procedure: IntegerProcedureBoolean): BOOLEAN;
		VAR request: IntegerRequestBoolean;
		BEGIN NEW (request, value, procedure); Add (request, NoDelay); RETURN request.result;
		END AddIntegerRequestBoolean;

		PROCEDURE AddRealRequestInteger* (value: FLOAT32; procedure: RealProcedureInteger): INTEGER;
		VAR request: RealRequestInteger;
		BEGIN NEW (request, value, procedure); Add (request, NoDelay); RETURN request.result;
		END AddRealRequestInteger;

		PROCEDURE Remove*(message: Message);
		VAR prev, next: Message;
		BEGIN
			ASSERT (SequencerCalledThis ());
			IF message = NIL THEN RETURN END;
			prev := NIL; next := first;
			WHILE (next # NIL) & (next # message) DO prev := next; next := next.next END;
			IF next = message THEN
				IF prev = NIL THEN first := message.next; woken := TRUE; ELSE prev.next := message.next END;
			END;
			message.next := NIL;
		END Remove;

		(* this procedure is called sequentially and can be overridden in order to do contiguous work *)
		PROCEDURE Handle*;
		BEGIN
			IF (first # NIL) & (first.time # NoDelay) THEN Objects.SetTimeoutAt (timer, Wakeup, first.time) END;
			AWAIT ((first # NIL) & (first.time = NoDelay) OR ~handling OR woken);
			Objects.CancelTimeout (timer); woken := FALSE;
		END Handle;

		PROCEDURE Wakeup;
		BEGIN {EXCLUSIVE} woken := TRUE;
		END Wakeup;

		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE} handling := FALSE;
		END Stop;

	BEGIN {ACTIVE}
		WHILE handling DO HandleMessages; BEGIN {EXCLUSIVE} Handle END END;
	END Sequencer;

(* helper types *)
	BooleanHandler = PROCEDURE {DELEGATE} (property: Boolean; value: BOOLEAN);
	IntegerHandler = PROCEDURE {DELEGATE} (property: Integer; value: INTEGER);
	RealHandler = PROCEDURE {DELEGATE} (property: Real; value: FLOAT32);
	SetHandler = PROCEDURE {DELEGATE} (property: Set; value: SET);
	StringHandler = PROCEDURE {DELEGATE} (property: String; CONST value: ARRAY OF CHAR);

	Procedure = PROCEDURE {DELEGATE};
	BooleanProcedure = PROCEDURE {DELEGATE} (value: BOOLEAN);
	IntegerProcedure = PROCEDURE {DELEGATE} (value: INTEGER);
	IntegerIntegerProcedure = PROCEDURE {DELEGATE} (value0, value1: INTEGER);
	RealProcedure = PROCEDURE {DELEGATE} (value: FLOAT32);
	SetProcedure = PROCEDURE {DELEGATE} (value: SET);
	StringProcedure = PROCEDURE {DELEGATE} (CONST value: ARRAY OF CHAR);

	ProcedureBoolean = PROCEDURE {DELEGATE} (): BOOLEAN;
	ProcedureInteger = PROCEDURE {DELEGATE} (): INTEGER;
	ProcedureReal = PROCEDURE {DELEGATE} (): FLOAT32;

	IntegerProcedureBoolean = PROCEDURE {DELEGATE} (value: INTEGER): BOOLEAN;
	RealProcedureInteger = PROCEDURE {DELEGATE} (value: FLOAT32): INTEGER;

(* helper function for delayed execution *)
PROCEDURE Delay* (delay: SIGNED32): SIGNED32;
BEGIN RETURN delay + Kernel.GetTicks ();
END Delay;

END A2Sequencers.

Open issues:
- first parameter of event procedures concrete or abstract property type?
- no concrete request types implemented
- serializable interface of properties not implemented
