MODULE antsModels IN Oberon;   (** fof   **)
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



IMPORT antsObjects, vyBase, antsArrayObjects, antsCommands, Objects, Files, antsGlobals, Gadgets, antsMC, antsCaches,
	vyHostStrings, antsKernel, Links, antsRegions, aM := antsMessages;

TYPE
	Parameters* = antsGlobals.Parameters;  ParameterNames* = antsGlobals.ParameterNames;


	tModel* = POINTER TO tModelDesc;   (*= input parameters for the gibbs sampler, may be extended in your module *)
	PotentialFunction* = PROCEDURE ( M: tModel;  A: vyBase.Object ): LONGREAL;
	tModelDesc* = RECORD (vyBase.ObjDesc)
		coolingTemp-: LONGREAL;
		synced*: BOOLEAN;
		MCache*: antsCaches.FullCache;
		maxCacheSize-: LONGINT;
		region*: antsRegions.tRegion;
		par*: Parameters;   (* for automatic handling of attribute messages etc. , use that in higher modules *)
		parNames*: ParameterNames;   (* for automatic handling of attribute messages etc., names of par *)
		hotupdate*: BOOLEAN
	END;

	PROCEDURE StoreParameters( VAR R: Files.Rider;  p: Parameters;  pn: ParameterNames );
	VAR i: LONGINT;
	BEGIN
		IF p = NIL THEN Files.WriteLInt( R, 0 )
		ELSE
			Files.WriteLInt( R, LEN( p ) );
			FOR i := 0 TO LEN( p ) - 1 DO Files.WriteLReal( R, p[i] ) END
		END;
		IF pn = NIL THEN Files.WriteLInt( R, 0 )
		ELSE
			Files.WriteLInt( R, LEN( pn ) );
			FOR i := 0 TO LEN( pn ) - 1 DO Files.WriteString( R, pn[i] ) END
		END
	END StoreParameters;

	PROCEDURE ReadParameters( VAR R: Files.Rider;  VAR p: Parameters;  VAR pn: ParameterNames );
	VAR len, i: LONGINT;
	BEGIN
		Files.ReadLInt( R, len );
		IF len = 0 THEN p := NIL
		ELSE
			NEW( p, len );
			FOR i := 0 TO len - 1 DO Files.ReadLReal( R, p[i] ) END
		END;
		Files.ReadLInt( R, len );
		IF len = 0 THEN pn := NIL
		ELSE
			NEW( pn, len );
			FOR i := 0 TO len - 1 DO Files.ReadString( R, pn[i] ) END
		END
	END ReadParameters;

	PROCEDURE Store( VAR R: Files.Rider;  s: tModel );
	BEGIN
		Files.WriteInt( R, 2 );   (* version control *)
		Files.WriteLReal( R, s.coolingTemp );  Files.WriteBool( R, s.synced );  StoreParameters( R, s.par, s.parNames );
		Files.WriteBool( R, s.hotupdate )
	END Store;

	PROCEDURE Load( VAR R: Files.Rider;  s: tModel );
	VAR version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );   (* version control *)
		Files.ReadLReal( R, s.coolingTemp );  Files.ReadBool( R, s.synced );
		IF version > 0 THEN ReadParameters( R, s.par, s.parNames ) END;
		IF version > 1 THEN Files.ReadBool( R, s.hotupdate ) END
	END Load;

	PROCEDURE Init( s: antsKernel.Kernel );   (* standard Init *)
	VAR A: vyBase.Object;  obj: Objects.Object;  orig: antsArrayObjects.tINTEGERObject;
	BEGIN
		IF s = NIL THEN RETURN END;
		A := s.A;
		IF A = NIL THEN RETURN END;
		Links.GetLink( A, "orig", obj );
		IF (obj # NIL ) & (obj IS antsArrayObjects.tINTEGERObject) THEN orig := obj( antsArrayObjects.tINTEGERObject )
		ELSE orig := NIL
		END;

		IF A IS antsArrayObjects.tINTEGERObject THEN
			WITH A: antsArrayObjects.tINTEGERObject DO
				IF s.initwithorig THEN
					IF orig # NIL THEN antsArrayObjects.CopyII( orig.A, A.A, 0, 0, A.w, A.h, 0, 0 ) END
				ELSE antsArrayObjects.UniformO( A )
				END;
				A.Cache := NIL
			END;
		ELSE
		END

	END Init;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	(*= handler for the sampled picture, calls updates if picture has changed ->  graphical updates *)
	BEGIN
		WITH o: tModel DO
			IF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO
					o.synced := FALSE;   (* Out.String("Syncing Model in cause of Update Msg "); Out.Ln(); *)
					vyBase.Update( o );  Gadgets.Update( o );
				END;
			ELSIF M IS antsKernel.Init THEN
				WITH M: antsKernel.Init DO Init( M.dlink( antsKernel.Kernel ) );
				END;
			ELSIF M IS antsMC.Msg THEN
				WITH M: antsMC.Msg DO Gadgets.Update( o );
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  Load( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  Store( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO vyBase.objecthandle( o, M );
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN
						M.Enum( "Gen" );  M.Enum( "coolingTemp" );  M.Enum( "synced" );  M.Enum( "hotupdate" );
						IF antsGlobals.ParameterHandleAttribute( M, o.par, o.parNames ) THEN END;
						vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsModels.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "coolingTemp" THEN M.y := o.coolingTemp;  M.class := Objects.LongReal;  M.res := 0;  RETURN
						ELSIF M.name = "synced" THEN M.b := o.synced;  M.class := Objects.Bool;  M.res := 0;  RETURN
						ELSIF M.name = "hotupdate" THEN M.b := o.hotupdate;  M.class := Objects.Bool;  M.res := 0;  RETURN
						ELSIF antsGlobals.ParameterHandleAttribute( M, o.par, o.parNames ) THEN RETURN
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "synced" THEN
							IF M.class = Objects.Bool THEN o.synced := M.b;  M.res := 0;  RETURN END
							(* ELSIF M.name = "coolingTemp"THEN
					IF M.class = Objects.LongReal THEN o.coolingTemp := M.y; M.res := 0;  o.synced := FALSE; RETURN END;
					*)
						ELSIF M.name = "hotupdate" THEN
							IF M.class = Objects.Bool THEN o.hotupdate := M.b;  M.res := 0;  RETURN END
						ELSIF antsGlobals.ParameterHandleAttribute( M, o.par, o.parNames ) THEN
							o.synced := FALSE;  vyBase.Update( o );  RETURN
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END

				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END
	END Handler;

	PROCEDURE Open*( par: tModel );
	BEGIN
		IF par.handle = NIL THEN par.handle := Handler END;
		par.coolingTemp := 1;  par.synced := FALSE;  par.maxCacheSize := 10000000
	END Open;

	PROCEDURE SetTemperature*( par: tModel;  temp: LONGREAL );
	BEGIN
		IF par.coolingTemp = temp THEN RETURN END;
		par.coolingTemp := temp;  par.synced := FALSE
	END SetTemperature;

	PROCEDURE SetMaxCache*( par: tModel;  maxCacheSize: LONGINT );
	BEGIN
		IF par.maxCacheSize = maxCacheSize THEN RETURN END;
		par.maxCacheSize := maxCacheSize;  par.synced := FALSE
	END SetMaxCache;

	PROCEDURE Gen*;
	VAR p: tModel;
	BEGIN
		aM.cmd;  NEW( p );  p.handle := Handler;  Objects.NewObj := p;  antsObjects.Register( p );  p.coolingTemp := 1;
		p.hotupdate := FALSE;  p.maxCacheSize := 10000000
	END Gen;

	PROCEDURE DoAttachRegion*( model: tModel;  region: antsRegions.tRegion );
	BEGIN
		model.region := region
	END DoAttachRegion;

	PROCEDURE AttachRegion*;
	VAR l: antsCommands.tScanList;  model, region: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "model=OBJ region=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "model", model ) & antsCommands.ExpectObjectFromKeyword( l, "region", region ) THEN
			DoAttachRegion( model( tModel ), region( antsRegions.tRegion ) )
		END
	END AttachRegion;

	PROCEDURE RemoveRegion*;
	VAR l: antsCommands.tScanList;  model: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "model=OBJ" );
		IF antsCommands.ExpectObjectFromKeyword( l, "model", model ) THEN DoAttachRegion( model( tModel ), NIL );  END;
	END RemoveRegion;

BEGIN
	aM.launch;
END antsModels.
