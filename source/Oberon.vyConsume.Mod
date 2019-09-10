MODULE vyConsume IN Oberon;
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


(*	(c) Project Voyager, StatLab Heidelberg
(c) G.Sawitzki, StatLab Heidelberg
(c) M. Diller, F.Friedrich, StatLab Heidelberg
*)

(*! remove SLinks *)

IMPORT Display, Objects, TextGadgets, Texts, vyBase, vyLinks, vyName, vyRealVec, vyReadMatrix;

TYPE
	tConvProc* = PROCEDURE ( t: Texts.Text ): vyLinks.Link;
VAR
	datafromtext*: tConvProc;

	PROCEDURE TableFromText( t: Texts.Text ): vyLinks.Link;
	VAR obj: vyLinks.Link;  C, temp: vyReadMatrix.ListItem;  i: SIGNED32;
	BEGIN
		vyReadMatrix.ReadMatrix( C, FALSE , FALSE , t, 0, MAX( SIGNED32 ) );
		IF C = NIL THEN RETURN NIL END;
		i := 0;  temp := C;
		WHILE i < C.col DO
			vyLinks.InsertObj( obj, temp.obj );  INC( i );
			IF i < C.col THEN temp := temp.link( vyReadMatrix.ListItem ) END
		END;
		RETURN obj
	END TableFromText;

	PROCEDURE VectorFromText( VAR t: Texts.Text ): vyLinks.Link;
	VAR v: vyBase.tVector;  sc: Texts.Scanner;  obj: vyLinks.Link;
	BEGIN
		v := vyRealVec.New( 0 );  Texts.OpenScanner( sc, t, 0 );  Texts.Scan( sc );
		IF (sc.class # Texts.Real) & (sc.class # Texts.LongReal) & (sc.class # Texts.Int) THEN sc.eot := TRUE END;
		WHILE (~sc.eot) DO
			CASE sc.class OF
			Texts.Real:
					vyRealVec.Append( sc.x, v )
			| Texts.LongReal:
					vyRealVec.Append( SHORT( sc.y ), v )
			| Texts.Int:
					vyRealVec.Append( sc.i, v )
			END;
			Texts.Scan( sc );
			IF (sc.class # Texts.Real) & (sc.class # Texts.LongReal) & (sc.class # Texts.Int) THEN sc.eot := TRUE END
		END;
		vyLinks.InsertObj( obj, v );  RETURN obj
	END VectorFromText;

	PROCEDURE DataFromText*( VAR t: Texts.Text ): vyLinks.Link;
	BEGIN
		RETURN datafromtext( t )
	END DataFromText;

	PROCEDURE SetTableFromText*;
	BEGIN
		datafromtext := TableFromText
	END SetTableFromText;

	PROCEDURE DataFromTextGadget*( M: Display.ConsumeMsg ): Objects.Object;
	VAR obj1: Objects.Object;  obj: vyLinks.Link;  v: vyBase.tVector;  t: Texts.Text;  mobj: Objects.Object;
		F: TextGadgets.Frame;
	BEGIN
		mobj := M.obj;
		WHILE (mobj # NIL ) & (mobj IS TextGadgets.Frame) DO
			F := mobj( TextGadgets.Frame );  v := vyRealVec.New( 0 );  t := F.text;
			IF obj = NIL THEN obj := DataFromText( t ) ELSE vyLinks.InsertLastLink( obj, DataFromText( t ) ) END;
			mobj := mobj.slink
		END;
		vyLinks.MakeSLink( obj, obj1 );  RETURN obj1
	END DataFromTextGadget;

	PROCEDURE DataByNamedGadget*( VAR M: Display.ConsumeMsg ): Objects.Object;
	VAR obj1: Objects.Object;  obj: vyLinks.Link;  v: vyBase.Object;  mobj: Objects.Object;  amsg: Objects.AttrMsg;
		name: vyName.tNameArray;
	BEGIN
		obj1 := NIL;  mobj := M.obj;
		WHILE (mobj # NIL ) DO
			amsg.name := "Name";  amsg.id := Objects.get;  amsg.res := -1;  mobj.handle( mobj, amsg );
			IF (amsg.res >= 0) THEN
				COPY( amsg.s, name );  v := vyName.Find( vyName.NameBase, name );
				IF v # NIL THEN vyLinks.InsertObj( obj, v ) END
			END;
			mobj := mobj.slink
		END;
		IF obj1 # NIL THEN vyLinks.MakeSLink( obj, obj1 ) END;
		RETURN obj1
	END DataByNamedGadget;

	PROCEDURE GetText( obj: Objects.Object ): Texts.Text;
	VAR lmsg: Objects.LinkMsg;
	BEGIN
		(*! handle chain of objects *)
		lmsg.name := "Text";  lmsg.id := Objects.get;  lmsg.res := -1;  obj.handle( obj, lmsg );
		IF (lmsg.res >= 0) & (lmsg.obj # NIL ) & (lmsg.obj IS Texts.Text) THEN RETURN lmsg.obj( Texts.Text ) END;
		lmsg.name := "Model";  lmsg.id := Objects.get;  lmsg.res := -1;  obj.handle( obj, lmsg );
		IF (lmsg.res >= 0) & (lmsg.obj # NIL ) & (lmsg.obj IS Texts.Text) THEN RETURN lmsg.obj( Texts.Text ) ELSE RETURN NIL END

	END GetText;

	PROCEDURE DataFromMsg*( VAR M: Display.ConsumeMsg;  VAR t: Objects.Object ): Objects.Object;
	VAR obj: Objects.Object;  tloc: Texts.Text;
	BEGIN
		t := NIL;
		IF M.obj IS TextGadgets.Frame THEN t := M.obj( TextGadgets.Frame ).text;  RETURN DataFromTextGadget( M )
		ELSE
			obj := DataByNamedGadget( M );
			IF obj = NIL THEN
				tloc := GetText( M.obj );  t := tloc;
				IF tloc # NIL THEN vyLinks.MakeSLink( DataFromText( tloc ), obj ) END
			END;
			RETURN obj
		END
	END DataFromMsg;

	PROCEDURE DataFromObj*( obj: Objects.Object;  VAR t: Objects.Object ): Objects.Object;
	VAR tloc: Texts.Text;  ret: Objects.Object;
	BEGIN
		t := NIL;
		IF obj IS TextGadgets.Frame THEN
			WITH obj: TextGadgets.Frame DO
				tloc := obj.text;  t := tloc;  vyLinks.MakeSLink( DataFromText( obj.text ), ret );  RETURN ret
			END;
		ELSIF obj IS Texts.Text THEN
			WITH obj: Texts.Text DO
				t := obj;  vyLinks.MakeSLink( DataFromText( obj ), ret );  RETURN ret

				(*! add TextFields etc*)
			END;
		ELSE
			tloc := GetText( obj );  t := tloc;
			IF t # NIL THEN vyLinks.MakeSLink( DataFromText( tloc ), ret );  RETURN ret END;
			RETURN NIL
		END
	END DataFromObj;

BEGIN
	SetTableFromText
END vyConsume.