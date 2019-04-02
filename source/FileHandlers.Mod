MODULE FileHandlers;	(** AUTHOR "negelef"; PURPOSE "Open files according to file handlers"; *)

IMPORT
	Files, Configuration, Strings, Commands, Streams;

(** Opens the file path; corresponding file handlers are specified in Configuration.XML *)
PROCEDURE OpenFile* (CONST path : ARRAY OF CHAR; err: Streams.Writer; caller: OBJECT);
VAR config,filehandler: ARRAY 128 OF CHAR; name,filename, ext : Files.FileName; index: SIZE; res : WORD;
	context: Commands.Context; arg: Streams.StringReader; in: Streams.Reader; out: Streams.Writer;
BEGIN
	Files.SplitExtension(path, name, ext);
	index := Strings.Find (ext, 0, '@');
	IF index >= 0 THEN Strings.Truncate (ext, index); END;
	Strings.LowerCase(ext);
	config := "Filehandlers.";
	(* get the right handler *)
	Strings.Append(config, ext);
	Strings.Append(config, ".Open");
	Configuration.Get(config, filehandler, res);

	IF (res # Configuration.Ok) THEN
		IF err # NIL THEN err.String ("Opening '"); err.String (ext); err.String ("' files not specified in Configuration.XML."); err.Ln END;
		RETURN
	END;

	(* construct the context *)
	context := Commands.GetContext ();
	IF context = NIL THEN
		in := NIL; out := NIL
	ELSE
		in := context.in; out := context.out
	END;
	filename := '"';
	Strings.Append(filename,path);
	Strings.Append(filename,'"');
	IF index >= 0 THEN ext[index] := '@'; Strings.Move (ext, index, Strings.Length (ext) - index, ext, 0); Strings.Append (filename, ext); END;
	NEW (arg, LEN (filename)); arg.Set (filename);
	NEW (context, in, arg, out, err, caller);

	(* call the command *)
	Commands.Activate (filehandler, context, {}, res, name);
	IF res # Commands.Ok THEN
		IF err # NIL THEN err.String (name); err.Ln END
	END;
END OpenFile;

(* Open a file *)
PROCEDURE Open* (context: Commands.Context);
VAR path: ARRAY Files.NameLength OF CHAR;
BEGIN
	context.arg.Ln (path);
	Strings.TrimWS (path);
	OpenFile (path, context.error, context.caller);
END Open;

END FileHandlers.

System.Free FileHandlers ~

