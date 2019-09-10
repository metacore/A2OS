MODULE vyQuickDraw IN Oberon;
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

(*= a collection of simple plot routines used by vyStd2dLayer.tLayer*)

(*	history:
		9.8.95 md 0.0a1	alpha version
		03.07.95 11:15:11 md 0.0d0	created and Median implemented
*)

IMPORT
	vyTypes,
	vyHostDisplay :=vyGraphBase, vyGraphBase,vyPatterns,
	vyStd2dLayer;

CONST
	idversion*=	"vyQuickDraw v0r0a2";

	PROCEDURE Median*;
	(** vs 0.0d0 *)	(* md  03.07.95 11:15:35 *)
	VAR count: SIGNED32; med: FLOAT32; x, y: SIGNED16;
		BEGIN
		count := vyStd2dLayer.x.nrData;
		vyTypes.Sort (vyStd2dLayer.x);

		IF count MOD 2 = 0 THEN
			med := 0.5*(vyTypes.VGetR (vyStd2dLayer.x, (count-1) DIV 2) +
			vyTypes.VGetR (vyStd2dLayer.x, (count+1) DIV 2))
		ELSE
			med := vyTypes.VGetR (vyStd2dLayer.x, (count+1) DIV 2 - 1)
		END;

		vyHostDisplay.SetDisplayMode (vyHostDisplay.replace);
		vyHostDisplay.SetPatternJustification (vyHostDisplay.center, vyHostDisplay.top);
		vyHostDisplay.SetStringJustification (vyHostDisplay.center, vyHostDisplay.top);

		vyGraphBase.Point2dToPoint (med, 0, x, y);
		vyHostDisplay.PaintPat (x, y, vyPatterns.rhombus.sgn1);
		vyHostDisplay.PaintPat (x, y, vyPatterns.plus.sgn1);
		vyHostDisplay.String (x, y-6, "", "M");
	END Median;

END vyQuickDraw.

