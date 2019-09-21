(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Zip; (** AUTHOR "Stefan Walthert"; PURPOSE "ZIP codec"  **)

IMPORT
	Strings, Streams, Files, Archives, Locks, Zlib, ZlibReaders, ZlibWriters;

CONST

	(** result codes **)
	Ok* = 0;	(** operation on zip-file was successful **)
	FileError* = -1;	(** file not found **)
	NotZipArchiveError* = -2;	(** file is not in zip format **)
	EntryNotFound* = -3;	(** specified file was not found in zip-file **)
	EntryAlreadyExists* = -4;	(** file is already stored in zip-file -> can not add specified file to zip-file **)
	NotSupportedError* = -5;	(** can not extract specified file (compression method not supported/file is encrypted) **)
	DataError* = -6;	(** file is corrupted **)
	BadName* = -7;	(** bad file name *)
	ReaderError* = -8;	(** e.g. Reader not opened before Read **)

	(** compression levels **)
	DefaultCompression* = ZlibWriters.DefaultCompression;
	NoCompression* = ZlibWriters.NoCompression;
	BestSpeed* = ZlibWriters.BestSpeed;
	BestCompression* = ZlibWriters.BestCompression;

	(** compression strategies **)
	DefaultStrategy* = ZlibWriters.DefaultStrategy;
	Filtered* = ZlibWriters.Filtered;
	HuffmanOnly* = ZlibWriters.HuffmanOnly;
	
	EntryNameSize = 256;

	(* support *)
	Supported = 0;	(* can extract file *)
	IncompatibleVersion = 1;	(* version needed to extract < PKZIP 1.00 *)
	Encrypted = 2;	(* file is encrypted *)
	UnsupCompMethod = 3;	(* file not stored or deflated *)

	Stored = 0;	(* file is stored (no compression) *)
	Deflated = 8;	(* file is deflated *)

	SupportedCompMethods = {Stored, Deflated};
	CompatibleVersions = 1;	(* versions >= CompatibleVersions are supported *)

	(* headers *)
	LocalFileHeaderSignature = 04034B50H;
	CentralFileHeaderSignature = 02014B50H;
	EndOfCentralDirSignature = 06054B50H;

TYPE
	Entry* = POINTER TO EntryDesc;	(** description of a file stored in the zip-archive **)
	EntryDesc* = RECORD
		name-: ARRAY EntryNameSize OF CHAR;	(** name of file stored in the zip-archive **)
		method: SIGNED16;	(* compression method *)
		time-, date-: SIGNED32;	(** (Oberon) time and date when file was last modified **)
		crc32: SIGNED32;	(* checksum of uncompressed file data *)
		compSize-, uncompSize-: SIGNED32;	(** size of compressed / uncompressed file **)
		intFileAttr: SIGNED16;	(* internal file attributes, not used in this implementation *)
		extFileAttr: SIGNED32;	(* external file attributes, not used in this implementation *)
		extraField (* for future expansions *), comment-: POINTER TO ARRAY OF CHAR;	(** comment for this file **)
		genPurpBitFlag: SIGNED16;
		support: SIGNED8;
		dataDescriptor: BOOLEAN;	(* if set, data descriptor after (compressed) file data *)
		offsetLocal: SIGNED32;	(* offset of file header in central directory *)
		offsetFileData: SIGNED32;	(* offset of (compressed) file data *)
		offsetCentralDir: SIGNED32;	(* offset of local file header *)
		next: Entry
	END;

	Archive* = POINTER TO ArchiveDesc;	(** description of a zipfile **)
	ArchiveDesc* = RECORD
		nofEntries-: SIGNED16;	(** total number of files stored in the zipfile **)
		comment-: POINTER TO ARRAY OF CHAR;	(** comment for zipfile **)
		file-: Files.File;	(* pointer to the according zip-file *)
		offset: SIGNED32;	(* offset of end of central dir record *)
		firstEntry, lastEntry: Entry	(* first and last Entry of Archive *)
	END;
	

	Reader* = POINTER TO ReaderDesc;
	ReaderDesc* = RECORD	(** structure for reading from a zip-file into a buffer **)
		res-: INTEGER;	(** result of last operation **)
		open: BOOLEAN;
		ent: Entry
	END;

	UncompReader = POINTER TO UncompReaderDesc;
	UncompReaderDesc = RECORD (ReaderDesc)	(* structur for reading from a uncompressed entry *)
		fr: Files.Rider;
		crc32: SIGNED32;	(* crc32 of uncomressed data *)
	END;

	DefReader = POINTER TO DefReaderDesc;
	DefReaderDesc = RECORD (ReaderDesc)	(* structure for reading from a deflated entry *)
		zr: ZlibReaders.Reader
	END;
	
	(* for internal use only. lets read a specified amount of data *)
	SizeReader = OBJECT
	VAR
		r: Reader;
		max: SIZE;
		arc: ArchiveObj;

		PROCEDURE &Init*(r: Reader; size: SIGNED32; arc: ArchiveObj);
		BEGIN
			SELF.r := r; SELF.max := size; SELF.arc := arc
		END Init;

		PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: SIZE; VAR len: SIZE; VAR res: INTEGER);
		BEGIN
			IF max = 0 THEN
				res := Streams.Invalid;
				RETURN
			END;
			IF size < min THEN size := min END;
			IF size > max THEN size := max END;

			ReadBytes(r, buf, ofs, size, len);
			
			DEC(max, len);
			
			IF len > 0 THEN
				res := Streams.Ok
			ELSE
				res := Streams.EOF
			END
			
		END Receive;

	END SizeReader;
	
	EntryInfo* = OBJECT(Archives.EntryInfo)
	VAR
		name : ARRAY EntryNameSize OF CHAR;
		size : SIGNED32;

		PROCEDURE & Init*(CONST name : ARRAY OF CHAR; size : SIGNED32);
		BEGIN
			COPY(name, SELF.name); SELF.size := size
		END Init;

		PROCEDURE GetName*() : Strings.String;
		VAR n : Strings.String;
		BEGIN
			NEW(n, EntryNameSize); COPY(name, n^);
			RETURN n
		END GetName;

		PROCEDURE GetSize*() : SIGNED32;
		BEGIN
			RETURN size
		END GetSize;

		PROCEDURE GetInfoString*() : Strings.String;
		VAR s : Strings.String;
			temp : ARRAY 10 OF CHAR;
		BEGIN
			NEW(s, 128);
			Strings.Append(s^, "Name : ");
			Strings.Append(s^, name);
			Strings.Append(s^, "; Size : ");
			Strings.IntToStr(size, temp);
			Strings.Append(s^, temp);
			Strings.Append(s^, ";");
			RETURN s
		END GetInfoString;

	END EntryInfo;
	
	ArchiveObj* = OBJECT(Archives.Archive)
	VAR
		arc: Archive;
		lock: Locks.RecursiveLock;

		PROCEDURE & Init*(f: Files.File);
		VAR
			res: INTEGER;
		BEGIN
			arc := OpenArchiveFile(f, res);
			NEW(lock)
		END Init;

		PROCEDURE Acquire*;
		BEGIN
			lock.Acquire
		END Acquire;

		PROCEDURE Release*;
		BEGIN
			lock.Release
		END Release;

		(** return list of archive entries *)
		PROCEDURE GetIndex*(): Archives.Index;
		VAR i : SIGNED32;
			e : Entry;
			result : Archives.Index;
			ei : EntryInfo;
		BEGIN
			ASSERT(lock.HasLock());
			IF arc = NIL THEN
				RETURN NIL
			END;
			NEW(result, arc.nofEntries);
			i := 0;
			e := arc.firstEntry;
			WHILE e # NIL DO
				NEW(ei, e.name, e.uncompSize);
				result[i] := ei;
				e := e.next;
				INC(i)
			END;
			RETURN result
		END GetIndex;

		(** get info for a specific entry. return NIL if no such entry exists *)
		PROCEDURE GetEntryInfo*(CONST name: ARRAY OF CHAR) : Archives.EntryInfo;
		VAR
			res: INTEGER;
			e: Entry;
			ei: EntryInfo;
		BEGIN
			ASSERT(lock.HasLock());
			e := GetEntry(arc, name, res);
			IF e = NIL THEN RETURN NIL END;
			NEW(ei, e.name, e.uncompSize);
			RETURN ei
		END GetEntryInfo;

		(** remove named entry *)
		PROCEDURE RemoveEntry*(CONST name: ARRAY OF CHAR);
		VAR
			res: INTEGER;
			e: Entry;
		BEGIN
			ASSERT(lock.HasLock());
			e := GetEntry(arc, name, res);
			IF e # NIL THEN
				DeleteEntry(arc, e, res)
			END
		END RemoveEntry;

		(** rename an archive entry. return new EntryInfo or NIL if failed. *)
		PROCEDURE RenameEntry*(CONST from, to : ARRAY OF CHAR) : Archives.EntryInfo;
		BEGIN HALT(301)
		END RenameEntry;

		(** open a sender to write an entry with name to archive. the data will be written when Update is called *)
		PROCEDURE OpenSender*(CONST name : ARRAY OF CHAR) : Streams.Sender;
		BEGIN HALT(301)
		END OpenSender;

		(** read entry from archive *)
		PROCEDURE OpenReceiver*(CONST name : ARRAY OF CHAR): Streams.Receiver;
		VAR
			res: INTEGER;
			e: Entry;
			r: Reader;
			s: SizeReader;
		BEGIN
			ASSERT(lock.HasLock());
			e := GetEntry(arc, name, res);
			IF e = NIL THEN RETURN NIL END;
			r := OpenReader(arc, e);
			NEW(s, r, e.uncompSize, SELF);
			RETURN s.Receive
		END OpenReceiver;

		(** save a clone of the archive under a different name *)
		PROCEDURE Copy*(CONST name : ARRAY OF CHAR) : Archives.Archive;
		BEGIN HALT(301)
		END Copy;

		(* ----- internal functions ------------------------------------------------*)

	END ArchiveObj;

