MODULE vyScatter IN Oberon; 		(*vs 0.0a1 md   09.08.95 *)
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
This is an alpha test version used for early exploration only. Please do
not redistribute. Report any problems as soon as possible to
voyager@statlab.uni-heidelberg.de  *)

(*= 	Contents	discriminator for the 3 different scatter plots*)

IMPORT	vyHostTexts, vyBase, vyScatter1, vyScatter2, vyScatter3;

CONST
	idversion* = 	"vyScatter v0r0a2";

PROCEDURE ShowP*;
BEGIN
	IF vyBase.parameterCount = 1 THEN vyScatter1.ShowP
	ELSIF vyBase.parameterCount = 2 THEN vyScatter2.ShowP
	ELSIF vyBase.parameterCount = 3 THEN vyScatter3.ShowP
	END
END ShowP;


BEGIN
	vyHostTexts.Note(vyHostTexts.cAlert, idversion)
END vyScatter.