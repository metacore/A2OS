MODULE vyFctRandom IN Oberon;
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



(* System.Free vyFctRandom ~ *)
(*! improve speed for random vectors *)
(*! very careful check needed *)
IMPORT Objects, Display, vyBase, vyName, vyRealVec, vyTypes, vyRandom, vyPatterns, vyGraphBase, vyPort, vyFctEdit,
	vyParser, vyHostTexts, vyEvents;

CONST
	idversion* = "vyMouseData v0r0a4";  cLength = 256;
	cNNNN = 256;   (*128 *)
TYPE
	tDrawings = POINTER TO tDrawingsDesc;
	tDrawingsDesc = RECORD
		x, y: vyBase.tVector
	END;

VAR
	gMouseDense: vyBase.tVector;  RandomData: tDrawings;
	vector: BOOLEAN;   (* for the discrimination of called by Random or Randomvector *)

	PROCEDURE DefaultDense( dense: vyBase.tVector );
	BEGIN
		vyRealVec.SetLen( dense, cLength );  vyRealVec.Fill( dense, 0.5, 0, cLength )
	END DefaultDense;

	PROCEDURE Integral( d: vyBase.tVector ): FLOAT32;
	(*vs 0.0d0  md  14.02.95 17:45:03 *)
	VAR sum, dx: FLOAT32;  i: SIGNED32;
	BEGIN
		sum := 0;
		dx := 1 / (d.nrData - 1);   (*interval width*)
		dx := dx / 2;
		FOR i := 1 TO d.nrData - 1 DO sum := sum + dx * (vyTypes.VGetR( d, i - 1 ) + vyTypes.VGetR( d, i )) END;
		RETURN sum
	END Integral;

	PROCEDURE CleanUp;
	(*vs 0.0d0  md  14.02.95 17:54:21 *)
	BEGIN
		vyBase.Clear( RandomData.x );  vyBase.Clear( RandomData.y )
	END CleanUp;

	PROCEDURE Handler( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0d0  md  14.02.95 17:49:31 *)
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

	PROCEDURE Random*( factor: FLOAT32 ): FLOAT32;
	(*! ????  careful check needed. What does it do ? *)
	(*vs 0.0d0  md  14.02.95 10:36:18 *)
	VAR x, y, y1, y2, dx, dindx, offset: FLOAT64;  i: SIGNED16;
	BEGIN
		IF (RandomData.x.nrData >= cNNNN) THEN CleanUp;  vyBase.Update( gMouseDense ) END;
		x := vyRandom.Uniform();

		dx := 1 / (gMouseDense.nrData - 1);   (*interval width*)
		dindx := x / dx;   (*x measured in intervalls*)
		offset := dindx - ENTIER( dindx );   (*distance from left interval boarder*)
		i := SHORT( ENTIER( dindx ) );   (*index of left interval boarder*)
		y1 := vyTypes.VGetR( gMouseDense, i );
		IF i < RandomData.y.nrData THEN y2 := vyTypes.VGetR( gMouseDense, i + 1 ) ELSE y2 := y1 END;
		y := y1 + (y2 - y1) * offset;

		y := y + vyRandom.Gauss( 0, 1 ) * factor;  vyRealVec.Append( SHORT( x ), RandomData.x );
		vyRealVec.Append( SHORT( y ), RandomData.y );
		IF ~vector THEN vyBase.Update( RandomData.x );  vyBase.Update( RandomData.y ) END;

		RETURN SHORT( x )
	END Random;

	PROCEDURE RandomVector*( x: vyBase.tVector;  nrData: SIGNED32 );
	(*vs 0.0d0  md  05.07.95 15:00:06 *)
	VAR i: SIGNED32;
	BEGIN
		vector := TRUE;
		IF (x # NIL ) & (nrData > 0) THEN
			i := 0;
			WHILE i < nrData DO vyRealVec.Append( Random( 1.0 ), x );  INC( i ) END;
			vyBase.Update( RandomData.x )
		END;
		vector := FALSE
	END RandomVector;

	PROCEDURE Recall( denseEditor: vyFctEdit.tLayer );
	(*vs 0.0d0  md  23.06.95 15:22:19 *)
	VAR i: SIGNED32;
	BEGIN
		vyGraphBase.SetPatternJustification( vyGraphBase.center, vyGraphBase.center );
		vyGraphBase.SetDisplayMode( vyGraphBase.replace );  vyGraphBase.SetForeColor( 15 );

		FOR i := 0 TO RandomData.x.nrData - 1 DO
			vyGraphBase.PaintPat2d( vyTypes.VGetR( RandomData.x, i ), vyTypes.VGetR( RandomData.y, i ),
													  vyPatterns.cross.sgn0 )
		END

	END Recall;

	PROCEDURE EditHandler( o: Objects.Object;  VAR msg: Objects.ObjMsg );
	(*vs 0.0d0  md  23.06.95 15:18:12 *)
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
	(*vs 0.0d0  md  14.02.95 10:34:39 *)
	VAR dense: vyFctEdit.tLayer;  pict: vyPort.Picture;
	BEGIN
		CleanUp;  NEW( dense );  pict := vyFctEdit.Embed( dense, gMouseDense, 0, 0, 1, 1, FALSE , TRUE , TRUE );  vyPort.Write( pict );
		dense.handle := EditHandler;  vyBase.Subscribe( (*for messages from source*) gMouseDense, dense );
		vyBase.Subscribe( (*for messages from source*) RandomData.x, dense )
	END Define;

	PROCEDURE InitMouseData;
		(*vs 0.0d0  md  14.02.95 11:11:35 *)

		PROCEDURE OpenDrawings( ob: tDrawings );
		(*vs 0.0d0  md  14.02.95 11:17:19 *)
		BEGIN
			ob.x := vyRealVec.New( cNNNN );  vyName.RegisterNamed( ob.x, "FctX" );  ob.y := vyRealVec.New( cNNNN );
			vyName.RegisterNamed( ob.y, "FctY" );  vyHostTexts.Msg( "Variables generated as FctX and FctY" )
		END OpenDrawings;

		PROCEDURE OpenDense( dense: vyBase.tVector );
		(*vs 0.0d0  md  14.02.95 11:22:52 *)
		BEGIN
			DefaultDense( dense );  dense.handle := Handler;  vyName.RegisterNamed( dense, "vyFctRandom density" )
		END OpenDense;

	BEGIN
		NEW( RandomData );
		ASSERT ( RandomData # NIL );
		OpenDrawings( RandomData );  gMouseDense := vyRealVec.New( cLength );  OpenDense( gMouseDense );
		vector := FALSE
	END InitMouseData;

	PROCEDURE Simulate*;
	VAR sc: vyParser.Scanner;  i: SIGNED32;  r, x: FLOAT32;  b: BOOLEAN;
	BEGIN
		x := 1.0;  vyParser.OpenParScanner( sc );
		IF vyParser.Number( sc, i ) THEN
			b := vyParser.Real( sc, x );
			WHILE (i > 0) DO r := Random( x );  DEC( i ) END
		ELSE vyParser.MsgSyntax( "Simulate", "# of Points/4;Factor/56" )
		END
	END Simulate;

BEGIN
	InitMouseData
END vyFctRandom.