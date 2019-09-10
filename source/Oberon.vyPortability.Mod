MODULE vyPortability IN Oberon;	(** fof  **)
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


(*
	(c) Project Voyager
	(c) Felix Friedrich
*)

(* this module contains all items that either
	a) need a platform (Windows/Linux/Aos/Native) specific implementation
	b) exist for some platforms only,  for others noop procedures (or so) are plugged in
	c) have different interfaces on different platforms, for standardized use in Voyager modules.
*)



IMPORT Display,Display3,Pictures,Modules IN A2,SYSTEM;

TYPE
	displayBuffer* = POINTER TO displayBufferDesc;
	displayBufferDesc= RECORD
	END;

	Type* = Modules.TypeDesc;


PROCEDURE DisplayAvailable*(): BOOLEAN; (* used if several displays can be available, to test if display still alive *)
BEGIN
	RETURN TRUE;
END DisplayAvailable;

PROCEDURE DisplayWidth*(): SIGNED32;
BEGIN
	RETURN Display.Width;
END DisplayWidth;

PROCEDURE DisplayHeight*(): SIGNED32;
BEGIN
	RETURN Display.Height;
END DisplayHeight;

PROCEDURE DisplayUpdate*; (* for bluebottle, needed in native? *)
BEGIN
	Display.Update;
END DisplayUpdate;



PROCEDURE OpenBuffer*(VAR db: displayBuffer; VAR w,h: SIGNED16);
BEGIN	db := NIL; (* indicates that buffer is unusable, that is for vyGraphBase0 => Images are used exclusively *)
END OpenBuffer;

PROCEDURE CloseBuffer*(db: displayBuffer);
END CloseBuffer;

PROCEDURE WriteBuffer*(db: displayBuffer; m: Display3.Mask; atx,aty: SIGNED16);
END WriteBuffer;

PROCEDURE LockOberon*; (* Locks the Oberon.Loop to stop receiveing Display-messages , e.g. while opening new displays, used in Windows *)
END LockOberon; (* not necessary for native *)

PROCEDURE UnlockOberon*; (* Unlocks the Oberon.Loop *)
END UnlockOberon; (* not necessary for native *)

PROCEDURE StretchedPict*(M: Display3.Mask; pict: Pictures.Picture; x,y,w,h,dx,dy,dw,dh,mode: SIGNED16);
END StretchedPict; (* not implemented for native. Since images are used as double buffer, that's no hard restriction (but: no printing) *)

PROCEDURE TypeOf*(p: ANY): Type;
VAR type: Type;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, p)-4, type);
	SYSTEM.GET(SYSTEM.VAL(ADDRESS, type)-4, type);
	RETURN type
END TypeOf;


 (*--------------- preproc end ----------------*)

END vyPortability.
