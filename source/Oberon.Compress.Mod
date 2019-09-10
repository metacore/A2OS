(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Compress IN Oberon; (** portable *)	(* ejz  *)
	IMPORT FileDir, Files, Modules, Texts, Oberon,
		(* TextDocs *)
		Objects, Gadgets, Documents, TextDocs, Desktops;
		(* TextDocs *)
		(* TextFrames
		MenuViewers, TextFrames, Viewers;
		TextFrames *)

	CONST
		BufferSize = 4*1024;
		IndexBitCount = 12;
		LengthBitCount = 4;
		WindowSize = 4096;
		RawLookAheadSize = 16;
		BreakEven = 1;
		LookAheadSize = RawLookAheadSize + BreakEven;
		TreeRoot = WindowSize;
		EndOfStream = 0;
		Unused = 0;
		Temp = "Temp.Compress";
		err1 = "Error in archive";
		err2 = " not found";
		err3 = "encryption key needed";
		xx = 32768;
		Menu = 0;
		Cmd = 1;
		EOFName = "~ ";
		Done *= 0;
		ArchiveNotFound* = 1;
		ErrorInArchive *= 2;
		EntryNotFound *= 3;
		ArchiveExists *= 4;
		FileError *= 5;
		KeyNeeded* = 6;
		DocId0 = 0F7X; DocId1 = 07X;
		(* TextDocs *)
		DocMenu = "Compress.Open[Open] Compress.Add[Add] Compress.Extract[Extract] Compress.Delete[Delete] TextDocs.Search[Search]";
		(* TextDocs *)
		(* TextFrames
		DirMenu = "System.Close System.Grow Compress.Open Compress.Extract Compress.Delete Compress.Add";
		EditMenu = "System.Close System.Copy System.Grow Edit.Search Edit.Store";
		TextFrames *)

		(* extensions *)
		encryption* = 0;

	TYPE
		Node = RECORD
			parent, smallerChild, largerChild: SIGNED16
		END;
		Name* = ARRAY 32 OF CHAR;
		Header* = RECORD
			name*: Name;
			length*, check: SIGNED32;
			date*, time*: SIGNED32;
			ratio*: FLOAT32;
			extensions*: SET (* encryption *)
		END;
		List = POINTER TO ListDesc;
		ListDesc = RECORD
			name: FileDir.FileName;
			next: List
		END;
		HeaderList = POINTER TO HeaderListDesc;
		HeaderListDesc = RECORD
			header: Header;
			next: HeaderList
		END;
		EnumProc* = PROCEDURE (h: Header; VAR stop: BOOLEAN);
		CryptProc* = PROCEDURE (VAR Rin: Files.Rider; nIn: SIGNED32; VAR Rout: Files.Rider; key: ARRAY OF CHAR; VAR res: SIGNED16);

	VAR
		W: Texts.Writer;
		Buffer: ARRAY BufferSize OF CHAR;
		BufferPtr, CurBitNr, CurByte, Len, maxLen: SIGNED32;
		Window: ARRAY WindowSize+RawLookAheadSize+1 OF CHAR;
		Tree: ARRAY WindowSize+1 OF Node;
		Err, verbose, sorted: BOOLEAN;
		cmdSource: SIGNED32;
		headerList: HeaderList;
		Decrypt*, Encrypt*: CryptProc;
		curKey: ARRAY 64 OF CHAR;

	PROCEDURE ReadHeader(VAR R: Files.Rider; VAR h: Header; VAR err: BOOLEAN);
		VAR chk, pos: SIGNED32; i: SIGNED16;
	BEGIN
		pos := Files.Pos(R);
		Files.ReadBytes(R, h.name, 32);
		IF (h.name[0] = DocId0) & (h.name[1] = DocId1) THEN
			(* new doc-format skip header *)
			Files.Set(R, Files.Base(R), pos);
			Files.ReadInt(R, i);
			Files.ReadString(R, h.name);
			Files.ReadInt(R, i); Files.ReadInt(R, i);
			Files.ReadInt(R, i); Files.ReadInt(R, i);
			ReadHeader(R, h, err);
			RETURN
		END;
		IF R.eof & (R.res = 32) THEN
			h.name := EOFName; err := FALSE;
			RETURN
		END;
		Files.ReadLInt(R, h.length); Files.ReadLInt(R, h.check);
		Files.ReadLInt(R, h.date); Files.ReadLInt(R, h.time);
		Files.ReadReal(R, h.ratio);
		IF h.length < 0 THEN
			Files.ReadSet(R, h.extensions);
			h.length := -h.length
		ELSE
			h.extensions := {}
		END;
		IF (h.ratio > 0.0) & (h.ratio < 1000000.0) THEN
			pos := 0; chk := 0;
			WHILE pos < 32 DO
				chk := chk+ORD(h.name[pos]); INC(pos)
			END;
			chk := chk+h.length+ENTIER(h.ratio)+(h.time MOD xx)+(h.date MOD xx);
			err := chk # h.check
		ELSE
			err := TRUE
		END
	END ReadHeader;

	PROCEDURE WriteHeader(VAR R: Files.Rider; VAR h: Header);
		VAR i: SIGNED32;
	BEGIN
		IF curKey # "" THEN
			INCL(h.extensions, encryption)
		END;
		h.check := 0; i := 0;
		WHILE (i < 32) & (h.name[i] # 0X) DO
			h.check := h.check + ORD(h.name[i]);
			INC(i)
		END;
		WHILE i < 32 DO
			h.name[i] := 0X; INC(i)
		END;
		Oberon.GetClock(h.time, h.date);
		h.check := h.check+ENTIER(h.ratio)+h.length+(h.time MOD xx)+(h.date MOD xx);
		Files.WriteBytes(R, h.name, 32);
		IF h.extensions # {} THEN
			Files.WriteLInt(R, -h.length)
		ELSE
			Files.WriteLInt(R, h.length)
		END;
		Files.WriteLInt(R, h.check);
		Files.WriteLInt(R, h.date); Files.WriteLInt(R, h.time);
		Files.WriteReal(R, h.ratio);
		IF h.extensions # {} THEN
			Files.WriteSet(R, h.extensions)
		END
	END WriteHeader;

	PROCEDURE CopyFrom(VAR Ri, Ro: Files.Rider; len: SIGNED32);
		VAR i: SIGNED32;
	BEGIN
		Files.ReadBytes(Ri, Buffer, BufferSize);
		i := BufferSize;
		WHILE i <= len DO
			Files.WriteBytes(Ro, Buffer, BufferSize);
			Files.ReadBytes(Ri, Buffer, BufferSize);
			INC(i, BufferSize)
		END;
		Files.WriteBytes(Ro, Buffer, len MOD BufferSize)
	END CopyFrom;

	PROCEDURE CopyTo(VAR Ri, Ro: Files.Rider);
	BEGIN
		Files.ReadBytes(Ri, Buffer, BufferSize);
		WHILE ~Ri.eof DO
			Files.WriteBytes(Ro, Buffer, BufferSize);
			Files.ReadBytes(Ri, Buffer, BufferSize)
		END;
		Files.WriteBytes(Ro, Buffer, BufferSize-Ri.res)
	END CopyTo;

	PROCEDURE InputBit(VAR R: Files.Rider): SIGNED32;
		VAR h: SIGNED32;
	BEGIN
		IF CurBitNr = 7 THEN
			IF BufferPtr = BufferSize THEN
				Files.ReadBytes(R, Buffer, BufferSize);
				INC(Len, BufferSize-R.res); BufferPtr := 0;
				IF (Len-BufferSize) >= maxLen THEN Err := TRUE END
			END;
			CurByte := ORD(Buffer[BufferPtr]); INC(BufferPtr)
		END;
		h := ASH(CurByte, -CurBitNr) MOD 2;
		DEC(CurBitNr); IF CurBitNr < 0 THEN CurBitNr := 7 END;
		RETURN h
	END InputBit;

	PROCEDURE InputBits(VAR R: Files.Rider; count: SIGNED32): SIGNED32;
		VAR i, h: SIGNED32;
	BEGIN
		h := 0;
		i := count-1;
		WHILE i >= 0 DO
			IF CurBitNr = 7 THEN
				IF BufferPtr = BufferSize THEN
					Files.ReadBytes(R, Buffer, BufferSize);
					INC(Len, BufferSize-R.res); BufferPtr := 0;
					IF (Len-BufferSize) >= maxLen THEN Err := TRUE END
				END;
				CurByte := ORD(Buffer[BufferPtr]); INC(BufferPtr)
			END;
			IF ASH(CurByte, -CurBitNr) MOD 2 = 1 THEN
				h := h+ASH(1, i)
			END;
			DEC(CurBitNr); IF CurBitNr < 0 THEN CurBitNr := 7 END;
			DEC(i)
		END;
		RETURN h
	END InputBits;

	PROCEDURE FlushBits(VAR R: Files.Rider);
	BEGIN
		IF CurBitNr # 7 THEN
			Buffer[BufferPtr] := CHR(CurByte); INC(BufferPtr)
		END;
		IF BufferPtr > 0 THEN
			Files.WriteBytes(R, Buffer, BufferPtr); INC(Len, BufferPtr)
		END
	END FlushBits;

	PROCEDURE OutputBit(VAR R: Files.Rider; bit: SIGNED32);
	BEGIN
		IF bit = 1 THEN
			CurByte := CurByte+ASH(1, CurBitNr)
		END;
		DEC(CurBitNr);
		IF CurBitNr < 0 THEN
			Buffer[BufferPtr] := CHR(CurByte); INC(BufferPtr);
			IF BufferPtr = BufferSize THEN
				Files.WriteBytes(R, Buffer, BufferSize);
				INC(Len, BufferSize); BufferPtr := 0
			END;
			CurBitNr := 7; CurByte := 0
		END
	END OutputBit;

	PROCEDURE OutputBits(VAR R: Files.Rider; bits, count: SIGNED32);
		VAR i, h: SIGNED32;
	BEGIN
		h := bits; i := count-1;
		WHILE i >= 0 DO
			IF ASH(h, -i) MOD 2 = 1 THEN
				CurByte := CurByte+ASH(1, CurBitNr)
			END;
			DEC(CurBitNr);
			IF CurBitNr < 0 THEN
				Buffer[BufferPtr] := CHR(CurByte); INC(BufferPtr);
				IF BufferPtr = BufferSize THEN
					Files.WriteBytes(R, Buffer, BufferSize);
					INC(Len, BufferSize); BufferPtr := 0
				END;
				CurBitNr := 7; CurByte := 0
			END;
			DEC(i)
		END
	END OutputBits;

	PROCEDURE Init;
		VAR i: SIGNED32;
	BEGIN
		i := 0;
		WHILE i <= WindowSize DO
			Tree[i].parent := Unused;
			Tree[i].smallerChild := Unused;
			Tree[i].largerChild := Unused;
			Window[i] := 0X; INC(i)
		END;
		WHILE i <= WindowSize+RawLookAheadSize DO
			Window[i] := 0X; INC(i)
		END
	END Init;

	PROCEDURE InitTree(r: SIGNED32);
	BEGIN
		Tree[TreeRoot].largerChild := SHORT(r);
		Tree[r].parent := TreeRoot;
		Tree[r].largerChild := Unused;
		Tree[r].smallerChild := Unused
	END InitTree;

	PROCEDURE ContractNode(oldNode, newNode: SIGNED32);
		VAR help: SIGNED32;
	BEGIN
		help := Tree[oldNode].parent;
		Tree[newNode].parent := SHORT(help);
		IF Tree[help].largerChild = oldNode THEN
			Tree[help].largerChild := SHORT(newNode)
		ELSE
			Tree[help].smallerChild := SHORT(newNode)
		END;
		Tree[oldNode].parent := Unused
	END ContractNode;

	PROCEDURE ReplaceNode(oldNode, newNode: SIGNED32);
		VAR help, parent: SIGNED32;
	BEGIN
		parent := Tree[oldNode].parent;
		IF Tree[parent].smallerChild = oldNode THEN
			Tree[parent].smallerChild := SHORT(newNode)
		ELSE
			Tree[parent].largerChild := SHORT(newNode)
		END;
		Tree[newNode] := Tree[oldNode];
		help := Tree[newNode].smallerChild;
		Tree[help].parent := SHORT(newNode);
		help := Tree[newNode].largerChild;
		Tree[help].parent := SHORT(newNode);
		Tree[oldNode].parent := Unused
	END ReplaceNode;

	PROCEDURE DeleteString(p: SIGNED32);
		VAR replacement, larger, smaller, next: SIGNED32;
	BEGIN
		IF Tree[p].parent = Unused THEN RETURN END;
		larger := Tree[p].largerChild;
		smaller := Tree[p].smallerChild;
		IF larger = Unused THEN
			ContractNode(p, smaller)
		ELSIF smaller = Unused THEN
			ContractNode(p, larger)
		ELSE
			replacement := smaller;
			next := Tree[replacement].largerChild;
			WHILE next # Unused DO
				replacement := next;
				next := Tree[next].largerChild
			END;
			DeleteString(replacement);
			ReplaceNode(p, replacement)
		END
	END DeleteString;

	PROCEDURE AddString(newNode: SIGNED32; VAR matchPosition: SIGNED32): SIGNED32;
		VAR i, n, t, testNode, delta, matchLength, child: SIGNED32;
	BEGIN
		IF newNode = EndOfStream THEN
			RETURN 0
		END;
		testNode := Tree[TreeRoot].largerChild;
		matchLength := 0;
		LOOP
			i := 0; delta := 0; n := newNode; t := testNode;
			WHILE (i < LookAheadSize) & (delta = 0) DO
				delta := ORD(Window[n]) - ORD(Window[t]);
				INC(i); INC(n); INC(t)
			END;
			IF delta # 0 THEN DEC(i) END;
			IF i >= matchLength THEN
				matchLength := i; matchPosition := testNode;
				IF matchLength >= LookAheadSize THEN
					ReplaceNode(testNode, newNode);
					RETURN matchLength
				END
			END;
			IF delta >= 0 THEN
				child := Tree[testNode].largerChild
			ELSE
				child := Tree[testNode].smallerChild
			END;
			IF child = Unused THEN
				IF delta >= 0 THEN
					Tree[testNode].largerChild := SHORT(newNode)
				ELSE
					Tree[testNode].smallerChild := SHORT(newNode)
				END;
				Tree[newNode].parent := SHORT(testNode);
				Tree[newNode].largerChild := Unused;
				Tree[newNode].smallerChild := Unused;
				RETURN matchLength
			END;
			testNode := child
		END
	END AddString;

	PROCEDURE Compress(VAR Input, Output: Files.Rider; maxbytes: SIGNED32);
		VAR
			i, lookAheadBytes, currentPosition, replaceCount, matchLength, matchPosition: SIGNED32;
			currentLookAheadPos, bytesread: SIGNED32;
			buf: ARRAY BufferSize OF CHAR; bufpos, buflen: SIGNED32; bufend: BOOLEAN; ch: CHAR;
		PROCEDURE Read;
		BEGIN
			IF bufpos < buflen THEN
				IF bytesread < maxbytes THEN
					ch := buf[bufpos]; INC(bufpos); INC(bytesread)
				ELSE
					ch := 0X; bufend := TRUE
				END
			ELSIF ~bufend THEN
				Files.ReadBytes(Input, buf, BufferSize);
				buflen := BufferSize-Input.res;
				IF buflen <= 0 THEN
					ch := 0X; bufend := TRUE
				ELSE
					ch := buf[0]; bufpos := 1; INC(bytesread)
				END
			END
		END Read;
	BEGIN
		Init(); bufend := FALSE;
		bufpos := 0; buflen := 0;
		i := 0; bytesread := 0;
		WHILE (i < LookAheadSize) & ~bufend DO
			Read(); INC(i);
			Window[i] := ch;
			IF i <= RawLookAheadSize THEN
				Window[i+WindowSize-1] := ch
			END
		END;
		IF bufend THEN DEC(i) END;
		lookAheadBytes := i;
		InitTree(1); currentPosition := 1;
		matchLength := 0; matchPosition := 0;
		WHILE lookAheadBytes > 0 DO
			IF matchLength > lookAheadBytes THEN
				matchLength := lookAheadBytes
			END;
			IF matchLength <= BreakEven THEN
				replaceCount := 1;
				OutputBit(Output, 1);
				OutputBits(Output, ORD(Window[currentPosition]), 8)
			ELSE
				OutputBit(Output, 0);
				OutputBits(Output, matchPosition, IndexBitCount);
				OutputBits(Output, matchLength-(BreakEven+1), LengthBitCount);
				replaceCount := matchLength
			END;
			i := 0;
			WHILE i < replaceCount DO
				currentLookAheadPos := currentPosition+LookAheadSize;
				DeleteString(currentLookAheadPos MOD (WindowSize-1));
				Read();
				IF bufend THEN
					DEC(lookAheadBytes)
				ELSE
					Window[currentLookAheadPos] := ch;
					Window[currentLookAheadPos MOD (WindowSize-1)] := ch
				END;
				currentPosition := (currentPosition+1) MOD (WindowSize-1);
				IF lookAheadBytes # 0 THEN
					matchLength := AddString(currentPosition, matchPosition)
				END;
				INC(i)
			END
		END;
		OutputBit(Output, 0);
		OutputBits(Output, EndOfStream, IndexBitCount)
	END Compress;

	PROCEDURE Expand(VAR Input, Output: Files.Rider);
		VAR
			i, currentPosition, matchLength, matchPosition: SIGNED32;
			buf: ARRAY BufferSize OF CHAR; bufpos: SIGNED32; ch: CHAR;
		PROCEDURE Write;
		BEGIN
			IF bufpos < BufferSize THEN
				buf[bufpos] := ch; INC(bufpos)
			ELSE
				Files.WriteBytes(Output, buf, BufferSize);
				buf[0] := ch; bufpos := 1
			END
		END Write;
	BEGIN
		Init(); Err := FALSE;
		bufpos := 0; currentPosition := 1;
		LOOP
			IF InputBit(Input) # 0 THEN
				ch := CHR(InputBits(Input, 8)); Write();
				Window[currentPosition] := ch;
				IF currentPosition < RawLookAheadSize+1 THEN
					Window[currentPosition+WindowSize-1] := ch
				END;
				currentPosition := (currentPosition+1) MOD (WindowSize-1)
			ELSE
				matchPosition := InputBits(Input, IndexBitCount);
				IF matchPosition = EndOfStream THEN EXIT END;
				matchLength := InputBits(Input, LengthBitCount);
				INC(matchLength, BreakEven);
				i := 0;
				WHILE i <= matchLength DO
					ch := Window[matchPosition+i]; Write();
					Window[currentPosition] := ch;
					IF currentPosition < RawLookAheadSize+1 THEN
						Window[currentPosition+WindowSize-1] := ch;
					END;
					currentPosition := (currentPosition+1) MOD (WindowSize-1);
					INC(i)
				END
			END;
			IF Err THEN RETURN END
		END;
		IF bufpos > 0 THEN Files.WriteBytes(Output, buf, bufpos) END
	END Expand;

(** Compress len Bytes form Ri to Ro. *)
	PROCEDURE CopyToArc*(VAR Ri, Ro: Files.Rider; len: SIGNED32; VAR h: Header);
		VAR
			F: Files.File; R: Files.Rider;
			len0: SIGNED32; res: SIGNED16;
	BEGIN
		len0 := len; INC(len); Len := 0;
		BufferPtr := 0; CurBitNr := 7; CurByte := 0;
		IF encryption IN h.extensions THEN
			F := Files.New(""); Files.Set(R, F, 0);
			Compress(Ri, R, len);
			FlushBits(R); Files.Set(R, F, 0);
			len := Len; Len := Files.Pos(Ro);
			Encrypt(R, len, Ro, curKey, res);
			Len := Files.Pos(Ro)-Len
		ELSE
			Compress(Ri, Ro, len);
			FlushBits(Ro); res := Done
		END;
		IF len0 < 1 THEN len0 := 1 END;
		h.length := Len; h.ratio := 100*Len/len0
	END CopyToArc;

(** Expand a maximum of len Bytes from Ri to Ro.
	res:
		Done
		ErrorInArchive: error in compressed data *)
	PROCEDURE CopyFromArc*(VAR Ri, Ro: Files.Rider; VAR h: Header; VAR res: SIGNED16);
		VAR F: Files.File; R: Files.Rider;
	BEGIN
		Len := 0;
		BufferPtr := BufferSize; CurBitNr := 7; CurByte := 0;
		IF encryption IN h.extensions THEN
			IF (Decrypt # NIL) & (curKey # "") THEN
				F := Files.New(""); Files.Set(R, F, 0);
				Decrypt(Ri, h.length, R, curKey, res);
				IF res = Done THEN
					maxLen := Files.Length(F); Files.Set(R, F, 0);
					Expand(R, Ro);
					Err := Err OR ((Len MOD BufferSize) # BufferPtr)
				END
			ELSE
				Texts.WriteString(W, err3);
				Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
				res := KeyNeeded
			END
		ELSE
			maxLen := h.length;
			Expand(Ri, Ro); res := Done
		END;
		IF Err THEN res := ErrorInArchive END
	END CopyFromArc;

(* TextDocs *)
	PROCEDURE GetArcName(VAR name: ARRAY OF CHAR);
		VAR D: Documents.Document;
	BEGIN
		IF Desktops.IsInMenu(Gadgets.context) THEN
			D := Desktops.CurDoc(Gadgets.context);
			IF D # NIL THEN
				cmdSource := Menu; COPY(D.name, name);
				RETURN
			END
		END;
		cmdSource := Cmd; COPY(EOFName, name)
	END GetArcName;
(* TextDocs *)

(* TextFrames
	PROCEDURE GetArcName(VAR name: ARRAY OF CHAR);
		VAR V: Viewers.Viewer; S: Texts.Scanner;
	BEGIN
		V := Oberon.Par.vwr;
		IF (V.dsc IS TextFrames.Frame) & (V.dsc = Oberon.Par.frame) THEN
			Texts.OpenScanner(S, V.dsc(TextFrames.Frame).text, 0);
			Texts.Scan(S);
			IF S.class IN {Texts.Name, Texts.String} THEN
				cmdSource := Menu; COPY(S.s, name);
				RETURN
			END
		END;
		cmdSource := Cmd; COPY(EOFName, name)
	END GetArcName;
TextFrames *)

	PROCEDURE Remove(VAR nameList: List; VAR name: ARRAY OF CHAR);
		VAR cur, prev: List;
	BEGIN
		cur := nameList.next;
		prev := nameList;
		WHILE cur # NIL DO
			IF cur.name = name THEN
				prev.next := cur.next;
				RETURN
			ELSE
				prev := cur
			END;
			cur := cur.next
		END
	END Remove;

	PROCEDURE Search(nameList: List; VAR name: ARRAY OF CHAR): List;
	BEGIN
		WHILE nameList # NIL DO
			IF nameList.name = name THEN RETURN nameList END;
			nameList := nameList.next
		END;
		RETURN NIL
	END Search;

	PROCEDURE ClearCrypt*;
	BEGIN
		Decrypt := NIL; Encrypt := NIL; curKey := ""
	END ClearCrypt;

	PROCEDURE InstallCrypt*(install, key: ARRAY OF CHAR);
		VAR
			mod: Modules.Module;
			cmd: Modules.Command;
			i, j: SIGNED32;
	BEGIN
		ClearCrypt();
		i := 0;
		WHILE (install[i] # 0X) & (install[i] # ".") DO
			INC(i)
		END;
		IF install[i] = "." THEN
			install[i] := 0X; INC(i);
			mod := Modules.ThisMod(install);
			IF mod # NIL THEN
				j := 0;
				WHILE install[i] # 0X DO
					install[j] := install[i]; INC(i); INC(j)
				END;
				install[j] := 0X;
				cmd := Modules.ThisCommand(mod, install);
				IF cmd # NIL THEN
					cmd(); COPY(key, curKey)
				END
			END
		END;
		ASSERT((Decrypt # NIL) & (Encrypt # NIL))
	END InstallCrypt;

	PROCEDURE GetArgs(VAR nameList: List);
		VAR
			h, last: List;
			S: Texts.Scanner;
			mn: FileDir.FileName;
			arrow: BOOLEAN;
			T: Texts.Text;
			beg, end, time, pos: SIGNED32;
	BEGIN
		ClearCrypt();
		verbose := FALSE; sorted := FALSE;
		pos := 0; end := 0; arrow := FALSE;
		nameList := NIL; last := NIL;
		GetArcName(mn);
		IF mn # EOFName THEN
			arrow := TRUE;
			NEW(h); h.next := NIL;
			COPY(mn, h.name);
			nameList := h;
			last := nameList;
			Oberon.GetSelection(T, beg, end, time);
			IF time > 0 THEN
				Texts.OpenScanner(S, T, beg); pos := beg; Texts.Scan(S)
			ELSE
				RETURN
			END
		ELSE
			Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
			Texts.Scan(S);
			WHILE (S.class = Texts.Char) & (S.c = Oberon.OptionChar) DO
				Texts.Scan(S);
				ASSERT(S.class = Texts.Name);
				CASE CAP(S.s[0]) OF
					"C": Texts.Scan(S); COPY(S.s, mn); ASSERT(S.class = Texts.Name);
							Texts.Scan(S); ASSERT(S.class IN {Texts.Name, Texts.String});
							InstallCrypt(mn, S.s)
					|"D": verbose := TRUE
					|"S": sorted := TRUE
				END;
				Texts.Scan(S)
			END;
			IF (S.class = Texts.Char) & (S.c = "^") THEN
				arrow := TRUE;
				Oberon.GetSelection(T, beg, end, time);
				IF time > 0 THEN
					Texts.OpenScanner(S, T, beg); pos := beg; Texts.Scan(S)
				ELSE
					RETURN
				END
			END
		END;
		WHILE (S.class # Texts.Inval) & ((cmdSource = Menu) & (pos <= end+S.len)) OR
						((cmdSource = Cmd) & (S.class IN {Texts.Name, Texts.String}) & (~arrow OR (arrow & (pos <= end+S.len)))) DO
			NEW(h);
			h.next := NIL;
			COPY(S.s, h.name);
			IF Search(nameList, h.name) = NIL THEN
				IF last = NIL THEN
					nameList := h
				ELSE
					last.next := h
				END;
				last := h
			END;
			Texts.Scan(S);
			IF ~arrow & (S.class = Texts.Char) & (S.c = "^") THEN
				arrow := TRUE;
				Oberon.GetSelection(T, beg, end, time);
				IF time > 0 THEN
					Texts.OpenScanner(S, T, beg); Texts.Scan(S)
				END
			END;
			pos := Texts.Pos(S)
		END
	END GetArgs;

	PROCEDURE Trimm(VAR name: ARRAY OF CHAR);
		VAR i, j: SIGNED32; ch: CHAR;
	BEGIN
		i := 0; j := 0; ch := name[0];
		WHILE ch # 0X DO
			IF (ch = "/") OR (ch = "\") THEN
				j := 0
			ELSE
				name[j] := ch; INC(j)
			END;
			INC(i); ch := name[i]
		END;
		name[j] := 0X
	END Trimm;

	PROCEDURE NextName(VAR name: ARRAY OF CHAR);
		VAR i: SIGNED32; ch: CHAR;
	BEGIN
		i := 0; WHILE name[i] # 0X DO INC(i) END;
		ch := name[i-1];
		IF (ch >= "0") & (ch <= "8") THEN
			name[i-1] := CHR(ORD(ch)+1)
		ELSE
			name[i] := "0"; name[i+1] := 0X
		END
	END NextName;

	PROCEDURE InsertHeadSort(h: Header; VAR stop: BOOLEAN);
		VAR newElem, prevElem, curElem: HeaderList;
	BEGIN
		NEW(newElem); newElem.header := h;
		prevElem := NIL; curElem := headerList;
		WHILE (curElem # NIL) & (curElem.header.name < h.name) DO
			prevElem := curElem; curElem := curElem.next
		END;
		newElem.next := curElem;
		IF (prevElem = NIL) THEN headerList := newElem ELSE prevElem.next := newElem END
	END InsertHeadSort;

(** Enumerate all entries in the archive (archive). Stop if stop (in enumProc) is set or if at end of archive.
		res:
			Done
			ArchiveNotFound: archive-file not found
			ErrorInArchive: internal error in archive-file *)
	PROCEDURE Enumerate*(archive: ARRAY OF CHAR; enumProc: EnumProc; sorted: BOOLEAN; VAR res: SIGNED16);
		VAR
			F: Files.File; R: Files.Rider;
			h: Header; err, stop: BOOLEAN;
	BEGIN
		IF sorted THEN
			headerList := NIL;
			Enumerate(archive, InsertHeadSort, FALSE, res);
			IF res = Done THEN
				stop := FALSE;
				WHILE ~stop & (headerList # NIL) DO
					enumProc(headerList.header, stop); headerList := headerList.next
				END
			END;
			headerList := NIL
		ELSE
			F := Files.Old(archive);
			IF F # NIL THEN
				err := FALSE; stop := FALSE;
				Files.Set(R, F, 0);
				ReadHeader(R, h, err);
				WHILE (h.name # EOFName) & ~err & ~stop DO
					enumProc(h, stop);
					Files.Set(R, F, Files.Pos(R)+h.length);
					ReadHeader(R, h, err)
				END;
				IF err THEN
					res := ErrorInArchive
				ELSE
					res := Done
				END
			ELSE
				res := ArchiveNotFound
			END
		END
	END Enumerate;

(** Add a new entry (file) to the archive (archive) with data read from R.
		file: input: name of the entry
				output: name choosen for entry (may differ if names collaps)
		res:
			Done
			ArchiveNotFound: archive-file not found
			ErrorInArchive: internal error in archive-file *)
	PROCEDURE AddFile*(archive: ARRAY OF CHAR; VAR file: ARRAY OF CHAR; VAR R: Files.Rider; len: SIGNED32; VAR res: SIGNED16);
		VAR
			ArcF: Files.File;
			Ra: Files.Rider;
			h: Header;
			pos: SIGNED32;
			addL, ha: List;
			err: BOOLEAN;
	BEGIN
		ArcF := Files.Old(archive);
		IF ArcF # NIL THEN
			Files.Set(Ra, ArcF, 0);
			addL := NIL;
			pos := Files.Pos(Ra);
			ReadHeader(Ra, h, err);
			WHILE (h.name # EOFName) & ~err DO
				IF addL = NIL THEN
					NEW(addL); COPY(h.name, addL.name);
					addL.next := NIL
				ELSE
					NEW(ha); COPY(h.name, ha.name);
					ha.next := addL; addL := ha
				END;
				Files.Set(Ra, ArcF, Files.Pos(Ra)+h.length);
				pos := Files.Pos(Ra);
				ReadHeader(Ra, h, err)
			END;
			IF err THEN
				res := ErrorInArchive;
				RETURN
			END;
			Trimm(file);
			WHILE Search(addL, file) # NIL DO
				NextName(file)
			END;
			pos := Files.Pos(Ra);
			COPY(file, h.name);
			h.extensions := {};
			WriteHeader(Ra, h);
			CopyToArc(R, Ra, len, h);
			Files.Set(Ra, ArcF, pos);
			WriteHeader(Ra, h);
			Files.Close(ArcF);
			res := Done
		ELSE
			res := ArchiveNotFound
		END
	END AddFile;

	PROCEDURE WriteDocHead(VAR R: Files.Rider);
	BEGIN
		(* TextDocs *)
		Files.WriteInt(R, Documents.Id);
		(* TextDocs *)
		(* TextFrames
		Files.Write(R, DocId0); Files.Write(R, DocId1);
		TextFrames *)
		Files.WriteString(R, "Compress.NewDoc");
		Files.WriteInt(R, 0); Files.WriteInt(R, 0);
		Files.WriteInt(R, 200); Files.WriteInt(R, 250)
	END WriteDocHead;

(** Delete entry (file) from the archive (archive).
		res:
			Done
			ArchiveNotFound: archive-file not found
			ErrorInArchive: internal error in archive-file
			EntryNotFound: no such entry (entry) found *)
	PROCEDURE DeleteFile*(archive, file: ARRAY OF CHAR; VAR res: SIGNED16);
		VAR
			ArcF, TmpF: Files.File;
			Ra, Rt: Files.Rider;
			h: Header;
			err, del: BOOLEAN;
			pos: SIGNED32;
	BEGIN
		ArcF := Files.Old(archive);
		IF ArcF # NIL THEN
			TmpF := Files.New(Temp);
			Files.Set(Rt, TmpF, 0);
			del := FALSE;
			Files.Set(Ra, ArcF, 0);
			ReadHeader(Ra, h, err);
			WHILE (h.name # EOFName) & ~err DO
				pos := Files.Pos(Ra);
				IF h.name = file THEN
					del := TRUE
				ELSE
					WriteHeader(Rt, h);
					Files.Set(Ra, ArcF, pos);
					CopyFrom(Ra, Rt, h.length)
				END;
				Files.Set(Ra, ArcF, pos+h.length);
				ReadHeader(Ra, h, err)
			END;
			IF err THEN
				res := ErrorInArchive
			ELSIF del THEN
				Files.Set(Rt, TmpF, 0);
				ArcF := Files.New(archive);
				Files.Set(Ra, ArcF, 0);
				WriteDocHead(Ra);
				CopyTo(Rt, Ra);
				Files.Register(ArcF);
				res := Done
			ELSE
				res := EntryNotFound
			END
		ELSE
			res := ArchiveNotFound
		END
	END DeleteFile;

(** Extract entry (file) from the archive (archive) and write its data to R.
		res:
			Done
			ArchiveNotFound: archive-file not found
			ErrorInArchive: internal error in archive-file
			EntryNotFound no such entry (entry) found *)
	PROCEDURE ExtractFile*(archive, file: ARRAY OF CHAR; VAR R: Files.Rider; VAR res: SIGNED16);
		VAR
			ArcF: Files.File;
			Ra: Files.Rider;
			h: Header;
			err, found: BOOLEAN;
			pos: SIGNED32;
	BEGIN
		ArcF := Files.Old(archive);
		IF ArcF # NIL THEN
			found := FALSE; res := Done;
			Files.Set(Ra, ArcF, 0);
			ReadHeader(Ra, h, err);
			WHILE (h.name # EOFName) & ~err & ~found DO
				pos := Files.Pos(Ra);
				IF h.name = file THEN
					found := TRUE;
					CopyFromArc(Ra, R, h, res)
				ELSE
					Files.Set(Ra, ArcF, pos+h.length);
					ReadHeader(Ra, h, err)
				END
			END;
			IF err THEN
				res := ErrorInArchive
			ELSIF ~found THEN
				res := EntryNotFound
			END
		ELSE
			res := ArchiveNotFound
		END
	END ExtractFile;

(** Extract all entries in archive (archive).
		res:
			Done
			ArchiveNotFound: archive-file not found
			ErrorInArchive: internal error in archive-file
			FileError: an entry file could not be created *)
	PROCEDURE ExtractAllFiles*(archive: ARRAY OF CHAR; VAR res: SIGNED16);
		VAR
			ArcF, AddF: Files.File;
			Ra, RF: Files.Rider;
			h: Header;
			err: BOOLEAN;
			pos: SIGNED32;
	BEGIN
		ArcF := Files.Old(archive);
		IF ArcF # NIL THEN
			Files.Set(Ra, ArcF, 0);
			ReadHeader(Ra, h, err);
			WHILE (h.name # EOFName) & ~err DO
				pos := Files.Pos(Ra);
				AddF := Files.New(h.name);
				IF AddF # NIL THEN
					Files.Set(RF, AddF, 0);
					CopyFromArc(Ra, RF, h, res);
					IF res = Done THEN
						Files.Register(AddF); Files.SetDate(AddF, h.time, h.date)
					ELSE
						RETURN
					END
				ELSE
					res := FileError;
					RETURN
				END;
				Files.Set(Ra, ArcF, pos+h.length);
				ReadHeader(Ra, h, err)
			END;
			IF err THEN
				res := ErrorInArchive
			ELSE
				res := Done
			END
		ELSE
			res := ArchiveNotFound
		END
	END ExtractAllFiles;

(** Create a new empty archive.
		res:
			Done
			ArchiveExists: archive allready existed
			FileError: archive-file could not be created *)
	PROCEDURE CreateArchive*(archive: ARRAY OF CHAR; VAR res: SIGNED16);
		VAR
			ArcF: Files.File;
			R: Files.Rider;
	BEGIN
		ArcF := Files.Old(archive);
		IF ArcF = NIL THEN
			ArcF := Files.New(archive);
			IF ArcF = NIL THEN
				res := FileError
			ELSE
				Files.Set(R, ArcF, 0);
				WriteDocHead(R);
				Files.Register(ArcF);
				res := Done
			END
		ELSE
			res := ArchiveExists
		END
	END CreateArchive;

	PROCEDURE ShowHead(h: Header; VAR stop: BOOLEAN);
	BEGIN
		Texts.WriteString(W, h.name);
		IF verbose THEN
			Texts.WriteString(W, "  ");
			Texts.WriteDate(W, h.time, h.date);
			Texts.WriteString(W, "   ");
			Texts.WriteInt(W, h.length, 0);
			Texts.WriteString(W, "  ");
			Texts.WriteRealFix(W, h.ratio, 0, 2, 0);
			Texts.WriteString(W, "% ");
			IF encryption IN h.extensions THEN
				Texts.WriteString(W, "   encrypted")
			END
		END;
		Texts.WriteLn(W)
	END ShowHead;

(* TextDocs *)
	PROCEDURE DocHandler(D: Objects.Object; VAR M: Objects.ObjMsg);
	BEGIN
		WITH D: Documents.Document DO
			IF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "Gen" THEN
							M.class := Objects.String;
							M.s := "Compress.NewDoc";
							M.res := 0
						ELSE
							TextDocs.DocHandler(D, M)
						END
					ELSE
						TextDocs.DocHandler(D, M)
					END
				END
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.get THEN
						IF M.name = "DeskMenu" THEN
							M.obj := Gadgets.CopyPublicObject("CompressDocs.DeskMenu", TRUE);
							IF M.obj = NIL THEN M.obj := Desktops.NewMenu(DocMenu) END;
							M.res := 0
						ELSIF M.name = "SystemMenu" THEN
							M.obj := Gadgets.CopyPublicObject("CompressDocs.SystemMenu", TRUE);
							IF M.obj = NIL THEN M.obj := Desktops.NewMenu(DocMenu) END;
							M.res := 0
						ELSIF M.name = "UserMenu" THEN
							M.obj := Gadgets.CopyPublicObject("CompressDocs.UserMenu", TRUE);
							IF M.obj = NIL THEN M.obj := Desktops.NewMenu(DocMenu) END;
							M.res := 0
						ELSE
							TextDocs.DocHandler(D, M)
						END
					ELSE
						TextDocs.DocHandler(D, M)
					END
				END
			ELSE
				TextDocs.DocHandler(D, M)
			END
		END
	END DocHandler;

	PROCEDURE LoadDoc(D: Documents.Document);
		VAR
			res: SIGNED16;
			T: Texts.Text;
			L: Objects.LinkMsg;
			A: Objects.AttrMsg;
	BEGIN
		Enumerate(D.name, ShowHead, sorted, res);
		verbose := FALSE;
		IF res = ArchiveNotFound THEN
			CreateArchive(D.name, res);
			IF res = Done THEN
				Texts.WriteString(W, "New archive");
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf)
			ELSE
				D.dsc := NIL
			END
		ELSE
			A.id := Objects.set;
			A.name := "Lock";
			A.class := Objects.Bool;
			A.b := TRUE;
			D.dsc.handle(D.dsc, A);
			NEW(T);
			Texts.Open(T, "");
			Texts.WriteLn(W);
			CASE res OF
				ErrorInArchive: Texts.WriteString(W, err1)
			ELSE
			END;
			Texts.Append(T, W.buf);
			L.id := Objects.set;
			L.name := "Model";
			L.obj := T;
			D.dsc.handle(D.dsc, L)
		END
	END LoadDoc;

(** Document new-procedure for compress-archives.
		Old archive files can be opened with Desktops.OpenDoc old.arc(Compress.NewDoc) . *)
	PROCEDURE NewDoc*;
		VAR D: Objects.Object;
	BEGIN
		D := Gadgets.CreateObject("TextDocs.NewDoc");
		WITH D: Documents.Document DO
			D.Load := LoadDoc;
			D.handle := DocHandler
		END;
		Objects.NewObj := D
	END NewDoc;

(** Compress.Directory:
	Display a list of all entries in an archive. If option "d" is used
	additional information on contents is given. If option "s" is used
	the output is sorted by filename.
	syntax:
		Compress.Directory Archive.Arc
		Compress.Directory /d Archive.Arc
		Compress.Directory ^
		Compress.Directory /d ^ *)
	PROCEDURE Directory*;
		VAR
			nameList: List;
			D: Objects.Object;
	BEGIN
		GetArgs(nameList);
		IF nameList = NIL THEN
			RETURN
		ELSE
			D := Gadgets.CreateObject("Compress.NewDoc");
			WITH D: Documents.Document DO
				COPY(nameList.name, D.name);
				LoadDoc(D);
				Desktops.ShowDoc(D)
			END
		END
	END Directory;
(* TextDocs *)

(* TextFrames
	PROCEDURE GetText(): Texts.Text;
		VAR
			V: Viewers.Viewer;
	BEGIN
		V := Oberon.Par.vwr;
		IF (V = NIL) OR (V.dsc = NIL) OR (V.dsc.next = NIL) THEN
			RETURN NIL
		ELSIF V.dsc.next IS TextFrames.Frame THEN
			RETURN V.dsc.next(TextFrames.Frame).text
		ELSE
			RETURN NIL
		END
	END GetText;

(** Compress.Directory:
	Display a list of all entries in an archive. If option "d" is used
	additional information on contents is given.
	syntax:
		Compress.Directory Archive.Arc
		Compress.Directory /d Archive.Arc
		Compress.Directory ^
		Compress.Directory /d ^ *)
	PROCEDURE Directory*;
		VAR
			nameList: List;
			res, x, y: SIGNED16;
			T: Texts.Text;
			V: MenuViewers.Viewer;
	BEGIN
		GetArgs(nameList);
		IF nameList = NIL THEN
			RETURN
		END;
		Enumerate(nameList.name, ShowHead, res);
		verbose := FALSE;
		IF res = ArchiveNotFound THEN
			CreateArchive(nameList.name, res);
			IF res = Done THEN
				Texts.WriteString(W, "New archive");
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf)
			END
		ELSE
			IF cmdSource = Menu THEN
				T := GetText()
			ELSE
				T := NIL
			END;
			IF T = NIL THEN
				NEW(T);
				T := TextFrames.Text("");
				Oberon.AllocateUserViewer(Oberon.Mouse.X, x, y);
				V := MenuViewers.New(TextFrames.NewMenu(nameList.name, DirMenu), TextFrames.NewText(T, 0), TextFrames.menuH, x, y);
				V.dsc.next.handle := TextFrames.Handle
			ELSE
				Texts.Delete(T, 0, T.len)
			END;
			Texts.WriteLn(W);
			CASE res OF
				ErrorInArchive: Texts.WriteString(W, err1)
			ELSE
			END;
			Texts.Append(T, W.buf)
		END
	END Directory;
TextFrames *)

(** Compress.Add:
	Add files to an archive, if the archive not already exists, create
	a new one.
	syntax:
		Compress.Add Archive.Arc file1 file2 ... ~
		Compress.Add Archive.Arc ^ ~ *)
	PROCEDURE Add*;
		VAR
			nl, nameList: List;
			addL, ha: List;
			new, err, changed: BOOLEAN;
			ArcF, AddF: Files.File;
			R, RF: Files.Rider;
			h: Header;
			pos: SIGNED32;
	BEGIN
		GetArgs(nameList);
		IF (nameList = NIL) OR (nameList.next = NIL) THEN
			RETURN
		END;
		new := FALSE;
		ArcF := Files.Old(nameList.name);
		IF ArcF = NIL THEN
			Texts.WriteString(W, "New archive");
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			new := TRUE;
			ArcF := Files.New(nameList.name);
			Files.Set(R, ArcF, 0);
			WriteDocHead(R)
		END;
		Texts.WriteString(W, "Compress.Add ");
		Texts.WriteString(W, nameList.name);
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf);
		changed := FALSE;
		Files.Set(R, ArcF, 0);
		addL := NIL;
		pos := Files.Pos(R);
		ReadHeader(R, h, err);
		WHILE (h.name # EOFName) & ~err DO
			IF addL = NIL THEN
				NEW(addL); COPY(h.name, addL.name);
				addL.next := NIL
			ELSE
				NEW(ha); COPY(h.name, ha.name);
				ha.next := addL; addL := ha
			END;
			Files.Set(R, ArcF, Files.Pos(R)+h.length);
			pos := Files.Pos(R);
			ReadHeader(R, h, err)
		END;
		IF err THEN
			Texts.WriteString(W, err1);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			Files.Close(ArcF);
			RETURN
		END;
		h.length := 0;
		nl := nameList.next;
		WHILE nl # NIL DO
			AddF := Files.Old(nl.name);
			IF AddF = NIL THEN
				Texts.WriteString(W, "    ");
				Texts.WriteString(W, nl.name);
				Texts.WriteString(W, err2);
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf)
			ELSE
				Trimm(nl.name);
				WHILE Search(addL, nl.name) # NIL DO
					NextName(nl.name)
				END;
				Files.Set(R, ArcF, Files.Length(ArcF));
				pos := Files.Pos(R);
				COPY(nl.name, h.name);
				Texts.WriteString(W, "    ");
				Texts.WriteString(W, nl.name);
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf);
				changed := TRUE;
				h.extensions := {};
				WriteHeader(R, h);
				Files.Set(RF, AddF, 0);
				CopyToArc(RF, R, Files.Length(AddF), h);
				Files.Close(AddF);
				Files.Set(R, ArcF, pos);
				WriteHeader(R, h);
				NEW(ha);
				ha.name := nl.name;
				ha.next := addL;
				addL := ha
			END;
			nl := nl.next
		END;
		IF new THEN
			Files.Register(ArcF)
		ELSE
			Files.Close(ArcF)
		END;
		(* TextDocs *)
		IF changed & (cmdSource = Menu) THEN
			LoadDoc(Desktops.CurDoc(Gadgets.context))
		END
		(* TextDocs *)
		(* TextFrames
		IF changed & (cmdSource = Menu) THEN
			Directory()
		END
		TextFrames *)
	END Add;

(** Compress.Delete
	Delete selected files from an archive.
	syntax:
		Compress.Delete Archive.Arc file1 file2 ... ~
		Compress.Delete Archive.Arc ^ ~ *)
	PROCEDURE Delete*;
		TYPE
			DelList = POINTER TO DelListDesc;
			DelListDesc = RECORD
				start, end: SIGNED32;
				next: DelList
			END;
		VAR
			nameList, nl: List;
			DeleteList, last, dl: DelList;
			ArcF, TmpF: Files.File;
			R, Rt: Files.Rider;
			h: Header;
			pos, beg: SIGNED32;
			res: SIGNED16;
			err, changed: BOOLEAN;
	BEGIN
		GetArgs(nameList);
		IF (nameList = NIL) OR (nameList.next = NIL) THEN
			RETURN
		END;
		ArcF := Files.Old(nameList.name);
		IF ArcF = NIL THEN
			Texts.WriteString(W, nameList.name);
			Texts.WriteString(W, err2);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			RETURN
		END;
		DeleteList := NIL; last := NIL;
		changed := FALSE;
		Texts.WriteString(W, "Compress.Delete ");
		Texts.WriteString(W, nameList.name);
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf);
		Files.Set(R, ArcF, 0); beg := 0;
		ReadHeader(R, h, err);
		WHILE (h.name # EOFName) & (nameList.next # NIL) & ~err DO
			pos := Files.Pos(R);
			IF Search(nameList, h.name) # NIL THEN
				NEW(dl);
				dl.start := beg;
				dl.end := pos+h.length;
				dl.next := NIL;
				IF last = NIL THEN
					DeleteList := dl
				ELSE
					last.next := dl
				END;
				last := dl;
				Texts.WriteString(W, "    ");
				Texts.WriteString(W, h.name);
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf);
				Remove(nameList, h.name)
			END;
			Files.Set(R, ArcF, pos+h.length);
			beg := pos+h.length;
			ReadHeader(R, h, err)
		END;
		Files.Close(ArcF);
		nl := nameList.next;
		WHILE nl # NIL DO
			Texts.WriteString(W, "    ");
			Texts.WriteString(W, nl.name);
			Texts.WriteString(W, err2);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			nl := nl.next
		END;
		IF err THEN
			Texts.WriteString(W, err1);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END;
		IF DeleteList # NIL THEN
			changed := TRUE;
			Files.Delete(Temp, res); Files.Rename(nameList.name, Temp, res);
			ArcF := Files.New(nameList.name);
			Files.Set(R, ArcF, 0);
			TmpF := Files.Old(Temp);
			Files.Set(Rt, TmpF, 0);
			WHILE DeleteList # NIL DO
				CopyFrom(Rt, R, DeleteList.start-Files.Pos(Rt));
				Files.Set(Rt, TmpF, DeleteList.end);
				DeleteList := DeleteList.next
			END;
			CopyTo(Rt, R);
			Files.Close(TmpF);
			Files.Delete(Temp, res);
			Files.Register(ArcF)
		END;
		(* TextDocs *)
		IF changed & (cmdSource = Menu) THEN
			LoadDoc(Desktops.CurDoc(Gadgets.context))
		END
		(* TextDocs *)
		(* TextFrames
		IF changed & (cmdSource = Menu) THEN
			Directory()
		END
		TextFrames *)
	END Delete;

(** Compress.Open
	Unpack a file from an archive and open it in a viewer.
	No file is written to disk.
	syntax:
		Compress.Open Archive.Arc file ~
		Compress.Open Archive.Arc ^ ~ *)
	PROCEDURE Open*;
		VAR
			nameList: List;
			ArcF, AddF: Files.File;
			R, RF: Files.Rider;
			h: Header;
			pos: SIGNED32;
			err: BOOLEAN;
			dot, j: SIGNED32;
			res: SIGNED16;
			temp: ARRAY 32 OF CHAR;
			(* TextDocs *)
			D: Documents.Document;
			(* TextDocs *)
			(* TextFrames
			x, y: SIGNED16;
			T: Texts.Text;
			V: MenuViewers.Viewer;
			TextFrames *)
	BEGIN
		GetArgs(nameList);
		IF nameList = NIL THEN
			RETURN
		ELSIF nameList.next = NIL THEN
			RETURN
		END;
		ArcF := Files.Old(nameList.name);
		IF ArcF = NIL THEN
			Texts.WriteString(W, nameList.name);
			Texts.WriteString(W, err2);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			RETURN
		END;
		AddF := NIL;
		Files.Set(R, ArcF, 0);
		ReadHeader(R, h, err);
		WHILE (h.name # EOFName) & ~err & (AddF = NIL) DO
			pos := Files.Pos(R);
			IF h.name = nameList.next.name THEN
				COPY(Temp, temp);
				res := 0;
				WHILE temp[res] # 0X DO
					INC(res)
				END;
				dot := -1;
				j := 0;
				WHILE h.name[j] # 0X DO
					IF h.name[j] = "." THEN
						dot := j
					END;
					INC(j)
				END;
				IF dot > 0 THEN
					WHILE h.name[dot] # 0X DO
						temp[res] := h.name[dot];
						INC(res);
						INC(dot)
					END;
					temp[res] := 0X
				END;
				AddF := Files.New(temp);
				Files.Set(RF, AddF, 0);
				CopyFromArc(R, RF, h, res);
				IF res = Done THEN
					Files.Register(AddF)
				ELSE
					RETURN
				END
			ELSE
				Files.Set(R, ArcF, pos+h.length);
				ReadHeader(R, h, err)
			END
		END;
		IF err THEN
			Texts.WriteString(W, err1);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END;
		Files.Close(ArcF);
		IF AddF # NIL THEN
			(* TextDocs *)
			D := Documents.Open(temp);
			COPY(h.name, D.name);
			Desktops.ShowDoc(D);
			(* TextDocs *)
			(* TextFrames
			NEW(T);
			T := TextFrames.Text(temp);
			Oberon.AllocateUserViewer(Oberon.Mouse.X, x, y);
			V := MenuViewers.New(TextFrames.NewMenu(h.name, EditMenu), TextFrames.NewText(T, 0), TextFrames.menuH, x, y);
			V.dsc.next.handle := TextFrames.Handle;
			TextFrames *)
			Files.Delete(temp, res)
		ELSE
			Texts.WriteString(W, nameList.next.name);
			Texts.WriteString(W, err2);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END
	END Open;

	PROCEDURE NewFile(VAR name: ARRAY OF CHAR): Files.File;
		VAR f, g: Files.File; old, new: FileDir.FileName;
	BEGIN
		Texts.WriteString(W, "    ");
		Texts.WriteString(W, name);
		Texts.Append(Oberon.Log, W.buf);
		f := Files.Old(name);
		g := Files.New(name);
		IF f # NIL THEN
			Files.GetName(f, old);
			Files.GetName(g, new);
			IF old = new THEN
				Texts.WriteString(W, " overwriting")
			END
		END;
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf);
		RETURN g
	END NewFile;

(** Compress.Extract
	Unpack selected files from an archive.
	syntax:
		Compress.Extract Archive.Arc file1 file2 ... ~
		Compress.Extract Archive.Arc ^ ~ *)
	PROCEDURE Extract*;
		VAR
			nameList: List;
			ArcF, AddF: Files.File;
			R, RF: Files.Rider;
			h: Header;
			pos: SIGNED32;
			res: SIGNED16;
			err: BOOLEAN;
	BEGIN
		GetArgs(nameList);
		IF (nameList = NIL) OR (nameList.next = NIL) THEN
			RETURN
		END;
		ArcF := Files.Old(nameList.name);
		IF ArcF = NIL THEN
			Texts.WriteString(W, nameList.name);
			Texts.WriteString(W, err2);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			RETURN
		END;
		Texts.WriteString(W, "Compress.Extract ");
		Texts.WriteString(W, nameList.name);
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf);
		Files.Set(R, ArcF, 0);
		ReadHeader(R, h, err);
		WHILE (h.name # EOFName) & (nameList.next # NIL) & ~err DO
			pos := Files.Pos(R);
			IF Search(nameList, h.name) # NIL THEN
				AddF := NewFile(h.name);
				Files.Set(RF, AddF, 0);
				CopyFromArc(R, RF, h, res);
				IF res = Done THEN
					Files.Register(AddF); Files.SetDate(AddF, h.time, h.date)
				ELSE
					err := TRUE
				END;
				Remove(nameList, h.name)
			END;
			IF ~err THEN
				Files.Set(R, ArcF, pos+h.length);
				ReadHeader(R, h, err)
			END
		END;
		IF err THEN
			Texts.WriteString(W, err1);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf)
		END;
		IF nameList.next # NIL THEN
			nameList := nameList.next;
			WHILE nameList # NIL DO
				Texts.WriteString(W, nameList.name);
				Texts.WriteString(W, err2);
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf);
				nameList := nameList.next
			END
		END;
		Files.Close(ArcF)
	END Extract;

	PROCEDURE InsertHeadEnd(h: Header; VAR stop: BOOLEAN);
	BEGIN
		NEW(headerList.next); headerList := headerList.next;
		headerList.next := NIL; headerList.header := h
	END InsertHeadEnd;

(** Compress.Rename
	Rename entries in a archive.
	syntax:
		Compress.Rename Archive.Arc old1 => new1 old2 => new2 ... ~ *)
	PROCEDURE Rename*;
		VAR
			S: Texts.Scanner;
			F: Files.File;
			R: Files.Rider;
			h, hn: HeaderList;
			he: Header;
			name: Name;
			pos: SIGNED32;
			res: SIGNED16;
			err: BOOLEAN;
	BEGIN
		Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Texts.Scan(S);
		IF S.class IN {Texts.Name, Texts.String} THEN
			Texts.WriteString(W, "Compress.Rename "); Texts.WriteString(W, S.s);
			F := Files.Old(S.s);
			NEW(h); h.next := NIL; headerList := h;
			Enumerate(S.s, InsertHeadEnd, FALSE, res);
			headerList := h.next;
			IF res = Done THEN
				Texts.Scan(S);
				WHILE (S.class IN {Texts.Name, Texts.String}) & (res = Done) DO
					COPY(S.s, name); res := -1;
					Texts.WriteLn(W); Texts.WriteString(W, "    ");
					Texts.WriteString(W, name);
					Texts.Scan(S);
					IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
						IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
							IF S.class IN {Texts.Name, Texts.String} THEN
								h := headerList;
								WHILE (h # NIL) & (h.header.name # name) DO
									h := h.next
								END;
								IF h # NIL THEN
									IF encryption IN h.header.extensions THEN
										Texts.WriteString(W, err3); res := KeyNeeded
									ELSE
										hn := h; h := headerList;
										WHILE (h # NIL) & (h.header.name # S.s) DO
											h := h.next
										END;
										IF h = NIL THEN
											Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
											COPY(S.s, hn.header.name); res := Done
										ELSE
											Texts.WriteString(W, " name conflict")
										END
									END
								ELSE
									Texts.WriteString(W, err2)
								END
							END
						END
					END;
					Texts.Append(Oberon.Log, W.buf);
					Texts.Scan(S)
				END;
				IF res = Done THEN
					err := FALSE; Files.Set(R, F, 0);
					ReadHeader(R, he, err); h := headerList;
					WHILE (he.name # EOFName) & ~err DO
						pos := Files.Pos(R);
						IF he.name # h.header.name THEN
							Files.Set(R, F, pos-20-32);
							WriteHeader(R, h.header)
						END;
						Files.Set(R, F, pos+he.length);
						ReadHeader(R, he, err); h := h.next
					END;
					Files.Close(F)
				END
			ELSIF res = ArchiveNotFound THEN
				Texts.WriteString(W, err2)
			ELSE
				Texts.Write(W, " "); Texts.WriteString(W, err1)
			END;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
		END
	END Rename;

(** Compress.ExtractAll
	Unpack all files from a list of archives.
	syntax:
		Compress.ExtractAll Archive1.Arc ... ~*)
	PROCEDURE ExtractAll*;
		VAR
			nameList: List;
			ArcF, AddF: Files.File;
			R, RF: Files.Rider;
			h: Header;
			pos: SIGNED32;
			res: SIGNED16;
			err: BOOLEAN;
	BEGIN
		GetArgs(nameList); err := FALSE;
		WHILE (nameList # NIL) & ~err DO
			ArcF := Files.Old(nameList.name);
			IF ArcF = NIL THEN
				Texts.WriteString(W, nameList.name);
				Texts.WriteString(W, err2);
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf);
				RETURN
			END;
			Texts.WriteString(W, "Compress.ExtractAll ");
			Texts.WriteString(W, nameList.name);
			Texts.WriteLn(W);
			Texts.Append(Oberon.Log, W.buf);
			Files.Set(R, ArcF, 0);
			ReadHeader(R, h, err);
			WHILE (h.name # EOFName) & ~err DO
				pos := Files.Pos(R);
				AddF := NewFile(h.name);
				Files.Set(RF, AddF, 0);
				CopyFromArc(R, RF, h, res);
				IF res = Done THEN
					Files.Register(AddF); Files.SetDate(AddF, h.time, h.date)
				ELSE
					err := TRUE
				END;
				IF ~err THEN
					Files.Set(R, ArcF, pos+h.length);
					ReadHeader(R, h, err)
				END
			END;
			IF err THEN
				Texts.WriteString(W, err1);
				Texts.WriteLn(W);
				Texts.Append(Oberon.Log, W.buf)
			END;
			Files.Close(ArcF);
			nameList := nameList.next
		END
	END ExtractAll;

BEGIN
	verbose := FALSE;
	Texts.OpenWriter(W)
END Compress.
