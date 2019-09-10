MODULE antsPerfectS IN Oberon;   (** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)




IMPORT antsObjects, vyBase, antsCommands, antsKernel, antsMC, vyName, aM := antsMessages, antsArrayObjects,
	vyHostTexts, Objects, Gadgets, Files, Math := MathL IN A2;

TYPE

	tSamplingScheme = POINTER TO tSamplingSchemeDesc;
	tSamplingSchemeDesc = RECORD (vyBase.ObjDesc)
		c: antsMC.Chain;
		nrsamples: SIGNED32;
		maxnrsamples: SIGNED32;
		coalescence: BOOLEAN
	END;

	PROCEDURE Store0( o: tSamplingScheme;  VAR M: Objects.FileMsg );
	BEGIN
		Files.WriteInt( M.R, 0 );  Gadgets.WriteRef( M.R, o.lib, o.c );  Files.WriteLInt( M.R, o.maxnrsamples )
	END Store0;

	PROCEDURE Load0( o: tSamplingScheme;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;  version: SIGNED16;
	BEGIN
		Files.ReadInt( M.R, version );  Gadgets.ReadRef( M.R, o.lib, objsub );
		IF objsub # NIL THEN o.c := objsub( antsMC.Chain ) END;
		Files.ReadLInt( M.R, o.maxnrsamples )
	END Load0;

	PROCEDURE Copy*( VAR M: Objects.CopyMsg;  src, dest: tSamplingScheme );
	BEGIN
		vyBase.CopyObject( M, src, dest );
		(* (* never deepcopy data in a layer ! *)
	IF M.id = Objects.deep THEN
	ELSE
	END;
	*)
		dest.c := src.c

	END Copy;

	PROCEDURE Gen*;
	VAR s: tSamplingScheme;
	BEGIN
		aM.cmd;  NEW( s );  s.handle := Handler;  Objects.NewObj := s;  antsObjects.Register( s )
	END Gen;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR copy: tSamplingScheme;  uhandle: Objects.Handler;  gen: PROCEDURE;

	CONST GenProc = "antsPerfectS.Gen";   (* Gen Procedure as String *)
	BEGIN
		uhandle := vyBase.objecthandle;   (* handler of root object*)
		gen := Gen;   (* gen Procedure as PROCEDURE *)

		WITH o: tSamplingScheme DO
			IF M IS Objects.CopyMsg THEN
				WITH M: Objects.CopyMsg DO
					IF M.stamp = o.stamp THEN
						M.obj := o.dlink (* copy M arrives again *)
					ELSE
						gen;  copy := Objects.NewObj( tSamplingScheme );  M.obj := copy;   (* Generator  *)
						Copy( M, o, M.obj( tSamplingScheme ) ) (* do not call uhanlde, may result in new object of type "root" *)
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					uhandle( o, M );
					IF M.id = Objects.load THEN Load0( o, M )
					ELSIF M.id = Objects.store THEN Store0( o, M )
					END;
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Gen" );  M.Enum( "NrSamples" );  M.Enum( "MaxNrSamples" );  M.Enum( "coalescence" );  uhandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( GenProc, M.s );  M.class := Objects.String;  M.res := 0
						ELSIF M.name = "NrSamples" THEN M.class := Objects.Int;  M.i := o.nrsamples;  M.res := 0
						ELSIF M.name = "coalescence" THEN M.class := Objects.Bool;  M.b := o.coalescence;  M.res := 0
						ELSIF M.name = "MaxNrSamples" THEN M.class := Objects.Int;  M.i := o.maxnrsamples;  M.res := 0
						ELSE uhandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "MaxNrSamples" THEN
							IF M.class = Objects.Int THEN o.maxnrsamples := Power2( ENTIER( Math.ln( M.i ) / Math.ln( 2 ) + 0.5 ) );  M.res := 0 END
						ELSE uhandle( o, M )
						END
					ELSE uhandle( o, M )
					END
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					IF M.id = Objects.enum THEN M.Enum( "Chain" )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Chain" THEN M.obj := o.c;  M.res := 0 ELSE uhandle( o, M ) END
					ELSE uhandle( o, M )
					END

				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					uhandle( o, M )
					(* add own binds here: Bind(o.entry,M) *)
				END;
			ELSE uhandle( o, M )
			END
		END
	END Handler;

	PROCEDURE Compare( A1, A2: antsArrayObjects.tINTEGERObject ): BOOLEAN;
	VAR y, x: SIGNED32;
	BEGIN
		FOR y := 0 TO A1.h - 1 DO
			FOR x := 0 TO A1.w - 1 DO
				IF A1.A[y, x] # A2.A[y, x] THEN RETURN FALSE END
			END
		END;
		RETURN TRUE
	END Compare;

	PROCEDURE Power2( l: SIGNED32 ): SIGNED32;
	VAR t: SIGNED32;  p: SIGNED32;
	BEGIN
		p := 1;
		FOR t := 1 TO l DO p := p * 2 END;
		RETURN p
	END Power2;

	PROCEDURE DoRunScheme( S: tSamplingScheme );
	VAR a1, a2: antsArrayObjects.tINTEGERObject;  s1, s2: antsKernel.Kernel;  i: SIGNED32;  c: antsMC.Chain;  o1, o2: vyBase.Object;
	BEGIN
		vyHostTexts.Note( vyHostTexts.cNotify, "Running a backward sampling exponential scheme" );  c := S.c( antsMC.Chain );  o1 := c.getKernel( 0 );  o2 := c.getKernel( 1 );
		s1 := o1( antsKernel.Kernel );  s2 := o2( antsKernel.Kernel );  a1 := s1.A( antsArrayObjects.tINTEGERObject );
		a2 := s2.A( antsArrayObjects.tINTEGERObject );
		IF ((a1.w) # (a2.w)) OR ((a1.h) # (a2.h)) OR ((a1.depth) # (a2.depth)) THEN
			vyHostTexts.Note( vyHostTexts.cAlert, "antsPerfectS: Arrays do not coincide in size or depth" );  vyBase.Update( S );  RETURN
		END;
		c.init();  i := 0;
		WHILE (S.nrsamples < S.maxnrsamples) DO
			Gadgets.Update( S );  c.jumpTo( -Power2( i ) );  S.nrsamples := Power2( i );  c.toLast();
			IF Compare( a1, a2 ) THEN aM.S( "Coalescence reached" );  S.coalescence := TRUE;  Gadgets.Update( S );  RETURN END;
			INC( i )
		END;
		Gadgets.Update( S );  aM.S( "Coalescence not reached" )
	END DoRunScheme;

	PROCEDURE RunScheme*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  S: tSamplingScheme;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			S := obj( tSamplingScheme );  S.nrsamples := 0;  S.coalescence := FALSE;  DoRunScheme( S )
		END
	END RunScheme;

	PROCEDURE InitScheme*;
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  S: tSamplingScheme;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN
			S := obj( tSamplingScheme );  S.nrsamples := 0;  S.coalescence := FALSE;  vyBase.Update( S );
		END
	END InitScheme;

	PROCEDURE NewScheme*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  S: tSamplingScheme;  c: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name= NAME chain=OBJ" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) & antsCommands.ExpectObjectFromKeyword( l, "chain", c ) THEN
			Gen;  S := Objects.NewObj( tSamplingScheme );  S.c := c( antsMC.Chain );  S.maxnrsamples := 100;
			vyBase.Subscribe( S, c );  vyName.RegisterNamed( S, name )
		END
	END NewScheme;

BEGIN
	aM.launch;
END antsPerfectS.

(*
PROCEDURE RunSchemeFM*;
VAR l: antsCommands.tScanList;   p: antsCommands.tParameter;   name: vyName.tNameArray;   obj, model: vyBase.Object;
S: tSamplingScheme;   t: SIGNED32;
BEGIN
l := antsCommands.ScanFromPar();
IF antsCommands.ExpectObjectFromKeyword(l, "name", 1, obj) &
antsCommands.ExpectObjectFromKeyword(l, "model", 2, model) THEN
S := obj(tSamplingScheme);
IF (S(tSamplingScheme).s1.par # model) OR (S(tSamplingScheme).s2.par # model) THEN
antsKernel.DoAttachModel(S(tSamplingScheme).s1, model(antsKernel.tParameter));
antsKernel.DoAttachModel(S(tSamplingScheme).s2, model(antsKernel.tParameter))
END;
S.lastseed := 0;   S.currentseed := 0;   S.nrsamples := 0;   S.coalescence := FALSE;   	antsRandom.GetSeed(S.nextseed);
DoRunScheme(S)
END
END RunSchemeFM;

PROCEDURE AttachModel*;
VAR l: antsCommands.tScanList;   p: antsCommands.tParameter;   name: vyName.tNameArray;
model, PS: vyBase.Object;   copy: antsArrayObjects.tObject;
BEGIN
l := antsCommands.ScanFromPar();
IF antsCommands.ExpectObjectFromKeyword(l, "model", 2, model) &
antsCommands.ExpectObjectFromKeyword(l, "name", 1, PS) THEN
antsKernel.DoAttachModel(PS(tSamplingScheme).s1, model(antsKernel.tParameter));
antsKernel.DoAttachModel(PS(tSamplingScheme).s2, model(antsKernel.tParameter))
END
END AttachModel;

*)

antsPerfectS.NewScheme f4Scheme f4Chain ~
antsPerfectS.RunScheme f4Scheme ~
System.Free antsPerfectS ~