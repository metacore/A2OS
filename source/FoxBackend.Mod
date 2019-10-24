MODULE FoxBackend; (**  AUTHOR "kaeserm,fof"; PURPOSE "Oberon Compiler: Common backend module";  **)

IMPORT
	Streams, Diagnostics, Basic := FoxBasic, Global := FoxGlobal, BinaryCode := FoxBinaryCode,
	Formats := FoxFormats, SyntaxTree := FoxSyntaxTree, SemanticChecker := FoxSemanticChecker, Options, Strings;

TYPE
	SectionName = ARRAY 256 OF CHAR;
	SizeInBits* = SIZE;

	Backend* = OBJECT
	VAR
		diagnostics-: Diagnostics.Diagnostics;
		log-: Streams.Writer;
		flags*: SET;
		system-: Global.System;
		error-: BOOLEAN;
		checker-: SemanticChecker.Checker;
		source-: SyntaxTree.String;
		findSectionName-: SectionName;
		findSectionOffset-: SIGNED32;
		capabilities-: SET;
		oberon07-: BOOLEAN;
		hasLinkRegister-: BOOLEAN;
		name-: ARRAY 32 OF CHAR;

		codeUnit-: SizeInBits;

		(* constructor *)
		PROCEDURE & InitBackend *;
		BEGIN
			oberon07 := FALSE;
			system := NIL; (* only one instance per backend, never reallocate ! *)
			diagnostics := NIL;
			flags := {};
			error := FALSE;
			findSectionName := "";
			findSectionOffset := 0;
			hasLinkRegister := FALSE;
			codeUnit := -1;
		END InitBackend;

		PROCEDURE SetOberon07*;
		BEGIN
			(*
			ASSERT(system = NIL); (* assert that system Object has not been requested yet *)
			object may be reused!
			*)
			oberon07 := TRUE
		END SetOberon07;

		PROCEDURE SetCapabilities*(capabilities: SET);
		BEGIN
			SELF.capabilities := capabilities;
		END SetCapabilities;

		PROCEDURE SetHasLinkRegister*;
		BEGIN
			hasLinkRegister := TRUE;
		END SetHasLinkRegister;

		PROCEDURE SetCodeUnit* (unit: SizeInBits);
		BEGIN
			SELF.codeUnit := unit;
		END SetCodeUnit;

		PROCEDURE ResetError*;
		BEGIN error := FALSE
		END ResetError;

		(* initialize backend for usage *)
		PROCEDURE Initialize*(diagnostics: Diagnostics.Diagnostics; log: Streams.Writer; flags: SET; checker: SemanticChecker.Checker; system: Global.System);
		BEGIN
			error := FALSE;
			SELF.diagnostics := diagnostics;
			SELF.log := log;
			SELF.flags := flags;
			SELF.checker := checker;
			SELF.system := system;
		END Initialize;

		PROCEDURE SetName*(CONST name: ARRAY OF CHAR);
		BEGIN
			COPY(name, SELF.name);
		END SetName;

		(* Get the system used by this backend (singleton) *)
		PROCEDURE GetSystem*():Global.System;
		BEGIN
			RETURN Global.DefaultSystem();
		END GetSystem;

		PROCEDURE Error*(CONST source: ARRAY OF CHAR; position: Basic.Position; errorNumber: SIGNED32; CONST err: ARRAY OF CHAR);
		BEGIN
			IF (errorNumber # Basic.InvalidCode) OR (err # "") THEN
				Basic.ErrorC(diagnostics, source, position, errorNumber, err);
			END;
			error := TRUE;
		END Error;

		PROCEDURE ProcessSyntaxTreeModule*(syntaxTreeModule: SyntaxTree.Module): Formats.GeneratedModule;
		BEGIN RETURN NIL
		END ProcessSyntaxTreeModule;

		PROCEDURE ProcessIntermediateCodeModule*(intermediateCodeModule: Formats.GeneratedModule): Formats.GeneratedModule;
		BEGIN RETURN NIL (* only applicable for backends that use an intermediate backend *)
		END ProcessIntermediateCodeModule;

		(* general emision for chained backends -- used for active cells specification emission *)
		PROCEDURE Emit*(backend: Backend): BOOLEAN;
		BEGIN RETURN FALSE
		END Emit;

		PROCEDURE FindPC*(x: SyntaxTree.Module; CONST sectionName: ARRAY OF CHAR; sectionOffset: SIGNED32);
		BEGIN
		END FindPC;

		(* code address check method to patch code addresses if in forbidden range (Spartan6!) *)
		PROCEDURE CheckCodeAddress*(VAR adr: BinaryCode.Unit) ;
		BEGIN
		END CheckCodeAddress;

		(* method to query the instruction set description *)
		PROCEDURE GetDescription*(VAR instructionSet: ARRAY OF CHAR);
		BEGIN instructionSet := "undefined";
		END GetDescription;

		PROCEDURE CanPassInRegister*(type: SyntaxTree.Type): BOOLEAN;
		BEGIN RETURN FALSE
		END CanPassInRegister;

		PROCEDURE DefineOptions*(options: Options.Options);
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		END GetOptions;

		PROCEDURE DefaultObjectFileFormat*(): Formats.ObjectFileFormat;
		BEGIN RETURN NIL
		END DefaultObjectFileFormat;

		PROCEDURE DefaultSymbolFileFormat*(): Formats.SymbolFileFormat;
		BEGIN RETURN NIL
		END DefaultSymbolFileFormat;

	END Backend;

	PROCEDURE GetDummy*():Backend;
	VAR backend: Backend;
	BEGIN
		NEW(backend);
		RETURN backend;
	END GetDummy;

	PROCEDURE GetBackendByName*(CONST name: ARRAY OF CHAR): Backend;
	VAR
		procname: ARRAY 256 OF CHAR;
		factory: PROCEDURE (): Backend;
		backend: Backend;
	BEGIN
		backend := NIL;
		IF Strings.Length(name) > 0 THEN
			GETPROCEDURE(name,"Get", factory); (* try long name for example -G=OCERABackend *)

			IF factory = NIL THEN (* try short name for example -G=ERA*)
				procname := "Fox";
				Strings.Append(procname, name);
				Strings.Append(procname, "Backend");
				GETPROCEDURE(procname,"Get", factory);
			END;

			IF factory # NIL THEN
				backend := factory();
				Assert(backend # NIL,"backend factory returned NIL backend");
			END;
		END;
		RETURN backend
	END GetBackendByName;

	PROCEDURE Assert(b: BOOLEAN; CONST reason: ARRAY OF CHAR);
	BEGIN
		ASSERT(b);
	END Assert;

END FoxBackend.
