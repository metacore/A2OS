MODULE antsKernel IN Oberon;   (** fof  **)
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



(*= basic definition and handler mechanism of a gibbs sampler on antsPictArray.tArrayObj. Intended for scheduled gibbs sampling.
for implementing a gibbs sampler you only have to define your one-step and init procedures, see below.
*)
IMPORT antsObjects, vyBase, antsArrayObjects, antsCommands, MathL IN A2, Objects, Files, Gadgets, vyName, antsMC,
	vyHostStrings, aM := antsMessages, vyLinks, Links, vyRanBase;

CONST
	ModelActive* = 10;  ModelSelected* = 9;

TYPE
	Msg* = antsMC.Msg;  Init* = antsMC.InitMsg;

	samplingMsg* = RECORD (Msg)
	(* cacheSize*: LONGINT;  (* move that to kernel, editable (change on exchange of definition) *)  *)
		action*: vyName.tNameArray
	END;

	(*
	Init*= antsMC.InitMsg;

	gibbs*=RECORD(samplingMsg) END;
	metropolis*=RECORD(samplingMsg)  END;


	annealing*= RECORD(gibbs); (* temp*: LONGREAL *) END;
	metropolisanneal*= RECORD(metropolis); (*  temp*: LONGREAL *) END;
	*)



	Kernel* = POINTER TO KernelDesc;
	temperatureScheme* = PROCEDURE ( k: Kernel;  pos: LONGINT );
	visitingScheme* = PROCEDURE ( x, w: LONGINT ): LONGINT;

	KernelDesc* = RECORD (vyBase.ObjDesc)
		A*: vyBase.Object;
		initwithorig-: BOOLEAN;
		(* Aorig*: vyBase.Object; realized as Link on A *)
		par-: vyBase.Object;
		visit-: visitingScheme;
		parallel-: BOOLEAN;
		ModelClass*: vyLinks.Link;
		ModelClassCount*: INTEGER;
		makeTemperature*: temperatureScheme;
		cacheSize*: LONGINT;
		temperature*: LONGREAL;
		samplerType*: vyName.tNameArray
	END;

VAR
	constScheme*, loganneal, expanneal, linanneal: temperatureScheme;

	(*
	,metropolisd,logmetranneal,expmetranneal,linmetranneal:  temperatureScheme; *)


	linearv, chequerboardv, randomv: visitingScheme;

CONST
	staticCacheSize = 1000000;  dynamicCacheSize = 10000;  gibbsSampler* = "gibbsSampler";  metropolisSampler* = "metropolisSampler";
	exchangeAlgorithm* = "exchangeAlgorithm";

	PROCEDURE linearVisit*( x, w: LONGINT ): LONGINT;
	BEGIN
		RETURN x
	END linearVisit;

	PROCEDURE checkerBoardVisit*( x, w: LONGINT ): LONGINT;
	VAR y: LONGINT;
	BEGIN
		y := 2 * x;
		IF y >= w THEN RETURN (y + 1 - w) ELSE RETURN y END
	END checkerBoardVisit;

	PROCEDURE randomVisit*( x, w: LONGINT ): LONGINT;
	BEGIN
		RETURN vyRanBase.RandomGenerator.GetRandomL( vyRanBase.RandomGenerator, w )
	END randomVisit;

	PROCEDURE MMCopy( VAR from, to: antsMC.Msg );
	BEGIN
		to.pos := from.pos;  to.gen := from.gen;  to.error := from.error;  to.errormsg := from.errormsg
	END MMCopy;

	PROCEDURE Prepare( s: Kernel;  VAR omsg: antsMC.Msg;  VAR msg: samplingMsg );
	BEGIN
		MMCopy( omsg, msg );  msg.dlink := s;  msg.action := s.samplerType;  s.makeTemperature( s, omsg.pos );
		msg.temp := s.temperature;
		(* s.cacheSize := noCacheSize; *)  (* msg.visit := s.visit; msg.parallel := s.parallel; *)

	END Prepare;

	PROCEDURE Finish( s: Kernel;  VAR omsg: antsMC.Msg;  VAR msg: samplingMsg );
	BEGIN
		omsg.error := msg.error;  omsg.errormsg := msg.errormsg
	END Finish;

	PROCEDURE LogAnneal( s: Kernel;  pos: LONGINT );
	VAR A: vyBase.Object;
	BEGIN
	(* Prepare(s,omsg,msg); *)
		(* s.cacheSize := dynamicCacheSize; *)
		A := s.A;
		IF A IS antsArrayObjects.tObject THEN
			WITH A: antsArrayObjects.tObject DO s.temperature := MathL.ln( pos + 1 ) / MathL.ln( MathL.sqrt( A.w * A.h ) )
			END;
		ELSE s.temperature := MathL.ln( pos + 1 )
		END
	END LogAnneal;

	PROCEDURE LinAnneal( s: Kernel;  pos: LONGINT );
	VAR A: vyBase.Object;
	BEGIN
		(* s.cacheSize := dynamicCacheSize; *)
		A := s.A;
		IF A IS antsArrayObjects.tObject THEN
			WITH A: antsArrayObjects.tObject DO s.temperature := (pos) / MathL.sqrt( A.w * A.h )
			END;
		ELSE s.temperature := (pos)
		END
	END LinAnneal;

	PROCEDURE ExpAnneal( s: Kernel;  pos: LONGINT );
	VAR A: vyBase.Object;
	BEGIN
		(*  s.cacheSize := dynamicCacheSize; *)
		A := s.A;
		IF A IS antsArrayObjects.tObject THEN
			WITH A: antsArrayObjects.tObject DO s.temperature := MathL.exp( pos / MathL.sqrt( A.w * A.h ) )
			END;
		ELSE s.temperature := MathL.exp( pos )
		END
	END ExpAnneal;

	PROCEDURE Const( s: Kernel;  pos: LONGINT );
	(* BEGIN s.cacheSize := staticCacheSize;*)
	END Const;

