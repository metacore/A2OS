MODULE antsArrayConversions IN Oberon;   (** fof  **)
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



(* central point where decisions are made if loaded object is of type IMAGE or of type PICTURE,
difference of these two formats is mainly speed and accesibility of colors,
PICTURE is indexed color format
IMAGE is mainly true color *)

IMPORT antsArrayImages, antsArrayPictures, Files, antsCommands, antsToolbox, Strings, Objects, Links, aM := antsMessages,
	antsSecurity, vyBase, vyName, vyTracking, Effects, Pictures, Display, antsArrayObjects, antsArrayPictures16;

	PROCEDURE getSuffix( name: ARRAY OF CHAR;  VAR suffix: ARRAY OF CHAR );
	VAR lastptpos, end: SIGNED32;  i: SIGNED32;
	BEGIN
		suffix[0] := 0X;  i := 0;  lastptpos := -1;
		WHILE (name[i] # 0X) DO
			IF name[i] = "." THEN lastptpos := i END;
			INC( i )
		END;
		end := i;  i := lastptpos + 1;
		WHILE (i < end) DO suffix[i - lastptpos - 1] := Strings.UpperCh( name[i] );  INC( i ) END
	END getSuffix;

	PROCEDURE finish( VAR f: Files.File;  name: ARRAY OF CHAR );
	VAR suffix: ARRAY 256 OF CHAR;
		obj: antsArrayObjects.tObject;  pobj: antsArrayPictures16.tObject;
	BEGIN
		IF f = NIL THEN RETURN END;
		getSuffix( name, suffix );
		IF (suffix = "GIF") OR (suffix = "PICT") THEN antsArrayPictures.finishFile( f, name )
		ELSIF suffix = "PGM" THEN
			antsArrayObjects.finishload( f, name );  obj := antsArrayObjects.loadedobj;
			IF obj = NIL THEN RETURN END;
			WITH obj: antsArrayObjects.tINTEGERObject DO
				antsArrayPictures16.Gen;  pobj := Objects.NewObj( antsArrayPictures16.tObject );
				antsArrayPictures16.FromArray( pobj, obj )
			END;
			antsSecurity.Halt( "not yet supported" )
		ELSE  (* BMP,ICO,IFF,JPG,PCX,PPM,PSD,TGA,XBM,XPM *)
			antsArrayImages.finishFile( f, name )
		END
	END finish;

	PROCEDURE LoadDialoged*;
	BEGIN
		antsCommands.InitScan( "" );  antsToolbox.FileOpen( finish, "Pictures (GIF,PICT,BMP,ICO,IFF,JPG,PCX,PPM,PSD,TGA,XBM,XPM,PGM)", "*.GIF;*.PICT;*.BMP;*.ICO;*.IFF;*.JPG;*.JPEG;*.PCX;*.PPM;*.PSD; *.TGY;*.XBM;*.XPM;*.PGM" )
	END LoadDialoged;

	PROCEDURE Grey*;
	VAR obj: vyBase.Object;  name: vyName.tNameArray;  depth: SIGNED32;
	BEGIN
		antsCommands.InitScan( "from=OBJ to=NAME depth=INT ~# Attach Array  with name <to> to Image or Picture  <from> " );
		IF antsCommands.ExpectObject( "from", obj ) & antsCommands.ExpectName( "to", name ) &
		    antsCommands.ExpectNumber( "depth", depth ) THEN
			IF obj IS antsArrayPictures.tObject THEN
				WITH obj: antsArrayPictures.tObject DO antsArrayPictures.DoToArray( obj, depth, name );
				END;
			ELSIF obj IS antsArrayImages.tObject THEN
				WITH obj: antsArrayImages.tObject DO antsArrayImages.DoToArray( obj, depth, name )
				END;
			ELSE antsSecurity.Halt( "Can't convert, wrong format" )
			END
		END
	END Grey;

	PROCEDURE Put*;
	VAR msg: antsArrayPictures.setPictMsg;  obj: vyBase.Object;  keys: SET;  dx, dy: SIGNED16;  pict: Pictures.Picture;  i, r, g, b: SIGNED16;
		copy: antsArrayObjects.tINTEGERArray;  orig: Objects.Object;
	BEGIN
		antsCommands.InitScan( "from=OBJ ~# Interactively put obj <from> to some Port" );
		IF antsCommands.ExpectObject( "from", obj ) THEN
			IF obj IS antsArrayPictures.tObject THEN
				WITH obj: antsArrayPictures.tObject DO
					NEW( pict );  Pictures.Create( pict, obj.pict.width, obj.pict.height, obj.pict.depth );
					Pictures.Copy( obj.pict, pict, 0, 0, obj.pict.width, obj.pict.height, 0, 0, obj.pict.width, obj.pict.height,
										    Display.replace );
					FOR i := 0 TO 255 DO Pictures.GetColor( obj.pict, i, r, g, b );  Pictures.SetColor( pict, i, r, g, b ) END;
					msg.pict := pict;  vyTracking.TrackMouseCont( keys, dx, dy, Effects.PointHand );
					antsToolbox.MsgToTypedXY( dx, dy, msg, "antsViews.tLayerDesc" );
					IF msg.changed # NIL THEN  (* now look for original array, maybe we changed the sampling array *)
						Links.GetLink( msg.changed, "orig", orig );
						IF orig # NIL THEN
							WITH orig: antsArrayObjects.tINTEGERObject DO
								antsArrayObjects.CopyII( msg.changed( antsArrayObjects.tINTEGERObject ).A, copy, 0, 0,
																		 msg.changed( antsArrayObjects.tINTEGERObject ).w,
																		 msg.changed( antsArrayObjects.tINTEGERObject ).h, 0, 0 );
								antsArrayObjects.EmbedINTEGERArray( copy, orig )
							END
						END
						(*
				vyName.GetObjId(msg.changed,name);
				(* name := msg.changed; *)
				Strings.Append(name,"O");
				chobj := vyName.FindObj(name);
				Out.Ln; Out.String("Trying to change "); Out.String(name);
				IF chobj # NIL THEN
				Out.Ln; Out.String("Found Orig");
				WITH chobj: antsArrayObjects.tINTEGERObject DO
				antsArrayObjects.CopyII(msg.changed(antsArrayObjects.tINTEGERObject).A,copy,0,0,msg.changed(antsArrayObjects.tINTEGERObject).w,
				msg.changed(antsArrayObjects.tINTEGERObject).h,0,0);
				antsArrayObjects.EmbedINTEGERArray(copy,chobj);
				END;
				END;
				*)
					END
				END;
			ELSE aM.eS( "Can't put, wrong format" )
			END

		END
	END Put;

BEGIN
	aM.launch;
END antsArrayConversions.
antsArrayConversions.LoadDialoged myname ~
Voyager.Show myname as antsViews ~
antsArrayConversions.Grey myname myarray 10 ~
antsArrayConversions.Put myname ~
