(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Configuration; (** AUTHOR "pjm"; PURPOSE "XML-based configuration"; *)

IMPORT KernelLog, Strings, Files, XMLObjects, XML, XMLScanner, XMLParser, Streams;

CONST
	Ok* = 0;
	ElementNotFound* = 10001;
	AttributeNotFound* = 10002;
	WrongType* = 10003;
	Error* = 10004;

	SavePrefix = "Save.";
	UserPrefix = "My";
	ConfigFile = "Configuration.XML";

	(* element and attribute names - must match DTD in ConfigFile *)
	Section = "Section"; Setting = "Setting";
	NameAttr = "name"; ValueAttr = "value";

VAR
	config*: XML.Document;	(** internalized config file *)
	system-: Configuration;

(** In the children of element "parent", find an element with name "type" and "NameAttr" attribute "name". *)
PROCEDURE GetNamedElement*(parent: XML.Element; CONST type, name: ARRAY OF CHAR): XML.Element;
VAR enum: XMLObjects.Enumerator; p: ANY; e: XML.Element; s: XML.String;
BEGIN
	enum := parent.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			e := p(XML.Element); s := e.GetName();
			IF (s # NIL) & (s^ = type) THEN	(* correct element name *)
				s := e.GetAttributeValue(NameAttr);
				IF (s # NIL) & (s^ = name) THEN	(* correct element name attribute *)
					RETURN e
				END
			END
		END
	END;
	RETURN NIL
END GetNamedElement;

TYPE

	Configuration* = OBJECT
		VAR config- := NIL: XML.Document;	(** internalized config file *)
		VAR origin, configName: Files.FileName;
		VAR error := FALSE: BOOLEAN;

		PROCEDURE &Open*(CONST name: Files.FileName);
		VAR f: Files.File; scanner: XMLScanner.Scanner; parser: XMLParser.Parser; r: Files.Reader;
		VAR fileName : Files.FileName;
		BEGIN
			configName := "";
			origin := name;
			config := NIL;
			error := FALSE;

			COPY(UserPrefix, fileName);	Strings.Append(fileName, name); (* user config *)
			f := Files.Old(fileName);
			IF f = NIL THEN (* default config *)
				COPY(name, fileName);
				f := Files.Old(fileName);
			END;

			IF f # NIL THEN
				configName := fileName;
				NEW(r, f, 0);
				NEW(scanner, r); NEW(parser, scanner);
				parser.reportError := TrapHandler;
				config := parser.Parse();
				IF error THEN
					COPY(SavePrefix, fileName);	Strings.Append(fileName, name);
					f := Files.Old(fileName);
					IF f # NIL THEN
						NEW(r, f, 0);
						NEW(scanner, r); NEW(parser, scanner);
						parser.reportError := TrapHandler;
						config := parser.Parse();
					END
				END
			END;
			IF f = NIL THEN
				KernelLog.String("Configuration file not found");
			END;
		END Open;

		PROCEDURE GetSection*(CONST key : ARRAY OF CHAR) : XML.Element;
		BEGIN {EXCLUSIVE}
			RETURN GetElementX(Section, key);
		END GetSection;

		PROCEDURE GetSetting*(CONST key : ARRAY OF CHAR) : XML.Element;
		BEGIN {EXCLUSIVE}
			RETURN GetElementX(Setting, key);
		END GetSetting;

		PROCEDURE GetElementX(CONST type, key : ARRAY OF CHAR) : XML.Element;
		VAR e : XML.Element; name : ARRAY 64 OF CHAR; i, j : SIGNED32;
		BEGIN
			IF (config # NIL) THEN
				i := 0; e := config.GetRoot();
				WHILE (e # NIL) DO
					j := 0; WHILE (key[i] # 0X) & (key[i] # ".") DO name[j] := key[i]; INC(i); INC(j) END;
					name[j] := 0X;
					IF key[i] = 0X THEN	(* look for setting *)
						e := GetNamedElement(e, type, name);
						IF e # NIL THEN	(* found *)
							RETURN e;
						END
					ELSE	(* look for section *)
						INC(i);	(* skip '.' *)
						e := GetNamedElement(e, Section, name);
					END;
				END;
			END;
			RETURN NIL;
		END GetElementX;

		(** 	Find the setting specified by the key, which is a path name through the sections to the setting, and return its value. *)
		PROCEDURE Get*(CONST key: ARRAY OF CHAR; VAR val: ARRAY OF CHAR; VAR res : INTEGER);
		VAR e: XML.Element; s: Strings.String; a: XML.Attribute;
		BEGIN {EXCLUSIVE}
			e := GetElementX(Setting, key);
			IF (e # NIL) THEN
				s := e.GetName();
				IF (s # NIL) & (s^ = Setting) THEN
					a := e.GetAttribute(ValueAttr);
					IF (a # NIL) THEN
						s := a.GetValue();
						IF (s # NIL) THEN
							IF (Strings.Length(s^) < LEN(val)) THEN
								COPY(s^, val);
								res := Ok;
							ELSE
								res := Error;
							END;
						ELSE
							res := Error;
						END
					ELSE
						res := AttributeNotFound;
					END;
				ELSE
					res := Error;
				END;
			ELSE
				res := ElementNotFound;
			END;
		END Get;

		PROCEDURE GetBoolean*(CONST key : ARRAY OF CHAR; VAR value : BOOLEAN; VAR res : INTEGER);
		VAR string : ARRAY 8 OF CHAR;
		BEGIN
			Get(key, string, res);
			IF (res = Ok) THEN
				Strings.UpperCase(string);
				Strings.TrimWS(string);
				IF (string = "TRUE") THEN value := TRUE;
				ELSIF (string = "FALSE") THEN value := FALSE;
				ELSE
					res := WrongType;
				END;
			END;
		END GetBoolean;

		PROCEDURE GetColor*(CONST key : ARRAY OF CHAR; VAR value : SIGNED32; VAR res : INTEGER);
		VAR string : ARRAY 16 OF CHAR; tempres : INTEGER;
		BEGIN
			Get(key, string, res);
			IF (res = Ok) THEN
				Strings.TrimWS(string);
				Strings.HexStrToInt(string, value, tempres);
				IF tempres # Strings.Ok THEN res := Error; END;
			END;
		END GetColor;

		PROCEDURE GetInteger*(CONST key : ARRAY OF CHAR; VAR value : SIGNED32; VAR res : INTEGER);
		VAR string : ARRAY 16 OF CHAR;
		BEGIN
			Get(key, string, res);
			IF (res = Ok) THEN
				Strings.TrimWS(string);
				Strings.StrToInt(string, value);
			END;
		END GetInteger;

		PROCEDURE GetInteger64*(CONST key : ARRAY OF CHAR; VAR value : SIGNED64; VAR res : INTEGER);
		VAR string : ARRAY 21 OF CHAR;
		BEGIN
			Get(key, string, res);
			IF (res = Ok) THEN
				Strings.TrimWS(string);
				Strings.StrToHInt(string, value);
			END;
		END GetInteger64;

		(** update (or insert if necessairy) the setting specified by the key. if the specified section/setting is not yet existing, it will be created *)
		PROCEDURE Put*(CONST key, val : ARRAY OF CHAR; VAR res : INTEGER);
		VAR e, child : XML.Element; i, j : SIGNED32; name : ARRAY 64 OF CHAR;
		BEGIN {EXCLUSIVE}
			res := Ok;
			IF config # NIL THEN
				i := 0; e := config.GetRoot();
				WHILE key[i] # 0X DO
					j := 0; WHILE (key[i] # 0X) & (key[i] # '.') DO name[j] := key[i]; INC(i); INC(j) END;
					name[j] := 0X;
					IF key[i] = '.' THEN (* section *)
						child := GetNamedElement(e, Section, name);
						IF child = NIL THEN (* create section *)
							NEW(child); e.AddContent(child);
							child.SetName(Section); child.SetAttributeValue("name", name)
						END;
						e := child; INC(i) (* skip '.' *)
					ELSE (* setting *)
						child := GetNamedElement(e, Setting, name);
						IF child = NIL THEN (* create setting *)
							NEW(child); e.AddContent(child);
							child.SetName(Setting); child.SetAttributeValue("name", name)
						END;
						child.SetAttributeValue("value", val)
					END
				END;
				WriteConfig();
			ELSE
				res := Error;
			END
		END Put;

		PROCEDURE PutBoolean*(CONST key : ARRAY OF CHAR; value : BOOLEAN; VAR res : INTEGER);
		BEGIN
			IF value THEN Put(key, "TRUE", res) ELSE Put(key, "FALSE", res); END;
		END PutBoolean;

		PROCEDURE PutColor*(CONST key : ARRAY OF CHAR; value : SIGNED32; VAR res : INTEGER);
		VAR string : ARRAY 9 OF CHAR;
		BEGIN
			Strings.IntToHexStr(value, 8, string);
			Put(key, string, res);
		END PutColor;

		PROCEDURE PutInteger*(CONST key : ARRAY OF CHAR; value : SIGNED64; VAR res : INTEGER);
		VAR string : ARRAY 21 OF CHAR;
		BEGIN
			Strings.IntToStr(value, string);
			Put(key, string, res);
		END PutInteger;

		PROCEDURE WriteConfig;
		VAR f : Files.File; out : Files.Writer;
		BEGIN
			IF config # NIL THEN
				f := Files.New(configName); (* user or default *)
				Files.OpenWriter(out, f, 0);
				config.Write(out, NIL, 0);
				out.Update();
				Files.Register(f)
			END
		END WriteConfig;

		PROCEDURE TrapHandler(pos, line, row: Streams.Position; CONST msg: ARRAY OF CHAR);
		BEGIN
			IF ~error THEN (* user or default configuration file *)
				KernelLog.String("Error in ");
				KernelLog.String(configName);
				KernelLog.String(" at position ");
				KernelLog.String("pos= "); KernelLog.Int(pos, 0); KernelLog.String(" line= "); KernelLog.Int(line, 0); KernelLog.String(" row= "); KernelLog.Int(row, 0);
				KernelLog.String(" switching to ");
				KernelLog.String(SavePrefix); KernelLog.String(origin);	KernelLog.String(" !"); KernelLog.Ln;
			ELSE
				KernelLog.String("Error in ");
				KernelLog.String(SavePrefix); KernelLog.String(origin); KernelLog.String(" giving up!"); KernelLog.Ln;
			END;
			error := TRUE; config := NIL;
		END TrapHandler;

	END Configuration;


PROCEDURE GetSection*(CONST key : ARRAY OF CHAR) : XML.Element;
BEGIN
	RETURN system.GetElementX(Section, key);
END GetSection;

PROCEDURE GetSetting*(CONST key : ARRAY OF CHAR) : XML.Element;
BEGIN
	RETURN system.GetElementX(Setting, key);
END GetSetting;


(** 	Find the setting specified by the key, which is a path name through the sections to the setting, and return its value. *)
PROCEDURE Get*(CONST key: ARRAY OF CHAR; VAR value: ARRAY OF CHAR; VAR res : INTEGER);
BEGIN
	system.Get(key, value, res);
END Get;

PROCEDURE GetBoolean*(CONST key : ARRAY OF CHAR; VAR value : BOOLEAN; VAR res : INTEGER);
BEGIN
	system.GetBoolean(key, value, res);
END GetBoolean;

PROCEDURE GetColor*(CONST key : ARRAY OF CHAR; VAR value : SIGNED32; VAR res : INTEGER);
BEGIN
	system.GetColor(key, value, res);
END GetColor;

PROCEDURE GetInteger*(CONST key : ARRAY OF CHAR; VAR value : SIGNED32; VAR res : INTEGER);
BEGIN
	system.GetInteger(key, value, res);
END GetInteger;

PROCEDURE GetInteger64*(CONST key : ARRAY OF CHAR; VAR value : SIGNED64; VAR res : INTEGER);
BEGIN
	system.GetInteger64(key, value, res);
END GetInteger64;

(** update (or insert if necessairy) the setting specified by the key. if the specified section/setting is not yet existing, it will be created *)
PROCEDURE Put*(CONST key, value : ARRAY OF CHAR; VAR res : INTEGER);
BEGIN
	system.Put(key, value, res);
END Put;

PROCEDURE PutBoolean*(CONST key : ARRAY OF CHAR; value : BOOLEAN; VAR res : INTEGER);
BEGIN
	system.PutBoolean(key, value, res);
END PutBoolean;

PROCEDURE PutColor*(CONST key : ARRAY OF CHAR; value : SIGNED32; VAR res : INTEGER);
BEGIN
	system.PutColor(key, value, res);
END PutColor;

PROCEDURE PutInteger*(CONST key : ARRAY OF CHAR; value : SIGNED64; VAR res : INTEGER);
BEGIN
	system.PutInteger(key, value, res);
END PutInteger;

(** Internalize the config file. *)
PROCEDURE Init*;
BEGIN {EXCLUSIVE}
	config := NIL;
	system := NEW Configuration(ConfigFile);
	config := system.config;
END Init;

BEGIN
	Init;
END Configuration.

System.Free Configuration ~

PET.Open Configuration.XML

