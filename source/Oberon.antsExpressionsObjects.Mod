MODULE antsExpressionsObjects IN Oberon;   (** fof  **)
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




IMPORT vyBase, vyLongrealVec, vyRealVec, Objects, vyIntVec, vyLongintVec, vyTypes, vyName, SYSTEM, vyPointerVec;

	PROCEDURE ToVec1( VAR v: vyBase.tData;  len: SIGNED32 ): vyBase.tData;
	VAR res: vyBase.tVector;
	BEGIN
		IF v IS vyLongrealVec.tLONGREAL THEN
			WITH v: vyLongrealVec.tLONGREAL DO
				res := vyLongrealVec.New( len );  vyLongrealVec.Fill( res, v.x, 0, len );  RETURN res;
			END;
		ELSIF v IS vyRealVec.tREAL THEN
			WITH v: vyRealVec.tREAL DO res := vyRealVec.New( len );  vyRealVec.Fill( res, v.x, 0, len );  RETURN res;
			END;
		ELSIF v IS vyLongintVec.tLONGINT THEN
			WITH v: vyLongintVec.tLONGINT DO res := vyLongintVec.New( len );  vyLongintVec.Fill( res, v.i, 0, len );  RETURN res;
			END;
		ELSIF v IS vyIntVec.tINTEGER THEN
			WITH v: vyIntVec.tINTEGER DO res := vyIntVec.New( len );  vyIntVec.Fill( res, v.i, 0, len );  RETURN res
			END;
		ELSE RETURN v
		END
	END ToVec1;

	PROCEDURE ToVec( VAR v1, v2: vyBase.tData );
	BEGIN
		IF v1 IS vyBase.tVector THEN
			WITH v1: vyBase.tVector DO
				IF v2 IS vyBase.tVector THEN
					WITH v2: vyBase.tVector DO RETURN
					END;
				ELSE v2 := ToVec1( v2, v1.nrData )
				END
			END;
		ELSE
			IF v2 IS vyBase.tVector THEN
				WITH v2: vyBase.tVector DO v1 := ToVec1( v1, v2.nrData )
				END;
			ELSE RETURN
			END
		END
	END ToVec;

	PROCEDURE ConvertSize( fixed: vyBase.tData;  VAR var: vyBase.tData;  new: BOOLEAN );
	VAR len: SIGNED32;  dest: vyBase.tData;
	BEGIN
		IF fixed IS vyBase.tVector THEN
			WITH fixed: vyBase.tVector DO
				IF var IS vyBase.tVector THEN
					IF var( vyBase.tVector ).nrData = fixed.nrData THEN RETURN END;
					IF new THEN vyTypes.Copy( var, dest );  var := dest END
				END;
				len := fixed.nrData;
				IF var IS vyLongrealVec.tVector THEN
					WITH var: vyLongrealVec.tVector DO vyLongrealVec.SetLen( var, len )
					END;
				ELSIF var IS vyRealVec.tVector THEN
					WITH var: vyRealVec.tVector DO vyRealVec.SetLen( var, len )
					END;
				ELSIF var IS vyLongintVec.tVector THEN
					WITH var: vyLongintVec.tVector DO vyLongintVec.SetLen( var, len )
					END;
				ELSIF var IS vyIntVec.tVector THEN
					WITH var: vyIntVec.tVector DO vyIntVec.SetLen( var, len )
					END;
				ELSE
				END
			END;
		ELSE
		END
	END ConvertSize;

	PROCEDURE TakeSmaller( VAR v1, v2: vyBase.tData );
	BEGIN
		IF (v1 IS vyBase.tVector) & (v2 IS vyBase.tVector) THEN
			IF v1( vyBase.tVector ).nrData < v2( vyBase.tVector ).nrData THEN ConvertSize( v1, v2, TRUE )
			ELSIF v1( vyBase.tVector ).nrData > v2( vyBase.tVector ).nrData THEN ConvertSize( v2, v1, TRUE )
			END
		END
	END TakeSmaller;

	PROCEDURE Convert( from, to: vyBase.tData;  VAR res: vyBase.tData );
	(* Copy Data of from to res with type of to *)
	VAR i: SIGNED32;  len: SIGNED32;
	BEGIN
		IF from IS vyBase.tVector THEN
			WITH from: vyBase.tVector DO len := from.nrData
			END;
		ELSE
			IF to IS vyBase.tVector THEN
				WITH to: vyBase.tVector DO len := to.nrData
				END;
			ELSE
			END
		END;

		IF from IS vyLongrealVec.tVector THEN
			WITH from: vyLongrealVec.tVector DO
				IF to IS vyIntVec.tVector THEN
					WITH to: vyIntVec.tVector DO
						res := vyIntVec.New( len );
						FOR i := 0 TO len - 1 DO vyIntVec.Set( SHORT( ENTIER( vyLongrealVec.Get( from, i ) ) ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyLongintVec.tVector THEN
					WITH to: vyLongintVec.tVector DO
						res := vyLongintVec.New( len );
						FOR i := 0 TO len - 1 DO vyLongintVec.Set( ENTIER( vyLongrealVec.Get( from, i ) ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyRealVec.tVector THEN
					WITH to: vyRealVec.tVector DO
						res := vyRealVec.New( len );
						FOR i := 0 TO len - 1 DO vyRealVec.Set( SHORT( vyLongrealVec.Get( from, i ) ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyLongrealVec.tVector THEN
					WITH to: vyLongrealVec.tVector DO vyTypes.Copy( from, res )
					END;
				ELSE
				END;
			END;
		ELSIF from IS vyRealVec.tVector THEN
			WITH from: vyRealVec.tVector DO
				IF to IS vyIntVec.tVector THEN
					WITH to: vyIntVec.tVector DO
						res := vyIntVec.New( len );
						FOR i := 0 TO len - 1 DO vyIntVec.Set( SHORT( ENTIER( vyRealVec.Get( from, i ) ) ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyLongintVec.tVector THEN
					WITH to: vyLongintVec.tVector DO
						res := vyLongintVec.New( len );
						FOR i := 0 TO len - 1 DO vyLongintVec.Set( ENTIER( vyRealVec.Get( from, i ) ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyRealVec.tVector THEN
					WITH to: vyRealVec.tVector DO vyTypes.Copy( from, res )
					END;
				ELSIF to IS vyLongrealVec.tVector THEN
					WITH to: vyLongrealVec.tVector DO
						res := vyLongrealVec.New( len );
						FOR i := 0 TO len - 1 DO vyLongrealVec.Set( vyRealVec.Get( from, i ), res( vyBase.tVector ), i ) END
					END;
				ELSE
				END;
			END;
		ELSIF from IS vyLongintVec.tVector THEN
			WITH from: vyLongintVec.tVector DO
				IF to IS vyIntVec.tVector THEN
					WITH to: vyIntVec.tVector DO
						res := vyIntVec.New( len );
						FOR i := 0 TO len - 1 DO vyIntVec.Set( SHORT( vyLongintVec.Get( from, i ) ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyLongintVec.tVector THEN
					WITH to: vyLongintVec.tVector DO vyTypes.Copy( from, res )
					END;
				ELSIF to IS vyRealVec.tVector THEN
					WITH to: vyRealVec.tVector DO
						res := vyRealVec.New( len );
						FOR i := 0 TO len - 1 DO vyRealVec.Set( vyLongintVec.Get( from, i ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyLongrealVec.tVector THEN
					WITH to: vyLongrealVec.tVector DO
						res := vyLongrealVec.New( len );
						FOR i := 0 TO len - 1 DO vyLongrealVec.Set( vyLongintVec.Get( from, i ), res( vyBase.tVector ), i ) END
					END;
				ELSE
				END;
			END;
		ELSIF from IS vyIntVec.tVector THEN
			WITH from: vyIntVec.tVector DO
				IF to IS vyIntVec.tVector THEN
					WITH to: vyIntVec.tVector DO vyTypes.Copy( from, res )
					END;
				ELSIF to IS vyLongintVec.tVector THEN
					WITH to: vyLongintVec.tVector DO
						res := vyLongintVec.New( len );
						FOR i := 0 TO len - 1 DO vyLongintVec.Set( vyIntVec.Get( from, i ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyRealVec.tVector THEN
					WITH to: vyRealVec.tVector DO
						res := vyRealVec.New( len );
						FOR i := 0 TO len - 1 DO vyRealVec.Set( vyIntVec.Get( from, i ), res( vyBase.tVector ), i ) END;
					END;
				ELSIF to IS vyLongrealVec.tVector THEN
					WITH to: vyLongrealVec.tVector DO
						res := vyLongrealVec.New( len );
						FOR i := 0 TO len - 1 DO vyLongrealVec.Set( vyIntVec.Get( from, i ), res( vyBase.tVector ), i ) END
					END;
				ELSE
				END
			END;
		END
	END Convert;

	PROCEDURE SortByTyp( VAR smaller, bigger: vyBase.tData ): BOOLEAN;

		PROCEDURE Swap;
		VAR sw: vyBase.tData;
		BEGIN
			sw := smaller;  smaller := bigger;  bigger := sw
		END Swap;

	BEGIN
		IF (bigger IS vyLongrealVec.tVector) OR (bigger IS vyLongrealVec.tLONGREAL) THEN
		ELSIF (bigger IS vyRealVec.tVector) OR (bigger IS vyRealVec.tREAL) THEN
			IF (smaller IS vyLongrealVec.tVector) OR (smaller IS vyLongrealVec.tLONGREAL) THEN Swap;  RETURN TRUE END
		ELSIF (bigger IS vyLongintVec.tVector) OR (bigger IS vyLongintVec.tLONGINT) THEN
			IF (smaller IS vyLongrealVec.tVector) OR (smaller IS vyRealVec.tVector) OR (smaller IS vyLongrealVec.tLONGREAL) OR
			    (smaller IS vyRealVec.tREAL) THEN
				Swap;  RETURN TRUE
			END
		ELSIF (bigger IS vyIntVec.tVector) OR (bigger IS vyIntVec.tINTEGER) THEN
			IF (smaller IS vyLongrealVec.tVector) OR (smaller IS vyRealVec.tVector) OR (smaller IS vyLongintVec.tVector) OR
			    (smaller IS vyLongrealVec.tLONGREAL) OR (smaller IS vyRealVec.tREAL) OR (smaller IS vyLongintVec.tLONGINT) THEN
				Swap;  RETURN TRUE
			END
		ELSE
		END;
		RETURN FALSE
	END SortByTyp;

	PROCEDURE vyLongintVecAdd( VAR res: vyLongintVec.tVector;  x, y: vyBase.tData );
	VAR i: SIGNED32;
	BEGIN
		WITH x: vyLongintVec.tVector DO
			WITH y: vyLongintVec.tVector DO
				res := vyLongintVec.New( x.nrData );
				FOR i := 0 TO x.nrData - 1 DO vyLongintVec.Set( vyLongintVec.Get( x, i ) + vyLongintVec.Get( y, i ), res, i ) END
			END
		END
	END vyLongintVecAdd;

	PROCEDURE vyIntVecAdd( VAR res: vyIntVec.tVector;  x, y: vyBase.tData );
	VAR i: SIGNED32;
	BEGIN
		WITH x: vyIntVec.tVector DO
			WITH y: vyIntVec.tVector DO
				res := vyIntVec.New( x.nrData );
				FOR i := 0 TO x.nrData - 1 DO vyIntVec.Set( vyIntVec.Get( x, i ) + vyIntVec.Get( y, i ), res, i ) END
			END
		END
	END vyIntVecAdd;

	PROCEDURE Add*( VAR res: vyBase.tData;  v1, v2: vyBase.tData );
	VAR swap: BOOLEAN;
	BEGIN
		res := NIL;  ToVec( v1, v2 );  swap := SortByTyp( v1, v2 );  TakeSmaller( v1, v2 );  Convert( v1, v2, res );
		IF v1 IS vyBase.tVector THEN
			WITH v1: vyBase.tVector DO
				IF v2 IS vyBase.tVector THEN
					WITH v2: vyBase.tVector DO
						IF res IS vyLongrealVec.tVector THEN
							WITH res: vyLongrealVec.tVector DO vyLongrealVec.Add( res, res, v2 )
							END;
						ELSIF res IS vyRealVec.tVector THEN
							WITH res: vyRealVec.tVector DO vyRealVec.Add( res, res, v2 )
							END;
						ELSIF res IS vyLongintVec.tVector THEN
							WITH res: vyLongintVec.tVector DO vyLongintVecAdd( res, res, v2 )
							END;
						ELSIF res IS vyIntVec.tVector THEN
							WITH res: vyIntVec.tVector DO vyIntVecAdd( res, res, v2 )
							END;
						ELSE
						END
					END;
				ELSE
				END
			END;
		ELSE
		END
	END Add;

	PROCEDURE Mult*( VAR res: vyBase.tData;  v1, v2: vyBase.tData );
	VAR swap: BOOLEAN;
	BEGIN
		res := NIL;  ToVec( v1, v2 );  swap := SortByTyp( v1, v2 );  TakeSmaller( v1, v2 );  Convert( v1, v2, res );
		IF v1 IS vyBase.tVector THEN
			WITH v1: vyBase.tVector DO
				IF v2 IS vyBase.tVector THEN
					WITH v2: vyBase.tVector DO
						IF res IS vyLongrealVec.tVector THEN
							WITH res: vyLongrealVec.tVector DO vyLongrealVec.Mult( res, res, v2 )
							END;
						ELSIF res IS vyRealVec.tVector THEN
							WITH res: vyRealVec.tVector DO
								vyRealVec.Mult( res, res, v2 )
								(*|res: vyLongintVec.tVector DO vyLongintVecMult(res,res,v2)
			|res: vyIntVec.tVector DO vyIntVecMult(res,res,v2)*)
							END;
						ELSE
						END
					END;
				ELSE
				END
			END;
		ELSE
		END
	END Mult;

	PROCEDURE Sub*( VAR res: vyBase.tData;  v1, v2: vyBase.tData );
	VAR swap: BOOLEAN;
	BEGIN
		res := NIL;  ToVec( v1, v2 );  swap := SortByTyp( v1, v2 );  TakeSmaller( v1, v2 );  Convert( v1, v2, res );
		IF v1 IS vyBase.tVector THEN
			WITH v1: vyBase.tVector DO
				IF v2 IS vyBase.tVector THEN
					WITH v2: vyBase.tVector DO
						IF res IS vyLongrealVec.tVector THEN
							WITH res: vyLongrealVec.tVector DO
								IF swap THEN vyLongrealVec.Sub( res, v2, res ) ELSE vyLongrealVec.Sub( res, res, v2 ) END;
							END;
						ELSIF res IS vyRealVec.tVector THEN
							WITH res: vyRealVec.tVector DO
								IF swap THEN vyRealVec.Sub( res, v2, res ) ELSE vyRealVec.Sub( res, res, v2 ) END;
								(*|res: vyLongintVec.tVector DO IF swap THEN vyLongintVecSub(res,v2,res) ELSE vyLongintVecSub(res,res,v2) END;
			|res: vyIntVec.tVector DO IF swap THEN vyIntVecSub(res,v2,res) ELSE vyIntVecSub(res,res,v2) END*)
							END;
						ELSE
						END
					END;
				ELSE
				END
			END;
		ELSE
		END
	END Sub;

	PROCEDURE Div*( VAR res: vyBase.tData;  v1, v2: vyBase.tData );
	VAR swap: BOOLEAN;
	BEGIN
		res := NIL;  ToVec( v1, v2 );  swap := SortByTyp( v1, v2 );  TakeSmaller( v1, v2 );  Convert( v1, v2, res );
		IF v1 IS vyBase.tVector THEN
			WITH v1: vyBase.tVector DO
				IF v2 IS vyBase.tVector THEN
					WITH v2: vyBase.tVector DO
						IF res IS vyLongrealVec.tVector THEN
							WITH res: vyLongrealVec.tVector DO
								IF swap THEN vyLongrealVec.Div( res, v2, res ) ELSE vyLongrealVec.Div( res, res, v2 ) END;
							END;
						ELSIF res IS vyRealVec.tVector THEN
							WITH res: vyRealVec.tVector DO
								IF swap THEN vyRealVec.Div( res, v2, res ) ELSE vyRealVec.Div( res, res, v2 ) END;
								(*|res: vyLongintVec.tVector DO IF swap THEN vyLongintVecDiv(res,v2,res) ELSE vyLongintVecDiv(res,res,v2) END;
			|res: vyIntVec.tVector DO IF swap THEN vyIntVecDiv(res,v2,res) ELSE vyIntVecDiv(res,res,v2) END*)
							END;
						ELSE
						END
					END;
				ELSE
				END
			END;
		ELSE
		END
	END Div;

	PROCEDURE AddPtr*( VAR res: ANY;  p1, p2: ANY );
	VAR resB: vyBase.tData;
	BEGIN
		IF p1 IS vyBase.tData THEN
			WITH p1: vyBase.tData DO
				IF p2 IS vyBase.tData THEN
					WITH p2: vyBase.tData DO Add( resB, p1, p2 );  res := resB
					END;
				ELSE
				END
			END;
		ELSE
		END
	END AddPtr;

	PROCEDURE SubPtr*( VAR res: ANY;  p1, p2: ANY );
	VAR resB: vyBase.tData;
	BEGIN
		IF p1 IS vyBase.tData THEN
			WITH p1: vyBase.tData DO
				IF p2 IS vyBase.tData THEN
					WITH p2: vyBase.tData DO Sub( resB, p1, p2 );  res := resB
					END;
				ELSE
				END
			END;
		ELSE
		END
	END SubPtr;

	PROCEDURE MultPtr*( VAR res: ANY;  p1, p2: ANY );
	VAR resB: vyBase.tData;
	BEGIN
		IF p1 IS vyBase.tData THEN
			WITH p1: vyBase.tData DO
				IF p2 IS vyBase.tData THEN
					WITH p2: vyBase.tData DO Mult( resB, p1, p2 );  res := resB
					END;
				ELSE
				END
			END;
		ELSE
		END
	END MultPtr;

	PROCEDURE DivPtr*( VAR res: ANY;  p1, p2: ANY );
	VAR resB: vyBase.tData;
	BEGIN
		IF p1 IS vyBase.tData THEN
			WITH p1: vyBase.tData DO
				IF p2 IS vyBase.tData THEN
					WITH p2: vyBase.tData DO Div( resB, p1, p2 );  res := resB
					END;
				ELSE
				END
			END;
		ELSE
		END
	END DivPtr;

	PROCEDURE NegLR( x: FLOAT64 ): FLOAT64;
	BEGIN
		RETURN -x
	END NegLR;

	PROCEDURE NegR( x: FLOAT32 ): FLOAT32;
	BEGIN
		RETURN -x
	END NegR;

	PROCEDURE NegL( x: SIGNED32 ): SIGNED32;
	BEGIN
		RETURN -x
	END NegL;

	PROCEDURE NegI( x: SIGNED16 ): SIGNED16;
	BEGIN
		RETURN -x
	END NegI;

	PROCEDURE Neg*( VAR res: vyBase.tData;  v1: vyBase.tData );
	BEGIN
		WITH v1: vyBase.tVector DO
			vyTypes.Copy( v1, res );
			IF res IS vyLongrealVec.tVector THEN
				WITH res: vyLongrealVec.tVector DO vyLongrealVec.DoOp1( res, NegLR )
				END;
			ELSIF res IS vyRealVec.tVector THEN
				WITH res: vyRealVec.tVector DO
					vyRealVec.DoOp1( res, NegR )
					(*|res: vyLongintVec.tVector DO vyLongintVec.DoOp1(rs,NegL);
		|res: vyIntVec.tVector DO vyIntVec.DoOp1(rs,NegI);*)
				END;
			ELSE
			END
		END
	END Neg;

	PROCEDURE NegPtr*( VAR res: ANY;  p1: ANY );
	VAR resB: vyBase.tData;
	BEGIN
		IF p1 IS vyBase.tData THEN
			WITH p1: vyBase.tData DO Neg( resB, p1 );  res := resB
			END;
		ELSE
		END

	END NegPtr;

	PROCEDURE AssignPointer*( x: SIGNED32;  adr: SIGNED32;  name: ARRAY OF CHAR ): BOOLEAN;
	VAR xx: vyPointerVec.tLONGINT;  p: ANY;
	BEGIN
		IF adr = 0 THEN xx := vyPointerVec.NewLongintObject( x );  vyName.RegisterNamed( xx, name );  RETURN TRUE
		ELSE
			p := SYSTEM.VAL( ANY, adr );
			IF p IS vyPointerVec.tLONGINT THEN
				WITH p: vyPointerVec.tLONGINT DO p.i := x;  RETURN TRUE
				END;
			ELSE RETURN AssignPointer( x, 0, name )
			END
		END;
		RETURN FALSE
	END AssignPointer;

	PROCEDURE Assign*( this: Objects.Object;  res: Objects.Object ): BOOLEAN;
	VAR v: vyBase.tData;
		(* res --> this *)
	BEGIN
		IF res IS vyBase.tVector THEN
			WITH res: vyBase.tVector DO
				IF this IS vyBase.tData THEN
					WITH this: vyBase.tData DO ConvertSize( res, this, FALSE )
					END;
				ELSE
				END;
				IF this IS vyBase.tVector THEN
					WITH this: vyBase.tVector DO
						Convert( res, this, v );
						IF v IS vyLongrealVec.tVector THEN
							WITH v: vyLongrealVec.tVector DO vyLongrealVec.CopyData( v, this );  vyBase.Update( this );  RETURN TRUE;
							END;
						ELSIF v IS vyRealVec.tVector THEN
							WITH v: vyRealVec.tVector DO vyRealVec.CopyData( v, this );  vyBase.Update( this );  RETURN TRUE;
							END;
						ELSIF v IS vyIntVec.tVector THEN
							WITH v: vyIntVec.tVector DO vyIntVec.CopyData( v, this );  vyBase.Update( this );  RETURN TRUE;
							END;
						ELSIF v IS vyLongintVec.tVector THEN
							WITH v: vyLongintVec.tVector DO vyLongintVec.CopyData( v, this );  vyBase.Update( this );  RETURN TRUE
							END;
						END
					END;
				ELSE
				END
			END;
		ELSE
		END;
		RETURN FALSE
	END Assign;

	PROCEDURE AssignLReal*( x: FLOAT64;  adr: SIGNED32;  name: ARRAY OF CHAR ): BOOLEAN;
	VAR xx: vyLongrealVec.tLONGREAL;  p: ANY;
	BEGIN
		IF adr = 0 THEN xx := vyLongrealVec.NewLongrealObject( x );  vyName.RegisterNamed( xx, name );  RETURN TRUE
		ELSE
			p := SYSTEM.VAL( ANY, adr );
			IF p IS vyLongrealVec.tLONGREAL THEN
				WITH p: vyLongrealVec.tLONGREAL DO p.x := x;  RETURN TRUE
				END;
			ELSE RETURN AssignLReal( x, 0, name )
			END
		END;
		RETURN FALSE
	END AssignLReal;

	PROCEDURE AssignReal*( x: FLOAT32;  adr: SIGNED32;  name: ARRAY OF CHAR ): BOOLEAN;
	VAR xx: vyRealVec.tREAL;  p: ANY;
	BEGIN
		IF adr = 0 THEN xx := vyRealVec.NewRealObject( x );  vyName.RegisterNamed( xx, name );  RETURN TRUE
		ELSE
			p := SYSTEM.VAL( ANY, adr );
			IF p IS vyRealVec.tREAL THEN
				WITH p: vyRealVec.tREAL DO p.x := x;  RETURN TRUE
				END;
			ELSE RETURN AssignReal( x, 0, name )
			END
		END;
		RETURN FALSE
	END AssignReal;

	PROCEDURE AssignLongint*( x: SIGNED32;  adr: SIGNED32;  name: ARRAY OF CHAR ): BOOLEAN;
	VAR xx: vyLongintVec.tLONGINT;  p: ANY;
	BEGIN
		IF adr = 0 THEN xx := vyLongintVec.NewLongintObject( x );  vyName.RegisterNamed( xx, name );  RETURN TRUE
		ELSE
			p := SYSTEM.VAL( ANY, adr );
			IF p IS vyLongintVec.tLONGINT THEN
				WITH p: vyLongintVec.tLONGINT DO p.i := x;  RETURN TRUE
				END;
			ELSE RETURN AssignLongint( x, 0, name )
			END
		END;
		RETURN FALSE
	END AssignLongint;

	PROCEDURE AssignInt*( x: SIGNED16;  adr: SIGNED32;  name: ARRAY OF CHAR ): BOOLEAN;
	VAR xx: vyIntVec.tINTEGER;  p: ANY;
	BEGIN
		IF adr = 0 THEN xx := vyIntVec.NewIntegerObject( x );  vyName.RegisterNamed( xx, name );  RETURN TRUE
		ELSE
			p := SYSTEM.VAL( ANY, adr );
			IF p IS vyIntVec.tINTEGER THEN
				WITH p: vyIntVec.tINTEGER DO p.i := x;  RETURN TRUE
				END;
			ELSE RETURN AssignInt( x, 0, name )
			END
		END;
		RETURN FALSE
	END AssignInt;

END antsExpressionsObjects.
