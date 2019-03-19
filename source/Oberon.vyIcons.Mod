MODULE vyIcons IN Oberon;
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



IMPORT Objects, Icons,  vyHostTexts, vyParser, vyName, vyBase, Links;


PROCEDURE DoMakeIcon (myobj: vyBase.Object;  idname: ARRAY OF CHAR);
	VAR obj: Objects.Object;  attrmsg: Objects.AttrMsg;  icon: Icons.Icon;
BEGIN
	IF myobj # NIL THEN
		NEW(icon);
		Icons.MakeIcon(icon, idname, NIL);
		obj := icon;

		attrmsg.id := Objects.set;  attrmsg.name := "Name";
		attrmsg.class := Objects.String;  COPY(idname, attrmsg.s);  attrmsg.res := - 1;
		obj.handle(obj, attrmsg);

		Links.SetLink(obj, "Value", myobj);

		vyHostTexts.InsertGadget(obj)
	END

END DoMakeIcon;


PROCEDURE MakeIcon*;
	VAR sc: vyParser.Scanner;  idname: vyName.tNameArray;  myobj: vyBase.Object;
BEGIN
	NEW(sc);
	vyParser.OpenParScanner(sc);
	WHILE vyParser.Name(sc, idname) DO
		myobj :=  vyName.Find(vyName.NameBase, idname);
		DoMakeIcon(myobj, idname)
	END
END MakeIcon;

END vyIcons.

System.Free vyIcons ~
