MODULE vyHostPrint IN Oberon;  	(** fof  **)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(*! implement PrintFocusPort, using the model from Desktops.PritnDoc. The implementation here does not work:
printer not selected correctly.
Final showpage command missing
*)
(* System.Free vyHostPrint* vyCG* *)
IMPORT vyParser, vyHostStrings, Files, vyHostTexts, PSPrinter,
	Attributes, Display, Objects, Documents, Printer, Texts, Oberon, vyPort, vyBase;
	VAR W: Texts.Writer;
	(* from Desktops *)
	(** Used in the form:
	Desktops.PrintDoc <printer-name> [ "/" options ] <list-of files> ~
	Desktops.PrintDoc <printer-name> [ "/" options ] *	(* Marked document *)
	Prints a document.
	*)
PROCEDURE DoPrintFocusPort;
	(*= vyPrint.PrintFocusPort x.EPS * *)
	(*= vyPrint.PrintFocusPort x.PS * *)

	VAR S: Attributes.Scanner;    printer, options: ARRAY 64 OF CHAR;
	port: vyPort.Frame;

PROCEDURE PrinterErr;
	VAR err: ARRAY 32 OF CHAR;
BEGIN
	IF Printer.res # 0 THEN
		IF Printer.res = 1 THEN err := " no connection"
		ELSIF Printer.res = 2 THEN err := " no link"
		ELSIF Printer.res = 3 THEN err := " printer not ready"
		ELSIF Printer.res = 4 THEN err := " no permission"END;
		Texts.WriteString(W, err);   Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
	END
END PrinterErr;

PROCEDURE printPort (port: vyPort.Frame);
	VAR P: Display.DisplayMsg;
BEGIN
	IF port # NIL THEN
		(*	Texts.WriteString(W, port.name); *)
		P.device := Display.printer;   P.id := Display.contents;   P.F := NIL;   P.x := 0;   P.y := 0;   P.dlink := NIL;
		port.handle(port, P);
		IF Printer.res # 0 THEN PrinterErr
		ELSE Texts.WriteString(W, " Ok")
		END
	ELSE Texts.WriteString(W, "[Voyager port not found]")
	END;
	Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
END printPort;


PROCEDURE OpenPrinter (name, options: ARRAY OF CHAR);
	VAR retries: SIGNED16;
BEGIN
	retries := 1;
	Printer.Open(name, options);
	WHILE (Printer.res > 0) & (Printer.res < 4 ) & (retries > 0) DO
		Texts.Write(W, "-");   vyHostTexts.AppendToLog(W);
		Printer.Open(name, options);   DEC(retries)
	END
END OpenPrinter;

