MODULE vyStd2dLayer IN Oberon;   (*vs 0.0a1 md   09.08.95 *)
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

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
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(* 	(c) Project Voyager, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)

(*= a standard layer for quick and dirty plots without interactive possibilities *)

(*	history:
9.8.95 md 0.0a1	alpha version
3.7.95 md 0.0d0	created *)

IMPORT Objects, Display, vyHostTexts, vyParser, vyBase, vyHostStrings, vyTypes, vyName, vyDisplay2d, vyPort;

CONST
	idversion* = "vyStd2dLayer v0r0a3";  sourceModule = "vyQuickDraw";

TYPE
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc* = RECORD (vyPort.tLayerDesc)
		recallProcedure: ARRAY 32 OF CHAR
	END;

VAR
	x*: vyBase.tVector;

	PROCEDURE Copy( source, dest: tLayer );
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Recall( layer: tLayer;  msg: Display.DisplayMsg );
	(*vs 0.0a1   md  03.07.95 *)
	VAR method: ARRAY 64 OF CHAR;
		res: SIGNED16;
	BEGIN
		COPY( sourceModule, method );  vyHostStrings.Append( method, "." );
		vyHostStrings.Append( method, layer.recallProcedure );  x := layer.x;
		vyBase.CallWString( idversion, method, "", FALSE , res )

	END Recall;

	PROCEDURE Handler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0a1	md  20.07.94 *)
	VAR layer, copy: tLayer;  done: BOOLEAN;
	BEGIN
		layer := o( tLayer );  done := FALSE;

		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO Recall( layer, msg );  done := TRUE
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				NEW( copy );  msg.obj := copy;  vyPort.LayerHandler( layer, msg );  Copy( layer, msg.obj( tLayer ) );  done := TRUE
			END;
		ELSE
		END;

		IF ~done THEN vyPort.LayerHandler( layer, msg )
		END
	END Handler;

	PROCEDURE Open*( layer: tLayer;  data: Objects.Object;  recallProc: ARRAY OF CHAR );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;

	BEGIN
		layer.x := vyBase.GetVFromObj( data );
		IF (layer.x = NIL ) THEN vyHostTexts.Msg( "can't plot this data as a layer: not the right type!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		END;
		COPY( recallProc, id );  vyHostStrings.Append( id, ": " );  vyName.AppendObjId( data( vyBase.Object ), id );
		vyPort.OpenLayer( layer, id );  COPY( recallProc, layer.recallProcedure );  layer.handle := Handler;
		vyBase.Subscribe( (*for messages from source*) layer.x, layer )
	END Open;

	PROCEDURE Show*;
	VAR data: Objects.Object;  layer: tLayer;  minX, maxX: FLOAT32;
		recallProc: ARRAY 32 OF CHAR;
		s: vyParser.Scanner;  nans: SIGNED32;
	BEGIN
		vyParser.OpenParScanner( s );
		IF ~vyParser.Name( s, recallProc ) THEN vyHostTexts.NoteSS( vyHostTexts.cAlert, idversion, "recall procedure expected" );  RETURN END;
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			NEW( layer );  Open( layer, data, recallProc );  vyTypes.VGetMinMaxR( layer.x, minX, maxX, nans );
			vyPort.AddLayer( vyPort.InsertNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( minX, 0, maxX - minX, 1 ) ), layer );
			data := vyBase.NextParObj()
		END
	END Show;

	PROCEDURE Alloc*;
	VAR layer: tLayer;
	BEGIN
		NEW( layer );  layer.handle := Handler;  Objects.NewObj := layer
	END Alloc;

END vyStd2dLayer.
