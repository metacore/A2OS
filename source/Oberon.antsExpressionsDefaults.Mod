MODULE antsExpressionsDefaults IN Oberon;   (** fof  **)
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




IMPORT SYSTEM, vyBase, vyLinks, antsExpressions, vyTypes, vyHostTexts, Texts, vyLongrealVec, vyRealVec, vyLongintVec,
	vyRandom, vyScale, vyPort, Objects, Gadgets, Out;

VAR
	defaultPlot*: ARRAY 64 OF CHAR;

	PROCEDURE ShowAs*( a: vyBase.Object;  s: ARRAY OF CHAR ): Objects.Object;
	VAR link: vyLinks.Link;
	BEGIN
		link := NIL;  vyLinks.InsertObj( link, a );  vyBase.Show( link, 1, s );  vyScale.Insert;  RETURN vyPort.newframe
	END ShowAs;

	PROCEDURE Show*( a: Objects.Object ): Objects.Object;
	BEGIN
		IF a = NIL THEN RETURN NIL END;
		IF a IS vyBase.tData THEN
			WITH a: vyBase.tData DO RETURN ShowAs( a, defaultPlot );
			END;
		ELSIF a IS Gadgets.Frame THEN
			WITH a: Gadgets.Frame DO vyHostTexts.InsertGadget( a );  RETURN a
			END;
		ELSE RETURN a
		END
	END Show;

	PROCEDURE Write*( ob: vyBase.Object );
	BEGIN
		IF ob # NIL THEN
			IF ob IS vyBase.tData THEN
				vyTypes.Write( vyHostTexts.w, ob( vyBase.tData ) );  Texts.WriteLn( vyHostTexts.w );
				vyHostTexts.InsertLog( vyHostTexts.w.buf )
			ELSE
			END
		END
	END Write;

	PROCEDURE RanV*( len: LONGINT ): vyBase.Object;
	VAR i: LONGINT;
	VAR v: vyLongrealVec.tVector;
	BEGIN
		v := vyLongrealVec.New( len );
		FOR i := 0 TO vyLongrealVec.Len( v ) - 1 DO vyLongrealVec.Set( vyRandom.Uniform(), v, i ) END;
		RETURN v
	END RanV;

	PROCEDURE Ran*( ): LONGREAL;
	BEGIN
		RETURN vyRandom.Uniform()
	END Ran;

	PROCEDURE Vec*( len: LONGINT ): vyBase.Object;
	BEGIN
		RETURN vyLongrealVec.New( len )
	END Vec;

	PROCEDURE VecR*( len: LONGINT ): vyBase.Object;
	BEGIN
		RETURN vyRealVec.New( len )
	END VecR;

	PROCEDURE VecL*( len: LONGINT ): vyBase.Object;
	BEGIN
		RETURN vyLongintVec.New( len )
	END VecL;

	PROCEDURE Len*( ob: ANY ): LONGINT;
	BEGIN
		IF ob IS vyBase.tVector THEN
			WITH ob: vyBase.tVector DO RETURN ob.nrData
			END;
		ELSE RETURN 0
		END
	END Len;

	PROCEDURE ChunkSummary*( v: vyBase.tVector );
	VAR buf: vyBase.tBuf;
	BEGIN
		buf := v.buf;
		WHILE (buf # NIL ) DO Out.Ln;  Out.String( "BUF: " );  Out.Int( buf.len, 10 );  Out.Int( buf.usedentries, 10 );  buf := buf.next END
	END ChunkSummary;

	PROCEDURE Ptr*( i: LONGINT ): ANY;
	BEGIN
		RETURN SYSTEM.VAL( ANY, i )
	END Ptr;

	PROCEDURE Selection*( ): ANY;
	VAR obj: Objects.Object;  t2: LONGINT;
	BEGIN
		Gadgets.GetSelection( obj, t2 );
		IF t2 >= 0 THEN RETURN obj ELSE RETURN NIL END
	END Selection;

	PROCEDURE EnableCR*;
	BEGIN
		antsExpressions.enableCR := TRUE
	END EnableCR;

	PROCEDURE DisableCR*;
	BEGIN
		antsExpressions.enableCR := FALSE
	END DisableCR;

	PROCEDURE Init;
	BEGIN
		defaultPlot := "LinePlot"
	END Init;

BEGIN
	Init;
END antsExpressionsDefaults.
