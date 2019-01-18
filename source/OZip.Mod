MODULE OZip; (** AUTHOR GF; PURPOSE "files and streams compression tool"; *)

IMPORT Streams, Commands, Files, Strings, BW :=  BorrowsWheeler, Huffman, Log := KernelLog;

(*
	Format	=	ComprTag { Block }
	Block		=	Index  Freqs  Code 
	Freqs		= 	num { freq } 			(num = 0,  (256 * freq))
				|	num { freq patt }		(num = 1..127)
	Code		=	size { CHAR }		(size in bits ! )
	num	=	CHAR			
	patt	=	CHAR
	freq	=	RawNum
	Index	=	RawNum
	size	=	RawNum
*)

CONST
	BlockSize = 8*1024;
	ComprTag = LONGINT(0FEFD1F2FH);
	Suffix = ".oz";
		

	PROCEDURE Compress*( r: Streams.Reader;  w: Streams.Writer );
	VAR 
		huff: Huffman.Encoder; 
		bw: BW.Encoder;  index: LONGINT; 
		buffer: ARRAY BlockSize OF CHAR;  len: LONGINT;
	BEGIN 
		NEW( huff, w );  NEW( bw );
		w.RawLInt( ComprTag );
		LOOP
			r.Bytes( buffer, 0, BlockSize, len );
			IF len < 1 THEN  EXIT  END;
			index := bw.EncodeBlock( buffer, len );
			w.RawNum( index );
			huff.CompressBlock( buffer, len );
			IF r IS Files.Reader THEN  Log.Char( '.' )  END
		END
	END Compress;
	
	
		
	PROCEDURE Uncompress*( r: Streams.Reader;  w: Streams.Writer;  VAR msg: ARRAY OF CHAR ): BOOLEAN;
	VAR 
		huff: Huffman.Decoder;
		tag, len, i, bwIndex: LONGINT; 
		bw: BW.Decoder;
		buffer: ARRAY BlockSize OF CHAR;
	BEGIN 
		r.RawLInt( tag );
		IF tag # ComprTag  THEN
			msg := "OZip.Uncompress: bad input (compressed stream expected)"; 
			RETURN FALSE
		END;
		NEW( huff, r );  NEW( bw );
		WHILE r.Available( ) > 0 DO	
			r.RawNum( bwIndex );
			huff.ExtractBlock( buffer, len );	
			bw.DecodeBlock( buffer, len, bwIndex );
			FOR i := 0 TO len - 1 DO  w.Char( buffer[i] )  END;
			IF w IS Files.Writer THEN  Log.Char( '.' )  END
		END;
		w.Update;
		RETURN TRUE
	END Uncompress;

	

	
	PROCEDURE NewFile( CONST name: ARRAY OF CHAR ): Files.File;
	VAR
		name2: ARRAY 128 OF CHAR;  res: LONGINT;
	BEGIN
		IF Files.Old( name ) # NIL THEN
			COPY( name, name2);  Strings.Append( name2, ".Bak" );
			Files.Rename( name, name2, res );
		END;
		RETURN Files.New( name )
	END NewFile;
	
	
	
	(** OZip.CompressFile  infile [outfile] ~ *)
	PROCEDURE CompressFile*( c: Commands.Context );
	VAR
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2: ARRAY 128 OF CHAR;
	BEGIN
		IF c.arg.GetString( name1 ) THEN
			IF ~c.arg.GetString( name2 ) THEN
				name2 := name1;  Strings.Append( name2, Suffix )
			END;
			f1 := Files.Old( name1 );
			IF f1 # NIL THEN
				Log.String( "OZip.Compress " ); Log.String( name1 ); Log.Char( ' ' );
				Files.OpenReader( r, f1, 0 ); 
				f2 := NewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				Compress( r, w );  w.Update;  Files.Register( f2 );
				Log.String( " => " );  Log.String( name2 );  Log.Ln; 
			ELSE
				c.error.String( "could not open file  " );  c.error.String( name1 );  c.error.Ln
			END
		ELSE
			c.error.String( "usage: OZip.CompressFile infile [outfile] ~ " );  c.error.Ln;
		END;
		c.error.Update
	END CompressFile;
	
	
	(** OZip.UncompressFile  infile [outfile] ~ *)
	PROCEDURE UncompressFile*( c: Commands.Context );
	VAR
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2, msg: ARRAY 128 OF CHAR;
	BEGIN
		IF c.arg.GetString( name1 ) THEN
			IF ~c.arg.GetString( name2 ) THEN
				name2 := name1;
				IF Strings.EndsWith( Suffix, name2 ) THEN  name2[Strings.Length( name2 ) - 3] := 0X
				ELSE  Strings.Append( name2, ".uncomp" )
				END
			END;
			f1 := Files.Old( name1 );
			IF f1 # NIL THEN
				Files.OpenReader( r, f1, 0 );	 
				f2 := NewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				Log.String( "OZip.Uncompress " );  Log.String( name1 );  Log.Char( ' ' );
				IF Uncompress( r, w, msg ) THEN
					w.Update;  Files.Register( f2 );
					Log.String( " => " );  Log.String( name2 );  Log.Ln; 
				ELSE
					c.error.String( msg );  c.error.Ln
				END
			ELSE
				c.error.String( "could not open file  " );  c.error.String( name1 );  c.error.Ln
			END
		ELSE
			c.error.String( "usage: OZip.UncompressFile infile [outfile] ~ " );  c.error.Ln;
		END;
		c.error.Update
	END UncompressFile;
	
END OZip.


	OZip.CompressFile   OZip.Mod ~
	OZip.CompressFile   OZip.GofU ~
	OZip.CompressFile   guide.pdf ~
		
	OZip.UncompressFile   OZip.Mod.oz  TTT.Mod ~
	OZip.UncompressFile   OZip.GofU.oz  TTT.GofU ~
	OZip.UncompressFile   guide.pdf.oz  TTT.pdf ~
	
	System.Free  OZip Huffman  BorrowsWheeler ~
