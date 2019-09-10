(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Files IN Oberon;	(* pjm *)
(** AUTHOR "pjm"; PURPOSE "Oberon for Aos files"; *)

IMPORT SYSTEM, KernelLog IN A2, AosKernel := Kernel IN A2, Files IN A2, Kernel;

CONST
	BufSize = 4096;
	MaxBufs = 4;
	Slow = FALSE;
	Trace = TRUE;

TYPE
	File* = POINTER TO RECORD
		buf: Buffer;	(* circular list of buffers *)
		bufs: SIGNED32;	(* number of buffers allocated *)
		alen, blen: SIGNED32;	(* file size = alen*BufSize + blen, 0 <= blen <= BufSize *)
		r: Files.Rider;	(* rider on underlying Aos file *)
		checktime, checkdate, checklen: SIGNED32
	END;

	Rider* = RECORD
		buf: Buffer;	(* buffer hint *)
		apos, bpos: SIGNED32;
		eof*: BOOLEAN;	(** has end of file been passed *)
		res*: SIGNED32;	(** leftover byte count for ReadBytes/WriteBytes *)
		f: File
	END;

	Buffer = POINTER TO RECORD
		apos, lim: SIGNED32;
		mod: BOOLEAN;
		next: Buffer;
		data: ARRAY BufSize OF CHAR
	END;

	Bytes4 = ARRAY 4 OF SYSTEM.BYTE;
	Bytes8 = ARRAY 8 OF SYSTEM.BYTE;

VAR
	files: AosKernel.FinalizedCollection;	(* all open files - cleaned up by GC *)
	search: Files.File;	(* file being searched for *)
	found: File;	(* file found *)

(* Update our copy of the underlying file's time and length. *)

PROCEDURE UpdateFile(f: File);
BEGIN
	f.r.file.GetDate(f.checktime, f.checkdate); f.checklen := f.r.file.Length()(SIGNED32);
END UpdateFile;

(* Check if our copy of the underlying file's time and length match the reality. *)

PROCEDURE FileChanged(f: File): BOOLEAN;
VAR time, date: SIGNED32;
BEGIN
	f.r.file.GetDate(time, date);
	RETURN (time # f.checktime) OR (date # f.checkdate) OR (f.r.file.Length() # f.checklen)
END FileChanged;

(* Enumerator used in Old to search files collection for existing file handle using Files file as key. *)

PROCEDURE Search(f: ANY; VAR cont: BOOLEAN);
BEGIN
	IF f(File).r.file = search THEN
		found := f(File); cont := FALSE
	END
END Search;

(** Creates a new file with the specified name. *)
PROCEDURE New*(CONST name: ARRAY OF CHAR): File;
VAR f: File; file: Files.File;
BEGIN
	Kernel.CheckOberonLock;	(* can only be called from Oberon *)
	file := Files.New(name);
	IF file # NIL THEN
		NEW(f); f.bufs := 1; f.alen := 0; f.blen := 0;
		NEW(f.buf); f.buf.apos := 0; f.buf.lim := 0; f.buf.next := f.buf; f.buf.mod := FALSE;
		file.Set(f.r, 0); UpdateFile(f);
		IF name # "" THEN
			files.Add(f, NIL)	(* add to collection *)
			(* it is ok to add it here, and not only in Register, as in underlying file systems, because the underlying file system will take care of the case where an Old is attempted on a file that has been New'ed, but not Register'ed (Old will fail). *)
		END
	ELSE
		f := NIL
	END;
	RETURN f
END New;

(** Open an existing file. The same file descriptor is returned if a file is opened multiple times. *)
PROCEDURE Old*(CONST name: ARRAY OF CHAR): File;
VAR f: File; file: Files.File; len: SIGNED32;
BEGIN
	Kernel.CheckOberonLock;	(* can only be called from Oberon *)
	file := Files.Old(name);
	IF file # NIL THEN
		search := file; found := NIL;	(* search for existing handle *)
		files.Enumerate(Search);	(* modify global found *)
		search := NIL; f := found; found := NIL;
		IF (f # NIL) & FileChanged(f) THEN	(* underlying file changed *)
			IF Trace THEN
				KernelLog.String("Files: Stale "); WriteFile(f); KernelLog.Ln
			END;
			files.Remove(f); f := NIL	(* throw away old record (even though user may still have a copy; that is his fault) *)
		END;
		IF f = NIL THEN	(* none found, create new handle *)
			len := file.Length()(SIGNED32);
			NEW(f); f.bufs := 1; f.alen := len DIV BufSize; f.blen := len MOD BufSize;
			NEW(f.buf); f.buf.apos := 0; f.buf.next := f.buf; f.buf.mod := FALSE;
			file.Set(f.r, 0); file.ReadBytes(f.r, f.buf.data, 0, BufSize);
			IF f.alen = 0 THEN f.buf.lim := f.blen ELSE f.buf.lim := BufSize END;
			UpdateFile(f);
			files.Add(f, NIL)	(* add to collection *)
		ELSE
			(* return existing handle *)
		END
	ELSE
		f := NIL
	END;
	RETURN f
END Old;

(** Register a file created with New in the directory, replacing the previous file in the directory with the same name. The file is automatically closed. *)
PROCEDURE Register*(f: File);
BEGIN
	Update(f); Files.Register(f.r.file)
END Register;

(** Flushes the changes made to a file to disk. Register will automatically Close a file. *)
PROCEDURE Close*(f: File);
BEGIN
	IF f # NIL THEN Update(f) END
END Close;

(** Returns the current length of a file. *)
PROCEDURE Length*(f: File): SIGNED32;
BEGIN
	RETURN f.alen*BufSize + f.blen
END Length;

(** Returns the time (t) and date (d) when a file was last modified. *)
PROCEDURE GetDate*(f: File; VAR t, d: SIGNED32);
BEGIN
	f.r.file.GetDate(t, d)
END GetDate;

(** Sets the modification time (t) and date (d) of a file. *)
PROCEDURE SetDate*(f: File; t, d: SIGNED32);
BEGIN
	Update(f);	(* otherwise later updating will modify time/date again *)
	f.r.file.SetDate(t, d)
END SetDate;

(** Positions a Rider at a certain position in a file. Multiple Riders can be positioned at different locations in a file. A Rider cannot be positioned beyond the end of a file. *)
PROCEDURE Set*(VAR r: Rider; f: File; pos: SIGNED32);
BEGIN
	IF f # NIL THEN
		r.eof := FALSE; r.res := 0; r.buf := f.buf; r.f := f;
		IF pos < 0 THEN
			r.apos := 0; r.bpos := 0
		ELSIF pos < f.alen*BufSize + f.blen THEN
			r.apos := pos DIV BufSize; r.bpos := pos MOD BufSize
		ELSE
			r.apos := f.alen; r.bpos := f.blen	(* blen may be BufSize *)
		END
	ELSE
		r.buf := NIL; r.f := NIL
	END
END Set;

(** Returns the offset of a Rider positioned on a file. *)
PROCEDURE Pos*(VAR r: Rider): SIGNED32;
BEGIN
	RETURN r.apos*BufSize + r.bpos
END Pos;

(** Returns the File a Rider is based on. *)
PROCEDURE Base*(VAR r: Rider): File;
BEGIN
	RETURN r.f
END Base;

(** Read a byte from a file, advancing the Rider one byte further. R.eof indicates if the end of the file has been passed. *)
PROCEDURE Read*(VAR r: Rider; VAR x: SYSTEM.BYTE);
VAR buf: Buffer;
BEGIN
	buf := r.buf;
	IF r.apos # buf.apos THEN buf := GetBuf(r.f, r.apos); r.buf := buf END;
	IF r.bpos < buf.lim THEN
		x := buf.data[r.bpos]; INC(r.bpos)
	ELSIF r.apos < r.f.alen THEN
		INC(r.apos);
		buf := SearchBuf(r.f, r.apos);
		IF buf = NIL THEN	(* replace a buffer *)
			buf := r.buf;
			IF buf.mod THEN WriteBuf(r.f, buf) END;
			ReadBuf(r.f, buf, r.apos)
		ELSE
			r.buf := buf
		END;
		IF buf.lim > 0 THEN
			x := buf.data[0]; r.bpos := 1
		ELSE
			x := 0X; r.eof := TRUE
		END
	ELSE
		x := 0X; r.eof := TRUE
	END
END Read;

(** Reads a sequence of length n bytes into the buffer x, advancing the Rider. Less bytes will be read when reading over the length of the file. r.res indicates the number of unread bytes. x must be big enough to hold n bytes. *)
PROCEDURE ReadBytes*(VAR r: Rider; VAR x: ARRAY OF SYSTEM.BYTE; len: SIGNED32);
VAR src, dst: ADDRESS; m: SIGNED32; buf: Buffer; ch: CHAR;
BEGIN
	IF LEN(x) < len THEN SYSTEM.HALT(19) END;
	IF Slow THEN
		m := 0;
		LOOP
			IF len <= 0 THEN EXIT END;
			Read(r, ch);
			IF r.eof THEN EXIT END;
			x[m] := ch; INC(m); DEC(len)
		END;
		r.res := len
	ELSE
		IF len > 0 THEN
			dst := ADDRESSOF(x[0]); buf := r.buf;
			IF r.apos # buf.apos THEN buf := GetBuf(r.f, r.apos); r.buf := buf END;
			LOOP
				IF len <= 0 THEN EXIT END;
				src := ADDRESSOF(buf.data[0]) + r.bpos; m := r.bpos + len;
				IF m <= buf.lim THEN
					SYSTEM.MOVE(src, dst, len); r.bpos := m; r.res := 0; EXIT
				ELSIF buf.lim = BufSize THEN
					m := buf.lim - r.bpos;
					IF m > 0 THEN SYSTEM.MOVE(src, dst, m); INC(dst, m); DEC(len, m) END;
					IF r.apos < r.f.alen THEN
						INC(r.apos); r.bpos := 0; buf := SearchBuf(r.f, r.apos);
						IF buf = NIL THEN
							buf := r.buf;
							IF buf.mod THEN WriteBuf(r.f, buf) END;
							ReadBuf(r.f, buf, r.apos)
						ELSE
							r.buf := buf
						END
					ELSE
						r.bpos := buf.lim; r.res := len; r.eof := TRUE; EXIT
					END
				ELSE
					m := buf.lim - r.bpos;
					IF m > 0 THEN SYSTEM.MOVE(src, dst, m); r.bpos := buf.lim END;
					r.res := len - m; r.eof := TRUE; EXIT
				END
			END
		ELSE
			r.res := 0
		END
	END
END ReadBytes;

(**
Portable routines to read the standard Oberon types.
*)

PROCEDURE ReadInt*(VAR r: Rider; VAR x: SIGNED16);
VAR x0, x1: SIGNED8;
BEGIN
	Read(r, x0); Read(r, x1);
	x := LONG(x1) * 100H + LONG(x0) MOD 100H
END ReadInt;

PROCEDURE ReadLInt*(VAR r: Rider; VAR x: SIGNED32);
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END ReadLInt;

PROCEDURE ReadSet*(VAR r: Rider; VAR x: SET);
VAR s: SET32;
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes4, s), 4);
	x := s;
END ReadSet;

PROCEDURE ReadBool*(VAR r: Rider; VAR x: BOOLEAN);
VAR s: SIGNED8;
BEGIN
	Read(r, s); x := s # 0
END ReadBool;

PROCEDURE ReadReal*(VAR r: Rider; VAR x: FLOAT32);
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END ReadReal;

PROCEDURE ReadLReal*(VAR r: Rider; VAR x: FLOAT64);
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes8, x), 8)
END ReadLReal;

PROCEDURE ReadString*(VAR r: Rider; VAR x: ARRAY OF CHAR);
VAR i: SIGNED16; ch: CHAR;
BEGIN i := 0;
	LOOP
		Read(r, ch); x[i] := ch; INC(i);
		IF ch = 0X THEN EXIT END;
		IF i = LEN(x) THEN x[i-1] := 0X;
			REPEAT Read(r, ch) UNTIL ch = 0X;
			EXIT
		END
	END
END ReadString;

(** Reads a number in compressed variable length notation using the minimum amount of bytes. *)
PROCEDURE ReadNum*(VAR r: Rider; VAR x: SIGNED32);
VAR ch: CHAR; n: SIGNED16; y: SIGNED32;
BEGIN
	n := 0; y := 0; Read(r, ch);
	WHILE ch >= 80X DO INC(y, LSH(LONG(ORD(ch)) - 128, n)); INC(n, 7); Read(r, ch) END;
	x := ASH(LSH(LONG(ORD(ch)), 25), n-25) + y
END ReadNum;

(** Writes a byte into the file at the Rider position, advancing the Rider by one. *)
PROCEDURE Write*(VAR r: Rider; x: SYSTEM.BYTE);
VAR buf: Buffer;
BEGIN
	buf := r.buf;
	IF r.apos # buf.apos THEN buf := GetBuf(r.f, r.apos); r.buf := buf END;
	IF r.bpos >= buf.lim THEN
		IF r.bpos < BufSize THEN
			INC(buf.lim); INC(r.f.blen)	(* blen may become BufSize *)
		ELSE
			buf.lim := BufSize;	(* used by WriteBuf *)
			WriteBuf(r.f, buf); INC(r.apos); buf := SearchBuf(r.f, r.apos);
			IF buf = NIL THEN
				buf := r.buf;
				IF r.apos <= r.f.alen THEN
					ReadBuf(r.f, buf, r.apos)
				ELSE
					buf.apos := r.apos; buf.lim := 1; INC(r.f.alen); r.f.blen := 1
				END
			ELSE
				r.buf := buf
			END;
			r.bpos := 0
		END
	END;
	buf.data[r.bpos] := CHR(x); INC(r.bpos); buf.mod := TRUE
END Write;

(** Writes the buffer x containing n bytes into a file at the Rider position. *)
PROCEDURE WriteBytes*(VAR r: Rider; CONST x: ARRAY OF SYSTEM.BYTE; len: SIGNED32);
VAR src, dst: ADDRESS; m: SIGNED32; buf: Buffer;
BEGIN
	IF LEN(x) < len THEN SYSTEM.HALT(19) END;
	IF Slow THEN
		m := 0;
		WHILE len > 0 DO
			Write(r, x[m]); INC(m); DEC(len)
		END;
		r.res := len
	ELSE
		IF len > 0 THEN
			src := ADDRESSOF(x[0]);
			buf := r.buf;
			IF r.apos # buf.apos THEN buf := GetBuf(r.f, r.apos); r.buf := buf END;
			LOOP
				IF len <= 0 THEN EXIT END;
				buf.mod := TRUE; dst := ADDRESSOF(buf.data[0]) + r.bpos; m := r.bpos + len;
				IF m <= buf.lim THEN
					SYSTEM.MOVE(src, dst, len); r.bpos := m; EXIT
				ELSIF m <= BufSize THEN
					SYSTEM.MOVE(src, dst, len); r.bpos := m;
					r.f.blen := m; buf.lim := m; EXIT
				ELSE
					buf.lim := BufSize;	(* used by WriteBuf *)
					m := BufSize - r.bpos;
					IF m > 0 THEN SYSTEM.MOVE(src, dst, m); INC(src, m); DEC(len, m) END;
					WriteBuf(r.f, buf); INC(r.apos); r.bpos := 0; buf := SearchBuf(r.f, r.apos);
					IF buf = NIL THEN
						buf := r.buf;
						IF r.apos <= r.f.alen THEN
							ReadBuf(r.f, buf, r.apos)
						ELSE
							buf.apos := r.apos; buf.lim := 0; INC(r.f.alen); r.f.blen := 0
						END
					ELSE
						r.buf := buf
					END
				END
			END
		END
	END
END WriteBytes;

(**
Portable routines to write the standard Oberon types.
*)

PROCEDURE WriteInt*(VAR r: Rider; x: SIGNED16);
BEGIN
	Write(r, SHORT(x)); Write(r, SHORT(x DIV 100H))
END WriteInt;

PROCEDURE WriteLInt*(VAR r: Rider; x: SIGNED32);
BEGIN
	WriteBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END WriteLInt;

PROCEDURE WriteSet*(VAR r: Rider; x: SET);
VAR s: SET32;
BEGIN
	s := SET32(x);
	WriteBytes(r, SYSTEM.VAL(Bytes4, s), 4)
END WriteSet;

PROCEDURE WriteBool*(VAR r: Rider; x: BOOLEAN);
BEGIN
	IF x THEN Write(r, 1) ELSE Write(r, 0) END
END WriteBool;

PROCEDURE WriteReal*(VAR r: Rider; x: FLOAT32);
BEGIN
	WriteBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END WriteReal;

PROCEDURE WriteLReal*(VAR r: Rider; x: FLOAT64);
BEGIN
	WriteBytes(r, SYSTEM.VAL(Bytes8, x), 8)
END WriteLReal;

PROCEDURE WriteString*(VAR r: Rider; CONST x: ARRAY OF CHAR);
VAR i: SIGNED16; ch: CHAR;
BEGIN
	i := 0;
	LOOP ch := x[i]; Write(r, ch); INC(i);
		IF ch = 0X THEN EXIT END;
		IF i = LEN(x) THEN Write(r, 0X); EXIT END
	END
END WriteString;

(** Writes a number in a compressed format. *)
PROCEDURE WriteNum*(VAR r: Rider; x: SIGNED32);
BEGIN
	WHILE (x < - 64) OR (x > 63) DO Write(r, CHR(x MOD 128 + 128)); x := x DIV 128 END;
	Write(r, CHR(x MOD 128))
END WriteNum;

(** Deletes a file. res = 0 indicates success. *)
PROCEDURE Delete*(name: ARRAY OF CHAR; VAR res: SIGNED16);
VAR r: SIGNED32;
BEGIN
	Files.Delete(name, r);
	IF (r >= MIN(SIGNED16)) & (r <= MAX(SIGNED16)) THEN res := SHORT(r) ELSE res := -1 END
END Delete;

(** Renames a file. res = 0 indicates success. *)
PROCEDURE Rename*(CONST old, new: ARRAY OF CHAR; VAR res: SIGNED16);
VAR r: SIGNED32;
BEGIN
	Files.Rename(old, new, r);
	IF (r >= MIN(SIGNED16)) & (r <= MAX(SIGNED16)) THEN res := SHORT(r) ELSE res := -1 END
END Rename;

(** Returns the full name of a file. *)
PROCEDURE GetName*(f: File; VAR name: ARRAY OF CHAR);
BEGIN
	f.r.file.GetName(name)
END GetName;

PROCEDURE ReadBuf(f: File; buf: Buffer; pos: SIGNED32);
VAR file: Files.File;
BEGIN
	file := f.r.file;
	file.Set(f.r, pos*BufSize);
	ASSERT(file.Pos(f.r) = pos*BufSize);
	file.ReadBytes(f.r, buf.data, 0, BufSize);
	IF pos < f.alen THEN buf.lim := BufSize ELSE buf.lim := f.blen END;
	buf.apos := pos; buf.mod := FALSE;
END ReadBuf;

PROCEDURE WriteBuf(f: File; buf: Buffer);
VAR pos, n: SIGNED32; file: Files.File;
BEGIN
	file := f.r.file;
	pos := buf.apos*BufSize;
	n := pos - file.Length()(SIGNED32);
	IF n > 0 THEN	(* pos is past current eof, extend file *)
		file.Set(f.r, file.Length());
		WHILE n > 0 DO file.Write(f.r, 0X); DEC(n) END
	END;
	file.Set(f.r, pos);
	ASSERT(file.Pos(f.r) = pos);
	file.WriteBytes(f.r, buf.data, 0, buf.lim);
	UpdateFile(f);
	buf.mod := FALSE
END WriteBuf;

PROCEDURE SearchBuf(f: File; pos: SIGNED32): Buffer;
VAR buf: Buffer;
BEGIN
	buf := f.buf;
	LOOP
		IF buf.apos = pos THEN EXIT END;
		buf := buf.next;
		IF buf = f.buf THEN buf := NIL; EXIT END
	END;
	RETURN buf
END SearchBuf;

PROCEDURE GetBuf(f: File; pos: SIGNED32): Buffer;
VAR buf: Buffer;
BEGIN
	buf := f.buf;
	LOOP
		IF buf.apos = pos THEN EXIT END;
		IF buf.next = f.buf THEN
			IF f.bufs < MaxBufs THEN
				NEW(buf); buf.next := f.buf.next; f.buf.next := buf;
				INC(f.bufs)
			ELSE
				f.buf := buf;
				IF buf.mod THEN WriteBuf(f, buf) END
			END;
			buf.apos := pos;
			IF pos <= f.alen THEN ReadBuf(f, buf, pos) END;	(* ELSE? *)
			EXIT
		END;
		buf := buf.next
	END;
	RETURN buf
END GetBuf;

PROCEDURE Update(f: File);
VAR buf: Buffer;
BEGIN
	buf := f.buf;
	REPEAT
		IF buf.mod THEN WriteBuf(f, buf) END;
		buf := buf.next
	UNTIL buf = f.buf;
	f.r.file.Update();	(* update the underlying file also *)
	UpdateFile(f)
END Update;

PROCEDURE WriteFile(f: File);
VAR name: ARRAY 64 OF CHAR;
BEGIN
	IF Trace THEN
		KernelLog.Hex(ADDRESS( f), 8); KernelLog.Char(" ");
		KernelLog.Hex(ADDRESS(f.r.file), 1); KernelLog.Char(" ");
		KernelLog.Int(Length(f), 1); KernelLog.Char(" ");
		KernelLog.Int(f.r.file.Length(), 1); KernelLog.Char(" ");
		GetName(f, name);
		KernelLog.String(name)
	END
END WriteFile;

(* debugging *)

(*
PROCEDURE ShowList*;
VAR
	enum: OBJECT
		VAR i: SIGNED32;

		PROCEDURE EnumFile(f: ANY; VAR cont: BOOLEAN);
		BEGIN
			WITH f: File DO
				KernelLog.Int(i, 1); KernelLog.Char(" ");
				WriteFile(f); KernelLog.Ln;
				INC(i)
			END
		END EnumFile;
	END;

BEGIN
	NEW(enum); enum.i := 0; KernelLog.Ln;
	files.Enumerate(enum.EnumFile)
END ShowList;
*)

BEGIN
	NEW(files)
END Files.

(** Remarks:

1. Oberon uses the little-endian byte ordering for exchanging files between different Oberon platforms.

2. Files are separate entities from directory entries. Files may be anonymous by having no name and not being registered in a directory. Files only become visible to other clients of the Files module by explicitly passing a File descriptor or by registering a file and then opening it from the other client. Deleting a file of which a file descriptor is still available, results in the file becoming anonymous. The deleted file may be re-registered at any time.

3. Files and their access mechanism (Riders) are separated. A file might have more than one rider operating on it at different offsets in the file.

4. The garbage collector will automatically close files when they are not required any more. File buffers will be discarded without flushing them to disk.  Use the Close procedure to update modified files on disk.

5. Relative and absolute filenames written in the directory syntax of the host operating system are used. By convention, Oberon filenames consists of the letters A..Z, a..z, 0..9, and ".". The directory separator is typically / or :. Oberon filenames are case sensitive. *)

(*
to do:
o Rename duplicate methods/procedures in Files (e.g. Register0 method)
o remove Read/Write methods to encourage buffering (bad idea?)
- handle case where underlying file is changed by someone else (e.g. a log file being written by an active object)
- check if file handle is a good "key" (yes, because it can not be re-used while we hold it in the list, through the rider)
*)
