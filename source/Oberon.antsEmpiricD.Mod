MODULE antsEmpiricD IN Oberon;  	(* gs  **)
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



(*= generic definition module for types used in any empiric distribution module *)
IMPORT antsArrayObjects, vyBase, aM := antsMessages;

TYPE

	EmpiricalDistribution* = POINTER TO EDDesc;   (* abstract type for some empirical distributions *)
	EDDesc* = RECORD END;

	tParameter* = POINTER TO tParameterDesc;   (*=  output parameter for empirical distribution *)
	tParameterDesc* = RECORD (vyBase.ObjDesc)
		ED*: EmpiricalDistribution;   (*= empirical distribution on set *)
		CEDo*: EmpiricalDistribution;    (*= empirical distribution on coding(+) set (called "odd")*)
		CEDe*: EmpiricalDistribution;   (*= empirical distribution on coding (-) set (called "even") *)
		A*: antsArrayObjects.tINTEGERObject;    (*= passed through Array*)
		x*, y*, w*, h*: LONGINT;   (*= empirical distribution referres to this region *)
	END;


BEGIN aM.launch;
END antsEmpiricD.
