MODULE AnimationCodec; (** AUTHOR "staubesv"; PURPOSE "Codec for proprietary animation format"; *)

(*

	STATUS: APLHA, don't rely on (undocumented) animation description format

*)

IMPORT
	Streams, KernelLog, Strings, Files, Codecs, XML, XMLScanner, XMLParser, WMGraphics;

CONST
	Version = "ANI09a";

	HeaderMissing* = 20001;
	HeaderError* = 20002;
	WrongVersion* = 20003;
	FormatError* = 20004;
	ImageNotFound* = 20010;

	XmlHeader = "Header";
	XmlVersion = "version";
	XmlWidth = "width";
	XmlHeight = "height";
	XmlBackgroundColor = "bgcolor";
	XmlFrames = "Frames";
	XmlFrame = "Frame";
	XmlImageName = "image";
	XmlLeft = "x";
	XmlTop = "y";
	XmlDelayTime = "time";
	XmlDisposeMode = "mode";
	XmlFrom = "from";
	XmlTo = "to";

	Debug = TRUE;

TYPE

	Settings = RECORD
		x, y : LONGINT;
		time, mode : LONGINT;
	END;

TYPE

	Decoder* = OBJECT(Codecs.AnimationDecoder)
	VAR
		animation : XML.Element;
		width, height, bgcolor : LONGINT;
		default : Settings;
		error : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			animation := NIL;
			width := 0; height := 0; bgcolor := 0;
			RestoreDefaultSettings;
			error := FALSE;
		END Init;

		PROCEDURE RestoreDefaultSettings;
		BEGIN
			default.x := 0; default.y := 0; default.time := 20; default.mode := Codecs.Unspecified;
		END RestoreDefaultSettings;

		PROCEDURE ReportError(pos, line, col: Streams.Position; CONST msg: ARRAY OF CHAR);
		BEGIN
			error := TRUE;
		END ReportError;

		(* open the decoder on an InputStream *)
		PROCEDURE Open*(in : Streams.Reader; VAR res : WORD);
		VAR
			scanner : XMLScanner.Scanner; parser : XMLParser.Parser; document : XML.Document;
			content : XML.Content;

			PROCEDURE CheckHeader(header : XML.Element; VAR res : WORD);
			VAR name, version : Strings.String; ignore : BOOLEAN;
			BEGIN
				ASSERT(header # NIL);
				name := header.GetName();
				IF (name # NIL) & (name^ = XmlHeader) THEN
					version := header.GetAttributeValue(XmlVersion);
					IF (version # NIL) THEN
						IF (version^ = Version) THEN
							IF GetInteger(header, XmlWidth, width) & GetInteger(header, XmlHeight, height) & (width > 0) & (height > 0) THEN
								ignore := GetInteger(header, XmlBackgroundColor, bgcolor);
								res := Codecs.ResOk;
							ELSE
								res := HeaderError;
							END;
						ELSE
							res := WrongVersion;
						END;
					ELSE
						res := HeaderError;
					END;
				ELSE
					res := HeaderMissing;
				END;
			END CheckHeader;

		BEGIN
			ASSERT(in # NIL);
			NEW(scanner, in);
			NEW(parser, scanner);
			parser.reportError := ReportError;
			document := parser.Parse();
			IF ~error & (document # NIL) THEN
				animation := document.GetRoot();
				IF (animation # NIL) THEN
					content := animation.GetFirst();
					IF (content # NIL) & (content IS XML.Element) THEN
						CheckHeader(content(XML.Element), res);
						IF (res # Codecs.ResOk) THEN animation := NIL; END;
					ELSE
						res := Codecs.ResFailed;
					END;
				ELSE
					res := Codecs.ResFailed;
				END;
			ELSE
				animation := NIL;
				res := Codecs.ResFailed;
			END;
			IF Debug & (res # Codecs.ResOk) THEN
				KernelLog.String("AnimationCodec: Could not open animation, res = "); KernelLog.Int(res, 0); KernelLog.Ln;
			END;
		END Open;

		PROCEDURE ProcessFrame(frame : XML.Element; VAR desc : Codecs.ImageDescriptor; VAR res : WORD);
		VAR string, imageName : Strings.String; from, to, current : LONGINT; minDigits : SIZE; filename : Files.FileName; last, d : Codecs.ImageDescriptor;
		BEGIN
			NEW(desc);
			IF ~GetInteger(frame, XmlLeft, desc.left) THEN desc.left := default.x; END;
			IF ~GetInteger(frame, XmlTop, desc.top) THEN desc.top := default.y; END;
			IF ~GetInteger(frame, XmlDelayTime, desc.delayTime) THEN desc.delayTime := default.time; END;
			IF ~GetInteger(frame, XmlDisposeMode, desc.disposeMode) THEN desc.disposeMode := default.mode; END;
			IF ~GetInteger(frame, XmlFrom, from) THEN from := 0 END;
			IF ~GetInteger(frame, XmlTo, to) THEN to := 0; END;
			imageName := frame.GetAttributeValue(XmlImageName);
			IF (imageName # NIL) THEN
				IF (from = 0) & (to = 0) THEN
					desc.image := WMGraphics.LoadImage(imageName^, TRUE);
					IF (desc.image # NIL) THEN
						res := Codecs.ResOk;
					ELSE
						res := ImageNotFound;
					END;
				ELSE
					string := frame.GetAttributeValue(XmlFrom);
					IF (string # NIL) THEN
						Strings.TrimWS(string^);
						minDigits := Strings.Length(string^);
					ELSE
						minDigits := 0;
					END;

					last := NIL; d := desc;
					res := Codecs.ResOk;
					current := from;
					REPEAT
						GenerateFilename(imageName^, filename, current, minDigits);
						d.image := WMGraphics.LoadImage(filename, TRUE);
						IF (d.image = NIL) THEN
							res := ImageNotFound;
						END;
						IF (last = NIL) THEN
							last := d;
						ELSE
							d.previous := last;
							last.next := d;
							last := d;
						END;
						INC(current);
						IF (current <= to) THEN
							NEW(d);
							d.left := last.left; d.top := last.top; d.delayTime := last.delayTime; d.disposeMode := last.disposeMode;
						END;
					UNTIL (res # Codecs.ResOk) OR (current > to);
				END;
			ELSE
				res := FormatError;
			END;
		END ProcessFrame;

		PROCEDURE ProcessFrames(frames : XML.Element; VAR sequence : Codecs.ImageSequence; VAR res : WORD);
		VAR frame : XML.Content; name : Strings.String; desc, last : Codecs.ImageDescriptor; value : LONGINT;
		BEGIN
			ASSERT(frames # NIL);
			last := sequence.images;
			IF (last # NIL) THEN WHILE (last.next # NIL) DO last := last.next; END; END;
			RestoreDefaultSettings;
			IF GetInteger(frames, XmlLeft, value) THEN default.x := value; END;
			IF GetInteger(frames, XmlTop, value) THEN default.y := value; END;
			IF GetInteger(frames, XmlDelayTime, value) THEN default.time := value; END;
			IF GetInteger(frames, XmlDisposeMode,value) THEN default.mode := value; END;
			res := Codecs.ResOk;
			frame := frames.GetFirst();
			WHILE (res = Codecs.ResOk) & (frame # NIL) DO
				IF (frame IS XML.Element) THEN
					name := frame(XML.Element).GetName();
					IF (name # NIL) & (name^ = XmlFrame) THEN
						ProcessFrame(frame(XML.Element), desc, res);
						IF (res = Codecs.ResOk) THEN
							IF (last = NIL) THEN
								ASSERT(sequence.images = NIL);
								sequence.images := desc;
							ELSE
								desc.previous := last;
								last.next := desc;
							END;
							last := desc;
						ELSE
							sequence.images := NIL;
						END;
					END;
				END;
				frame := frames.GetNext(frame);
			END;
		END ProcessFrames;

		PROCEDURE GetImageSequence*(VAR sequence : Codecs.ImageSequence; VAR res : WORD);
		VAR content : XML.Content; frames : XML.Element; string : Strings.String;
		BEGIN
			IF (animation = NIL) THEN res := Codecs.ResFailed; RETURN; END;
			sequence.width := width; sequence.height := height; sequence.bgColor := bgcolor; sequence.images := NIL;
			res := Codecs.ResOk;
			content := animation.GetFirst();
			WHILE (res = Codecs.ResOk) & (content # NIL) DO
				IF (content IS XML.Element) THEN
					frames := content(XML.Element);
					string := frames.GetName();
					IF (string # NIL) & (string^ = XmlFrames) THEN
						ProcessFrames(frames, sequence, res);
						IF (res # Codecs.ResOk) THEN
							sequence.images := NIL;
						END;
					END;
				END;
				content := animation.GetNext(content);
			END;
			IF Debug & (res # Codecs.ResOk) THEN
				KernelLog.String("AnimationCodec: Could not decode image sequence, res = "); KernelLog.Int(res, 0); KernelLog.Ln;
			END;
		END GetImageSequence;

	END Decoder;

PROCEDURE GenerateFilename(CONST base : ARRAY OF CHAR; VAR filename : ARRAY OF CHAR; suffix, minDigits : SIZE);
VAR name, extension : Files.FileName; temp, digits : SIZE; nbr : ARRAY 32 OF CHAR;
BEGIN
	Files.SplitExtension(base, name, extension);
	COPY(name, filename);
	digits := 0; temp := suffix;
	REPEAT
		INC(digits); temp := temp DIV 10;
	UNTIL temp = 0;
	WHILE (digits < minDigits) DO Strings.Append(filename, "0"); INC(digits); END;
	Strings.IntToStr(suffix, nbr);
	Strings.Append(filename, nbr);
	Strings.Append(filename, ".");
	Strings.Append(filename, extension);
	KernelLog.String(filename); KernelLog.Ln;
END GenerateFilename;

PROCEDURE GetInteger(element : XML.Element; CONST attributeName : ARRAY OF CHAR; VAR value : LONGINT) : BOOLEAN;
VAR valueStr : Strings.String;
BEGIN
	ASSERT(element # NIL);
	value := 0;
	valueStr := element.GetAttributeValue(attributeName);
	IF (valueStr # NIL) THEN
		Strings.TrimWS(valueStr^);
		Strings.StrToInt(valueStr^, value);
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;
END GetInteger;

PROCEDURE GenDecoder*() : Codecs.AnimationDecoder;
VAR d : Decoder;
BEGIN
	NEW(d); RETURN d;
END GenDecoder;

END AnimationCodec.
