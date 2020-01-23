MODULE DebugInfo; (** AUTHOR "BohdanT"; PURPOSE "Debug information"; *)

IMPORT KernelLog, SYSTEM, Reflection, Files, Texts, TextUtilities, Modules, UTF8Strings;
VAR
	beginstr:ARRAY 10 OF CHAR;		(*for search @body section in the textfile*)
	endinstr:ARRAY 10 OF CHAR;		
	beginstrutf:ARRAY 10 OF LONGINT;
	endinstrutf:ARRAY 10 OF LONGINT;

CONST
	Trace = TRUE;

TYPE
	(*Information about relation position in text and offset in binary module*)
	PosInfo = POINTER TO RECORD
		pos:LONGINT;
		pc:ADDRESS;
		BrkState:SET;
		next:PosInfo;
	END;

	(*ProcInfo describe procedure position information for step over *)
	ProcInfo = POINTER TO RECORD	
	
		name:ARRAY 255 OF CHAR;		(*Name of procedure*)
		posList:PosInfo;					(*Pointer to list of position information*)
		next:ProcInfo;						(*pointer to next procedure in the module*)
		startOfs,							(*first and last address in memory (TODO: need find RET in code and END proc in source and add additional information)*)
		lastOfs:ADDRESS;
		END;

	ModuleInfoArr = POINTER TO ARRAY OF PosInfo;
	
	ModuleInfo* = OBJECT
	VAR
		name*:ARRAY 80 OF CHAR;			(*Name of module*)
		procList*:ProcInfo;				(*List of procedure*)
		nofmi*:LONGINT;
		mi*:ModuleInfoArr;
