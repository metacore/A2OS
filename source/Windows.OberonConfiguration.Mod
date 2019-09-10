MODULE OberonConfiguration;   (** fof  **)
(* read from and write to configuration files / texts etc. *)


CONST

	TAB = 9X;  CR = 0DX;  LF = 0AX;  MaxStrLen = 512;  MaxIdLen = 64;

	eot = 0;  lbrace = 2;  rbrace = 3;  eol = 4;  equals = 6;  char = 7;  whitespace = 8;  EOR* = 0X;  cr* = 0;  crlf* = 1;
	lf* = 2;  lfcr* = 3;

TYPE

	tName = ARRAY MaxIdLen + 1 OF CHAR;
	tString = ARRAY MaxStrLen OF CHAR;   (* probably too long *)

	tEntry* = POINTER TO RECORD
				name-: tName;
				next: tEntry;
				father-: tSegment;
			END;
		KeyValueEnumerator* = PROCEDURE ( key, value: ARRAY OF CHAR );
	EntryEnumerator* = PROCEDURE ( entry: tEntry );

	tValue* = POINTER TO RECORD (tEntry)
				value*: tString;
			END;

	tSegment* = POINTER TO RECORD (tEntry)
				nEntries: SIGNED32;
				entries: tEntry;
			END;

	WriterProc* = PROCEDURE ( ch: CHAR );
	ReaderProc* = PROCEDURE ( VAR ch: CHAR );

