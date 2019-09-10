(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Modules IN Oberon;
(** AUTHOR "pjm"; PURPOSE "Oberon for Aos module loader"; *)

IMPORT Modules IN A2;

TYPE
	Command* = PROCEDURE;
	Module* = Modules.Module;
	ModuleName* = Modules.Name;

VAR
	res*: SIGNED16;
	resMsg*: ARRAY 256 OF CHAR;
	extension*: ARRAY 8 OF CHAR;

PROCEDURE CreateContext (VAR context: ARRAY OF CHAR; CONST name: ARRAY OF CHAR);
VAR i: SIGNED16;
BEGIN
	context := "Oberon-"; i := 0;
	WHILE name[i] # 0X DO context[i + 7] := name[i]; INC (i) END;
	context[i + 7] := 0X;
END CreateContext;

PROCEDURE FindMod*(CONST name: ARRAY OF CHAR): Module;
VAR context: ARRAY 64 OF CHAR;
BEGIN
	CreateContext (context, name);
	RETURN Modules.ModuleByName(context);
END FindMod;

PROCEDURE ThisMod*(CONST name: ARRAY OF CHAR): Module;
VAR context: ARRAY 64 OF CHAR; m: Module;  r: SIGNED32;
BEGIN
	CreateContext (context, name);
	m := Modules.ThisModule(context, r, resMsg);
	res := SHORT(r);
	(*Kernel.modules := Modules.root;*)
	RETURN m
END ThisMod;

PROCEDURE ThisCommand*(mod: Module; CONST name: ARRAY OF CHAR): Command;
VAR c: Command;
BEGIN
	GETPROCEDURE (mod.name, name, c);
	IF c = NIL THEN
		COPY(mod.name, resMsg);  Modules.Append(".", resMsg);  Modules.Append(name, resMsg);
		Modules.Append(" not found", resMsg);
		res := 5
	ELSE
		res := 0;  resMsg := ""
	END;
	RETURN c
END ThisCommand;

PROCEDURE Free*(CONST name: ARRAY OF CHAR; all: BOOLEAN);
VAR context: ARRAY 64 OF CHAR; r: SIGNED32;
BEGIN
	ASSERT(~all);	(* not implemented *)
	CreateContext (context, name);
	Modules.FreeModule(context, r, resMsg);
	res := SHORT(r)
END Free;

PROCEDURE InstallTermHandler*(h: Modules.TerminationHandler);
BEGIN
	Modules.InstallTermHandler(h)
END InstallTermHandler;

BEGIN
	COPY(Modules.extension[0], extension)	(* hack for Compiler to recognize Aos *)
END Modules.

(*
26.05.98	pjm	Started
*)
