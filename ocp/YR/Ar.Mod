MODULE Ar; (** AUTHOR "Yaroslav Romanchenko"; PURPOSE "Basic Unix AR (DEB) archive packing and unpacking"; *)

IMPORT
	Commands, Options, Files, Strings, Dates;

CONST
	MAGIC = '!<arch>'0AX;
	MagicLen = 8;
	FileIdLen = 16;
	FileTimeLen = 12;
	OwnerIdLen = 6;
	GroupIdLen = 6;
	FileModeLen = 8;
	FileSizeLen = 10;

	CRLF = ''0DX''0AX;


TYPE
	Chars = ARRAY OF CHAR;

OPERATOR "+"(CONST a1, a2: Chars): Strings.String;
BEGIN
	RETURN Strings.ConcatToNew(a1, a2)
END "+";

PROCEDURE CalcSeconds(days, hours, minutes, seconds: SIGNED32): SIGNED64;
BEGIN

	RETURN ((days * 24 + hours) * 60 + minutes) * 60 + seconds

END CalcSeconds;

PROCEDURE SecondsToDateTime(val: SIGNED64): Dates.DateTime;
VAR
	dt: Dates.DateTime;
BEGIN

	dt := Dates.ZeroDateUnix;
	Dates.AddSeconds(dt, SIGNED32(val MOD 60));
	val := SIGNED32(val DIV 60);
	Dates.AddMinutes(dt, SIGNED32(val MOD 60));
	val := SIGNED32(val DIV 60);
	Dates.AddHours(dt, SIGNED32(val MOD 24));
	Dates.AddDays(dt, SIGNED32(val DIV 24));
	RETURN dt

END SecondsToDateTime;

PROCEDURE GetUnixSecondsNow(): SIGNED64;
VAR
	dt: Dates.DateTime;
	days, hours, minutes, seconds: SIGNED32;
BEGIN

	dt := Dates.Now();
	Dates.TimeDifference(dt, Dates.ZeroDateUnix, days, hours, minutes, seconds);
	RETURN CalcSeconds(days, hours, minutes, seconds)

END GetUnixSecondsNow;

PROCEDURE GetUnixSecondsFile(file: Files.File): SIGNED64;
VAR
	t, d: SIGNED32;
	dt: Dates.DateTime;
	days, hours, minutes, seconds: SIGNED32;
BEGIN

	file.GetDate(t, d);
	dt := Dates.OberonToDateTime(d, t);
	Dates.TimeDifference(dt, Dates.ZeroDateUnix, days, hours, minutes, seconds);
	RETURN CalcSeconds(days, hours, minutes, seconds)

END GetUnixSecondsFile;

PROCEDURE TransferBytes(from : Files.Reader; to : Files.Writer; n : Files.Size);
VAR buf : ARRAY 1024 OF CHAR;
	len : SIZE;
BEGIN
	WHILE n > 1024 DO
		from.Bytes(buf, 0, 1024, len);
		to.Bytes(buf, 0, 1024);
		DEC(n, 1024)
	END;
	from.Bytes(buf, 0, SIZE(n), len);
	to.Bytes(buf, 0, SIZE(n));
	to.Update()
END TransferBytes;

PROCEDURE WriteMagic(writer: Files.Writer);
BEGIN

	writer.String(MAGIC)

END WriteMagic;

PROCEDURE WriteField(writer: Files.Writer; CONST value: ARRAY OF CHAR; fieldLen: INTEGER);
VAR
	len: SIZE;
BEGIN

	len := Strings.Length(value);
	writer.Bytes(value, 0, MIN(len, fieldLen));
	WHILE len < fieldLen DO
		writer.Char(20X); INC(len)
	END

END WriteField;

PROCEDURE WriteFileHeader(writer: Files.Writer; CONST fileName: ARRAY OF CHAR; fileUnixTime: SIGNED64;
  ownerId, groupId, fileMode: SIGNED32; fileSize: Files.Size);
VAR
	stamp: ARRAY FileTimeLen OF CHAR;
	id: ARRAY MAX(OwnerIdLen, GroupIdLen) OF CHAR;
	mode: ARRAY FileModeLen OF CHAR;
	size: ARRAY FileSizeLen OF CHAR;