BEGIN
	Texts.WriteString(W, "vyPrint.PrintFocusPort ");   vyHostTexts.AppendToLog(W);
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);
	IF (S.class = Attributes.Name) OR (S.class = Attributes.String) THEN (* printer name *)
		COPY(S.s, printer);   Attributes.Scan(S);
		IF (S.class = Attributes.Char) & (S.c = Oberon.OptionChar) THEN
			Attributes.Scan(S);
			IF (S.class # Texts.Name) & (S.class # Texts.String) THEN options := ""
			ELSE COPY(S.s, options)
			END;
			Attributes.Scan(S)
		ELSE options := ""
		END;
		Texts.WriteString(W, printer);   Texts.Write(W, " ");   vyHostTexts.AppendToLog(W);
		port := vyPort.GetFocus();
		IF port # NIL THEN
			OpenPrinter(printer, options);
			IF Printer.res = 0 THEN printPort(port);   Printer.Close
			ELSE 	PrinterErr


			END
		ELSE Texts.WriteString(W, 'no Voyager focus port found');   Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
		END
	ELSE Texts.WriteString(W, " unknown printer");   Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
	END
END DoPrintFocusPort;

PROCEDURE PrintFocusPort*;
	VAR printer: Printer.Printer;
BEGIN
	printer := Printer.current;
	PSPrinter.Install;
	DoPrintFocusPort;
	Printer.Install(printer)
END PrintFocusPort;

PROCEDURE PrintPic*;
	VAR S: Attributes.Scanner;   M: Display.SelectMsg;   obj: Objects.Object;
	D: Documents.Document;   printer, options: ARRAY 64 OF CHAR;

PROCEDURE PrinterErr;
	VAR err: ARRAY 32 OF CHAR;
BEGIN
	IF Printer.res # 0 THEN
		IF Printer.res = 1 THEN err := " no connection"
		ELSIF Printer.res = 2 THEN err := " no link"
		ELSIF Printer.res = 3 THEN err := " printer not ready"
		ELSIF Printer.res = 4 THEN err := " no permission"END;
		Texts.WriteString(W, err);   Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
	END
END PrinterErr;

PROCEDURE printDoc (doc: Documents.Document);
	VAR P: Display.DisplayMsg;
BEGIN
	IF doc # NIL THEN
		Texts.WriteString(W, doc.name);
		P.device := Display.printer;   P.id := Display.contents;   P.F := NIL;   P.x := 0;   P.y := 0;   P.dlink := NIL;
		doc.handle(doc, P);
		IF Printer.res # 0 THEN PrinterErr
		ELSE Texts.WriteString(W, " Ok")
		END
	ELSE Texts.WriteString(W, "[Document not found]")
	END;
	Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
END printDoc;

PROCEDURE PrintSelectedDocViewers;
BEGIN
	M.id := Display.get;   M.F := NIL;   M.sel := NIL;   M.obj := NIL;   M.time := 0;   Display.Broadcast(M);
	IF M.time > 0 THEN
		obj := M.obj;
		WHILE obj # NIL DO
			IF obj IS Documents.Document THEN
				printDoc(obj(Documents.Document))
			END;
			obj := obj.slink
		END
	ELSE Texts.WriteString(W, " [no selection]");   vyHostTexts.AppendToLog(W)
	END
END PrintSelectedDocViewers;

PROCEDURE OpenPrinter (name, options: ARRAY OF CHAR);
	VAR retries: SIGNED16;
BEGIN
	retries := 1;
	Printer.Open(name, options);
	WHILE (Printer.res > 0) & (Printer.res < 4 ) & (retries > 0) DO
		Texts.Write(W, "-");   vyHostTexts.AppendToLog(W);
		Printer.Open(name, options);   DEC(retries)
	END
END OpenPrinter;

BEGIN
	Texts.WriteString(W, "vyPrint.PrintPic ");   vyHostTexts.AppendToLog(W);
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);
	IF (S.class = Attributes.Name) OR (S.class = Attributes.String) THEN (* printer name *)
		COPY(S.s, printer);   Attributes.Scan(S);
		IF (S.class = Attributes.Char) & (S.c = Oberon.OptionChar) THEN
			Attributes.Scan(S);
			IF (S.class # Texts.Name) & (S.class # Texts.String) THEN options := ""
			ELSE COPY(S.s, options)
			END;
			Attributes.Scan(S)
		ELSE options := ""
		END;
		Texts.WriteString(W, printer);   Texts.Write(W, " ");   vyHostTexts.AppendToLog(W);
		IF (S.class = Attributes.Char) & (S.c = "*") THEN
			D := Documents.MarkedDoc();
			IF D # NIL THEN
				OpenPrinter(printer, options);
				IF Printer.res = 0 THEN printDoc(D);   Printer.Close
				ELSE PrinterErr
				END
			END
		ELSIF (S.class = Attributes.Char) & (S.c = "@") THEN (* Selection *)
			OpenPrinter(printer, options);
			IF Printer.res = 0 THEN PrintSelectedDocViewers;   Printer.Close
			ELSE PrinterErr
			END
		ELSE
			Printer.res := 0;
			WHILE (S.class = Attributes.Name) & (Printer.res = 0) DO
				D := Documents.Open(S.s);
				IF D # NIL THEN
					OpenPrinter(printer, options);
					IF Printer.res = 0 THEN printDoc(D);   Printer.Close ELSE PrinterErr END
				ELSE Texts.Write(W, 22X);   Texts.WriteString(W, S.s);   Texts.Write(W, 22X);   Texts.WriteString(W, " loading failed");
					Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
				END;
				Attributes.Scan(S)
			END
		END
	ELSE Texts.WriteString(W, " unknown printer");   Texts.WriteLn(W);   vyHostTexts.AppendToLog(W)
	END
END PrintPic;


PROCEDURE Print (suffix: ARRAY OF CHAR);
	VAR sc: vyParser.Scanner;   name, prefix: ARRAY 32 OF CHAR;  i, res: SIGNED16;  printer: Printer.Printer;
BEGIN
	printer := Printer.current;
	NEW(sc);  vyParser.OpenParScanner(sc);
	(*! implement vyParser.String (w/o name convention for voyager) *)
	IF (vyParser.Name(sc, name))  THEN
		vyHostStrings.Append(name, ".");
		vyHostStrings.Append(name, suffix)
	ELSE
		prefix := "PSFile.";
		i := 0;
		REPEAT
			INC(i);
			COPY(prefix, name);
			vyHostStrings.AppendInt(i, 0, name);
			vyHostStrings.Append(name, ".");
			vyHostStrings.Append(name, suffix)
		UNTIL (Files.Old(name) = NIL)
	END;
	vyHostTexts.NoteSS(vyHostTexts.cNotify, "Printing :", name);
	COPY(name, prefix);
	vyHostStrings.Append(name, " *");
	PSPrinter.Install;
	vyBase.CallWString("vyPrintPS", "Desktops.PrintDoc", name, FALSE, res);
	Printer.Install(printer)
END Print;

PROCEDURE PS*;
BEGIN
	Print("PS")
END PS;

PROCEDURE EPS*;
BEGIN
	Print("EPS")
END EPS;

PROCEDURE FocusPictToGIF*;
	VAR sc: vyParser.Scanner;   name, prefix, suffix: ARRAY 32 OF CHAR;    i: SIGNED16;     pict: vyPort.Picture;
	F: Files.File;  R: Files.Rider;
BEGIN
	COPY("GIF", suffix);
	NEW(sc);
	vyParser.OpenParScanner(sc);
	(*! implement vyParser.String (w/o name convention for voyager) *)
	IF (vyParser.Name(sc, name))  THEN
		vyHostStrings.Append(name, ".");
		vyHostStrings.Append(name, suffix)
	ELSE
		prefix := "vyPrintPict.";
		i := 0;
		REPEAT
			INC(i);
			COPY(prefix, name);
			vyHostStrings.AppendInt(i, 0, name);
			vyHostStrings.Append(name, ".");
			vyHostStrings.Append(name, suffix)
		UNTIL (Files.Old(name) = NIL)
	END;
	vyHostTexts.NoteSS(vyHostTexts.cNotify, "Store FocusPicture as GIF :", name);
	pict := vyPort.GetFocusPicture();
	IF pict = NIL THEN vyHostTexts.Note(vyHostTexts.cNotify, "No Focus Picture, cancelled.");  RETURN END;
	F := Files.New(name);
	Files.Set(R, F, 0);
	vyPort.StorePictAsGIF(pict, R);
	Files.Register(F);  Files.Close(F)
END FocusPictToGIF;

BEGIN
	Texts.OpenWriter(W);
END vyHostPrint.

System.Free vyPrint ~
vyPrint.PS ~
vyPrint.EPS ~
vyPrint.FocusPictToGIF ~
vyPrint.PS MyName ~ (* suffix PS automatically appended !! *)
vyPrint.EPS MyName ~(* suffix EPS automatically appended !! *)
vyPrint.FocusPictToGIF MyName ~(* suffix GIF automatically appended !! *)
