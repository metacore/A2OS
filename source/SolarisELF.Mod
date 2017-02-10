MODULE SolarisELF;

IMPORT Files, Commands, Streams, Strings;

CONST 
	HeaderPart = "A2Loader.elf";
	CorePart = "Solaris32G.core";
	Offset = 10*1024;

	
	PROCEDURE NewFile( CONST name: ARRAY OF CHAR; log: Streams.Writer ): Files.File;
	VAR
		name2: ARRAY 128 OF CHAR;  res: LONGINT;
	BEGIN
		IF Files.Old( name ) # NIL THEN
			COPY( name, name2);  Strings.Append( name2, ".Bak" );
			Files.Rename( name, name2, res );
			log.String( "Backup created in " ); log.String( name2 );  log.Ln
		END;
		RETURN Files.New( name )
	END NewFile;
	
	PROCEDURE Build*( cc: Commands.Context );
	VAR in1, in2, fout: Files.File;  r: Files.Reader; w: Files.Writer;
		outname: ARRAY 64 OF CHAR;
		size, i: SIZE; c: CHAR;
	BEGIN
		in1 := Files.Old( HeaderPart );
		IF in1 = NIL THEN
			cc.error.String( HeaderPart );  cc.error.String( " not found" ); cc.error.Ln;
			cc.error.Update;
			RETURN
		END;
		in2 := Files.Old( CorePart );
		IF in2 = NIL THEN
			cc.error.String( CorePart );  cc.error.String( " not found" ); cc.error.Ln;
			cc.error.Update;
			RETURN
		END;
		
		IF cc.arg.GetString( outname ) THEN
			size := in1.Length();  Files.OpenReader( r, in1, 0 );
			fout := NewFile( outname, cc.out );  Files.OpenWriter( w, fout, 0 );
			FOR i := 1 TO size DO
				r.Char( c ); w.Char( c )
			END;
			
			FOR i := 1 TO Offset - size DO  w.Char( '=' )  END;
			
			size := in2.Length();  Files.OpenReader( r, in2, 0 );
			FOR i := 1 TO size DO
				r.Char( c ); w.Char( c )
			END;
			
			w.Update;  Files.Register( fout );
			
			cc.out.String( outname );  cc.out.String( " created" ); cc.out.Ln;
		ELSE
			cc.error.String( "fileneme missing" );  cc.error.Ln
		END;
		cc.error.Update;
		cc.out.Update
	END Build;

END SolarisELF.

   SystemTools.Free  SolarisELF ~
   
   SolarisELF.Build  Solaris32G.elf ~
   