BEGIN

	WriteField(writer, fileName, FileIdLen);
	Strings.IntToStr(fileUnixTime, stamp); WriteField(writer, stamp, FileTimeLen);
	Strings.IntToStr(ownerId, id); WriteField(writer, id, OwnerIdLen);
	Strings.IntToStr(groupId, id); WriteField(writer, id, GroupIdLen);
	Strings.IntToStr(fileMode, mode); WriteField(writer, mode, FileModeLen);
	Strings.IntToStr(fileSize, size); WriteField(writer, size, FileSizeLen);
	writer.Char(60X); writer.Char(0AX)

END WriteFileHeader;

PROCEDURE InitArchive(CONST fileName: ARRAY OF CHAR; deb: BOOLEAN; VAR file: Files.File; VAR writer: Files.Writer);
BEGIN

	file := Files.New(fileName);
	Files.Register(file);
	Files.OpenWriter(writer, file, 0);

	(* Write AR file magic *)
	WriteMagic(writer);

	(* Write DEB file version header *)
	IF deb THEN
		WriteFileHeader(writer, "debian-binary", GetUnixSecondsNow(), 0, 0, 100644, 4);
		(* Version and new line char. 4 bytes in total *)
		writer.String("2.0"); writer.Char(0AX)
	END;

	writer.Update

END InitArchive;

PROCEDURE WriteFile(writer: Files.Writer; CONST fileName: ARRAY OF CHAR; file: Files.File);
VAR
	reader: Files.Reader;
BEGIN

	WriteFileHeader(writer, fileName, GetUnixSecondsFile(file), 0, 0, 100644, file.Length());

	Files.OpenReader(reader, file, 0);

	TransferBytes(reader, writer, file.Length());

	(* 2 bytes align! *)
	IF ODD(file.Length()) THEN
		writer.Char(0AX)
	END;

	writer.Update

END WriteFile;

PROCEDURE ReadField(reader: Files.Reader; VAR value: ARRAY OF CHAR; fieldLen: INTEGER): BOOLEAN;
VAR
	lenRead: SIZE;
BEGIN
	ASSERT(LEN(value) > fieldLen);
	reader.Bytes(value, 0, fieldLen, lenRead);
	value[fieldLen] := 0X;
	Strings.TrimRight(value, 20X);
	RETURN lenRead = fieldLen
END ReadField;

(** Usage: Ar.Ar [--overwrite] [--debHeader] <Ouput file> <Input file 1> <Input file 2> <Input file N> ~ *)
PROCEDURE Ar*(context : Commands.Context);
VAR
	options: Options.Options;
	fileNameIn, fileNameOut: Files.FileName;
	fileIn, fileOut: Files.File;
	writer: Files.Writer;
	res: INTEGER;

	PROCEDURE Error(CONST msg: ARRAY OF CHAR; res: INTEGER);
	BEGIN context.result := res; context.error.String(msg); context.error.Update END Error;

BEGIN

	NEW(options);
	options.Add("o", "overwrite", Options.Flag);
	options.Add("d", "debHeader", Options.Flag);
	IGNORE options.Parse(context.arg, context.out);

	context.arg.SkipWhitespace; context.arg.String(fileNameOut);
	context.out.String(("Creating " + fileNameOut + CRLF)^);

	fileOut := Files.Old(fileNameOut);
	IF fileOut # NIL THEN
		IF ~options.GetFlag("overwrite") THEN
			Error(("File already exists " + fileNameOut + CRLF)^, Files.FileAlreadyExists);
			RETURN
		ELSE
			fileOut := NIL; Files.Delete(fileNameOut, res)
		END
	END;

	WHILE context.arg.GetString(fileNameIn) DO

		context.out.String(("Input file " + fileNameIn + CRLF)^);

		fileIn := Files.Old(fileNameIn);
		IF fileIn # NIL THEN

			IF fileOut = NIL THEN
				InitArchive(fileNameOut, options.GetFlag("debHeader"), fileOut, writer)
			END;

			WriteFile(writer, fileNameIn, fileIn);

		ELSE
			Error(("File not found " + fileNameIn + CRLF)^, Files.FileNotFound);
			RETURN
		END

	END;
	context.out.String(("Done with " + fileNameOut + CRLF)^)

END Ar;