(*		mid:BtDecoder.ModuleInfo;*)
		mod:Modules.Module;
		saveCode*:Modules.Bytes;
		state*:LONGINT;
		PROCEDURE &Init*;
		BEGIN
			NEW(mi, 8192);
		END Init;

		PROCEDURE Sort*;
			PROCEDURE ThreeSort( l, c, r: LONGINT );
			VAR sort: PosInfo;
			BEGIN
				IF mi[l].pos > mi[c].pos THEN sort := mi[l];  mi[l] := mi[c];  mi[c] := sort END;
				IF mi[l].pos > mi[r].pos THEN sort := mi[l];  mi[l] := mi[r];  mi[r] := sort END;
				IF mi[c].pos > mi[r].pos THEN sort := mi[c];  mi[c] := mi[r];  mi[r] := sort END
			END ThreeSort;

			PROCEDURE InsertionSort( l, r: LONGINT );
			VAR i, j: LONGINT;  sort: PosInfo;
			BEGIN
				FOR i := l + 1 TO r DO
					sort := mi[i];  j := i;
					WHILE (j > 0) & (mi[j - 1].pos > sort.pos) DO mi[j] := mi[j - 1];  DEC( j ) END;
					mi[j] := sort
				END
			END InsertionSort;

			PROCEDURE QuickSort( l, r: LONGINT );
			CONST short = 7;   (* Short vectors sort faster with insertion. *)
			VAR c, i, j: LONGINT;  sort, temp: PosInfo;
			BEGIN
				IF r - l > short THEN  (* quick sort *)
					c := (l + r) DIV 2;  ThreeSort( l, c, r );  sort := mi[r];  i := l - 1;  j := r;
					REPEAT
						REPEAT INC( i ) UNTIL mi[i].pos >= sort.pos;
						REPEAT DEC( j ) UNTIL mi[j].pos <= sort.pos;
						temp := mi[i];  mi[i] := mi[j];  mi[j] := temp
					UNTIL j < i;
					mi[j] := mi[i];  mi[i] := mi[r];  mi[r] := temp;  QuickSort( l, j );  QuickSort( i + 1, r )
				ELSIF r > l THEN InsertionSort( l, r )
				ELSE  (* Nothing to sort. *)
				END
			END QuickSort;

		BEGIN
			IF nofmi <= 1 THEN RETURN END;
			QuickSort( 0, nofmi - 1 );
		END Sort;

		PROCEDURE AddPos*(curPI:ProcInfo; pos,pc:ADDRESS);
		VAR h : PosInfo;
		BEGIN {EXCLUSIVE}
			NEW(h); h.next := curPI.posList; curPI.posList := h;h.BrkState:={}; (*Add to proc info*)
			h.pos:=pos;
			h.pc:=pc;

			IF nofmi = LEN(mi) THEN Grow END; (*Add to module info*)
			mi[nofmi] := h;
			INC(nofmi);

		END AddPos;

		PROCEDURE Grow;
		VAR new: ModuleInfoArr; i : LONGINT;
		BEGIN
			NEW(new, LEN(mi) * 2);
			FOR i := 0 TO nofmi - 1 DO new[i] := mi[i] END;
			mi := new
		END Grow;

		PROCEDURE DumpPos*;
		VAR cur:ProcInfo;
		pl:PosInfo;
		BEGIN
			KernelLog.String("######################### "); KernelLog.Ln;
			cur:=procList;
			WHILE (cur#NIL)&(cur.posList#NIL)(*&(pos>cur.posList.pos)*) DO 
				pl:=cur.posList;
				WHILE (pl#NIL)(*pos>=pl.pos*) DO 
						KernelLog.String("pl.pos= "); KernelLog.Int(pl.pos,5);
						KernelLog.String(" pc= "); KernelLog.Int(pl.pc,5);  KernelLog.Ln;
					pl:=pl.next;
				END;
				cur:=cur.next;
			END;
			KernelLog.String("######################### "); KernelLog.Ln;
		END DumpPos;
		
		PROCEDURE AddProc*(CONST name:ARRAY OF CHAR):ProcInfo;
		VAR h : ProcInfo;
		BEGIN {EXCLUSIVE}
			NEW(h); h.next := procList; h.posList:=NIL; procList := h;
			COPY(name,h.name);
			RETURN h;
			
		END AddProc;
		
		PROCEDURE Find*(CONST name:ARRAY OF CHAR;adr:ADDRESS):LONGINT;
		VAR
			cur:ProcInfo;
			pi,pc:PosInfo;
		BEGIN
			cur:=procList;
			WHILE (cur#NIL)&(name#cur.name) DO cur:=cur.next; END;
			IF cur#NIL THEN
				pi:=cur.posList;
				pc:=pi;
				WHILE (pi#NIL)&(adr<pi.pc) DO pc:=pi; pi:=pi.next; END;
				IF pi#NIL THEN
					RETURN pi.pos
				ELSE
					RETURN -1;
				END
			ELSE
				RETURN -1;
			END;
		END Find;
		
		PROCEDURE FindPC*(CONST name:ARRAY OF CHAR;adr:ADDRESS):BOOLEAN;
		VAR
			cur:ProcInfo;
			pi,pc:PosInfo;
		BEGIN
			cur:=procList;
			WHILE (cur#NIL)&(name#cur.name) DO cur:=cur.next; END;
			IF cur#NIL THEN
				pi:=cur.posList;
				pc:=pi;
				WHILE (pi#NIL)&(adr#pi.pc) DO pc:=pi; pi:=pi.next; END;
				IF pi#NIL THEN
					RETURN TRUE
				ELSE
					RETURN FALSE;
				END
			ELSE
				RETURN FALSE;
			END;
		END FindPC;

		PROCEDURE FindProc*(CONST name:ARRAY OF CHAR;VAR pi:PosInfo):BOOLEAN;
		VAR cur:ProcInfo;
		BEGIN
			cur:=procList;
			WHILE (cur#NIL)&(name#cur.name) DO cur:=cur.next; END;
			IF cur#NIL THEN
				pi:=cur.posList;
				RETURN TRUE;
			END;
			RETURN FALSE;
		END FindProc;

		PROCEDURE FindPos*(pos:LONGINT):PosInfo;
		VAR
		 i:LONGINT;
		BEGIN
			ASSERT(nofmi>0);
			(*TODO: binary seach*)
			IF pos<mi[0].pos THEN RETURN NIL;END;
			i:=0;
			WHILE (i<nofmi)&(pos>mi[i].pos) DO INC(i);END;
		 	IF i>0 THEN DEC(i); END;
		 	RETURN mi[i];
		END FindPos;

		PROCEDURE FindPos2*(pos:LONGINT):PosInfo;
		VAR
		 i:LONGINT;
		BEGIN
			ASSERT(nofmi>0); (*Possible you use not midified FoxAMDBackend !!!*)
			(*TODO: binary seach*)
			i:=0;
			WHILE (i<nofmi)&(pos>mi[i].pos) DO INC(i);END;
		 	RETURN mi[i];
		END FindPos2;


		PROCEDURE FindPosInProc*(pos,len:LONGINT):BOOLEAN;
		VAR cur:ProcInfo;
		pl:PosInfo;
		BEGIN
			cur:=procList;
			WHILE (cur#NIL)&(cur.posList#NIL)(*&(pos>cur.posList.pos)*) DO 
				pl:=cur.posList;
				WHILE (pl#NIL)(*pos>=pl.pos*) DO 
					IF (pos<pl.pos)&((pos+len)>pl.pos) THEN
(*						KernelLog.Ln;
						KernelLog.String("pos= "); KernelLog.Int(pos,5); 
						KernelLog.String("pl.pos= "); KernelLog.Int(pl.pos,5);
						KernelLog.String(" len= "); KernelLog.Int(len,5); KernelLog.Ln;*)
						RETURN TRUE;
					END;
					pl:=pl.next;
				END;
				cur:=cur.next;
			END;
			RETURN FALSE;
		END FindPosInProc;
		
		PROCEDURE FindPCinProc*(pc:LONGINT;VAR cur:ProcInfo;VAR pi:PosInfo):BOOLEAN;
		BEGIN
			cur:=procList;
			WHILE (cur#NIL)&((pc<cur.startOfs)OR(pc>cur.lastOfs)) DO cur:=cur.next END;
			IF cur=NIL THEN RETURN FALSE END;
			pi:=cur.posList;
			WHILE (pi#NIL)&(pi.pc#pc)DO pi:=pi.next END;
			RETURN pi#NIL;
		END FindPCinProc;
		
		PROCEDURE FindPCinText*(pc:ADDRESS;VAR pos:LONGINT):BOOLEAN;
		VAR cur:ProcInfo;
		BEGIN
			cur:=procList;
			WHILE (cur#NIL)&(cur.posList#NIL) DO
			
			END;
		END FindPCinText;
		
	END ModuleInfo;

PROCEDURE GetProcOffset(CONST name:ARRAY OF CHAR; VAR adr:ADDRESS);
VAR
	mn,pn:ARRAY 80 OF CHAR; (*TODO: fix to max name length!*)
	i,j:LONGINT;
BEGIN
	i:=0;j:=0;
	WHILE (name[i]#0X)&(name[i]#".") DO mn[i]:=name[i];INC(i) END;
	INC(i);
	WHILE (name[i]#0X) DO pn[j]:=name[i];INC(i);INC(j)  END;
	IF pn="@Body" THEN
		GetProcedure(mn,"$$",adr);
	ELSE
		GetProcedure(mn,pn,adr);
	END;
(*	KernelLog.String("module= "); KernelLog.String(mn); KernelLog.Ln;
	KernelLog.String("procedure= "); KernelLog.String(pn); KernelLog.Ln;*)
END GetProcOffset;
PROCEDURE GetProcedure(mn,name:ARRAY OF CHAR;adr:ADDRESS);
  PROCEDURE GetProcAdr(refs: Modules.Bytes; VAR offset: SIZE);
  BEGIN
        IF Reflection.GetChar(refs, offset) = Reflection.sfProcedure THEN
          Reflection.SkipSize(offset);
          Reflection.SkipString(refs, offset);
          offset := Reflection.GetAddress(refs, offset);
        ELSE
          offset:=0;
        END;
  END GetProcAdr;
VAR
	mod : Modules.Module;
	res:LONGINT;
	ofs:SIZE;
	ignoreMsg : ARRAY 32 OF CHAR; 
BEGIN
  mod := Modules.ThisModule(mn, res, ignoreMsg);
  ofs:=Reflection.FindByName(mod.refs, 0, name, FALSE);
  GetProcAdr(mod.refs,ofs);
  adr:=ofs;
END GetProcedure; 
(*loading debug information the relationship position in the text and code from file, 
 and fixing addresses to the address of procedures  in memory  *)
PROCEDURE LoadModulePosInfo*(CONST name:ARRAY OF CHAR; VAR m:ModuleInfo;CONST text:Texts.Text);
(* 
name - name of file on disk
m - pointer to the module debug infomation
*)
		VAR
			file:Files.File;
			r: Files.Reader;
			pos,pc:LONGINT;
			count:LONGINT;
			ch:CHAR;
			offset:ADDRESS;
			buf:ARRAY 255 OF CHAR;
			curPI:ProcInfo;
			utilreader : Texts.TextReader;

			PROCEDURE SearchBegin((*CONST ucsStr: ARRAY OF Texts.Char32;*) from: LONGINT):LONGINT;
			BEGIN
					text.AcquireRead;
					RETURN TextUtilities.GenericPos(beginstrutf, from, text, FALSE, TRUE);
					text.ReleaseRead;
			END SearchBegin;
			
			PROCEDURE SearchEnd(VAR from: LONGINT;adr:ADDRESS):LONGINT;
			VAR
				idx:LONGINT;
				name,ext:ARRAY 80 OF CHAR;
				extf:ARRAY 80 OF LONGINT;
			BEGIN
					text.AcquireRead;
					from:=TextUtilities.GenericPos(endinstrutf, from, text, FALSE, FALSE);
					IF Trace THEN KernelLog.String(" pos end= "); KernelLog.Int(from,0); END;
					Files.SplitExtension(curPI.name,name,ext);
					idx:=0;UTF8Strings.UTF8toUnicode(ext, extf, idx);
					from:=TextUtilities.GenericPos(extf, from, text, FALSE, FALSE);
					IF Trace THEN KernelLog.String(" pos end+= "); KernelLog.Int(from,0); KernelLog.Ln; END;
					text.ReleaseRead;
					WHILE SYSTEM.GET32(adr)#0C35DEC89H DO INC(adr) END;(*Find first:	MOV	ESP, EBP; POP	EBP; RET*)
					RETURN adr;
			END SearchEnd;

		BEGIN
			NEW(utilreader, text);

			NEW(m);
			count:=0;curPI:=NIL;
			file := Files.Old (name);
			IF file = NIL THEN	KernelLog.String("Failed to open file ");KernelLog.String(name);KernelLog.Ln; RETURN; END;
			Files.OpenReader (r, file, 0);
			WHILE r.res = Files.Ok DO
				r.Char(ch);
				IF ch="m" THEN (*name of procedure marker*)
					IF curPI#NIL THEN (* *)
						curPI.lastOfs:=SearchEnd(pos,pc+offset);
						m.AddPos(curPI, pos, curPI.lastOfs);

					END;
					r.Ln(buf);
					GetProcOffset(buf,offset);
					curPI:=m.AddProc(buf);
					curPI.startOfs:=offset;
					IF offset=0 THEN
						KernelLog.String("NotFound: "); KernelLog.String(buf); KernelLog.Ln;
					END;
(*					winstance.combo.AddItem(Strings.NewString(buf),curPI);*)
				ELSIF ch="p" THEN(*position info marker*)
					r.SkipSpaces;r.Int(pos,FALSE);r.SkipSpaces;r.Int(pc,TRUE);r.Ln(buf);
					IF pc=0 THEN
						pos:=SearchBegin(pos);
					END;
					m.AddPos(curPI, pos, pc+offset);
				ELSIF ch=0X THEN
				ELSE
					HALT(18);(*panic, file unknow format*)
				END;
			END;
			m.Sort;
			m.mod := Modules.ThisModuleByAdr(pc+offset);

END LoadModulePosInfo;

VAR
	idx:LONGINT;
BEGIN
	beginstr:="BEGIN";
	endinstr:="END";
	idx:=0;UTF8Strings.UTF8toUnicode(beginstr, beginstrutf, idx);
	idx:=0;UTF8Strings.UTF8toUnicode(endinstr, endinstrutf, idx);
END DebugInfo.
