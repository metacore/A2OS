MODULE vyxPlots IN Oberon;
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



IMPORT Objects, Display, vyLinks, vyBase, vyName,  vyRealVec,
	vyDisplay2d, vyPort,  vyHostStrings, vyParser;

CONST
	lines* = "vyCharts.New";
	points* = "vyScatter2.New";
	scatter1* = "vyScatter1.New";
	scatter2* = "vyScatter2.New";
	scatter3* = "vyScatter3.New";
	surface* = "vySurface.New";
	boxwhisker* = "vyBoxWhisker.New";
	lineplot* = "vyLinePlot.New";
	distribution* = "vyDistribution.New";
	maxmass* = "vyMaxMass.New";
	shorth* = "vyShorth.New";

PROCEDURE Register (VAR vx, vy: vyBase.tVector;  namex, namey: vyName.tNameArray): Objects.Object;
	VAR ref: vyLinks.Link; ob: Objects.Object;
BEGIN
	IF vx = NIL THEN vx := vyRealVec.New(0) END;  IF vy = NIL THEN vy := vyRealVec.New(0) END;
	vyName.Register(vyName.NameBase, vx, namex);  	vyName.Register(vyName.NameBase, vy, namey);
	vyLinks.InsertObj(ref, vy);  	vyLinks.InsertObj(ref, vx);
	vyLinks.MakeSLink(ref, ob);  RETURN ob
END Register;

PROCEDURE DoEmptyPlot (VAR id: ARRAY OF CHAR);
	VAR v: vyBase.tVector;  link: vyLinks.Link;
	i: INTEGER;   res: INTEGER;
BEGIN
	FOR i := 1 TO 3 DO
		v := vyRealVec.New(0);  	vyName.Register(vyName.NameBase, v, "empty");
		vyLinks.InsertObj(link, v)
	END;
	vyLinks.MakeSLink(link, Objects.NewObj);
	vyBase.CallWString("", id, "", FALSE, res);
	vyPort.AddLayer(vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d( 0, 0, 1, 1)), Objects.NewObj(vyPort.tLayer))
END DoEmptyPlot;

PROCEDURE NewPlot* (PlotId: ARRAY OF CHAR;  data: Objects.Object);
	VAR msg: Display.ConsumeMsg;
BEGIN
	msg.obj := data;
	DoEmptyPlot(PlotId);
	Objects.NewObj.handle(Objects.NewObj, msg)
END NewPlot;

PROCEDURE EmptyPlot*;
	VAR  sc: vyParser.Scanner;  name, id: ARRAY 32 OF CHAR;
BEGIN
	NEW(sc);
	vyParser.OpenParScanner(sc);
	IF vyParser.ExpectName(sc, name) THEN
		IF (name[0] # "v") OR (name[1] # "y") THEN
			id := "vy";  vyHostStrings.Append(id, name)
		ELSE
			COPY(name, id)
		END;
		vyHostStrings.Append(id, ".New");
		DoEmptyPlot(id)
	END
END EmptyPlot;

PROCEDURE Lines* (VAR vx, vy: vyBase.tVector;  namex, namey: vyName.tNameArray);
BEGIN
	NewPlot(lines, Register(vx, vy, namex, namey))
END Lines;

PROCEDURE Points* (VAR vx, vy: vyBase.tVector;  namex, namey: vyName.tNameArray);
BEGIN
	NewPlot(scatter2, Register(vx, vy, namex, namey))
END Points;

PROCEDURE AddData* (x, y: REAL;  vx, vy: vyBase.tVector);
BEGIN	vyRealVec.Append(x, vx);  vyRealVec.Append(y, vy) END AddData;

PROCEDURE AddDataArray* (x, y: ARRAY OF REAL;  len: INTEGER;  vx, vy: vyBase.tVector);
	VAR i : INTEGER;
BEGIN	FOR i := 1 TO len DO vyRealVec.Append(x[i - 1], vx);  vyRealVec.Append(y[i - 1], vy)	END  END AddDataArray;

PROCEDURE Update* (v: vyBase.tVector);
BEGIN	vyBase.Update(v) END Update;

END vyxPlots.

System.Free vyxPlots * ~