(** Usage: Ar.UnAr [--extract] [--overwrite] [--prefix=<path>] <Input file> ~ *)
PROCEDURE UnAr*(context : Commands.Context);
VAR
	options: Options.Options;
	fileNameIn, fileName, prefix: Files.FileName;
	fileIn, fileOut: Files.File;
	reader: Files.Reader;
	writer: Files.Writer;
	buf: ARRAY FileIdLen + 1 OF CHAR;
	bufDT, bufFSize: ARRAY 32 OF CHAR;
	fileDate: SIGNED64;
	fileSize: SIZE;
	bOk: BOOLEAN;
	res: INTEGER;

	PROCEDURE Error(CONST msg: ARRAY OF CHAR; res: INTEGER);
	BEGIN context.result := res; context.error.String(msg); context.error.Update END Error;

BEGIN

	NEW(options);
	options.Add("o", "overwrite", Options.Flag);
	options.Add("e", "extract", Options.Flag);
	options.Add("p", "prefix", Options.String);
	IGNORE options.Parse(context.arg, context.out);
	
	IF ~options.GetString("prefix", prefix) THEN
		prefix[0] := 0X
	END;

	IF context.arg.GetString(fileNameIn) THEN
		context.out.String(("Archive file " + fileNameIn + CRLF)^);

		fileIn := Files.Old(fileNameIn);
		IF fileIn # NIL THEN

			Files.OpenReader(reader, fileIn, 0);

			(* Check magic *)
			IF ReadField(reader, buf, MagicLen) & (buf = MAGIC) THEN

				LOOP

					(* Read file name, date and size *)

					bOk := ReadField(reader, buf, FileIdLen);
					IF bOk THEN
						COPY(buf, fileName)
					ELSE EXIT END;

					bOk := ReadField(reader, buf, FileTimeLen);
					IF bOk THEN
						Strings.StrToHInt(buf, fileDate);
						Dates.FormatDateTime("yyyy.mm.dd hh:nn:ss", SecondsToDateTime(fileDate), bufDT)
					ELSE EXIT END;

					reader.SkipBytes(OwnerIdLen);
					reader.SkipBytes(GroupIdLen);
					reader.SkipBytes(FileModeLen);

					bOk := ReadField(reader, buf, FileSizeLen);
					IF bOk THEN
						Strings.StrToSize(buf, fileSize);
						Strings.IntToStr(fileSize, bufFSize)
					ELSE EXIT END;

					reader.SkipBytes(2);

					(* Read the file *)

					context.out.String(("File name " + fileName + ", datetime " + bufDT + ", size " + bufFSize + CRLF)^);
					context.out.Update;

					IF options.GetFlag("extract") THEN
						Strings.Concat(prefix, fileName, fileName);
						fileOut := Files.Old(fileName);
						IF fileOut # NIL THEN
							IF ~options.GetFlag("overwrite") THEN
								reader.SkipBytes(fileSize);
								context.out.String(("File exists " + fileName + ". Skipped" + CRLF)^);
								context.out.Update;
							ELSE
								fileOut := NIL; Files.Delete(fileName, res)
							END
						END;
						IF fileOut = NIL THEN
							fileOut := Files.New(fileName);
							Files.Register(fileOut);
							Files.OpenWriter(writer, fileOut, 0);

							TransferBytes(reader, writer, fileSize);
							writer.Update;
							context.out.String(("Extracted " + fileName + CRLF)^);
							context.out.Update
						END

					ELSE
						reader.SkipBytes(fileSize)
					END;

					(* 2 byte alignment *)
					IF ODD(fileSize) THEN
						reader.SkipBytes(1)
					END

				END

			ELSE
				Error(("Wrong file " + fileNameIn + CRLF)^, Commands.CommandError);
				RETURN
			END

		ELSE
			Error(("File not found " + fileNameIn + CRLF)^, Files.FileNotFound);
			RETURN
		END

	END

END UnAr;

BEGIN

END Ar.

System.DoCommands
	GZip.GZip control.tar 9 ~
	GZip.GZip data.tar 9 ~
	FSTools.CloseFiles control.tar.gz data.tar.gz ~
	Ar.Ar --overwrite --debHeader a2.deb control.tar.gz data.tar.gz ~
	FSTools.CloseFiles a2.deb ~
~

Ar.UnAr --extract --overwrite --prefix=tmp/ a2.deb ~

System.Free Ar ~