TYPE

	tWriter = OBJECT
			VAR PutCh: WriterProc;
				EndOfLine: SIGNED8;

				PROCEDURE & Init*( w: WriterProc;  eol: SIGNED8 );
				BEGIN
					PutCh := w;  EndOfLine := eol;
				END Init;

				PROCEDURE WriteSpace( level: SIGNED32 );
				VAR tab: CHAR;
				BEGIN
					tab := TAB;
					WHILE (level > 0) DO PutCh( TAB );  DEC( level );  END;
				END WriteSpace;

				PROCEDURE WriteLn;
				BEGIN
					CASE EndOfLine OF
					cr:    PutCh( CR );
					| crlf:
							PutCh( CR );  PutCh( LF );
					| lf:   PutCh( LF );
					| lfcr:
							PutCh( LF );  PutCh( CR );
					END;
				END WriteLn;

				(*
				PROCEDURE WriteQuotedString(str: ARRAY OF CHAR);
				VAR i: SIGNED32; q1 (* " *) ,q2 (* ' *) : BOOLEAN;  ch: CHAR;
				BEGIN
					ch := str[i]; q1 := FALSE; q2 := FALSE;
					WHILE(ch #0X) DO
						IF ch= '"' THEN q1 := TRUE;
						ELSIF ch = "'" THEN q2 := TRUE
						END;
						 INC( i );  ch := str[i];
					END;
					IF q1=FALSE THEN
						PutCh('"'); WriteString(str); PutCh('"');
					ELSIF q2=FALSE THEN
						PutCh("'"); WriteString(str); PutCh("'");
					ELSE (* no good *)
						 PutCh('"'); WriteString(str); PutCh('"');
					END

				END WriteQuotedString;
				*)


				PROCEDURE WriteString( str: ARRAY OF CHAR );
				VAR ch: CHAR;  i: SIGNED32;
				BEGIN
					ch := str[i];
					WHILE (ch # 0X) DO PutCh( ch );  INC( i );  ch := str[i];  END;
				END WriteString;

				PROCEDURE WriteEntry( e: tEntry;  VAR level: SIGNED32 );
				BEGIN
					IF e IS tValue THEN
					WITH e: tValue DO
						WriteLn;  WriteSpace( level );
						IF (level >=0) & (e.name # "") THEN WriteString( e.name );  WriteString( "=" );  PutCh( TAB ) END;
						WriteString( e.value );
						END;
					ELSIF e IS tSegment THEN

					WITH  e: tSegment DO
						IF (level >=0) & (e.name # "")  THEN
							WriteLn;  WriteSpace( level );  WriteString( e.name );  WriteString( "=" );  PutCh( TAB )
						END;
						WriteSegment( e, level );
					END;
					ELSE WriteLn;
						(* empty line or empty assignment*)
					END;
				END WriteEntry;

				PROCEDURE WriteSegment( s: tSegment;  VAR level: SIGNED32 );
				VAR entry: tEntry;
				BEGIN
					IF s = NIL THEN RETURN END;
					entry := s.entries;
					IF level >= 0 THEN WriteLn;  WriteSpace( level );  PutCh( "{" );  END;
					INC( level );
					WHILE (entry # NIL ) DO WriteEntry( entry, level );  entry := entry.next;  END;
					DEC( level );
					IF level >= 0 THEN WriteLn;  WriteSpace( level );  PutCh( "}" );  END;
				END WriteSegment;

			END tWriter;

	tParser = OBJECT
			VAR writer: tWriter;
				ch, lastch: CHAR;
				noerr: BOOLEAN;
				pos: SIGNED32;
				buflen, bufpos: SIGNED32;
				buf: ARRAY MaxIdLen + 2 OF CHAR;
				och: CHAR;
				GetCh: ReaderProc;
				(** scanner *)

				PROCEDURE & Init*( r: ReaderProc;  w: WriterProc );
				BEGIN
					GetCh := r;  NEW( writer, w, EndOfLine );  pos := 0;
				END Init;

				PROCEDURE err( n: ARRAY OF CHAR );

					PROCEDURE Int( x: SIGNED32 );
					VAR i: SIGNED32;
						a: ARRAY 12 OF CHAR;
					BEGIN
						i := 0;
						REPEAT a[i] := CHR( x MOD 10 + 30H );  x := x DIV 10;  INC( i ) UNTIL x = 0;
						REPEAT DEC( i );  writer.PutCh( a[i] ) UNTIL i = 0
					END Int;

				BEGIN
					noerr := FALSE;  writer.WriteString( n );  writer.WriteString( ". Error at pos " );  Int( pos );
					writer.WriteLn;
				END err;

				PROCEDURE Getchb( VAR ch: CHAR );
				BEGIN
					ch := buf[bufpos];  INC( bufpos );
					IF bufpos = buflen THEN buflen := 0;  bufpos := 0;  END;
				END Getchb;

				PROCEDURE Getch( VAR ch: CHAR );
				BEGIN
					IF ~noerr THEN ch := 0X;  RETURN END;
					lastch := ch;
					IF buflen > 0 THEN Getchb( ch ) ELSE GetCh( ch );  INC( pos );  END;
				END Getch;

				PROCEDURE Get( VAR sym: SIGNED8 );
				VAR s: SIGNED8;
				BEGIN
					IF och # 0X THEN  (* ignore controls in string *)
						IF ch = och THEN och := 0X;  s := char;  Getch( ch ) ELSE
							CASE ch OF
							| CR:
									s := eol;  och := 0X;  Getch( ch );
									IF (ch = LF) THEN Getch( ch ) END;
							| LF: s := eol;  och := 0X;  Getch( ch );
									IF (ch = CR) THEN Getch( ch ) END;
							| EOR:
									s := eot;
							ELSE s := char;  Getch( ch );
							END;
						END;
					ELSE
						CASE ch OF
						| 22X, 27X:
								och := ch;  s := char;  Getch( ch );
						| "{":
								s := lbrace;  Getch( ch );
						| "}":
								s := rbrace;  Getch( ch );
						| CR:
								s := eol;  Getch( ch );
								IF (ch = LF) THEN Getch( ch ) END;
						| LF: s := eol;  Getch( ch );
								IF (ch = CR) THEN Getch( ch ) END;
						| "=":
								s := equals;  Getch( ch );
						| " ", TAB:
								s := whitespace;  Getch( ch );
						| EOR:
								s := eot;
						ELSE s := char;  Getch( ch );
						END;
					END;
					sym := s;
				END Get;

			(** parser *)

				PROCEDURE White( VAR sym: SIGNED8 );
				BEGIN
					WHILE (sym = whitespace) OR (sym = eol) DO Get( sym ) END;
				END White;

				PROCEDURE SkipNL( VAR sym: SIGNED8 );
				BEGIN
					WHILE (sym = whitespace) DO Get( sym );  END;
					IF sym = eol THEN Get( sym ) END;
					WHILE (sym = whitespace) DO Get( sym );  END;
				END SkipNL;

				PROCEDURE Entry( VAR sym: SIGNED8;  name: ARRAY OF CHAR;  segment: tSegment );
				VAR value: tString;  i: SIGNED32;
				BEGIN
					i := 0;
					WHILE (sym = char) OR (sym = whitespace) OR (sym = equals) DO
						value[i] := lastch;  INC( i );   (* ASSERT(lastch # "}"); *)
						Get( sym );
					END;
					value[i] := 0X;  AddValue( segment, name, value );  SkipNL( sym );
				END Entry;

				PROCEDURE Subsection( VAR sym: SIGNED8;  name: ARRAY OF CHAR;  segment: tSegment ): BOOLEAN;
				VAR seg: tSegment;
				BEGIN
					IF sym # lbrace THEN RETURN FALSE END;
					Get( sym );  SkipNL( sym );   seg := AddSegment( segment, name );  Segment( sym, seg );
					IF sym = rbrace THEN Get( sym );  SkipNL( sym );  ELSE err( "'}' expected" );  Get( sym ) END;
					RETURN TRUE
				END Subsection;

				PROCEDURE AssignHead( VAR sym: SIGNED8;  VAR name: ARRAY OF CHAR ): BOOLEAN;
				VAR lastsym: SIGNED8;  buflastch: CHAR;
				BEGIN
					ASSERT( buflen = 0 );
					IF sym # char THEN RETURN FALSE END;
					bufpos := 0;  buflastch := lastch;  lastsym := sym;
					WHILE (sym = char) & (bufpos < MaxIdLen) DO
						buf[bufpos] := ch;  name[bufpos] := lastch;  INC( bufpos );  Get( sym );
					END;
					name[bufpos] := 0X;

					WHILE (sym = whitespace) & (bufpos < MaxIdLen) DO buf[bufpos] := ch;  INC( bufpos );  Get( sym );
					END;
					buf[bufpos] := ch;  INC( bufpos );  buf[bufpos] := 0X;

					IF sym = equals THEN bufpos := 0;  buflen := 0;  Get( sym );  White( sym );  RETURN TRUE
					ELSE
						buflen := bufpos;  ch := buflastch;  bufpos := 0;  och := 0X;  Get( sym );   (* repeats GetSym before entry *)
						RETURN FALSE;
					END;
				END AssignHead;

				PROCEDURE Segment( VAR sym: SIGNED8;  segment: tSegment );
				VAR name: tName;
				BEGIN
					WHILE (sym # eot) & (sym # rbrace) DO
						WHILE (sym = whitespace) DO Get( sym );  END;
						IF AssignHead( sym, name ) THEN
							IF Subsection( sym, name, segment ) THEN ELSE Entry( sym, name, segment ) END;
						ELSIF Subsection( sym, "", segment ) THEN
						ELSE Entry( sym, "", segment );
						END;
					END;
				END Segment;

				PROCEDURE Configuration( ): tSegment;
				VAR s: SIGNED8;  segment: tSegment;
				BEGIN
					buflen := 0;  bufpos := 0;  noerr := TRUE;  Getch( ch );  Get( s );  White( s );
					segment := AddSegment( NIL , "" );  Segment( s, segment );
					IF noerr THEN RETURN segment ELSE RETURN NIL END;
				END Configuration;

			END tParser;
VAR
	EndOfLine*: SIGNED8;  PathSeparator-: CHAR;

	(** output *)

	PROCEDURE Write*( e: tEntry;  w: WriterProc;  level: SIGNED32 );
	VAR writer: tWriter;
	BEGIN
		IF e = NIL THEN RETURN END;
		NEW( writer, w, EndOfLine );  writer.WriteEntry( e, level );
	END Write;

(**  tree generation *)

	PROCEDURE Append( e: tEntry;  VAR to: tEntry );
	VAR r: tEntry;
	BEGIN
		IF to = NIL THEN to := e;
		ELSE
			r := to;
			WHILE (r.next # NIL ) DO r := r.next;  END;
			r.next := e;
		END;
	END Append;

	PROCEDURE AddSegment*( to: tSegment;  name: ARRAY OF CHAR ): tSegment;
	VAR s: tSegment;
	BEGIN
		NEW( s );  COPY( name, s.name );
		IF to # NIL THEN INC( to.nEntries );  Append( s, to.entries );  s.father := to;  END;
		RETURN s;
	END AddSegment;

	PROCEDURE AddValue*( to: tSegment;  name, value: ARRAY OF CHAR );
	VAR v: tValue;  e: tEntry;
	BEGIN
		IF value # "" THEN
			NEW( v );  COPY( name, v.name );  COPY( value, v.value );  Append( v, to.entries );  v.father := to;
		ELSE NEW( e );  COPY( name, e.name );  Append( e, to.entries );  e.father := to;
		END;
		INC( to.nEntries )
	END AddValue;

(** reading *)

	PROCEDURE NullCh( ch: CHAR );
	END NullCh;

	PROCEDURE Read*( r: ReaderProc;  err: WriterProc ): tSegment;
	VAR p: tParser;
	BEGIN
		IF err = NIL THEN err := NullCh END;
		NEW( p, r, err );  RETURN p.Configuration();
	END Read;

(** tree manipulation *)

	PROCEDURE Delete( e: tEntry;  VAR from: tEntry );
	VAR r: tEntry;
	BEGIN
		IF from = e THEN from := from.next;
		ELSE
			r := from;
			WHILE (r.next # NIL ) DO
				IF r.next = e THEN
					r.next := e.next;  e.next := NIL;
					RETURN;   (* only one entry allowed *)
				END;
				r := r.next;
			END;
		END;
	END Delete;

	PROCEDURE StripQuotes*( VAR n: ARRAY OF CHAR );
	VAR i: SIGNED32;  ch, och: CHAR;   (* strips the quotes and deletes rest (!) *)
	BEGIN
		ch := n[0];
		IF (ch = "'") OR (ch = '"') THEN
			och := ch;
			REPEAT INC( i );  ch := n[i];  n[i - 1] := ch;  UNTIL (ch = 0X) OR (ch = och);
			n[i - 1] := 0X;
		END;
	END StripQuotes;

	PROCEDURE SameName( n1, n2: ARRAY OF CHAR ): BOOLEAN;
	BEGIN
		StripQuotes( n1 );  StripQuotes( n2 );
		IF n1 = n2 THEN RETURN TRUE ELSE RETURN FALSE END;
	END SameName;

	PROCEDURE FindNamedEntry*( in: tSegment;  name: ARRAY OF CHAR ): tEntry;
	VAR entry: tEntry;
	BEGIN
		IF in = NIL THEN RETURN NIL END;
		entry := in.entries;
		WHILE (entry # NIL ) & (~SameName( name, entry.name )) DO entry := entry.next;  END;
		RETURN entry;
	END FindNamedEntry;

	PROCEDURE RenameEntry*( e: tEntry;  name: ARRAY OF CHAR );
	BEGIN
		IF e = NIL THEN RETURN END;
		COPY( name, e.name );
	END RenameEntry;

	PROCEDURE RemoveEntry*( e: tEntry );
	BEGIN
		IF (e = NIL ) OR (e.father = NIL ) THEN RETURN END;
		Delete( e, e.father.entries );  DEC( e.father.nEntries );  e.father := NIL;
	END RemoveEntry;

	PROCEDURE AddEntry*( e: tEntry;  to: tSegment );
	BEGIN
		IF (e = NIL ) OR (to = NIL ) THEN RETURN END;
		ASSERT( e.father = NIL );  Append( e, to.entries );  INC( to.nEntries )
	END AddEntry;

	PROCEDURE EnumerateEntries*( enum: EntryEnumerator;  segment: tEntry );
	VAR entry: tEntry;
	BEGIN
		IF (segment = NIL ) OR (~(segment IS tSegment)) THEN RETURN END;
		entry := segment( tSegment ).entries;
		WHILE (entry # NIL ) DO enum( entry );  entry := entry.next END;
	END EnumerateEntries;

	PROCEDURE EnumerateVals*( enum: KeyValueEnumerator;  segment: tEntry );
	VAR entry: tEntry;
	BEGIN
		IF (segment = NIL ) OR (~(segment IS tSegment)) THEN RETURN END;
		entry := segment( tSegment ).entries;
		WHILE (entry # NIL ) DO
			IF entry IS tValue THEN
			WITH entry: tValue DO enum( entry.name, entry.value );
			END;
			END;
			entry := entry.next;
		END;
	END EnumerateVals;

	PROCEDURE Find*( root: tSegment;  name: ARRAY OF CHAR ): tEntry;
	VAR name0: tName;  ch: CHAR;  i, j: SIGNED32;  entry: tEntry;
	BEGIN
		i := 1;  j := 0;  ch := name[0];
		WHILE (ch # 0X) DO
			IF ch = PathSeparator THEN
				name0[j] := 0X;  entry := FindNamedEntry( root, name0 );
				IF (entry = NIL ) OR (~(entry IS tSegment)) THEN RETURN NIL ELSE root := entry( tSegment );  END;
				j := 0;
			ELSE name0[j] := ch;  INC( j );
			END;
			ch := name[i];  INC( i );
		END;
		name0[j] := 0X;  entry := FindNamedEntry( root, name0 );  RETURN entry;
	END Find;

	PROCEDURE FindOrCreateSegment(root: tSegment; name: ARRAY OF CHAR): tSegment;
	VAR name0: tName;  ch: CHAR;  i, j: SIGNED32;  entry: tEntry;
	BEGIN
		i := 1;  j := 0;  ch := name[0];
		WHILE (ch # 0X) DO
			IF ch = PathSeparator THEN
				name0[j] := 0X;
				entry := FindNamedEntry( root, name0 );
				IF entry = NIL THEN root := AddSegment(root,name0)
				ELSIF entry IS tSegment THEN root := entry(tSegment)
				ELSE RETURN NIL
				END;
				j := 0;
			ELSE name0[j] := ch;  INC( j );
			END;
			ch := name[i];  INC( i );
		END;
		name0[j] := 0X;
			entry := FindNamedEntry( root, name0 );
				IF entry = NIL THEN root := AddSegment(root,name0)
				ELSIF entry IS tSegment THEN root := entry(tSegment)
				ELSE RETURN NIL
				END;
			RETURN root;
	END FindOrCreateSegment;

	PROCEDURE DeletePath*(root: tSegment; name: ARRAY OF CHAR): BOOLEAN;
		VAR name0: tName;  ch: CHAR;  i, j: SIGNED32;  entry: tEntry;
	BEGIN
		i := 1;  j := 0;  ch := name[0];
		WHILE (ch # 0X) DO
			IF ch = PathSeparator THEN
				name0[j] := 0X;  entry := FindNamedEntry( root, name0 );
				IF (entry = NIL ) OR (~(entry IS tSegment)) THEN RETURN FALSE ELSE root := entry( tSegment );  END;
				j := 0;
			ELSE name0[j] := ch;  INC( j );
			END;
			ch := name[i];  INC( i );
		END;
		name0[j] := 0X;  entry := FindNamedEntry( root, name0 );
		IF (entry#NIL)& (entry IS tSegment) THEN
			RemoveEntry(entry) ;RETURN TRUE;
		ELSE
			RETURN FALSE
		END;
	END DeletePath;

	PROCEDURE DeleteKeyValue*( root: tSegment;  path, key: ARRAY OF CHAR ): BOOLEAN;
	VAR entry: tEntry;
	BEGIN
		entry := Find( root, path );
		IF (entry = NIL ) OR (~(entry IS tSegment)) THEN RETURN FALSE END;
		entry := FindNamedEntry( entry( tSegment ), key );
		IF (entry = NIL ) OR (~(entry IS tValue)) THEN RETURN FALSE END;
		RemoveEntry( entry );
		RETURN TRUE
	END DeleteKeyValue;

	PROCEDURE SetKeyValue*( root: tSegment;  path, key, value: ARRAY OF CHAR ): BOOLEAN;
	VAR entry: tEntry;
	BEGIN
		root := FindOrCreateSegment( root, path );
		IF (root = NIL )  THEN  RETURN FALSE END;
		entry := FindNamedEntry( root, key );
		IF (entry # NIL ) & (~(entry IS tValue)) THEN RETURN FALSE END;
		IF entry = NIL THEN AddValue( root, key, value ) ELSE COPY( value, entry( tValue ).value );  END;
		RETURN TRUE;
	END SetKeyValue;

	PROCEDURE GetKeyValue*( root: tSegment;  path, key: ARRAY OF CHAR;  VAR value: ARRAY OF CHAR ): BOOLEAN;
	VAR entry: tEntry;
	BEGIN
		entry := Find( root, path );
		IF (entry = NIL ) OR (~(entry IS tSegment)) THEN RETURN FALSE END;
		entry := FindNamedEntry( entry( tSegment ), key );
		IF (entry = NIL ) OR (~(entry IS tValue)) THEN RETURN FALSE END;
		COPY( entry( tValue ).value, value );
		RETURN TRUE;
	END GetKeyValue;

	PROCEDURE SetPathSeparator*( ch: CHAR );
	BEGIN
		PathSeparator := ch;
	END SetPathSeparator;

BEGIN
	EndOfLine := cr;  PathSeparator := ".";
END OberonConfiguration.

(*

	Assignemnts:
		name = values ... (EOL)
	or
		"name" = values. ... (EOL)

	An Assignment like
		mytest = { "gjhsgdfsdf" }

	makes mytest a SEGMENT, no value, i.e. in most cases DISABLES mytest
	except mytest is really meant to be a segment like in the following example

	Gadgets = {
		Defaults={
			...
			}
		}

	Configuration	=	White Segment eot
	Segment	=	{whitespace}	{[AssignHead] Subsection | [AssignHead] Entry}
	AssignHead	=	{char|String} {whitespace} "=" White
	Subsection 	= 	"{" SkipNL Segment "}" Nl
	Entry	=	{whitespace|char|String|equals} Nl	 (* may be empty = eol only *)
	White	=	{whitespace|Eol}
	Nl	=	{whitespace} Eol {whitespace}
	Eol 	=  	lf[cr]|cr[lf].
	String	=	'"' {char|controls} '"' | "'" {char|controls} "'"

	informal:
	lf	=	LF
	cr	=	CR
	char	=	letter | digit | symbol \ {controls}
	controls	=	"{","}","="
	whitespace 	=	tab|" "
*)
