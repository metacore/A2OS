MODULE RandomTest IN Oberon; 	(** gs  **)
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



IMPORT vyParser, vyRandom, vyLongrealVec, vyBase, vyName;

PROCEDURE Test3*;
	VAR i, len: LONGINT;  sc: vyParser.Scanner;  l1, l2, l3: vyBase.tVector;
BEGIN
	NEW(sc);  vyParser.OpenParScanner(sc);
	IF vyParser.ExpectNumber(sc, len) THEN
		l1 := vyLongrealVec.New(0);
		l2 := vyLongrealVec.New(0);
		l3 :=  vyLongrealVec.New(0);
		FOR i := 1 TO len DO
			vyLongrealVec.Append(vyRandom.Uniform(), l1);
			vyLongrealVec.Append(vyRandom.Uniform(), l2);
			vyLongrealVec.Append(vyRandom.Uniform(), l3)
		END;
		vyName.RegisterNamed(l1, "v1");  vyName.RegisterNamed(l2, "v2"); vyName.RegisterNamed(l3, "v3")
	END
END Test3;


END RandomTest.

RandomTest.Test3 1000 ~
Voyager.Show v1 v2 v3 ~

vyRandu.Install ~
vyRandParksMiller.Install ~
vyRan1.Install ~