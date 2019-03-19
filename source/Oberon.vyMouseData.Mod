MODULE vyMouseData IN Oberon;
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
(*=  define a dense interactively drawing random numbers according this dense *)

(*	history:
10.8.95 md 0.0a1	alpha version
14.2.95 md 0.0d7	complete new designed
26.1.95 md 0.0d6	cleaned
27.10.94 md 0.0d5	adaped to the renamed vyHostDisplay & vyPictures
27.10.94 md 0.0d4	changed according to the new abstract layer Charts.tLayer
25.10.94 md 0.0d3	vyTypes.CHunkREALEntry
14.08.94 md v0r0d0   created *)

IMPORT Objects, Display, vyBase, vyName, vyRealVec, vyTypes, vyRandom, vyPatterns, vyGraphBase, vyPort, vyFctEdit, vyEvents;

CONST
	idversion* = "vyMouseData v0r0a2";  cLength = 256;

TYPE
	tDrawings = POINTER TO tDrawingsDesc;
	tDrawingsDesc = RECORD
		x, y: vyBase.tVector
	END;

VAR
	gMouseDense: vyBase.tVector;  gAcceptedData, gRejectedData: tDrawings;
	vector: BOOLEAN;   (* for the discrimination of called by Random or Randomvector *)

	PROCEDURE DefaultDense( dense: vyBase.tVector );
	BEGIN
		vyRealVec.SetLen( dense, cLength );  vyRealVec.Fill( dense, 0.5, 0, cLength )
	END DefaultDense;

	PROCEDURE Integral( d: vyBase.tVector ): REAL;
	VAR sum, dx: REAL;  i: LONGINT;
	BEGIN
		sum := 0;
		dx := 1 / (d.nrData - 1);   (*interval width*)
		FOR i := 1 TO d.nrData - 1 DO
			sum := sum + dx * (vyTypes.VGetR( d, i - 1 ) + 1 / 2 * (vyTypes.VGetR( d, i ) - vyTypes.VGetR( d, i - 1 )))
		END;
		RETURN sum
	END Integral;

	PROCEDURE CleanUp;
	BEGIN
		vyBase.Clear( gAcceptedData.x );  vyBase.Clear( gAcceptedData.y );  vyBase.Clear( gRejectedData.x );
		vyBase.Clear( gRejectedData.y )
	END CleanUp;

	PROCEDURE Handler( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(** vs 0.0d0 *)  (* md  14.02.95 17:49:31 *)
	VAR dense: vyBase.tVector;
	BEGIN
		dense := o( vyBase.tVector );
		IF msg IS vyBase.UpdateMessage THEN
			WITH msg: vyBase.UpdateMessage DO
				IF Integral( dense ) = 0 THEN DefaultDense( dense ) END;
				CleanUp;
			END;
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO vyFctEdit.Handler( dense, msg )
			END;
		ELSE
		END
	END Handler;

	PROCEDURE Random*( ): LONGREAL;
	(*vs 0.0a1 *)  (* md  14.02.95 *)
	VAR x, y, x1, x2, y1, y2, dx, dindx, offset: REAL;  i: INTEGER;  ok: BOOLEAN;
	BEGIN
		ok := FALSE;

		REPEAT
			IF (gAcceptedData.x.nrData >= 128) OR (gRejectedData.x.nrData >= 128) THEN
				CleanUp;  vyBase.Update( gMouseDense )
			END;
			x := SHORT( vyRandom.Uniform() );  y := SHORT( vyRandom.Uniform() );

			dx := 1 / (gMouseDense.nrData - 1);   (*interval width*)
			dindx := x / dx;   (*x measured in intervalls*)
			offset := dindx - ENTIER( dindx );   (*distance from left interval boarder*)
			i := SHORT( ENTIER( dindx ) );   (*index of left interval boarder*)
			IF offset = 0 THEN ok := (y < vyTypes.VGetR( gMouseDense, i ))
			ELSE
				x1 := i * dx;  y1 := vyTypes.VGetR( gMouseDense, i );  x2 := (i + 1) * dx;
				y2 := vyTypes.VGetR( gMouseDense, i + 1 );  ok := (y < ((y2 - y1) / (x2 - x1) * (x - x1) + y1))
			END;

			IF ok THEN
				vyRealVec.Append( x, gAcceptedData.x );  vyRealVec.Append( y, gAcceptedData.y );
				IF ~vector THEN vyBase.Update( gAcceptedData.x ) END
			ELSE
				vyRealVec.Append( x, gRejectedData.x );  vyRealVec.Append( y, gRejectedData.y );
				IF ~vector THEN vyBase.Update( gRejectedData.x ) END
			END
		UNTIL ok;
		RETURN x
	END Random;

	PROCEDURE RandomVector*( v: vyBase.tVector;  nrData: LONGINT );
	(*vs 0.0a1 *)  (* md  05.07.95 *)
	VAR i: LONGINT;
	BEGIN
		vector := TRUE;
		IF (v # NIL ) & (nrData > 0) THEN
			i := 0;
			WHILE i < nrData DO vyRealVec.Append( Random(), v );  INC( i ) END;
			vyBase.Update( gAcceptedData.x )
		END;
		vector := FALSE
	END RandomVector;

	PROCEDURE Recall( denseEditor: vyFctEdit.tLayer );
	VAR i: LONGINT;
	BEGIN
		vyGraphBase.SetPatternJustification( vyGraphBase.center, vyGraphBase.center );
		vyGraphBase.SetDisplayMode( vyGraphBase.replace );  vyGraphBase.SetForeColor( vyGraphBase.black );

		FOR i := 0 TO gAcceptedData.x.nrData - 1 DO
			vyGraphBase.PaintPat2d( vyTypes.VGetR( gAcceptedData.x, i ), vyTypes.VGetR( gAcceptedData.y, i ),
													  vyPatterns.cross.sgn0 )
		END;

		FOR i := 0 TO gRejectedData.x.nrData - 1 DO
			vyGraphBase.PaintPat2d( vyTypes.VGetR( gRejectedData.x, i ), vyTypes.VGetR( gRejectedData.y, i ),
													  vyPatterns.circle.sgn0 )
		END
	END Recall;

	PROCEDURE EditHandler( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.a10 *)  (* md  23.06.95 *)
	VAR denseEditor: vyFctEdit.tLayer;  done: BOOLEAN;
	BEGIN
		denseEditor := o( vyFctEdit.tLayer );  done := FALSE;

		IF msg IS Display.DisplayMsg THEN
			WITH msg: Display.DisplayMsg DO vyFctEdit.Handler( denseEditor, msg );  Recall( denseEditor );  done := TRUE
			END;
		ELSIF msg IS vyEvents.EventMsg THEN
			WITH msg: vyEvents.EventMsg DO
				IF ~(msg.callForResponder) & (msg.gesture = vyEvents.EvtIdent) THEN
					CleanUp;  vyPort.UpdateHostPicture( denseEditor, msg )
				END
			END;
		ELSE
		END;

		IF ~done THEN vyFctEdit.Handler( denseEditor, msg )
		END
	END EditHandler;

	PROCEDURE Define*;
	VAR dense: vyFctEdit.tLayer;  pict: vyPort.Picture;
	BEGIN
		CleanUp;  NEW( dense );  pict := vyFctEdit.Embed( dense, gMouseDense, 0, 0, 1, 1, FALSE , TRUE , TRUE );  vyPort.Write( pict );
		dense.handle := EditHandler;  vyBase.Subscribe( (*for messages from source*) gMouseDense, dense );
		vyBase.Subscribe( (*for messages from source*) gAcceptedData.x, dense );
		vyBase.Subscribe( (*for messages from source*) gRejectedData.x, dense )
	END Define;

	PROCEDURE InitMouseData;
		(*VAR id: vyName.tNameArray;*)

		PROCEDURE OpenDrawings( ob: tDrawings );
		BEGIN
			ob.x := vyRealVec.New( 128 );  ob.y := vyRealVec.New( 128 )
		END OpenDrawings;

		PROCEDURE OpenDense( dense: vyBase.tVector );
		BEGIN
			DefaultDense( dense );  dense.handle := Handler;
			(*	COPY ("mouse density", id);*)
			vyName.RegisterNamed( dense, "mouse density" )
		END OpenDense;

	BEGIN
		NEW( gAcceptedData );
		ASSERT ( gAcceptedData # NIL );
		OpenDrawings( gAcceptedData );  NEW( gRejectedData );
		ASSERT ( gRejectedData # NIL );
		OpenDrawings( gRejectedData );  gMouseDense := vyRealVec.New( cLength );  OpenDense( gMouseDense );
		vector := FALSE
	END InitMouseData;

BEGIN
	InitMouseData
END vyMouseData.