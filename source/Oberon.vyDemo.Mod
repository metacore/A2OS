MODULE vyDemo IN Oberon;
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


(* 	Contents	Demo extension *)

IMPORT
	vyHostTexts,
	In,
	vyRegress;

CONST
	idversion* = 	"vyDemo v0r0d3";

PROCEDURE SetLevel*;
	VAR x: REAL;
BEGIN
	In.Open;  In.Real (x);
	IF In.Done THEN vyRegress.level := x;
		vyHostTexts.MsgSR ("Level = ", vyRegress.level);
		vyRegress.Regress
	ELSE vyHostTexts.Msg ("error in In: doesn't got a real number") END
END SetLevel;

END vyDemo.