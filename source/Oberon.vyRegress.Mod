MODULE vyRegress IN Oberon;
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
*)
(*! clean up and make prototype for extendibility. So far this is a mess *)
(*! data structure
Regression=
response:
regressors:
fit:
conf:
fitted:
residuals:
*)

IMPORT
	Texts, vyHostTexts, vyParser, vyBase, vyName,
	vyRealVec, vyTypes,
	vyDisplay2d, vyPort,  vyScatter2, vyLine, vyLinePlot,
	vyQFisher, MathL IN A2 (* ,vyCharts fuer Lutz*)
	, Out
	;

CONST
	idversion* = 	'vyRegress v0r0a2';
TYPE
	Real = vyBase.Real;
	tRegression = RECORD
		slope, intercept, errvar: LONGREAL;
		count: LONGINT;
		ymean, yssq: LONGREAL
	END;
	tFBandParameter = POINTER TO tFBandParameterDesc;
	tFBandParameterDesc = RECORD
		(vyLinePlot.tParameterDesc)
		Regression: tRegression;
		UpBand, F: LONGREAL
	END;

	tEstimator* = PROCEDURE ( Regressor, Response: vyBase.tData;   VAR Estimation: vyBase.tData);
	tConfidence* = PROCEDURE (Estimation: vyBase.tData;    VAR ConfidenceSet: vyBase.tData);

	VAR w: vyBase.TextsWriter;
	(* softstat hacks *)
	namex, namey: vyName.tNameArray;
	obx, oby: vyBase.tVector;    tempx, tempy: vyBase.Object;
	Fit, Resid: vyBase.tVector;
	para1, para2: tFBandParameter;
	xyPict, resPict: vyPort.Picture;

	level*: Real;
PROCEDURE SetEstimator* (Estimator: tEstimator;    Confidence: tConfidence);
END SetEstimator;
PROCEDURE WR (x: LONGREAL);    BEGIN vyHostTexts.WriteRealFix(w, SHORT(x), 8, 4, 0) END WR;
PROCEDURE WS (x: ARRAY OF CHAR);    BEGIN Texts.WriteString(w, x) END WS;

PROCEDURE ReportStattyp (VAR name: ARRAY OF CHAR;    VAR s: vyQFisher.Stattyp);
BEGIN vyHostTexts.Msg(name);   vyHostTexts.MsgSI('Nr of observations:', s.Count);
	vyHostTexts.MsgSR('Mean:', SHORT(s.Mean));
	IF s.Count > 1 THEN vyHostTexts.MsgSR('Std dev:', SHORT(MathL.sqrt(s.Ssq / (s.Count - 1)))) END
END  ReportStattyp;

PROCEDURE ReportRegression (VAR namey, namex: ARRAY OF CHAR;    par: tFBandParameter);
BEGIN
	Texts.WriteLn(w);   WS(namey);   WS(' = ');   	WR( par.Regression.slope); WS(' ');
	WS(namex);   WS(' + ');   WR( par.Regression.intercept);    WS(' + err');
	WS('       Var(err)=');   WR( par.Regression.errvar);    			Texts.WriteLn(w);    vyHostTexts.InsertLog(w.buf)
END  ReportRegression;

PROCEDURE FBand (x: Real;    para: vyLinePlot.tParameter): Real;
	VAR p: tFBandParameter;
BEGIN ASSERT (para IS tFBandParameter, vyBase.precc);    p := para(tFBandParameter);
	RETURN SHORT (p.Regression.intercept + p.Regression.slope * x +
	p.UpBand * MathL.sqrt(2 * p.F * p.Regression.errvar *
	(1 / p.Regression.count + (x - p.Regression.ymean) / p.Regression.yssq * (x - p.Regression.ymean)))
	)
END FBand;

PROCEDURE NewResidualsAndFit* (response, regressor: vyBase.tVector;   offs, slope: LONGREAL;
VAR residuals, fit: vyBase.tVector);
	VAR i, nrData: LONGINT;   curfit: Real;
