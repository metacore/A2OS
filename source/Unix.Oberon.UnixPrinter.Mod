(* ETH Oberon, Copyright 2000 ETH Zürich Institut für Computersysteme, ETH Zentrum, CH-8092 Zürich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE UnixPrinter IN Oberon;   (* mad, 1997 *)

(*	2001.02.16	g.f.	Unix print commad selectable via Oberon.Text	*)

IMPORT Unix IN A2, S := SYSTEM, Files, Printer, PSPrinter, Texts, Oberon, Out;

TYPE
	UnixPrinter* = POINTER TO UnixPrinterDesc;
	UnixPrinterDesc* = RECORD (PSPrinter.PSPrinterDesc)
				printerName: ARRAY 32 OF CHAR
			END;
VAR
	prcmd, prsel: ARRAY 128 OF CHAR;

	PROCEDURE Append( VAR s1: ARRAY OF CHAR;  s2: ARRAY OF CHAR );
	VAR i, j: SIGNED16;  ch: CHAR;
	BEGIN
		i := 0;  j := 0;
		WHILE s1[i] # 0X DO INC( i ) END;
		REPEAT ch := s2[j];  s1[i] := ch;  INC( i );  INC( j ) UNTIL ch = 0X
	END Append;

	PROCEDURE Open*( P: Printer.Printer;  printer, options: ARRAY OF CHAR );
	BEGIN
		WITH P: UnixPrinter DO PSPrinter.Open( P, printer, options );  COPY( printer, P.printerName );
		END
	END Open;

	PROCEDURE Close*( P: Printer.Printer );
	VAR cmd, name: ARRAY 256 OF CHAR;
		res: SIGNED16;
	BEGIN
		WITH P: UnixPrinter DO
			COPY( P.printerName, name );  COPY( prcmd, cmd );
			IF (name # "") & (name # "Default") & (name # "DefaultPrinter") THEN
				Append( cmd, prsel );  Append( cmd, name );  Append( cmd, " " );
			END;
			Append( cmd, name );
			PSPrinter.Close( P );
			IF name # "none" THEN Unix.system( ADDRESSOF( cmd ) );  Files.Delete( name, res )
			ELSE Files.Rename( name, "OberonPrintfile.ps", res )
			END
		END
	END Close;

	PROCEDURE NewPrinter*( ): Printer.Printer;
	VAR PS: Printer.Printer;  P: UnixPrinter;
	BEGIN
		PS := PSPrinter.NewPrinter();  NEW( P );

		WITH PS: PSPrinter.PSPrinter DO
			P.InitMetrics := PS.InitMetrics;  P.Escape := PS.Escape;  P.Page := PS.Page;  P.ReplConst := PS.ReplConst;
			P.ReplPattern := PS.ReplPattern;  P.Line := PS.Line;  P.Circle := PS.Circle;  P.Ellipse := PS.Ellipse;
			P.Spline := PS.Spline;  P.Picture := PS.Picture;  P.UseListFont := PS.UseListFont;  P.String := PS.String;
			P.ContString := PS.ContString;  P.UseColor := PS.UseColor;  P.GetMetric := PS.GetMetric
		END;

		P.name := "UnixPrinter.Install";  P.Open := Open;  P.Close := Close;  RETURN P
	END NewPrinter;

	PROCEDURE Install*;
	BEGIN
		Printer.Install( NewPrinter() )
	END Install;

	PROCEDURE Init;
	VAR S: Texts.Scanner;  i, j: SIGNED16;  c: CHAR;
		cmd: ARRAY 16 OF CHAR;
		W: Texts.Writer;
	BEGIN
		Oberon.OpenScanner( S, "Unix.PrintCommand" );
		IF S.class IN {Texts.Name, Texts.String} THEN
			COPY( S.s, prcmd );  i := 0;  j := 0;
			REPEAT
				c := prcmd[i];
				IF c = '/' THEN j := 0 ELSE cmd[j] := c;  INC( j ) END;
				INC( i )
			UNTIL c = 0X;
			i := 0;
			REPEAT
				c := cmd[i];
				IF c = ' ' THEN  cmd[i] := 0X;  c := 0X END;
				INC( i )
			UNTIL c = 0X;
			IF cmd = "lp" THEN prsel := " -d "
			ELSIF cmd = "lpr" THEN prsel := " -P"
			ELSE
				Texts.OpenWriter( W ); Texts.SetColor( W, 1 );
				Texts.WriteString( W, "UnixPrinter.Init: don't know how to handle printer selection with " );
				Texts.WriteString( W, prcmd );
				Texts.SetColor( W, 15 );
				Texts.WriteLn( W ); Texts.Append( Oberon.Log, W.buf );
				prsel := ""
			END
		ELSE prcmd := "lpr";  prsel := " -P"
		END
	END Init;

BEGIN
	Init
END UnixPrinter.