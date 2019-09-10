MODULE OberonFonts; (** AUTHOR "GF"; PURPOSE "Create Oberon fonts out of TrueType fonts" *)

IMPORT Strings, Files, S := SYSTEM, Log := KernelLog, Modules, TextUtilities,
		OTInt := OpenTypeInt, OType := OpenType, OpenTypeScan;

CONST
	ScreenDPI = 71;
	FontId = 0DBX;
	FontFont = 0X;

TYPE
	Name = ARRAY 32 OF CHAR;

	RasterData* = RECORD (OType.RasterData)
		adr*: ADDRESS;							(* base address of pattern *)
		bpr*: SIGNED32;							(* number of bytes per row *)
		len*: SIGNED32;							(* pattern length *)
	END;


	(* fill rectangle in pattern *)
	PROCEDURE FillRect( llx, lly, urx, ury, opacity: SIGNED16; VAR data: OType.RasterData0 );
		VAR x0, x1, h, n: SIGNED16;  adr, a: ADDRESS;  mask: SET;  byte: CHAR;
	BEGIN
		WITH data: RasterData DO
			x0 := llx DIV 8;  x1 := urx DIV 8;
			adr := data.adr + data.bpr * lly + x0;
			h := ury - lly;
			IF x0 = x1 THEN
				mask := {(llx MOD 8) .. ((urx-1) MOD 8)}
			ELSE
				mask := {(llx MOD 8) .. 7}
			END;
			n := h; a := adr;
			WHILE n > 0 DO
				ASSERT( (data.adr <= a) & (a < data.adr + data.len), 110 );
				S.GET( a, byte );
				S.PUT( a, CHR( SIGNED32(SET(ORD( byte )) + mask)) );
				DEC( n ); INC( a, data.bpr )
			END;
			IF x0 < x1 THEN
				INC( x0 ); INC( adr );
				WHILE x0 < x1 DO
					n := h;  a := adr;
					WHILE n > 0 DO
						ASSERT( (data.adr <= a) & (a < data.adr + data.len), 111 );
						S.PUT( a, 0FFX );
						DEC( n ); INC( a, data.bpr )
					END;
					INC( x0 ); INC( adr )
				END;
				IF 8*x1 # urx THEN
					mask := {0 .. (urx-1) MOD 8};
					n := h;  a := adr;
					WHILE n > 0 DO
						ASSERT( (data.adr <= a) & (a < data.adr + data.len), 112 );
						S.GET( a, byte );
						S.PUT( a, CHR( SIGNED32(SET(ORD( byte )) + mask)));
						DEC( n ); INC( a, data.bpr )
					END
				END
			END
		END
	END FillRect;

	PROCEDURE MakeFont( inst: OType.Instance;  glyph: OType.Glyph;  name: ARRAY OF CHAR ): Files.File;
		CONST
			mode = {OType.Hinted, OType.Width, OType.Raster};
		VAR
			file: Files.File;  font: OType.Font;  i, chars, ranges, xmin, ymin, xmax, ymax, j: SIGNED16;
			beg, end: ARRAY 64 OF SIGNED16;  data: RasterData;  no, bytes, k: SIGNED32;
			ras: OpenTypeScan.Rasterizer;
			w: Files.Writer;  ipos, apos: Files.Position;
			pattern: ARRAY 360*360 DIV 8 OF CHAR;				(* enough for 36 point at 720 dpi *)
	BEGIN
		file := Files.New( name );
		ASSERT(file # NIL);
		Files.OpenWriter( w, file, 0 );
		w.Char( FontId );																	(* Id *)
		w.Char( FontFont );																(* type (metric/font) *)
		w.Char( 0X );																		(* family *)
		w.Char( 0X );																		(* variant *)
		i := inst.font.hhea.ascender + inst.font.hhea.descender + inst.font.hhea.lineGap;
		w.RawInt( SHORT(OTInt.MulDiv( i, inst.yppm, 40H*LONG(inst.font.head.unitsPerEm) )) );	(* height *)

		w.RawInt( 0 ); w.RawInt( 0 ); w.RawInt( 0 ); w.RawInt( 0 );	(* fix later *) (* min/max X/Y *)

		font := inst.font;
		i := 0;  chars := 0;  ranges := 0;
		IF OType.UnicodeToGlyph( font, OType.CharToUnicode[1] ) = 0 THEN
			i := 2;  chars := 1;  beg[0] := 0;  end[0] := 1;  ranges := 1				(* make range for 0X *)
		END;
		REPEAT
			WHILE (i < 256) & (i # 9) & (OType.UnicodeToGlyph( font, OType.CharToUnicode[i] ) = 0) DO  INC( i )  END;
			IF i < 256 THEN
				beg[ranges] := i;  INC( i );  INC( chars );
				WHILE (i < 256) & (OType.UnicodeToGlyph( font, OType.CharToUnicode[i] ) # 0) DO  INC( i ); INC( chars )  END;
				end[ranges] := i;  INC( ranges )
			END
		UNTIL i = 256;
		w.RawInt( ranges);																(* number of runs *)
		i := 0;  WHILE i < ranges DO
			w.RawInt( beg[i] ); w.RawInt( end[i] );										(* start/end of run *)
			INC( i )
		END;

		ipos := w.Pos( );										(* open rider for later writing metrics *)
		i := 0;  WHILE i < chars DO
			w.RawInt( 0 ); w.RawInt( 0 ); w.RawInt( 0 ); w.RawInt( 0 ); w.RawInt( 0 );
			INC( i )
		END;

		xmin := MAX(SIGNED16); ymin := MAX(SIGNED16); xmax := MIN(SIGNED16); ymax := MIN(SIGNED16);
		i := 0;
		WHILE i < ranges DO
			j := beg[i];
			WHILE j < end[i] DO
				no := OType.UnicodeToGlyph( font, OType.CharToUnicode[j] );
				IF (j = 9) & (no = 0) THEN
					no := OType.UnicodeToGlyph( font, OType.CharToUnicode[ORD("I")] );
					OType.LoadGlyph( inst, glyph, ras, SHORT(no), {OType.Hinted, OType.Width} );
					glyph.awx := 8*glyph.awx;
					glyph.hbx := 0;  glyph.hby := 0;  glyph.rw := 0;  glyph.rh := 0
				ELSE
					OType.LoadGlyph( inst, glyph, ras, SHORT(no), mode )
				END;
				apos := w.Pos( );  w.SetPos( ipos );
				w.RawInt( glyph.awx );											(* advance *)
				w.RawInt( glyph.hbx );											(* horizontal bearing x *)
				w.RawInt( glyph.hby );											(* horizontal bearing y *)
				w.RawInt( glyph.rw );											(* image width *)
				w.RawInt( glyph.rh );												(* image height *)
				ipos := w.Pos( );  w.SetPos( apos );
				IF glyph.rw * glyph.rh # 0 THEN
					IF glyph.hbx < xmin THEN  xmin := glyph.hbx  END;
					IF glyph.hby < ymin THEN  ymin := glyph.hby  END;
					IF glyph.hbx + glyph.rw > xmax THEN  xmax := glyph.hbx + glyph.rw  END;
					IF glyph.hby + glyph.rh > ymax THEN  ymax := glyph.hby + glyph.rh  END;
					data.rect := FillRect;  data.adr := ADDRESSOF(pattern);
					data.bpr := (glyph.rw+7) DIV 8;  data.len := LEN(pattern);
					bytes := glyph.rh * data.bpr;
					ASSERT( bytes < LEN(pattern) );
					k := 0;  REPEAT  pattern[k] := 0X;  INC( k )  UNTIL k = bytes;
					OType.EnumRaster( ras, data );
					k := 0;  REPEAT  w.Char( pattern[k] ); INC( k )  UNTIL k = bytes			(* pattern *)
				END;
				INC( j )
			END;
			INC( i )
		END;

		w.SetPos( 6 );
		w.RawInt( xmin); w.RawInt( xmax);										(* minX/maxX *)
		w.RawInt( ymin); w.RawInt( ymax);										(* minY/maxY *)
		w.Update;
		RETURN file
	END MakeFont;



	PROCEDURE IsDigit( c: CHAR ): BOOLEAN;
	BEGIN
		RETURN (c >= '0') & (c <= '9')
	END IsDigit;

	PROCEDURE MakeTtfName( CONST oname: ARRAY OF CHAR; VAR ttfname: Name; VAR size, res: SIGNED16 );
	VAR i: SIGNED32; c: CHAR;
	BEGIN
		IF Strings.EndsWith( ".Scn.Fnt", oname ) THEN  res := ScreenDPI
		ELSIF Strings.EndsWith( ".Pr6.Fnt", oname ) THEN  res := 600
		ELSIF Strings.EndsWith( ".Pr3.Fnt", oname ) THEN  res := 300
		ELSIF Strings.EndsWith( ".Pr2.Fnt", oname ) THEN  res := 200
		ELSE  size := 0;  res := 0;  ttfname := "";  RETURN
		END;
		i := 0;
		REPEAT
			c := oname[i];  ttfname[i] := c;  INC( i )
		UNTIL IsDigit( c );
		ttfname[i-1] := 0X;
		size := 0;
		WHILE IsDigit( c ) DO
			size := 10*size + ORD( c ) - ORD( '0' );  c := oname[i];  INC( i )
		END;
		IF c = 'b' THEN  Strings.Append( ttfname, "_bd" )
		ELSIF c = 'i' THEN  Strings.Append( ttfname, "_i" )
		END;
		Strings.Append( ttfname, ".ttf" );
	END MakeTtfName;


	PROCEDURE ProvideFont*( CONST oname: ARRAY OF CHAR );
	VAR
		ttfname: Name;  size, res: SIGNED16;  f: Files.File;
		font: OType.Font;  inst: OType.Instance;  glyph: OType.Glyph;
	BEGIN
		f := Files.Old( oname );
		IF f # NIL THEN
			(* font already exists *) f.Close
		ELSE
			MakeTtfName( oname, ttfname, size, res );
			IF size > 0 THEN
				font := OType.Open( ttfname );
				IF font # NIL THEN
					NEW( glyph );
					OType.InitGlyph( glyph, font );
					OType.GetInstance( font, 40H*size, res, res, OType.Identity, inst );
					f := MakeFont( inst, glyph, oname );
					Files.Register( f );
					Log.String( "Created Oberon font " );  Log.String( oname );  Log.Ln
				END
			END
		END
	END ProvideFont;


	PROCEDURE Allocatable*( CONST oname: ARRAY OF CHAR ): BOOLEAN;
	VAR f: Files.File;  ttfname: Name;  size, res: SIGNED16;
	BEGIN
		f := Files.Old( oname );
		IF f # NIL THEN  RETURN TRUE
		ELSE
			MakeTtfName( oname, ttfname, size, res );
			f := Files.Old( ttfname );
			IF f # NIL THEN  RETURN TRUE  END;
			RETURN FALSE
		END
	END Allocatable;

	PROCEDURE Install*;
	END Install;

	PROCEDURE Finalize;
	BEGIN
		TextUtilities.oberonFontAllocatable := NIL
	END Finalize;


BEGIN
	TextUtilities.oberonFontAllocatable := Allocatable;
	Modules.InstallTermHandler( Finalize )
END OberonFonts.