BEGIN
	ASSERT(regressor IS vyRealVec.tVector , vyBase.precc);
	ASSERT( (regressor.nrData > 0), 101);
	nrData := regressor.nrData;
	IF residuals = NIL THEN
		residuals := vyRealVec.New(0);
		vyName.RegisterNamed(residuals, 'Residuals');    (*? register as object? *)
	END;    (*! do proper reuse of buffers *)
	IF fit = NIL THEN
		fit := vyRealVec.New(0);
		vyName.RegisterNamed(fit, 'Fit')
	END;    (*! do proper reuse of buffers *)
	FOR i := 0 TO nrData - 1 DO
		curfit := SHORT(offs + slope * vyTypes.VGetR (regressor, i));
		vyRealVec.Append(curfit, fit);
		vyRealVec.Append (vyTypes.VGetR (response, i) - curfit, residuals)
	END
END NewResidualsAndFit;

PROCEDURE CalcRegress (response, regressor: vyBase.tVector;    VAR regression: tRegression);
	VAR	XYSSQ: LONGREAL;    stx, sty: vyQFisher.Stattyp;    nrData, i: LONGINT;
BEGIN
	ASSERT(response.nrData = regressor.nrData, 100);
	nrData := response.nrData;
	XYSSQ := 0;    vyQFisher.initstat(stx);   	vyQFisher.initstat(sty);
	FOR i := 0 TO nrData - 1 DO
		vyQFisher.Addbistat(vyTypes.VGetR (response, i), vyTypes.VGetR (regressor, i), sty, stx, XYSSQ)
	END;
	ReportStattyp(namex, stx);   ReportStattyp(namey, sty);
	vyHostTexts.MsgSR('XYSSQ', SHORT(XYSSQ));
	regression.slope := XYSSQ / stx.Ssq;
	regression.intercept := sty.Mean - regression.slope * stx.Mean;
	regression.errvar := (sty.Ssq - regression.slope * XYSSQ) / (stx.Count - 2);
	regression.count := response.nrData;
	regression.ymean := sty.Mean;   regression.yssq := sty.Ssq
END CalcRegress;

PROCEDURE DoRegress* (response, regressor: vyBase.tVector;    inSim: BOOLEAN);
VAR
	Err: INTEGER;
	nrData, nans: LONGINT;
	minX, maxX, minY, maxY: Real;
	xyScatter, resScatter: vyScatter2.tLayer;
	regLine, nullLine: vyLine.tLayer;
	upBand, lowBand: vyLinePlot.tLayer;
	(*	ll:vyCharts.tLayer; (* fuer Lutz *) *)
	(*! check sequence of regressors in calculation and display *)