PROCEDURE ShowError*(errorCode : INTEGER; out : Streams.Writer);
BEGIN
	ASSERT(out # NIL);
	CASE errorCode OF
		|Ok: out.String("No Error");
		|FileError: out.String("File not found");
		|NotZipArchiveError: out.String("File is not in zip format");
		|EntryNotFound: out.String("File not found in zip archive");
		|EntryAlreadyExists: out.String("File already present in zip archive");
		|NotSupportedError: out.String("Compression method not supported or file encrypted");
		|DataError: out.String("File is corrupted");
		|BadName: out.String("Bad file name");
		|ReaderError: out.String("Reader Error");
	ELSE
		out.String("Unkown error, res: "); out.Int(errorCode, 0);
	END;
END ShowError;

(* length of str *)
PROCEDURE StringLength(CONST str: ARRAY OF CHAR): SIZE;
	VAR i, l: SIZE;
BEGIN
	l := LEN(str); i := 0;
	WHILE (i < l) & (str[i] # 0X) DO
		INC(i)
	END;
	RETURN i
END StringLength;

(* Converts Oberon time into MS-DOS time *)
PROCEDURE OberonToDosTime(t: SIGNED32): SIGNED16;
BEGIN
	RETURN SHORT(t DIV 1000H MOD 20H * 800H + t DIV 40H MOD 40H * 20H + t MOD 40H DIV 2)
END OberonToDosTime;

(* Converts Oberon date into MS-DOS time *)
PROCEDURE OberonToDosDate(d: SIGNED32): SIGNED16;
BEGIN
	RETURN SHORT((d DIV 200H + 1900 - 1980) * 200H + d MOD 200H)
END OberonToDosDate;

(* Converts MS-DOS time into Oberon time *)
PROCEDURE DosToOberonTime(t: SIGNED16): SIGNED32;
BEGIN
	RETURN LONG(t) DIV 800H MOD 20H * 1000H + t DIV 20H MOD 40H * 40H + t MOD 20H * 2
END DosToOberonTime;

(* Converts MS-DOS date into Oberon date *)
PROCEDURE DosToOberonDate(d: SIGNED16): SIGNED32;
BEGIN
	RETURN (LONG(d) DIV 200H MOD 80H + 1980 - 1900) * 200H + d MOD 200H
END DosToOberonDate;

(* Copy len bytes from src to dst; if compCRC32 is set, then the crc 32-checksum is computed *)
PROCEDURE Copy(VAR src, dst: Files.Rider; len: SIGNED32; compCRC32: BOOLEAN; VAR crc32: SIGNED32);
CONST
	BufSize = 4000H;
VAR
	n: SIGNED32;
	buf: ARRAY BufSize OF CHAR;
BEGIN
	IF compCRC32 THEN crc32 := Zlib.CRC32(0, buf, -1, -1) END;
	REPEAT
		IF len < BufSize THEN n := len
		ELSE n := BufSize
		END;
		src.file.ReadBytes(src, buf, 0, n);
		IF compCRC32 THEN crc32 := Zlib.CRC32(crc32, buf, 0, n - src.res) END;
		dst.file.WriteBytes(dst, buf, 0, n - src.res);
		DEC(len, n)
	UNTIL len = 0
END Copy;

(* Reads an Entry, r must be at the start of a file header; returns NIL if read was not successful *)
PROCEDURE ReadEntry(VAR r: Files.Rider): Entry;
VAR
	ent: Entry;
	intDummy, nameLen, extraLen, commentLen: SIGNED16;
	longDummy: SIGNED32; position: Streams.Position;
BEGIN
	Files.ReadLInt(r, longDummy);
	IF longDummy = CentralFileHeaderSignature THEN
		NEW(ent);
		ent.offsetCentralDir := r.file.Pos(r)(SIGNED32) - 4;
		ent.support := 0;
		Files.ReadInt(r, intDummy);	(* version made by *)
		Files.ReadInt(r, intDummy);	(* version needed to extract *)
		IF (intDummy MOD 100H) / 10 < CompatibleVersions THEN
			ent.support := IncompatibleVersion
		END;
		Files.ReadInt(r, ent.genPurpBitFlag);	(* general purpose bit flag *)
		IF ODD(ent.genPurpBitFlag) THEN
			ent.support := Encrypted	(* bit 0: if set, file encrypted *)
		END;
		ent.dataDescriptor := ODD(intDummy DIV 8);	(* bit 3: data descriptor after (compressed) file data *)
		Files.ReadInt(r, ent.method);	(* compression method *)
		IF (ent.support = Supported) & ~(ent.method IN SupportedCompMethods) THEN
			ent.support := UnsupCompMethod
		END;
		Files.ReadInt(r, intDummy); ent.time := DosToOberonTime(intDummy);	(* last mod file time *)
		Files.ReadInt(r, intDummy); ent.date := DosToOberonDate(intDummy);	(* last mod file date *)
		Files.ReadLInt(r, ent.crc32);	(* crc-32 *)
		Files.ReadLInt(r, ent.compSize);	(* compressed size *)
		Files.ReadLInt(r, ent.uncompSize);	(* uncompressed size *)
		Files.ReadInt(r, nameLen);	(* filename length *)
		Files.ReadInt(r, extraLen);	(* extra field length *)
		Files.ReadInt(r, commentLen);	(* file comment length *)
		Files.ReadInt(r, intDummy);	(* disk number start *)
		Files.ReadInt(r, ent.intFileAttr);	(* internal file attributes *)
		Files.ReadLInt(r, ent.extFileAttr);	(* external file attributes *)
		Files.ReadLInt(r, ent.offsetLocal);	(* relative offset of local header *)
		r.file.ReadBytes(r, ent.name, 0, nameLen);	(* filename *)
		IF extraLen # 0 THEN
			NEW(ent.extraField, extraLen);
			r.file.ReadBytes(r, ent.extraField^, 0, extraLen)	(* extra field *)
		END;
		IF commentLen > 0 THEN
			NEW(ent.comment, commentLen);
			r.file.ReadBytes(r, ent.comment^, 0, commentLen)	(* file comment *)
		END;
		(* read extra field length in the local file header (can be different from extra field length stored in the file header...) *)
		position := r.file.Pos(r);	(* store actual position of file reader *)
		r.file.Set(r, ent.offsetLocal + 28);	(* set r to position of extra field length in local file header *)
		Files.ReadInt(r, extraLen);	(* extra field length *)
		ent.offsetFileData := ent.offsetLocal + 30 + nameLen + extraLen;	(* compute offset of file data *)
		r.file.Set(r, position);	(* set position of file reader to previous position *)
		IF r.eof THEN	(* if file is a zip-archive, r is not at end of file *)
			ent := NIL
		END
	END;
	RETURN ent;
END ReadEntry;

(* Writes a local file header *)
PROCEDURE WriteLocalFileHeader(ent: Entry; VAR r: Files.Rider);
BEGIN
	Files.WriteLInt(r, LocalFileHeaderSignature);	(* local file header signature *)
	Files.WriteInt(r, CompatibleVersions * 10);	(* version needed to extract *)
	Files.WriteInt(r, ent.genPurpBitFlag);	(* general purpose bit flag *)
	Files.WriteInt(r, ent.method);	(* compression method *)
	Files.WriteInt(r, OberonToDosTime(ent.time));	(* last mod file time *)
	Files.WriteInt(r, OberonToDosDate(ent.date));	(* last mod file date *)
	Files.WriteLInt(r, ent.crc32);	(* crc-32 *)
	Files.WriteLInt(r, ent.compSize);	(* compressed size *)
	Files.WriteLInt(r, ent.uncompSize);	(* uncompressed size *)
	Files.WriteInt(r, SIGNED16(StringLength(ent.name)));	(* filename length *)
	IF ent.extraField # NIL THEN
		Files.WriteInt(r, SIGNED16(LEN(ent.extraField^)))	(* extra field length *)
	ELSE
		Files.WriteInt(r, 0)
	END;
	r.file.WriteBytes(r, ent.name, 0, StringLength(ent.name));	(* filename *)
	IF ent.extraField # NIL THEN
		r.file.WriteBytes(r, ent.extraField^, 0, LEN(ent.extraField^))	(* extra field *)
	END
END WriteLocalFileHeader;

(* Writes file header in central directory, updates ent.offsetCentralDir *)
PROCEDURE WriteFileHeader(ent: Entry; VAR r: Files.Rider);
BEGIN
	ent.offsetCentralDir := r.file.Pos(r)(SIGNED32);
	Files.WriteLInt(r, CentralFileHeaderSignature);	(* central file header signature *)
	Files.WriteInt(r, CompatibleVersions * 10);	(* version made by *)
	Files.WriteInt(r, CompatibleVersions * 10);	(* version needed to extract *)
	Files.WriteInt(r, ent.genPurpBitFlag);	(* general purpose bit flag *)
	Files.WriteInt(r, ent.method);	(* compression method *)
	Files.WriteInt(r, OberonToDosTime(ent.time));	(* last mod file time *)
	Files.WriteInt(r, OberonToDosDate(ent.date));	(* last mod file date *)
	Files.WriteLInt(r, ent.crc32);	(* crc-32 *)
	Files.WriteLInt(r, ent.compSize);	(* compressed size *)
	Files.WriteLInt(r, ent.uncompSize);	(* uncompressed size *)
	Files.WriteInt(r, SIGNED16(StringLength(ent.name)));	(* filename length *)
	IF ent.extraField = NIL THEN
		Files.WriteInt(r, 0)
	ELSE
		Files.WriteInt(r, SIGNED16(LEN(ent.extraField^)));	(* extra field length *)
	END;
	IF ent.comment = NIL THEN
		Files.WriteInt(r, 0)
	ELSE
		Files.WriteInt(r, SIGNED16(LEN(ent.comment^)));	(* file comment length *)
	END;
	Files.WriteInt(r, 0);	(* disk number start *)
	Files.WriteInt(r, ent.intFileAttr);	(* internal file attributes *)
	Files.WriteLInt(r, ent.extFileAttr);	(* external file attributes *)
	Files.WriteLInt(r, ent.offsetLocal);	(* relative offset of local header *)
	r.file.WriteBytes(r, ent.name, 0, StringLength(ent.name));	(* filename *)
	IF ent.extraField # NIL THEN
		r.file.WriteBytes(r, ent.extraField^, 0, LEN(ent.extraField^))	(* extra field *)
	END;
	IF ent.comment # NIL THEN
		r.file.WriteBytes(r, ent.comment^, 0, LEN(ent.comment^))	(* file comment *)
	END
END WriteFileHeader;

(* Writes end of central directory record *)
PROCEDURE WriteEndOfCentDir(arc: Archive; VAR r: Files.Rider);
BEGIN
	Files.WriteLInt(r, EndOfCentralDirSignature);	(* end of central dir signature *)
	Files.WriteInt(r, 0);	(* number of this disk *)
	Files.WriteInt(r, 0);	(* number of the disk with the start of the central directory *)
	Files.WriteInt(r, arc.nofEntries);	(* total number of entries in the central dir on this disk *)
	Files.WriteInt(r, arc.nofEntries);	(* total number of entries in the central dir *)
	IF arc.firstEntry # NIL THEN
		Files.WriteLInt(r, arc.offset - arc.firstEntry.offsetCentralDir)	(* size of the central directory (without end of central dir record) *)
	ELSE
		Files.WriteLInt(r, 0)
	END;
	IF arc.firstEntry = NIL THEN
		Files.WriteLInt(r, arc.offset)	(* offset of start of central directory with respect to the starting disk number *)
	ELSE
		Files.WriteLInt(r, arc.firstEntry.offsetCentralDir)	(* offset of start of central directory with respect to the starting disk number *)
	END;
	IF arc.comment = NIL THEN
		Files.WriteInt(r, 0)	(* zipfile comment length *)
	ELSE
		Files.WriteInt(r, SIGNED16(LEN(arc.comment^)));	(* zipfile comment length *)
		r.file.WriteBytes(r, arc.comment^, 0, LEN(arc.comment^))	(* zipfile comment *)
	END
END WriteEndOfCentDir;

(* Writes central directory + end of central directory record, updates arc.offset and offsetCentralDir of entries *)
PROCEDURE WriteCentralDirectory(arc: Archive; VAR r: Files.Rider);
VAR
	ent: Entry;
BEGIN
	ent := arc.firstEntry;
	WHILE ent # NIL DO
		WriteFileHeader(ent, r);
		ent := ent.next
	END;
	arc.offset := r.file.Pos(r)(SIGNED32);
	WriteEndOfCentDir(arc, r)
END WriteCentralDirectory;

(** Returns an Archive data structure corresponding to the specified zipfile;
	possible results:
	- Ok: operation was successful
	- FileError: file with specified name does not exist
	- NotZipArchiveError: file is not a correct zipfile **)

PROCEDURE OpenArchive*(CONST name: ARRAY OF CHAR; VAR res: INTEGER): Archive;
VAR
	arc: Archive;
	f: Files.File;
BEGIN
	res := Ok;
	f := Files.Old(name);
	arc := OpenArchiveFile(f, res);
	RETURN arc
END OpenArchive;

PROCEDURE OpenArchiveFile(f: Files.File; VAR res: INTEGER): Archive;
VAR
	arc: Archive;
	ent: Entry;
	r: Files.Rider;
	longDummy: SIGNED32;
	intDummy: SIGNED16;
BEGIN
	res := Ok;
	IF f = NIL THEN
		res := FileError
	ELSIF f.Length() < 22 THEN
		res := NotZipArchiveError
	ELSE
		longDummy := 0;
		f.Set(r, f.Length() - 17);
		WHILE (longDummy # EndOfCentralDirSignature) & (r.file.Pos(r) > 4) DO
			f.Set(r, f.Pos(r) - 5);
			Files.ReadLInt(r, longDummy)
		END;
		IF longDummy # EndOfCentralDirSignature THEN
			res := NotZipArchiveError
		ELSE
			NEW(arc);
			arc.file := f;
			arc.offset := f.Pos(r)(SIGNED32) - 4;
			Files.ReadInt(r, intDummy);	(* number of this disk *)
			Files.ReadInt(r, intDummy);	(* number of the disk with the start of the central directory *)
			Files.ReadInt(r, intDummy);	(* total number of entries in the central dir on this disk *)
			Files.ReadInt(r, arc.nofEntries);	(* total number of entries in the central dir *)
			Files.ReadLInt(r, longDummy);	(* size of the central directory *)
			Files.ReadLInt(r, longDummy);	(* offset of start of central directory with respect to the starting disk number *)
			Files.ReadInt(r, intDummy);	(* zipfile comment length *)
			IF intDummy # 0 THEN
				NEW(arc.comment, intDummy);
				r.file.ReadBytes(r, arc.comment^, 0, intDummy)	(* zipfile comment *)
			END;
			IF r.file.Pos(r) # r.file.Length() THEN
				res := NotZipArchiveError;
				arc := NIL
			ELSE
				r.file.Set(r, longDummy);	(* set r on position of first file header in central dir *)
				arc.firstEntry := ReadEntry(r); arc.lastEntry := arc.firstEntry;
				ent := arc.firstEntry; intDummy := 0;
				WHILE ent # NIL DO
					arc.lastEntry := ent; INC(intDummy); (* count number of entries *)
					ent.next := ReadEntry(r);
					ent := ent.next
				END;
				IF intDummy # arc.nofEntries THEN
					res := NotZipArchiveError;
					arc := NIL
				END
			END;
			f.Update();
		END
	END;
	RETURN arc
END OpenArchiveFile;

(** Returns an Archive that corresponds to a file with specified name;
	if there is already a zip-file with the same name, this already existing archive is returned;
	possible results: cf. OpenArchive **)
PROCEDURE CreateArchive*(CONST name: ARRAY OF CHAR; VAR res: INTEGER): Archive;
VAR
	f: Files.File;
	r: Files.Rider;
	arc: Archive;
BEGIN
	IF name#"" THEN f := Files.Old(name); END;
	IF f # NIL THEN
		RETURN OpenArchive(name, res)
	ELSE
		f := Files.New(name);
		NEW(arc);
		arc.file := f;
		arc.nofEntries := 0;
		arc.offset := 0;
		f.Set(r, 0);
		WriteEndOfCentDir(arc, r);
		IF name#"" THEN Files.Register(f) END;
		res := Ok;
		RETURN arc
	END
END CreateArchive;

(** Returns the first entry of the Archive arc (NIL if there is no Entry) **)
PROCEDURE FirstEntry*(arc: Archive): Entry;
BEGIN
	IF arc = NIL THEN
		RETURN NIL
	ELSE
		RETURN arc.firstEntry
	END
END FirstEntry;

(** Returns the next Entry after ent **)
PROCEDURE NextEntry*(ent: Entry): Entry;
BEGIN
	RETURN ent.next
END NextEntry;

(** Returns the Entry that corresponds to the file with the specified name and that is stored in the Archive arc;
	possible results:
	- Ok: Operation was successful
	- NotZipArchiveError: arc is not a valid Archive
	- EntryNotFound: no Entry corresponding to name was found **)
PROCEDURE GetEntry*(arc: Archive; CONST name: ARRAY OF CHAR; VAR res: INTEGER): Entry;
VAR
	ent: Entry;
BEGIN
	IF arc = NIL THEN
		res := NotZipArchiveError
	ELSE
		ent := arc.firstEntry;
		WHILE (ent # NIL) & (ent.name # name) DO
			ent := ent.next
		END;
		IF ent = NIL THEN
			res := EntryNotFound
		ELSE
			res := Ok
		END
	END;
	RETURN ent
END GetEntry;

(** Uncompresses and writes the data of Entry ent to Files.Rider dst;
	possible results:
	- Ok: Data extracted
	- NotZipArchiveError: arc is not a valid zip-archive
	- EntryNotFound: ent is not an Entry of arc
	- NotSupportedError: data of ent are encrypted or compression method is not supported
	- DataError: zipfile is corrupted
	- BadName: entry has a bad file name **)
PROCEDURE ExtractEntry*(arc: Archive; ent: Entry; VAR dst: Files.Rider; VAR res: INTEGER);
VAR
	src: Files.Rider; crc32: SIGNED32;
BEGIN
	IF arc = NIL THEN
		res := NotZipArchiveError
	ELSIF (dst.file = NIL) THEN
		res := BadName
	ELSIF (ent = NIL) OR (ent # GetEntry(arc, ent.name, res)) THEN
		res := EntryNotFound
	ELSIF ~(ent.method IN SupportedCompMethods) OR (ent.support > Supported) THEN
		res := NotSupportedError
	ELSE
		CASE ent.method OF
		| Stored:
			arc.file.Set(src, ent.offsetFileData);
			Copy(src, dst, ent.uncompSize, TRUE, crc32);
			IF crc32 = ent.crc32 THEN
				res := Ok
			ELSE
				res := DataError
			END
		| Deflated:
			arc.file.Set(src, ent.offsetFileData);
			ZlibReaders.Uncompress(src, dst, crc32, res);
			IF (res = ZlibReaders.Ok) & (crc32 = ent.crc32) THEN
				res := Ok
			ELSE
				res := DataError
			END
		END;
		IF res = Ok THEN
			dst.file.Update();
		END
	END
END ExtractEntry;

(** Reads and compresses len bytes from Files.Rider src with specified level and strategy
	and writes them to a new Entry in the Archive arc;
	possible results:
	- Ok: file was added to arc
	- NotZipArchiveError: arc is not a valid zip-archive
	- EntryAlreadyExists: there is already an Entry in arc with the same name
	- DataError: error during compression
	- BadName: src is not based on a valid file **)
PROCEDURE AddEntry*(arc: Archive; CONST name: ARRAY OF CHAR; VAR src: Files.Rider; len: SIGNED32; level, strategy: SIGNED8; VAR res: INTEGER);
VAR
	dst: Files.Rider; ent: Entry; start: SIGNED32;
BEGIN
	IF arc = NIL THEN
		res := NotZipArchiveError
	ELSIF (src.file = NIL) THEN
		res := BadName
	ELSIF (GetEntry(arc, name, res) # NIL) & (res = Ok) THEN
		res := EntryAlreadyExists
	ELSE
		NEW(ent);
		COPY(name, ent.name);
		ent.genPurpBitFlag := 0;
		IF level = NoCompression THEN
			ent.method := Stored
		ELSE
			ent.method := Deflated
		END;
		src.file.GetDate(ent.time, ent.date);
		ent.uncompSize := len;
		ent.intFileAttr := 0;
		ent.extFileAttr := 0;
		ent.comment := NIL;
		ent.support := Supported;
		ent.dataDescriptor := FALSE;
		IF arc.firstEntry # NIL THEN
			ent.offsetLocal := arc.firstEntry.offsetCentralDir
		ELSE
			ent.offsetLocal := 0
		END;
		arc.file.Set(dst, ent.offsetLocal);
		WriteLocalFileHeader(ent, dst);
		ent.offsetFileData := dst.file.Pos(dst)(SIGNED32);
		arc.file.Update();
		start := src.file.Pos(src)(SIGNED32);
		IF level = 0 THEN
			Copy(src, dst, len, TRUE, ent.crc32);
			ent.compSize := len;
			res := Ok
		ELSE
			ZlibWriters.Compress(src, dst, len, ent.compSize, level, strategy, ent.crc32, res);
			IF res # ZlibWriters.Ok THEN
				res := DataError
			ELSE
				res := Ok
			END
		END;
		IF res = Ok THEN
			ent.uncompSize := src.file.Pos(src)(SIGNED32) - start;
			arc.file.Update();
			arc.file.Set(dst, ent.offsetLocal + 14);
			Files.WriteLInt(dst, ent.crc32);
			Files.WriteLInt(dst, ent.compSize);
			arc.file.Update;
			IF arc.lastEntry # NIL THEN
				arc.lastEntry.next := ent
			ELSE	(* archive has no entries *)
				arc.firstEntry := ent
			END;
			arc.lastEntry := ent;
			INC(arc.nofEntries);
			arc.file.Set(dst, ent.offsetFileData + ent.compSize);
			WriteCentralDirectory(arc, dst);
			arc.file.Update();
			res := Ok
		END;
	END
END AddEntry;

(** Deletes Entry ent from Archive arc;
	Possible results:
	- Ok: ent was deleted, ent is set to NIL
	- NotZipArchiveError: arc is not a valid zip-archive
	- EntryNotFound: ent is not an Entry of Archive arc **)
PROCEDURE DeleteEntry*(arc: Archive; VAR ent: Entry; VAR res: INTEGER);
VAR
	f: Files.File; r1, r2: Files.Rider;
	ent2: Entry;
	arcname: ARRAY 256 OF CHAR;
	offset, diff: SIGNED32;
BEGIN
	IF arc = NIL THEN
		res := NotZipArchiveError
	ELSIF arc.firstEntry = NIL THEN
		res := EntryNotFound
	ELSIF arc.firstEntry = ent THEN
		offset := arc.firstEntry.offsetLocal;	(* arc.firstEntry.offsetLocal = 0 *)
		IF arc.lastEntry = arc.firstEntry THEN
			arc.lastEntry := arc.firstEntry.next	(* = NIL *)
		END;
		arc.firstEntry := arc.firstEntry.next;
		ent2 := arc.firstEntry;
		res := Ok
	ELSE
		ent2 := arc.firstEntry;
		WHILE (ent2.next # NIL) & (ent2.next # ent) DO
			ent2 := ent2.next
		END;
		IF ent2.next = NIL THEN
			res := EntryNotFound
		ELSE
			IF arc.lastEntry = ent2.next THEN
				arc.lastEntry := ent2
			END;
			offset := ent2.next.offsetLocal;
			ent2.next := ent2.next.next;
			ent2 := ent2.next;
			res := Ok
		END
	END;
	IF res = Ok THEN
		arc.file.GetName(arcname);
		f := Files.New(arcname);
		f.Set(r2, 0);
		arc.file.Set(r1, 0);
		Copy(r1, r2, offset, FALSE, diff);	(* no crc 32-checksum is computed -> diff used as dummy *)
		f.Update;
		ASSERT(ent2 = ent.next);
		IF ent2 # NIL THEN
			arc.file.Set(r1, ent2.offsetLocal);
			Copy(r1, r2, arc.firstEntry.offsetCentralDir - ent2.offsetLocal, FALSE, diff);	(* arc.firstEntry can not be NIL because ent # NIL *)
			f.Update;
			diff := ent2.offsetLocal - offset
		ELSE
			diff := arc.offset - offset
		END;
		WHILE (ent2 # NIL) DO	(* update offsets of entries *)
			DEC(ent2.offsetLocal, diff); DEC(ent2.offsetFileData, diff); DEC(ent2.offsetCentralDir, diff);
			ent2 := ent2.next
		END;
		DEC(arc.offset, diff);
		DEC(arc.nofEntries);
		WriteCentralDirectory(arc, r2);
		Files.Register(f); arc.file := f; ent := NIL
	END
END DeleteEntry;

(** open a Reader to read uncompressed data from a zip entry directly to memory **)
PROCEDURE OpenReader*(arc: Archive; ent: Entry): Reader;
VAR
	dummyBuf: ARRAY 1 OF CHAR;
	fr: Files.Rider;
	r: Reader;
	ur: UncompReader;
	dr: DefReader;
BEGIN
	IF ent.support = Supported THEN
		IF ent.method = Stored THEN
			NEW(ur);
			ur.crc32 := Zlib.CRC32(0, dummyBuf, -1, -1);
			arc.file.Set(ur.fr, ent.offsetFileData);
			r := ur;
			r.open := TRUE;
			r.res := Ok
		ELSIF ent.method = Deflated THEN
			arc.file.Set(fr, ent.offsetFileData);
			NEW(dr);
			ZlibReaders.Open(dr.zr, FALSE, fr);
			dr.res := dr.zr.res;
			r := dr;
			r.open := TRUE
		ELSE
			NEW(r);
			r.open := FALSE;
			r.res := NotSupportedError
		END;
	ELSE
		NEW(r);
		r.open := FALSE;
		r.res := NotSupportedError
	END;
	r.ent := ent;
	RETURN r;
END OpenReader;

(** read len bytes of uncompressed data into buf[offset] and return number of bytes actually read; Reader must be opened **)
PROCEDURE ReadBytes*(r: Reader; VAR buf: ARRAY OF CHAR; offset, len: SIZE; VAR read: SIZE);
VAR
	bufp: POINTER TO ARRAY OF CHAR; i: SIZE;
BEGIN
	IF r.open THEN
		IF r IS UncompReader THEN
			IF offset = 0 THEN
				r(UncompReader).fr.file.ReadBytes(r(UncompReader).fr, buf, 0, len);
			ELSE
				NEW(bufp, len);
				r(UncompReader).fr.file.ReadBytes(r(UncompReader).fr, bufp^, 0, len);
				FOR i := 0 TO len - 1 DO
					buf[offset + i] := bufp[i]
				END
			END;
			read := len - r(UncompReader).fr.res;
			r(UncompReader).crc32 := Zlib.CRC32(r(UncompReader).crc32, buf, offset, read)
		ELSIF r IS DefReader THEN
			ZlibReaders.ReadBytes(r(DefReader).zr, buf, offset, len, read);
			r.res := r(DefReader).zr.res
		END
	ELSE
		r.res := ReaderError
	END
END ReadBytes;

(** read decompressed byte **)
PROCEDURE Read*(r: Reader; VAR ch: CHAR);
VAR
	buf: ARRAY 1 OF CHAR; read: SIZE;
BEGIN
	ReadBytes(r, buf, 0, 1, read);
	ch := buf[0];
END Read;

(** close Reader **)
PROCEDURE Close*(r: Reader);
BEGIN
	IF r.open THEN
		IF r IS UncompReader THEN
			IF r(UncompReader).crc32 # r.ent.crc32 THEN
				r.res := DataError
			ELSE
				r.res := Ok
			END
		ELSIF r IS DefReader THEN
			ZlibReaders.Close(r(DefReader).zr);
			IF r(DefReader).zr.crc32 # r.ent.crc32 THEN
				r.res := DataError
			ELSE
				r.res := r(DefReader).zr.res
			END
		ELSE
			r.res := ReaderError
		END;
		r.open := FALSE
	ELSE
		r.res := ReaderError
	END
END Close;

(* ----- api --------------------------------------------------------------------------- *)

(** open an existing archive. applications should use the method Old in the superclass *)
PROCEDURE Old*(name: Archives.StringObject): Archives.Archive;
VAR
	archive: ArchiveObj;
	file: Files.File;
BEGIN
	file := Files.Old(name.value);
	IF file = NIL THEN
		RETURN NIL
	ELSE
		NEW(archive, file);
		RETURN archive
	END
END Old;

(** create a new archive, overwrite existing. applications should use the method New in the superclass *)
PROCEDURE New*(name: Archives.StringObject): Archives.Archive;
VAR
	archive: ArchiveObj;
	file: Files.File;
BEGIN
	file := Files.New(name.value);
	Files.Register(file);
	NEW(archive, file);
	RETURN archive
END New;

END Zip.
