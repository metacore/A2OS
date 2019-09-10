MODULE ants IN Oberon; 	(** fof  **)
(* collection of ants standard commands *)

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


IMPORT antsCommands, vyLinks, vyBase, Modules, Strings, aM := antsMessages, antsArrayObjects, vyLongrealVec, Objects, Links, antsToolbox,
	antsReadWrite, vyPort,antsFctVector,Texts,Gadgets,antsOnTheFly,SYSTEM;

	VAR (* some globals *)
	RR: antsReadWrite.Rider;

PROCEDURE Show*;
	VAR link: vyLinks.Link;  obj: vyBase.Object;  plotname, temp: ARRAY 256 OF CHAR;  objcount: SIGNED16;  plotmod: Modules.Module;  b: BOOLEAN;
BEGIN
	antsCommands.InitScan("obj=OBJ [plot=NAME| as NAME]");
	objcount := 0;
	WHILE antsCommands.GetObject("obj", obj) DO vyLinks.InsertObj(link, obj);  INC(objcount) END;
	IF objcount > 0 THEN
		IF antsCommands.GetName("plot", plotname) THEN
			IF plotname = "as"THEN b := antsCommands.GetName("plot", plotname) END;
			COPY(plotname, temp);
			plotmod := Modules.ThisMod(temp);
			IF (plotmod = NIL) OR (SYSTEM.VAL(ANY,Modules.ThisCommand(plotmod, "ShowP")) = NIL) THEN (* try Voyager *)
				temp := "vy";  Strings.Append(temp, plotname);  plotmod := Modules.ThisMod(temp)
			END;
			IF (plotmod = NIL) OR (SYSTEM.VAL(ANY,Modules.ThisCommand(plotmod, "ShowP")) = NIL) THEN (* try Ants *)
				temp := "ants";  Strings.Append(temp, plotname);  plotmod := Modules.ThisMod(temp)
			END;
			IF plotmod = NIL THEN   aM.SS("Unknown plotname:", plotname);  RETURN END
		ELSE
			temp := "antsPlots"
		END;
		vyBase.Show(link, objcount, temp)
	END
END Show;

PROCEDURE getTimeSeries (x, y: SIGNED32;  o: Objects.Object;  link: Objects.Object);
	VAR data: Objects.Object;   row: SIGNED32;   msg: vyPort.AdjustCoordMsg;  pos: SIGNED32;
BEGIN
	Links.GetLink(link, "data", data);
	WITH o: antsArrayObjects.tObject DO
		IF (x >= o.w) OR (y >= o.h) THEN RETURN END;
		WITH data: vyLongrealVec.tVector DO
			row :=  y * o.w + x ;
			pos := RR.Pos();  RR.ReadRowX(data, row);  RR.SetPos(pos);
			IF data # NIL THEN
				vyBase.Update(data);
				vyBase.ForUsersHandle( data, msg )
			END
		END
	END
END getTimeSeries;

PROCEDURE GetBrainTimeSeries*;
	VAR data: vyBase.Object;  filename: ARRAY 256 OF CHAR;  obj: Objects.Object;
BEGIN
	antsCommands.InitScan("filename=STR data=OBJ");
	IF antsCommands.ExpectString( "filename", filename ) & antsCommands.ExpectObject(  "data", data ) THEN
		vyBase.NewObj;  obj := Objects.NewObj;
		IF ~RR.Old(filename) THEN aM.SS("Can't open ", filename);  RETURN END;
		RR.ReadType;
		Links.SetLink(obj, "data", data);
		antsToolbox.InteractiveDo(obj, getTimeSeries);
		RR.Close
	END
END GetBrainTimeSeries;

PROCEDURE GetRowCol*;
	(* Command to copy interactively chosen row and column into vectors row, col, write row number / column number into r,c (vyLongrealVec.tLONGREAL)
	if not NIL *)
	VAR   		row, col: vyBase.Object;        		r, c: vyBase.Object;
BEGIN
	antsCommands.InitScan("row=OBJ col=OBJ [r=OBJ c=OBJ]");
	IF antsCommands.ExpectObject("row", row) &
		antsCommands.ExpectObject("col",  col) THEN
		IF antsCommands.GetObject("r",  r) & antsCommands.GetObject("c", c) THEN
		ELSE
			r := NIL;        		c := NIL
		END;
		antsArrayObjects.InteractiveGetRowCol(row(vyBase.tVector), col(vyBase.tVector), r, c);
		vyBase.Update(row);        		vyBase.Update(col)
	END
END GetRowCol;

PROCEDURE NewVec*;
BEGIN
	antsFctVector.NewVec;
END NewVec;

PROCEDURE RCompileE*; (*replace part of file with text from gadget, compile and execute command*)
VAR name,begPat,endPat,module,cmd: ARRAY 256 OF CHAR; obj: Objects.Object;
BEGIN
	antsCommands.InitScan("replace=NAME begPat=STR endPat=STR module=STR [cmd=NAME]");
	IF antsCommands.ExpectName("replace",name) & antsCommands.ExpectString("begPat",begPat)
	& antsCommands.ExpectString("endPat",endPat) & antsCommands.ExpectString("module",module) THEN
		IF ~antsCommands.GetName("cmd",cmd) THEN cmd := "" END;
		obj := Gadgets.FindObj(Gadgets.context,name);
		IF obj # NIL THEN Links.GetLink(obj,"Model",obj) END;
		IF (obj#NIL) & (obj IS Texts.Text) THEN
			IF antsOnTheFly.CompileText(obj(Texts.Text),module,cmd,begPat,endPat) THEN aM.dS("compiled ok");END;
		ELSE
			aM.eSS("Expected Texts.Text in context with name=",name);
		END;
	END;
END RCompileE;


BEGIN aM.launch; NEW(RR);
END ants.

ants.Show obj as LinePlot ~
ants.Show obj plot = LinePlot ~
ants.Show obj LinePlot ~
ants.Show obj ~

antsFctVector.NewVec data 1 ~
ants.GetTimeSeries bintest data ~
ants.GetTimeSeries  "angie/private/Orig3T"data ~
ants.Show data ~

System.Free ants ~

ants/src/antsReadWrite.Mod
