MODULE dbgTestVec IN Oberon;
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



IMPORT Objects, vyBase, vyName, vyLongrealVec, vyRealVec, vyRandom;
	VAR lastrndmvec-: vyRealVec.tVector;
PROCEDURE LRConstVec128*;
	VAR v: vyLongrealVec.tVector;
BEGIN v := vyLongrealVec.NewFilledNamed(128, 1.2, 'LRConstVec128');
	Objects.NewObj := v
END LRConstVec128;

PROCEDURE RConstVec128*;
	VAR v: vyRealVec.tVector;
BEGIN v := vyRealVec.NewFilledNamed(128, 1.2, 'RConstVec128');
	Objects.NewObj := v
END RConstVec128;

PROCEDURE RRndmVec128*;
	VAR v: vyRealVec.tVector; VAR i: SIGNED32;
BEGIN v := vyRealVec.New(128);
	vyRealVec.SetLen(v, 128);
	FOR i := 0 TO 127 DO
		vyRealVec.Set(vyRandom.Uniform(), v, i)
	END;
	vyName.RegisterNamed(v, 'RRndmVec128');
	Objects.NewObj := v;
	lastrndmvec := v
END RRndmVec128;

PROCEDURE RRndm2dimVec128*;
	VAR v, w: vyRealVec.tVector; VAR i: SIGNED32;
BEGIN
	v := vyRealVec.New(128);
	w := vyRealVec.New(128);
	vyRealVec.SetLen(v, 128);
	vyRealVec.SetLen(w, 128);
	FOR i := 0 TO 127 DO
		vyRealVec.Set(vyRandom.Uniform(), v, i);
		vyRealVec.Set(vyRandom.Uniform(), w, i)
	END;
	v.slink := w;
	vyName.RegisterNamed(v, 'RRndm2dimVec128');
	Objects.NewObj := v;
	lastrndmvec := v
END RRndm2dimVec128;


PROCEDURE ChangeLastRndmVector*;
	VAR i: SIGNED32;

BEGIN
	IF lastrndmvec = NIL THEN RRndmVec128
	ELSE
		FOR i := 0 TO 127 DO
			vyRealVec.Set(vyRandom.Uniform(), lastrndmvec, i)
		END
	END;
	IF lastrndmvec # NIL THEN vyBase.Update(lastrndmvec) END
END ChangeLastRndmVector;

END dbgTestVec.

scr
Gadgets.Insert RefFrame dbgTestVec.RConstVec128 ~

Gadgets.Insert RefFrame dbgTestVec.LRConstVec128 ~ Gadgets.Insert RefFrame Real ~
Gadgets.Insert RefFrame ~
Select Ref Gadget
RefGadgets.Create dbgTestVec.RConstVec128 ~
RefGadgets.Create dbgTestVec.RRndmVec128 ~

Gadgets.Insert vyDistribution.New dbgTestVec.RConstVec128 ~
RefGadgets.Create  vyDistribution.New  ~

SpotRef.Insert  dbgTestVec.RConstVec128 ~
SpotRef.Insert  vyDistribution.New dbgTestVec.RConstVec128 ~

Gadgets.Insert   vyDistribution.New dbgTestVec.RConstVec128 ~
