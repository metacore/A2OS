MODULE OZip3; (** AUTHOR GF; PURPOSE "file compression tool"; *)

IMPORT Commands, Files, Strings, BWHCompressor;

CONST
	ComprTag = SIGNED32(0FEFD3F39H);
	Suffix = ".oz3";


	PROCEDURE NewFile( CONST name: ARRAY OF CHAR ): Files.File;
	VAR
		tname, name2: ARRAY 128 OF CHAR;  res: SIGNED32;
	BEGIN
		tname := "./";
		Strings.Append( tname, name );
		IF Files.Old( tname ) # NIL THEN
			COPY( name, name2);  Strings.Append( name2, ".Bak" );
			Files.Rename( name, name2, res );
		END;
		RETURN Files.New( name )
	END NewFile;
	
	PROCEDURE Error( c: Commands.Context; CONST msg: ARRAY OF CHAR );
	BEGIN
		c.out.Update;
		c.error.String( msg ); c.error.Ln; c.error.Update
	END Error;
	


	(** OZip3.Compress  infile [outfile] ~ *)
	PROCEDURE Compress*( c: Commands.Context );
	VAR
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2: ARRAY 128 OF CHAR;
	BEGIN
		IF c.arg.GetString( name1 ) THEN
			c.out.String( "OZip3.Compress " ); c.out.String( name1 );  c.out.Update;
			IF ~c.arg.GetString( name2 ) THEN
				name2 := name1;  Strings.Append( name2, Suffix )
			END;
			f1 := Files.Old( name1 );
			IF f1 # NIL THEN
				f2 := Files.New( name2 ); 
				Files.OpenReader( r, f1, 0 );  Files.OpenWriter( w, f2, 0 );
				w.RawLInt( ComprTag );
				BWHCompressor.Compress( r, w );  Files.Register( f2 );
				c.out.String( " => " );  c.out.String( name2 );  c.out.Ln;  c.out.Update
			ELSE
				Error(  c, "  ### file not found" )
			END
		ELSE
			Error( c, "usage: OZip3.Compress infile [outfile] ~ " )
		END;
	END Compress;


	(** OZip3.Expand  infile [outfile] ~ *)
	PROCEDURE Expand*( c: Commands.Context );
	VAR
		f1, f2: Files.File;  tag: SIGNED32;
		r: Files.Reader;  w: Files.Writer;
		name1, name2: ARRAY 128 OF CHAR;
	BEGIN
		IF c.arg.GetString( name1 ) THEN
			c.out.String( "OZip3.Expand " );  c.out.String( name1 );  c.out.Update;
			IF ~c.arg.GetString( name2 ) THEN
				name2 := name1;
				IF Strings.EndsWith( Suffix, name2 ) THEN  
					name2[Strings.Length( name2 ) - 4] := 0X; 
				ELSE  
					Strings.Append( name2, ".uncompr" )
				END
			END;
			f1 := Files.Old( name1 );
			IF f1 # NIL THEN
				Files.OpenReader( r, f1, 0 );
				r.RawLInt( tag );
				IF tag # ComprTag THEN
					Error( c, "   ### input file not OZip3 compressed" )
				ELSE
					f2 := NewFile( name2 );  Files.OpenWriter( w, f2, 0 );
					BWHCompressor.Expand( r, w );
					Files.Register( f2 );
					c.out.String( " => " );  c.out.String( name2 );  c.out.Ln;  c.out.Update
				END
			ELSE
				Error( c, "   ### file not found" )
			END
		ELSE
			Error( c, "usage: OZip3.Expand infile [outfile] ~ " )
		END;
	END Expand;

END OZip3.


	OZip3.Compress   TLS.Mod ~
	OZip3.Compress   OZip3.Mod ~
	OZip3.Compress   guide.pdf ~

	OZip3.Expand   TLS.Mod.oz3  ~
	OZip3.Expand   OZip3.Mod.oz3  ~
	OZip3.Expand   guide.pdf.oz3  nguide.pdf ~

	System.Free  OZip3 BWHCompressor BitStreams MoveToFront ~
	
	
