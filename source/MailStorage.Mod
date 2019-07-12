MODULE MailStorage; (** AUTHOR "TF"; PURPOSE "Simple mail storage"; *)

IMPORT
	Streams, Files, KernelLog, Strings;

TYPE IndexEntry* = RECORD
		from, to : Streams.Position;
		hFrom, hTo, hSubject, hDate : ARRAY 64 OF CHAR;
	END;

TYPE Index = POINTER TO ARRAY OF IndexEntry;

TYPE Storage* = OBJECT
	VAR
		storageFile : Files.File;
		indexFile : Files.File;
		hFrom, hTo, hSubject, hDate : ARRAY 64 OF CHAR;
		nofItems : LONGINT;
		index : Index;
		persistentIndex : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			NEW(index, 1024);
			nofItems := 0
		END Init;

		PROCEDURE Open*(storageName, indexName : ARRAY OF CHAR);
		BEGIN
			storageFile := Files.Old(storageName);
			persistentIndex := indexName # "";
			IF storageFile = NIL THEN
				storageFile := Files.New(storageName);
			ELSE
				indexFile := Files.Old(indexName);
				IF indexFile = NIL THEN RebuildIndex
				ELSE (* LoadIndex *)
				END
			END
		END Open;

		PROCEDURE Match(VAR buf: ARRAY OF CHAR; with: ARRAY OF CHAR; VAR i : LONGINT): BOOLEAN;
		VAR j : LONGINT;
			PROCEDURE MYCAP(c : CHAR) : CHAR;
			BEGIN
				IF ('a' <= c) & (c <= 'z') THEN c := CAP(c) END;
				RETURN c
			END MYCAP;

		BEGIN
			i := 0;
			j := 0; WHILE (with[j] # 0X) & (MYCAP(buf[i]) = with[j]) DO INC(i); INC(j) END;
			RETURN with[j] = 0X
		END Match;

		PROCEDURE ScanMessage(r : Streams.Reader; VAR from, to : Streams.Position);
		VAR line : ARRAY 1001 OF CHAR; i : LONGINT;
		BEGIN
			hFrom := ""; hTo := ""; hSubject := ""; hDate := "";
			from := r.Pos();
			r.Ln(line);
			REPEAT
				r.Ln(line);
				IF (hFrom = "") & Match(line, "FROM:", i) THEN Strings.Delete(line, 0, i); COPY(line, hFrom)
					;KernelLog.String("line = "); KernelLog.String(line);
				ELSIF (hTo = "") & Match(line, "TO:", i) THEN Strings.Delete(line, 0, i); COPY(line, hTo)
					;KernelLog.String("line = "); KernelLog.String(line);
				ELSIF (hSubject = "") & Match(line, "SUBJECT:", i) THEN Strings.Delete(line, 0, i); COPY(line, hSubject)
					;KernelLog.String("line = "); KernelLog.String(line);
				ELSIF (hDate = "") & Match(line, "DATE:", i) THEN Strings.Delete(line, 0, i); COPY(line, hDate)
					;KernelLog.String("line = "); KernelLog.String(line);
				END;
			UNTIL (line = ".") OR (r.res # 0);
			to := r.Pos();
		END ScanMessage;

		PROCEDURE ScanStorage(r : Streams.Reader);
		VAR from, to : Streams.Position;
		BEGIN
			nofItems := 0;
			REPEAT
				ScanMessage(r, from, to);
				IF from # to THEN AddIndex(from, to, hFrom, hTo, hSubject, hDate) END
			UNTIL (r.res # 0) OR (from = to)
		END ScanStorage;

		PROCEDURE GrowIndex;
		VAR new : Index; i : LONGINT;
		BEGIN
			NEW(new, LEN(index) * 2);
			FOR i := 0 TO nofItems - 1 DO new[i] := index[i] END;
			index := new
		END GrowIndex;

		PROCEDURE AddIndex(from, to : Streams.Position; hFrom, hTo, hSubject, hDate : ARRAY OF CHAR);
		BEGIN
			IF nofItems = LEN(index) THEN GrowIndex END;
			index[nofItems].from := from;
			index[nofItems].to:= to;
			COPY(hFrom, index[nofItems].hFrom);
			COPY(hTo, index[nofItems].hTo);
			COPY(hSubject, index[nofItems].hSubject);
			COPY(hDate, index[nofItems].hDate);
			INC(nofItems)
		END AddIndex;

		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN nofItems
		END GetCount;

		PROCEDURE GetHeader*(nr : LONGINT; VAR hFrom, hTo, hSubject, hDate : ARRAY OF CHAR);
		BEGIN
			IF (nr >= 0) & (nr < nofItems) THEN
				COPY(index[nr].hFrom, hFrom);
				COPY(index[nr].hTo, hTo);
				COPY(index[nr].hSubject, hSubject);
				COPY(index[nr].hDate, hDate);
			END
		END GetHeader;

		PROCEDURE ToFile*(nr : LONGINT; filename : ARRAY OF CHAR) : BOOLEAN;
		VAR f : Files.File; r : Files.Reader; w : Files.Writer; str : ARRAY 1001 OF CHAR;
		BEGIN
			IF (nr >= 0) & (nr < nofItems) & (storageFile # NIL) THEN
				f := Files.New(filename);
				IF f # NIL THEN Files.OpenWriter(w, f, 0)
				ELSE RETURN FALSE
				END;
				Files.OpenReader(r, storageFile, index[nr].from);
				REPEAT
					r.Ln(str);
					IF str # "." THEN
						IF str[0] = "." THEN Strings.Delete(str, 0, 1) END;
						w.String(str); w.Ln;
						KernelLog.String(str)
					END
				UNTIL (str = ".") OR (r.res # 0);
				w.Update;
				Files.Register(f);
				RETURN TRUE
			ELSE RETURN FALSE
			END
		END ToFile;

		PROCEDURE RebuildIndex;
		VAR sr : Files.Reader;
		BEGIN
			IF storageFile # NIL THEN
				Files.OpenReader(sr, storageFile, 0);
				ScanStorage(sr)
			END
		END RebuildIndex;

	END Storage;

PROCEDURE Test*;
VAR storage : Storage; i : LONGINT;
BEGIN
	NEW(storage);
	storage.Open("MailMessages", "");
	FOR i := 0 TO storage.nofItems - 1 DO
		KernelLog.String("i = "); KernelLog.Int(i, 0); KernelLog.String(" : ");
		KernelLog.String("storage.index[i].from = "); KernelLog.Int(storage.index[i].from, 0);
		KernelLog.String("storage.index[i].to = "); KernelLog.Int(storage.index[i].to, 0); KernelLog.Ln;
	END;
END Test;


END MailStorage.

System.Free MailStorage
MailStorage.Test

Color Codes
 Highlight
Types and Procedures
Lock Acquire / Lock Release
Preferred notation (comment)
Unsafe / Temporary / Stupid / requires attention
Permanent Comment
Assertion
Debug

