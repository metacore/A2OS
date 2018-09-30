MODULE SVNUtil; (** AUTHOR "rstoll"; *)

IMPORT
	Files, Strings, MD5,
	SVNOutput,
	Dates;

TYPE
	(* only look for one match *)
	FSItemSearch* = OBJECT ( Files.Enumerator )	(** not shareable *)
		VAR
			adding, found: BOOLEAN;
			name0 : Files.FileName;
			path, mask : Strings.String;
			flags0: SET;
			time0, date0, size0 : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			found := FALSE;
			adding := FALSE;
			NEW ( path, 512 );
			NEW ( mask, 512 );
		END Init;

		PROCEDURE Exists* () : BOOLEAN;
		BEGIN
			RETURN found;
		END Exists;

		PROCEDURE FileExists* () : BOOLEAN;
		BEGIN
			RETURN found & (Files.Old ( mask^ ) # NIL);
		END FileExists;

		PROCEDURE Open*(m: ARRAY OF CHAR; flags: SET);
		BEGIN
			(* remove path delimiter at the end *)
			IF Strings.EndsWith ( Files.PathDelimiter, m ) THEN
				m[Strings.Length(m)-1] := 0X;
			END;

			COPY ( m, mask^ );
			Files.SplitPath ( mask^, path^, name0 );
			Strings.Append ( path^, "/*" );
			found := FALSE;

			adding := TRUE;
			Open^ ( path^, flags ); (* since i can't call the internal enumerator.. use the old Open procedure *)
			adding := FALSE;
		END Open;

		PROCEDURE GetEntry*(VAR name: ARRAY OF CHAR; VAR flags: SET; VAR time, date, size: LONGINT): BOOLEAN;
		BEGIN
			IF found THEN
				COPY ( name0, name );
				flags := flags0;
				time := time0;
				date := date0;
				size := size0;
			END;

			RETURN found;
		END GetEntry;

		(** For internal use only. *)

		PROCEDURE PutEntry*(VAR name: ARRAY OF CHAR; flags: SET; time, date, size: LONGINT);
		BEGIN
			ASSERT(adding);

			IF ~found & (name = mask^) THEN
				name[0] := name[0];
				found := TRUE;
				flags := flags0;
				time := time0;
				date := date0;
				size := size0;
			END;
		END PutEntry;

	END FSItemSearch;




PROCEDURE GetChecksum* ( CONST file : ARRAY OF CHAR ) : Strings.String;
CONST
	bufSize = 512;
VAR
	read, len : LONGINT;
	tmp, res : Strings.String;
	md5context : MD5.Context;
	md5digest : MD5.Digest;

	r : Files.Reader;
	f : Files.File;
BEGIN
	NEW ( tmp, bufSize );
	NEW ( res, 35 );

	f := Files.Old ( file  );
	ASSERT ( f # NIL );

	Files.OpenReader ( r, f, 0 );

	md5context := MD5.New();
	read := 0;
	LOOP
		r.Bytes ( tmp^, read, bufSize, len );
		MD5.WriteBytes ( md5context, tmp^, len );
		IF len < bufSize THEN EXIT END;
	END;

	MD5.Close ( md5context, md5digest );
	MD5.ToString ( md5digest, res^ );

	RETURN res;
END GetChecksum;


PROCEDURE CheckChecksum* ( CONST file, checksum : ARRAY OF CHAR ) : BOOLEAN;
VAR
	s : Strings.String;
BEGIN
	s := GetChecksum ( file );
	RETURN s^ = checksum;
END CheckChecksum;




PROCEDURE GetUUID* () : Strings.String;
VAR
	md5context : MD5.Context;
	md5digest : MD5.Digest;
	tmp : Strings.String;
BEGIN
	NEW ( tmp, 40 );
	md5context := MD5.New();
	Strings.FormatDateTime ( SVNOutput.DateFormat, Dates.Now(), tmp^ );

	MD5.WriteBytes ( md5context, tmp^, Strings.Length ( tmp^ ) );
	MD5.Close ( md5context, md5digest );
	MD5.ToString ( md5digest, tmp^ );

	RETURN tmp;
END GetUUID;


PROCEDURE FileExists* ( CONST file : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
	RETURN Files.Old ( file ) # NIL;
END FileExists;


(* simplistic url encoder/decoder stuff *)
PROCEDURE UrlEncode* ( CONST input : ARRAY OF CHAR; VAR output : ARRAY OF CHAR );
CONST
	unsafe = " <>#%[]|\^~[]'"; (* what about " *)
VAR
	i, j : LONGINT;
	tmp : ARRAY 3 OF CHAR;
BEGIN
	i := 0; j := 0;
	WHILE input[i] # 0X DO
		IF Strings.Find ( unsafe, 0, input[i] ) = -1 THEN
			output[j] := input[i];
			INC ( j );
		ELSE
			output[j] := '%'; INC ( j );
			Strings.IntToHexStr ( ORD(input[i]), 1, tmp );
			output[j] := tmp[0]; INC ( j );
			output[j] := tmp[1]; INC ( j );
		END;
		INC ( i );
	END;
	output[j] := 0X;
END UrlEncode;


PROCEDURE UrlDecode* (CONST input : ARRAY OF CHAR; VAR output : ARRAY OF CHAR );
VAR
	i, j, value: LONGINT; res: WORD;
	tmp : ARRAY 3 OF CHAR;
BEGIN
	i := 0; j := 0;
	tmp[2] := 0X;
	WHILE input[i] # 0X DO
		IF input[i] = '%' THEN
			INC ( i );
			tmp[0] := input[i]; INC ( i );
			tmp[1] := input [i]; INC ( i );

			Strings.HexStrToInt ( tmp, value, res ); ASSERT ( res = Strings.Ok );
			output[j] := CHR ( value ); INC ( j );
		ELSE
			output[j] := input[i];
			INC ( j ); INC ( i );
		END;
	END;
	output[j] := 0X;
END UrlDecode;



PROCEDURE RemoveFileDelimiterAtEnd* ( VAR s : ARRAY OF CHAR );
BEGIN
	IF Strings.EndsWith ( Files.PathDelimiter, s ) THEN
		s[Strings.Length(s)-1] := 0X;
	END;
END RemoveFileDelimiterAtEnd;


END SVNUtil.