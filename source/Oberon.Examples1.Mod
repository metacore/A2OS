(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Examples1 IN Oberon; (* jm 24.2.93 File: Examples1.Mod*)

(*
	Version management/storing/loading example. This example illustrates how pointers are saved to and
	restored from disk, how objects can be given version numbers, how to bind objects to libraries, and
	how to copy objects correctly.
*)

IMPORT Gadgets, Objects, Files, Texts, Oberon;

CONST
	ModName = "Examples1"; VersionNo = 2;

TYPE
	Frame* = POINTER TO FrameDesc;
	FrameDesc* = RECORD (Gadgets.FrameDesc)
		x: SIGNED16;
		ptr0, ptr1: Gadgets.Frame; (* Two pointers to frames *)
	END;

VAR W: Texts.Writer;

(* Write a version number *)
PROCEDURE WriteVersion(VAR R: Files.Rider);
BEGIN Files.WriteNum(R, VersionNo);
END WriteVersion;

(* Check the version number *)
PROCEDURE ReadVersion(VAR R: Files.Rider);
VAR x: SIGNED32;
BEGIN Files.ReadNum(R, x);
	IF x # VersionNo THEN
		Texts.WriteString(W, "Version "); Texts.WriteInt(W, VersionNo, 3); Texts.WriteString(W, " of ");
		Texts.WriteString(W, ModName); Texts.WriteString(W, " cannot read version "); Texts.WriteInt(W, x, 3);
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
		HALT(99)
	END;
END ReadVersion;

PROCEDURE CopyFrame*(VAR M: Objects.CopyMsg; from, to: Frame);
VAR obj: Objects.Object;
BEGIN
	Gadgets.CopyFrame(M, from, to);
	to.x := from.x;

	(* Copy pointers *)
	obj := Gadgets.CopyPtr(M, from.ptr0); IF obj # NIL THEN to.ptr0 := obj(Gadgets.Frame) END;
	obj := Gadgets.CopyPtr(M, from.ptr1); IF obj # NIL THEN to.ptr1 := obj(Gadgets.Frame) END;
END CopyFrame;

PROCEDURE Handler*(obj: Objects.Object; VAR M: Objects.ObjMsg);
VAR obj0: Objects.Object; obj2: Frame;
BEGIN
	WITH obj: Frame DO
		IF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					WriteVersion(M.R);
					Files.WriteInt(M.R, obj.x);

					(* Write pointers *)
					Gadgets.WriteRef(M.R, obj.lib, obj.ptr0);
					Gadgets.WriteRef(M.R, obj.lib, obj.ptr1);
					Gadgets.framehandle(obj, M)
				ELSIF M.id = Objects.load THEN
					ReadVersion(M.R);
					Files.ReadInt(M.R, obj.x);

					(* Read pointers back, checking their type. Dummies are discarded *)
					Gadgets.ReadRef(M.R, obj.lib, obj0);
					IF (obj0 # NIL) & (obj0 IS Gadgets.Frame) THEN obj.ptr0 := obj0(Gadgets.Frame) END;

					Gadgets.ReadRef(M.R, obj.lib, obj0);
					IF (obj0 # NIL) & (obj0 IS Gadgets.Frame) THEN obj.ptr1 := obj0(Gadgets.Frame) END;
					Gadgets.framehandle(obj, M);
				END
			END
		ELSIF M IS Objects.BindMsg THEN
			WITH M: Objects.BindMsg DO
				(* Bind objects known by pointers *)
				IF obj.ptr0 # NIL THEN obj.ptr0.handle(obj.ptr0, M) END;
				IF obj.ptr1 # NIL THEN obj.ptr1.handle(obj.ptr1, M) END;
				Gadgets.framehandle(obj, M);
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = obj.stamp THEN
					M.obj := obj.dlink
				ELSE
					NEW(obj2); obj.stamp := M.stamp; obj.dlink := obj2; CopyFrame(M, obj, obj2); M.obj := obj2
				END
			END
		END
	END
END Handler;

END Examples1.