BEGIN ASSERT (response.nrData = regressor.nrData, 100);
	nrData := response.nrData;
	IF ~inSim THEN NEW(para1);    NEW(para2) END;
	CalcRegress(response, regressor, para1.Regression);
	ReportRegression(namey, namex, para1);

	NewResidualsAndFit(response, regressor, para1.Regression.intercept, para1.Regression.slope, Resid, Fit);
	para1.F := SHORT(vyQFisher.Qfisher(2, SHORT(nrData - 2), level, Err));   (*  F value *)
	(* Draw confidence bands. This curve is given by a function *)

	para1.UpBand := 1;    			para2^ := para1^;    	para2.UpBand := - 1;

	IF ~inSim THEN
		(*response.slink := regressor;   regressor.slink := NIL; *)regressor.slink := response;  response.slink := NIL;
		vyTypes.VGetMinMax(regressor , minX, maxX, nans);
		vyTypes.VGetMinMax(response , minY, maxY, nans);
		Out.String('regressor: '); Out.LongReal(minX, 8); Out.LongReal(maxX, 8); Out.Ln;
		Out.String('response: '); Out.LongReal(minY, 8); Out.LongReal(maxY, 8); Out.Ln;

		xyPict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d ( minX, minY, maxX - minX, maxY - minY));

		(*	xyPict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyPort.NewC2d ( minY, minY, maxY - minY, maxX - minX)); *)
		NEW (xyScatter);    (*vyScatter2.Open (xyScatter, response);  *)vyScatter2.Init (xyScatter, regressor); 		vyPort.AddLayer (xyPict, xyScatter);
		NEW (regLine);
		vyLine.Open (regLine, FALSE, FALSE, 0, 0, SHORT(para1.Regression.slope), SHORT(para1.Regression.intercept));
		vyPort.AddLayer (xyPict, regLine);
		NEW (upBand);    vyLinePlot.Open (upBand, NIL, minX, maxX, FBand, para1, 10);
		vyPort.AddLayer (xyPict, upBand);
		NEW (lowBand);    vyLinePlot.Open (lowBand, NIL, minX, maxX, FBand, para2, 10);
		vyPort.AddLayer (xyPict, lowBand);
		(* fuer Lutz *)
		(*		NEW(ll);vyCharts.OpenChart(ll,'ll',regressor,response); vyPort.AddLayer (xyPict, ll);*)
		(* Ende fuer Lutz*)

		Fit.slink := Resid;  Resid.slink := NIL;
		(*	Resid.slink := Fit;   Fit.slink := NIL;*)
		vyTypes.VGetMinMax(Fit , minX, maxX, nans);
		vyTypes.VGetMinMax( Resid , minY, maxY, nans);
		Out.String('fit: '); Out.LongReal(minX, 8); Out.LongReal(maxX, 8); Out.Ln;

		Out.String('resid: '); Out.LongReal(minY, 8); Out.LongReal(maxY, 8); Out.Ln;

		resPict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d ( minX, minY, maxX - minX, maxY - minY));
		(*	resPict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyPort.NewC2d ( minY, minY, maxY - minY, maxX - minX));*)
		NEW (resScatter);    (*vyScatter2.Open (resScatter, Resid);  *)vyScatter2.Init (resScatter, Fit); 		vyPort.AddLayer (resPict, resScatter);
		NEW (nullLine);   vyLine.Open (nullLine, FALSE, FALSE, 0, 0, 0, 0);  		vyPort.AddLayer (resPict, nullLine)
	ELSE
		vyPort.PictureUpdate (xyPict);    vyPort.PictureUpdate (resPict)
	END;
	vyHostTexts.InsertLog(vyHostTexts.w.buf)
END DoRegress;

PROCEDURE Regress*;    (*vs 0.1d0 gs *)
	(*! remove. This is for graphics test only *)
	VAR inSim: BOOLEAN;
	s: vyParser.Scanner;
	(*! check sequence of regressors in calculation and display *)
BEGIN
	(*inSim := (namex#'') & (namey#'');
	(*! replace by vyParser.NamedObject *)
	IF ~inSim THEN
	vyParser.OpenParScanner(s);
	IF ~(vyParser.Name(s,namey) & vyParser.Name(s,namex))
	THEN vyParser.MsgSyntax('WriteData','Response/12!;Regressor/12!');
	END;
	END;

	IF ~inSim & ((oby=NIL) & (obx=NIL)) THEN
	tempy:=vyName.Find(vyName.NameBase, namey);
	tempx:=vyName.Find(vyName.NameBase, namex);
	END;
	*)
	inSim := FALSE;
	vyParser.OpenParScanner(s);
	IF ~(vyParser.Name(s, namey) & vyParser.Name(s, namex))
		THEN vyParser.MsgSyntax('WriteData', 'Response/12!;Regressor/12!')
	END;

	tempy := vyName.Find(vyName.NameBase, namey);
	tempx := vyName.Find(vyName.NameBase, namex);

	IF (tempy = NIL) OR (tempx = NIL) THEN
		vyHostTexts.MsgSS('Did not find', namey);    vyHostTexts.MsgSS('Did not find', namex);
		RETURN
	ELSE obx := tempx(vyBase.tVector);   oby := tempy(vyBase.tVector) END;

	DoRegress(oby, obx, inSim)
END Regress;

BEGIN Texts.OpenWriter(w);
	namex := '';    namey := '';
	oby := NIL;    obx := NIL;
	Fit := NIL;
	Resid := NIL;
	level := 0.90;
END vyRegress.