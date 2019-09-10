MODULE Archives; (** AUTHOR "FN"; PURPOSE "Abstract Archive Object"; *)

IMPORT
	Configuration, Strings, Streams;

CONST
	ArchiveNameSize = 128;

TYPE
	StringObject*= OBJECT
	VAR value -: ARRAY 256 OF CHAR;

		PROCEDURE & Init*(CONST name : ARRAY OF CHAR);
		VAR i : SIZE;
		BEGIN
			FOR i := 0 TO LEN(name)-1 DO
				value[i] := name[i];
				IF name[i] = 0X THEN RETURN END
			END
		END Init;

	END StringObject;

	EntryInfo*= OBJECT

		PROCEDURE GetName*() : Strings.String;
		BEGIN HALT(301)
		END GetName;

		PROCEDURE GetSize*() : SIGNED32;
		BEGIN HALT(301)
		END GetSize;

		PROCEDURE GetInfoString*() : Strings.String;
		BEGIN HALT(301)
		END GetInfoString;

	END EntryInfo;

	Index* = POINTER TO ARRAY OF EntryInfo;

	Archive* = OBJECT
	VAR name *: ARRAY ArchiveNameSize OF CHAR;

		PROCEDURE Acquire*;
		BEGIN HALT(301)
		END Acquire;

		PROCEDURE Release*;
		BEGIN HALT(301)
		END Release;

		PROCEDURE GetIndex*() : Index;
		BEGIN HALT(301)
		END GetIndex;

		PROCEDURE GetEntryInfo*(CONST name : ARRAY OF CHAR) : EntryInfo;
		BEGIN HALT(301)
		END GetEntryInfo;

		PROCEDURE RemoveEntry*(CONST name : ARRAY OF CHAR);
		BEGIN HALT(301)
		END RemoveEntry;

		PROCEDURE RenameEntry*(CONST from, to : ARRAY OF CHAR) : EntryInfo;
		BEGIN HALT(301)
		END RenameEntry;

		PROCEDURE OpenSender*(CONST name : ARRAY OF CHAR) : Streams.Sender;
		BEGIN HALT(301)
		END OpenSender;

		PROCEDURE OpenReceiver*(CONST name : ARRAY OF CHAR) : Streams.Receiver;
		BEGIN HALT(301)
		END OpenReceiver;

		PROCEDURE Copy*(CONST name : ARRAY OF CHAR) : Archive;
		BEGIN HALT(301)
		END Copy;

	END Archive;

	FactoryProcedure = PROCEDURE (name : StringObject) : Archive;

	(* ----- api ----------------------------------------------------- *)

	PROCEDURE Old*(CONST name, type : ARRAY OF CHAR) : Archive;
	VAR
		old : FactoryProcedure;
		a : StringObject;
		archive : Archive;
		config, factoryName : ARRAY 128 OF CHAR;
		res : INTEGER;
	BEGIN
		archive := NIL;
		config := "Archives."; Strings.Append(config, type);
		Configuration.Get(config, factoryName, res);
		IF (res = Configuration.Ok) THEN
			GETPROCEDURE(factoryName, "Old", old);
			IF (old # NIL) THEN
				NEW(a, name);
				archive := old(a);
			END;
		END;
		RETURN archive;
	END Old;

	PROCEDURE New*(CONST name, type : ARRAY OF CHAR) : Archive;
	VAR
		new : FactoryProcedure;
		a : StringObject;
		archive : Archive;
		config, factoryName : ARRAY 128 OF CHAR;
		res : INTEGER;
	BEGIN
		archive := NIL;
		config := "Archives."; Strings.Append(config, type);
		Configuration.Get(config, factoryName, res);
		IF (res = Configuration.Ok) THEN
			GETPROCEDURE(factoryName, "New", new);
			IF (new # NIL) THEN
				NEW(a, name);
				archive := new(a);
			END;
		END;
		RETURN archive;
	END New;

END Archives.