(*
PROCEDURE LogMetrAnneal (s: Kernel; VAR omsg: antsMC.Msg);
VAR A: vyBase.Object; msg: metropolisanneal;
BEGIN
Prepare(s,omsg,msg); msg.cacheSize := dynamicCacheSize;
msg.dlink := s;
A := s.A;
WITH A: antsArrayObjects.tObject DO
msg.temp := MathL.ln(msg.pos + 1) / MathL.ln(MathL.sqrt(A.w * A.h))
ELSE
msg.temp := MathL.ln(msg.pos + 1)
END;
s.par.handle(s.par,msg);
END LogMetrAnneal;

PROCEDURE LinMetrAnneal (s:Kernel; VAR omsg: antsMC.Msg);
VAR A: vyBase.Object; msg: metropolisanneal;
BEGIN
Prepare(s,omsg,msg); msg.cacheSize := dynamicCacheSize;
A := s.A;
WITH A: antsArrayObjects.tObject DO
msg.temp :=  (msg.pos) / MathL.sqrt(A.w * A.h)
ELSE
msg.temp :=  (msg.pos)
END;
s.par.handle(s.par,msg);
END LinMetrAnneal;

PROCEDURE ExpMetrAnneal (s:Kernel;VAR omsg:antsMC.Msg);
VAR A: vyBase.Object; msg: metropolisanneal;
BEGIN
Prepare(s,omsg,msg); msg.cacheSize := dynamicCacheSize;
A := s.A;
WITH A: antsArrayObjects.tObject DO
msg.temp :=  MathL.exp(msg.pos / MathL.sqrt(A.w * A.h))
ELSE
msg.temp :=  MathL.exp(msg.pos)
END;
s.par.handle(s.par,msg);
END ExpMetrAnneal;

PROCEDURE Metropolis (s: Kernel; VAR omsg:antsMC.Msg);
VAR msg: metropolis;
BEGIN
Prepare(s,omsg,msg); msg.cacheSize := staticCacheSize; msg.temp := MIN(LONGREAL);
s.par.handle(s.par,msg);
END Metropolis;
*)

	PROCEDURE Store( VAR R: Files.Rider;  s: Kernel );
	BEGIN
		Files.WriteInt( R, 5 );  Gadgets.WriteRef( R, s.lib, s.A );
		(*
	Gadgets.WriteRef(R, s.lib, s.Aorig); (*! remove *)
	*)
		Gadgets.WriteRef( R, s.lib, s.par );
		IF s.makeTemperature = constScheme THEN Files.WriteInt( R, 0 )
		ELSIF s.makeTemperature = loganneal THEN Files.WriteInt( R, 1 )
		ELSIF s.makeTemperature = linanneal THEN Files.WriteInt( R, 2 )
		ELSIF s.makeTemperature = expanneal THEN Files.WriteInt( R, 3 )
		END;
		(*
	ELSIF s.define = metropolisd THEN Files.WriteInt(R, 4)
	ELSIF s.define = logmetranneal THEN Files.WriteInt(R, 5)
	ELSIF s.define = linmetranneal THEN Files.WriteInt(R, 6)
	ELSIF s.define =  expmetranneal THEN Files.WriteInt(R, 7)
	END;
	*)
		Files.WriteString( R, s.samplerType );  Files.WriteInt( R, s.ModelClassCount );
		vyLinks.StoreLinks( R, s.lib, s.ModelClass );
		IF s.visit = linearv THEN Files.WriteInt( R, 0 )
		ELSIF s.visit = chequerboardv THEN Files.WriteInt( R, 1 )
		ELSIF s.visit = randomv THEN Files.WriteInt( R, 2 )
		ELSE
			Files.WriteInt( R, 3 ) (* linear Visit as default *)
		END;
		Files.WriteBool( R, s.parallel );  Files.WriteBool( R, s.initwithorig );  Files.WriteLInt( R, s.cacheSize );
		Files.WriteLReal( R, s.temperature )
	END Store;

	PROCEDURE Load( VAR R: Files.Rider;  s: Kernel );
	VAR objsub: Objects.Object;  coolint: INTEGER;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );  Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN s.A := objsub( vyBase.Object ) END;
		IF version < 2 THEN
			Gadgets.ReadRef( R, s.lib, objsub );
			IF objsub # NIL THEN
				Links.SetLink( s.A, "orig", objsub ) (* s.Aorig := objsub(vyBase.Object) *) ;  Links.GetLink( s.A, "orig", objsub );
				ASSERT ( objsub # NIL )
			END  (* AOrig should be link to A ! *)

		END;
		Gadgets.ReadRef( R, s.lib, objsub );
		IF objsub # NIL THEN
			s.par := objsub( vyBase.Object );  vyBase.UnSubscribe( s, s.par );
			vyBase.Subscribe( s.par, s ) (* fof 020526, wrong order before *)
		END;
		(* OpenSampler(s,s.par,0,0,FALSE,FALSE); *)
		Files.ReadInt( R, coolint );
		IF version < 5 THEN
			IF coolint = 0 THEN
				s.makeTemperature := constScheme;  s.samplerType := gibbsSampler;  s.cacheSize := staticCacheSize
			ELSIF coolint = 1 THEN
				s.makeTemperature := loganneal;  s.samplerType := gibbsSampler;  s.cacheSize := dynamicCacheSize
			ELSIF coolint = 2 THEN
				s.makeTemperature := linanneal;  s.samplerType := gibbsSampler;  s.cacheSize := dynamicCacheSize
			ELSIF coolint = 3 THEN
				s.makeTemperature := expanneal;  s.samplerType := gibbsSampler;  s.cacheSize := dynamicCacheSize
			ELSIF coolint = 4 THEN
				s.makeTemperature := constScheme;  s.samplerType := metropolisSampler;  s.cacheSize := staticCacheSize
			ELSIF coolint = 5 THEN
				s.makeTemperature := loganneal;  s.samplerType := metropolisSampler;  s.cacheSize := dynamicCacheSize
			ELSIF coolint = 6 THEN
				s.makeTemperature := linanneal;  s.samplerType := metropolisSampler;  s.cacheSize := dynamicCacheSize
			ELSIF coolint = 7 THEN
				s.makeTemperature := expanneal;  s.samplerType := metropolisSampler;  s.cacheSize := dynamicCacheSize
			END
		ELSE
			IF coolint = 0 THEN s.makeTemperature := constScheme
			ELSIF coolint = 1 THEN s.makeTemperature := loganneal
			ELSIF coolint = 2 THEN s.makeTemperature := linanneal
			ELSIF coolint = 3 THEN s.makeTemperature := expanneal
			END;
			Files.ReadString( R, s.samplerType )
		END;
		IF version > 0 THEN Files.ReadInt( R, s.ModelClassCount );  vyLinks.LoadLinks( R, s.lib, s.ModelClass ) END;
		IF version > 2 THEN
			Files.ReadInt( R, coolint );
			IF coolint = 0 THEN s.visit := linearVisit
			ELSIF coolint = 1 THEN s.visit := checkerBoardVisit
			ELSIF coolint = 2 THEN s.visit := randomVisit
			ELSE s.visit := linearVisit
			END
		END;
		IF version > 3 THEN Files.ReadBool( R, s.parallel );  Files.ReadBool( R, s.initwithorig ) END;
		IF version > 4 THEN Files.ReadLInt( R, s.cacheSize );  Files.ReadLReal( R, s.temperature ) END

	END Load;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	VAR sample: samplingMsg;
	BEGIN
		WITH o: Kernel DO
			IF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO vyBase.Update( o );
				END;
			ELSIF M IS antsMC.Msg THEN
				WITH M: antsMC.Msg DO
					IF o.par # NIL THEN
						IF M IS antsMC.StepMsg THEN
							Prepare( o, M, sample );  o.par.handle( o.par, sample );  Finish( o, M, sample )
							(*
					o.define(o,M);
					*)
						ELSIF M IS antsMC.InitMsg THEN o.makeTemperature( o, 0 );  M.dlink := o;  o.par.handle( o.par, M )
						END
					END;
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  Load( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  Store( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
					IF M.lib # o.lib THEN
						vyBase.objecthandle( o, M );  antsObjects.Bind( o.par, M );  antsObjects.Bind( o.A, M );
						(* antsObjects.Bind(o.Aorig,M); *)
						vyLinks.BindLinks( o.ModelClass, M )
					END;
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					vyLinks.DoHandleLinks( o.ModelClass, "ModelClass", M );
					IF M.id = Objects.enum THEN M.Enum( "OrigArray" );  M.Enum( "Array" );  M.Enum( "Model" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
					(* IF M.name = "OrigArray"THEN M.obj := o.Aorig;  M.res := 0 *)
						(*ELS*) IF M.name = "Array" THEN M.obj := o.A;  M.res := 0
						ELSIF M.name = "Model" THEN M.obj := o.par;  M.res := 0
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END;

				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN
						M.Enum( "Gen" );  M.Enum( "samplerType" );  M.Enum( "coolingScheme" );  M.Enum( "temperature" );  M.Enum( "VisitingScheme" );  M.Enum( "parallelUpdate" );  M.Enum( "startupWithOrig" );
						vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsKernel.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "samplerType" THEN COPY( o.samplerType, M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "coolingScheme" THEN
							IF o.makeTemperature = loganneal THEN M.s := "logarithmic"
							ELSIF o.makeTemperature = linanneal THEN M.s := "linear"
							ELSIF o.makeTemperature = expanneal THEN M.s := "exponential"
							ELSIF o.makeTemperature = constScheme THEN
								M.s := "const"
								(*
					ELSIF o.define = metropolisd THEN M.s := "metropolis"
					ELSIF o.define = logmetranneal THEN M.s := "metropolis log"
					ELSIF o.define = linmetranneal THEN M.s := "metropolis lin"
					ELSIF o.define = expmetranneal THEN M.s := "metropolis exp"
					*)
							END;
							M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "temperature" THEN M.y := o.temperature;  M.class := Objects.LongReal;  M.res := 0;  RETURN
						ELSIF M.name = "VisitingScheme" THEN
							IF o.visit = linearv THEN M.s := "raster"
							ELSIF o.visit = chequerboardv THEN M.s := "chequerBoard"
							ELSIF o.visit = randomv THEN M.s := "random"
							END;
							M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "parallelUpdate" THEN M.class := Objects.Bool;  M.b := o.parallel;  M.res := 0;  RETURN
						ELSIF M.name = "startupWithOrig" THEN M.class := Objects.Bool;  M.b := o.initwithorig;  M.res := 0;  RETURN
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "coolingScheme" THEN
							IF M.class = Objects.String THEN
								IF (M.s = "logarithmic") THEN
									o.makeTemperature := loganneal;  o.visit := linearVisit;  o.cacheSize := dynamicCacheSize;  M.res := 0
								ELSIF (M.s = "linear") THEN
									o.makeTemperature := linanneal;  o.visit := linearVisit;  o.cacheSize := dynamicCacheSize;  M.res := 0
								ELSIF (M.s = "exponential") THEN
									o.makeTemperature := expanneal;  o.visit := linearVisit;  o.cacheSize := dynamicCacheSize;  M.res := 0
								ELSIF (M.s = "const") THEN
									o.makeTemperature := constScheme;  o.visit := linearVisit;  o.cacheSize := staticCacheSize;  M.res := 0
								END;
								(*
					ELSIF  (M.s ="metropolis") THEN o.define :=metropolisd;  o.visit := randomVisit; M.res := 0
					ELSIF  (M.s ="metropolis log") THEN  o.define := logmetranneal;  o.visit := randomVisit; M.res := 0
					ELSIF  (M.s ="metropolis lin") THEN  o.define :=linmetranneal;  o.visit := randomVisit; M.res := 0
					ELSIF  (M.s ="metropolis exp") THEN  o.define := expmetranneal;  o.visit := randomVisit; M.res := 0
					END;
					*)
								Gadgets.Update( o )
							END
						ELSIF M.name = "temperature" THEN
							IF M.class = Objects.LongReal THEN o.temperature := M.y;  M.res := 0;  RETURN END
						ELSIF M.name = "samplerType" THEN
							IF M.class = Objects.String THEN
								IF (M.s = "gibbsSampler") OR (M.s = "gibbs") OR (M.s = "G") THEN o.samplerType := gibbsSampler;  o.visit := linearVisit
								ELSIF (M.s = "metropolisSampler") OR (M.s = "metropolis") OR (M.s = "M") THEN o.samplerType := metropolisSampler;  o.visit := randomVisit
								ELSIF (M.s = "exchangeAlgorithm") OR (M.s = "exchange") OR (M.s = "E") THEN o.samplerType := exchangeAlgorithm;  o.visit := randomVisit
								ELSE COPY( M.s, o.samplerType )
								END;
								M.res := 0;  Gadgets.Update( o )
							END
						ELSIF M.name = "VisitingScheme" THEN
							IF (M.s = "raster") OR (M.s = "r") THEN o.visit := linearVisit;  M.res := 0
							ELSIF (M.s = "chequerBoard") OR (M.s = "checkerBoard") OR (M.s = "chequer") OR (M.s = "chess") OR (M.s = "c") THEN o.visit := checkerBoardVisit;  M.res := 0
							ELSIF (M.s = "random") OR (M.s = "ran") THEN o.visit := randomVisit;  M.res := 0
							END;
							Gadgets.Update( o )
						ELSIF M.name = "parallelUpdate" THEN
							IF M.class = Objects.Bool THEN
								o.parallel := M.b;
								IF o.parallel THEN o.visit := linearVisit END;
								Gadgets.Update( o );  M.res := 0
							END
						ELSIF M.name = "startupWithOrig" THEN
							IF M.class = Objects.Bool THEN o.initwithorig := M.b;  M.res := 0 END

						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END

				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END
	END Handler;

	PROCEDURE Gen*;
	VAR s: Kernel;
	BEGIN
		aM.cmd;  NEW( s );  s.handle := Handler;  Objects.NewObj := s;  antsObjects.Register( s );  s.ModelClassCount := 0;
		s.ModelClass := NIL;  s.visit := linearVisit;  s.initwithorig := FALSE;  s.parallel := FALSE;  s.cacheSize := staticCacheSize;
		s.makeTemperature := constScheme;  s.temperature := 1;  s.samplerType := gibbsSampler
	END Gen;

	PROCEDURE Define*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  s: Kernel;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME # Define and register new Kernel" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			Gen;  s := Objects.NewObj( Kernel );  vyName.RegisterNamed( s, name );  aM.vSS( "Kernel registered:", name );
			(*
		IF antsCommands.FindKeyword(l,"gibbs") THEN s.define := gibbsd
		ELSIF antsCommands.FindKeyword(l,"expanneal") THEN s.define := expanneal
		ELSIF antsCommands.FindKeyword(l,"linanneal") THEN s.define := linanneal
		ELSIF antsCommands.FindKeyword(l,"anneal") THEN s.define := loganneal
		ELSE s.define := gibbsd;
		END;
		*)
		END
	END Define;

	PROCEDURE AttachArray*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  array, sampler: vyBase.Object;  copymsg: Objects.CopyMsg;
	BEGIN
		l := antsCommands.ScanFromPar( "sampler=OBJ array=OBJ # Attach array <array> to kernel <sampler>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "sampler", sampler ) & antsCommands.ExpectObjectFromKeyword( l, "array", array ) THEN
			sampler( Kernel ).A := array;
			(* copy to Orig field : *)
			copymsg.id := Objects.deep;  Objects.Stamp( copymsg );  copymsg.dlink := NIL;  array.handle( array, copymsg );
			IF (copymsg.obj # NIL ) & (copymsg.obj.handle # NIL ) THEN
				Links.SetLink( sampler( Kernel ).A, "orig", copymsg.obj );
				(* sampler(Kernel).Aorig := copymsg.obj(vyBase.Object); *)
				vyName.GetObjId( array, name );  vyHostStrings.Append( name, "O" );
				vyName.RegisterNamed( copymsg.obj( vyBase.Object ), name )
				(*
			vyName.RegisterNamed(sampler(Kernel).Aorig,name);
			*)
			ELSE aM.S( "Copy msg returned NIL, no orig object stored ! " )
			END;
			(* sampler.bindcount := 0; array.bindcount := 0; *)
			vyBase.Subscribe( sampler, array )
		END
	END AttachArray;

	PROCEDURE DoAddModel*( sampler: Kernel;  model: vyBase.Object );
	BEGIN
		vyLinks.InsertObjOnce( sampler.ModelClass, model );  INC( sampler.ModelClassCount );  aM.S( "antsKernel: Model added " )
	END DoAddModel;

	PROCEDURE DoDeleteModel*( sampler: Kernel;  model: vyBase.Object );
	VAR l: vyLinks.Link;
	BEGIN
		vyLinks.DeleteLink( sampler.ModelClass, model );  l := sampler.ModelClass;  sampler.ModelClassCount := 0;
		WHILE (l # NIL ) DO INC( sampler.ModelClassCount );  l := l.link END
	END DoDeleteModel;

	PROCEDURE DoAttachModel*( sampler: Kernel;  model: vyBase.Object );
	VAR l: vyLinks.Link;
	BEGIN
		IF sampler.par # NIL THEN vyBase.UnSubscribe( sampler.par, model ) END;
		sampler( Kernel ).par := model;
		(* sampler.bindcount := 0; model.bindcount := 0; *)
		vyBase.Subscribe( model, sampler );   (* changed order, fof 020208, wrong, changing again, fof 020526 *)
		aM.S( "antsKernel: Model attached " );  l := sampler.ModelClass;
		WHILE (l # NIL ) DO
			IF l.obj = model THEN INCL( l.flags, ModelActive ) ELSE EXCL( l.flags, ModelActive ) END;
			l := l.link
		END
	END DoAttachModel;

	PROCEDURE AttachModel*;
	VAR l: antsCommands.tScanList;  model, sampler: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "sampler=OBJ model=OBJ # attach model <model> to kernel <sampler>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "sampler", sampler ) & antsCommands.ExpectObjectFromKeyword( l, "model", model ) THEN
			DoAttachModel( sampler( Kernel ), model )
		END
	END AttachModel;

	PROCEDURE AttachAddModel*;
	VAR l: antsCommands.tScanList;  model, sampler: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "sampler=OBJ model=OBJ # attach model <model> to kernel <sampler>, add model to kernels modelset" );
		IF antsCommands.ExpectObjectFromKeyword( l, "sampler", sampler ) & antsCommands.ExpectObjectFromKeyword( l, "model", model ) THEN
			DoAddModel( sampler( Kernel ), model );  DoAttachModel( sampler( Kernel ), model )
		END
	END AttachAddModel;

	PROCEDURE DoResetModelClass*( sampler: Kernel );
	BEGIN
		sampler.ModelClass := NIL;  sampler.ModelClassCount := 0
	END DoResetModelClass;

	PROCEDURE ResetModelClass*;
	VAR l: antsCommands.tScanList;  sampler: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "sampler=OBJ # delete all models from sampler <sampler>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "sampler", sampler ) THEN DoResetModelClass( sampler( Kernel ) ) END
	END ResetModelClass;

	PROCEDURE WriteModels*;
	END WriteModels;

BEGIN
	aM.launch;  constScheme := Const;  linanneal := LinAnneal;  expanneal := ExpAnneal;  loganneal := LogAnneal;
	(*
	metropolisd := Metropolis; linmetranneal := LinMetrAnneal; expmetranneal := ExpMetrAnneal;
	logmetranneal := LogMetrAnneal;
	*)
	linearv := linearVisit;  chequerboardv := checkerBoardVisit;  randomv := randomVisit;
END antsKernel.

antsKernel.Define Kernel ~
antsMC.New Chain
antsMC.Add Chain Kernel ~
Voyager.Show Kernel as antsObjectView ~
