(**  AUTHOR "BohdanT"; PURPOSE "Debugger base";  **)
MODULE DebuggerBase;
IMPORT (*SYSTEM, Kernel32, Objects, Modules,*)  KernelLog;
CONST
	Trace = FALSE;
TYPE
	BrkPnt* = POINTER TO RECORD
		c*:CHAR; (*save char here*)
		adr*:LONGINT;
		pos*:LONGINT;
		active*:BOOLEAN;
		next*:BrkPnt;
	END;

	
TYPE

	BPList* = OBJECT
	VAR
		list*,
		tmp*:BrkPnt;
		active*:BOOLEAN;
		PROCEDURE &Init*;
		BEGIN
			active:=TRUE; 
		END Init;

		PROCEDURE AddBP*(adr:ADDRESS);
		VAR
			p,next,last:BrkPnt;
		BEGIN
			next:=list;

			NEW(p);
			p.adr:=adr;
			IF next#NIL THEN
				WHILE (next#NIL)&(next.adr<adr) DO last:=next; next:=next.next END;
				IF next=NIL THEN
					last.next:=p;
				ELSE
					IF next.adr=adr THEN RETURN END;
					p.adr:=next.adr;next.adr:=adr;
					IF Trace THEN KernelLog.String("SetBrk="); KernelLog.Hex(adr,0);  KernelLog.Ln; END;
					SetBrk(next);
					p.next:=next.next;
					next.next:=p;
				END;
			ELSE
				list:=p;
				IF Trace THEN KernelLog.String("SetBrk="); KernelLog.Hex(adr,0);  KernelLog.Ln; END;
				SetBrk(p);
			END;
			IF Trace THEN
				DumpList(list);
			END;
		END AddBP;

		PROCEDURE FindBP(lst:BrkPnt;adr:ADDRESS):BOOLEAN;
		VAR
			next:BrkPnt;
		BEGIN
			next:=lst;
			WHILE (next#NIL)&(next.adr#adr) DO next:=next.next END;
			RETURN next#NIL;
		END FindBP;
		
		PROCEDURE AddTmpBP*(adr:ADDRESS);
		VAR
			p:BrkPnt;
		BEGIN
			IF FindBP(list,adr)OR FindBP(tmp,adr) THEN RETURN END; (*no add if now real BP*)
			NEW(p);
			p.adr:=adr;
			p.next:=tmp;tmp:=p;
			SetBrk(p);
		END AddTmpBP;

		PROCEDURE RemoveTmpBP*;
		BEGIN
			WHILE tmp#NIL DO
				ClrBrk(tmp);
				tmp:=tmp.next;
			END;
			tmp:=NIL;
		END RemoveTmpBP;

 
		PROCEDURE RemoveBP*(adr:ADDRESS);
		VAR
			next,last:BrkPnt;
		BEGIN
			next:=list;
			WHILE (next#NIL)&(next.adr#adr) DO last:=next; next:=next.next END;
			IF next=NIL THEN RETURN END;
			ClrBrk(next);
			IF next=list THEN list:=next.next;
			ELSE
				IF next.next=NIL THEN
					last.next:=NIL;
				ELSE
					next.adr:=next.next.adr;
					next.next:=next.next.next;
				END;
			END;
			IF Trace THEN
				DumpList(list);
			END;
		END RemoveBP;


		PROCEDURE DumpList*(lst:BrkPnt);
		BEGIN
			KernelLog.String("dh: ");
			WHILE lst#NIL DO
				 KernelLog.Hex(lst.adr, 8); KernelLog.String(", ");
				 lst:=lst.next;
			END;
			KernelLog.Ln;
		END DumpList;
		
		PROCEDURE SetBrk*(bp:BrkPnt);
		END SetBrk;

		PROCEDURE ClrBrk*(bp:BrkPnt);
		END ClrBrk;
		
		PROCEDURE ChgState*(state:BOOLEAN);
		VAR
			p:BrkPnt;
		BEGIN
			IF active=state THEN RETURN END;
(*			KernelLog.String("ChgState "); KernelLog.Ln; *)

			active:=state;
			p:=list;
			WHILE p#NIL DO
				IF active THEN
					SetBrk(p);
				ELSE
					ClrBrk(p);
				END;
				p:=p.next;
			END;
			p:=tmp;
			WHILE p#NIL DO
				IF active THEN
					SetBrk(p);
				ELSE
					ClrBrk(p);
				END;
				p:=p.next;
			END;
			IF Trace THEN 
			KernelLog.String("list:");KernelLog.Ln;
			DumpList(list);
			KernelLog.String("tmp:");KernelLog.Ln;
			DumpList(tmp);
			KernelLog.String("...ok!"); KernelLog.Ln; 
			END;
		END ChgState;

	END BPList;


(** Termination handler. Removes the window from the display space when the module is unloaded. *)
PROCEDURE Cleanup;	(* K *)
BEGIN
END Cleanup;

BEGIN
	(*Modules.InstallTermHandler(Cleanup);*)
END DebuggerBase.


DebuggerBase.Install~
SystemTools.Free  DebuggerBase ~