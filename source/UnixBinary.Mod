MODULE UnixBinary;  (** AUTHOR "GF"; PURPOSE "build Unix programs"; *)

(* Build Unix programs by joining the loader and statically linked Oberon programs *)

IMPORT Files, Commands, Streams, Strings;

CONST 
	LoaderFilename = "OberonLoader";
	StartPos = 16*1024;	(* cf. OberonLoader.c *)

	
	PROCEDURE NewFile( CONST name: ARRAY OF CHAR; log: Streams.Writer ): Files.File;
	VAR
		name2: ARRAY 128 OF CHAR;  res: WORD;
	BEGIN
		IF Files.Old( name ) # NIL THEN
			COPY( name, name2);  Strings.Append( name2, ".Bak" );
			Files.Rename( name, name2, res );
			log.String( "Backup created in " ); log.String( name2 );  log.Ln
		END;
		RETURN Files.New( name )
	END NewFile;
	
	PROCEDURE Open( CONST name: ARRAY OF CHAR; log: Streams.Writer ): Files.File;
	VAR f: Files.File;
	BEGIN
		f := Files.Old( name );
		IF f = NIL THEN
			log.String( name );  log.String( " not found" ); log.Ln;
			log.Update;
		END;
		RETURN f
	END Open;
	
	PROCEDURE Build*( cc: Commands.Context );
	VAR in1, in2, out: Files.File;  r: Files.Reader; w: Files.Writer;
		inputname, token, outputname: ARRAY 64 OF CHAR;
		size, i: SIZE; c: CHAR;
	BEGIN
		IF 	cc.arg.GetString( inputname ) &
			cc.arg.GetString( token ) & (token = "->") &
			cc.arg.GetString( outputname ) THEN
			
				in1 := Open( LoaderFilename, cc.error );
				in2 := Open( inputname, cc.error );
				IF (in1 = NIL) OR (in2 = NIL) THEN  RETURN  END;
			
				size := in1.Length();  Files.OpenReader( r, in1, 0 );
				out := NewFile( outputname, cc.out );  Files.OpenWriter( w, out, 0 );
				
				FOR i := 1 TO size DO  r.Char( c ); w.Char( c )  END;
				
				FOR i := 1 TO StartPos - size DO  w.Char( '#' )  END;
				
				size := in2.Length();  Files.OpenReader( r, in2, 0 );
				FOR i := 1 TO size DO  r.Char( c ); w.Char( c )  END;
				
				w.Update;  Files.Register( out );
				cc.out.String( outputname );  cc.out.String( " created" ); cc.out.Ln;
		ELSE
			cc.error.String( "usage: UnixBinary.Build  StaticallyLinkedBinary  ->  Program ~" );  cc.error.Ln
		END;
		cc.error.Update;
		cc.out.Update
	END Build;

END UnixBinary.

   System.Free  UnixBinary ~
   
   UnixBinary.Build  oberon.bin -> A2Core ~
   
