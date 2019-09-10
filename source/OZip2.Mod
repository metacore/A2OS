MODULE OZip2; (** AUTHOR GF; PURPOSE "files and streams compression tool"; *)

IMPORT Streams, Commands, Files, Strings,
	BW :=  BorrowsWheeler, AH := AdaptiveHuffman;

(*
	Format	=	ComprTag { Block }
	Block		=	size  bwindex  { CHAR }
	bwindex	=	RawNum
	size		=	RawNum
*)

CONST
	BlockSize* = 8*1024;
	ComprTag = SIGNED32(0FEFD1F18H);
	Suffix = ".oz2";


	PROCEDURE Compress*( r: Streams.Reader;  w: Streams.Writer );
	VAR
		huff: AH.Encoder;
		bw: BW.Encoder;
		buffer: ARRAY BlockSize OF CHAR;  len: SIZE;
	BEGIN
		NEW( huff, w );  NEW( bw );
		w.RawLInt( ComprTag );
		LOOP
			r.Bytes( buffer, 0, BlockSize, len );
			IF len = 0 THEN  EXIT  END;
			w.RawNum( len );
			w.RawNum( bw.EncodeBlock( buffer, len ) );
			huff.CompressBlock( buffer, len );
		END;
		w.RawNum( 0 );	(* mark end of stream *)
		w.Update
	END Compress;


	(* returns false if input is not an OZip2 compressed stream *)
	PROCEDURE Uncompress*( r: Streams.Reader;  w: Streams.Writer ): BOOLEAN;
	VAR
		huff: AH.Decoder;
		bw: BW.Decoder;
		tag, len, bwIndex: SIGNED32;
		buffer: ARRAY BlockSize OF CHAR;
	BEGIN
		r.RawLInt( tag );
		IF tag = ComprTag  THEN
			NEW( huff, r );  NEW( bw );
			LOOP
				r.RawNum( len );
				IF len = 0 THEN  EXIT  END;
				r.RawNum( bwIndex );
				huff.ExtractBlock( buffer, len );
				bw.DecodeBlock( buffer, len, bwIndex );
				w.Bytes( buffer, 0, len )
			END;
			w.Update;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END Uncompress;




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



	(** OZip2.CompressFile  infile [outfile] ~ *)
	PROCEDURE CompressFile*( c: Commands.Context );
	VAR
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2: ARRAY 128 OF CHAR;
	BEGIN
		IF c.arg.GetString( name1 ) THEN
			c.out.String( "OZip2.CompressFile " ); c.out.String( name1 );  c.out.Update;
			IF ~c.arg.GetString( name2 ) THEN
				name2 := name1;  Strings.Append( name2, Suffix )
			END;
			f1 := Files.Old( name1 );
			IF f1 # NIL THEN
				Files.OpenReader( r, f1, 0 );
				f2 := NewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				Compress( r, w );  Files.Register( f2 );
				c.out.String( " => " );  c.out.String( name2 );  c.out.Ln;  c.out.Update
			ELSE
				c.error.String( "  ### file not found" );  c.error.Ln
			END
		ELSE
			c.error.String( "usage: OZip2.CompressFile infile [outfile] ~ " );  c.error.Ln;
		END;
		c.error.Update
	END CompressFile;


	(** OZip2.UncompressFile  infile [outfile] ~ *)
	PROCEDURE UncompressFile*( c: Commands.Context );
	VAR
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2: ARRAY 128 OF CHAR;
	BEGIN
		IF c.arg.GetString( name1 ) THEN
			c.out.String( "OZip2.UncompressFile " );  c.out.String( name1 );  c.out.Update;
			IF ~c.arg.GetString( name2 ) THEN
				name2 := name1;
				IF Strings.EndsWith( Suffix, name2 ) THEN  name2[Strings.Length( name2 ) - 4] := 0X
				ELSE  Strings.Append( name2, ".uncomp" )
				END
			END;
			f1 := Files.Old( name1 );
			IF f1 # NIL THEN
				Files.OpenReader( r, f1, 0 );
				f2 := NewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				IF Uncompress( r, w ) THEN
					Files.Register( f2 );
					c.out.String( " => " );  c.out.String( name2 );  c.out.Ln;  c.out.Update
				ELSE
					c.error.String( "  ### wrong input (OZip2 compressed data expected)" );  c.error.Ln
				END
			ELSE
				c.error.String( "   ### file not found" );  c.error.Ln
			END
		ELSE
			c.error.String( "usage: OZip2.UncompressFile infile [outfile] ~ " );  c.error.Ln;
		END;
		c.error.Update
	END UncompressFile;

END OZip2.


	OZip2.CompressFile   TLS.Mod ~
	OZip2.CompressFile   OZip2.GofUu ~
	OZip2.CompressFile   guide.pdf ~

	OZip2.UncompressFile   TLS.Mod.oz2  TTT.Mod ~
	OZip2.UncompressFile   OZip2.GofUu.oz2  TTT.GofUu ~
	OZip2.UncompressFile   guide.pdf.oz2  TTT.pdf ~

	System.Free  OZip2 AdaptiveHuffman  BorrowsWheeler ~
