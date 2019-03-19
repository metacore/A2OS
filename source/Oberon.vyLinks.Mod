MODULE vyLinks IN Oberon;
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


(*=
The Links module manage a set of references to objects for the objects.
Module vyLinks corresponds to S3 Links, but it does not require named links.

For named references to objects for the gadgets, see module Links.
*)

(*! unify with Links *)
IMPORT
	Files, Objects, Gadgets;
CONST
	ErrBase = 100;  (*! 20 for BlackBox *)
	ErrWrRefNOObj* = 10; 	(*= Attempt to write NIL object *)
	ErrWrRefPriv* = 11; 	(*= Warning: Object belonging to private library referenced in *)
	ErrWrRefNoRef* = 12; 	(*= Warning: Object without library referenced in lib.name *)
	ErrRdRefNoObj* = 20; 	(*= Warning: Object imported from does not exist (NIL pointer) *)
	ErrRdRefNotFound* = 21; (*= Warning: Object imported reference no found *)

	(* link flags *)(*! support link flags *)
	nohotlink* = 1;  (*= default is hot link *)
	changedvals* = 2;  (*= eg update message has been sent over this link and has not been handled completely *)
	linkfailed* = 3;  (*= eg communication failure, time out *)
	dispositionflags* = {nohotlink};
	statusflags* = {changedvals, linkfailed};
TYPE
	(* for named links, use module Links *)
	Link* = POINTER TO LinkDesc;
	LinkDesc* = RECORD
		link*: Link;  	(* next or prev, depending on insertion protocol *)
		flags*: SET;  (* used in ants *)
		obj*: Objects.Object
	END;

	LinkL* = POINTER TO  LinkLDesc;
	LinkLDesc* = RECORD (LinkDesc)
		val-: LONGINT
	END;

	Queue*	 = POINTER TO QueueDesc;
	QueueDesc*	 = RECORD
		(LinkDesc);
		qlink*: Link; 	(* free for queue user, eg. to allow back links *)
		first-: Link;
		last-: Link;
		count-: LONGINT
	END;

	VAR caching-: BOOLEAN;  (*= TRUE if errors are cached. ErrCache must be checked by user of caching *)
	ErrCache-: LinkL;  lasterr: LinkL;  errcode-: LONGINT;
	NoObject-: Objects.Object;  (* place holder to allow NIL objects in linked lists *)
	NoObjectHandler*: Objects.Handler;


PROCEDURE ResetErr*;
BEGIN ErrCache := NIL; lasterr := NIL;  errcode := 0
END ResetErr;

PROCEDURE CacheErrors*;
BEGIN caching := TRUE;  ResetErr END CacheErrors;

PROCEDURE HaltErrors*;
BEGIN caching := FALSE;  ResetErr END HaltErrors;

PROCEDURE AddErr* (ob: Objects.Object; code: LONGINT);
	VAR LL: LinkL;
BEGIN
	NEW(LL);
	LL.obj := ob;  LL.val := code;
	IF lasterr # NIL THEN lasterr.link := LL;  lasterr := LL
	ELSE ErrCache := LL END;  lasterr := LL;
	IF (~caching) & (code # 0) THEN errcode := code;  HALT(ErrBase) END
END AddErr;

PROCEDURE Atom (lib: Objects.Library;   name: ARRAY OF CHAR): INTEGER;
	VAR ref: INTEGER;
BEGIN
	Objects.GetKey(lib.dict, name, ref);   RETURN ref
END Atom;

PROCEDURE WriteRef (VAR r: Files.Rider;   lib: Objects.Library;   obj: Objects.Object);
BEGIN
	IF obj = NIL THEN Files.WriteInt(r, - 1); AddErr(NIL, ErrWrRefNOObj)
	ELSE
		IF obj.lib # NIL THEN
			IF obj.lib # lib THEN
				IF obj.lib.name = ""THEN (* private library *)
					Files.WriteInt(r, - 1);
					AddErr(obj, ErrWrRefPriv) (* Warning: Object belonging to private library referenced in *)
				ELSE
					Files.WriteInt(r, obj.ref);   Files.WriteInt(r, Atom(lib, obj.lib.name))
				END
			ELSE
				Files.WriteInt(r, obj.ref);
				Files.WriteInt(r, Atom(lib, ""))   (* belongs to this library *)
			END
		ELSE Files.WriteInt(r, - 1); AddErr(obj, ErrWrRefNoRef)
			(* Warning: Object without library referenced in lib.name *)
		END
	END
END WriteRef;

PROCEDURE ReadRef (VAR r: Files.Rider;   lib: Objects.Library;   VAR obj: Objects.Object);
	VAR i, l: INTEGER;   F: Objects.Library;   name: ARRAY 32 OF CHAR;
BEGIN
	Files.ReadInt(r, i);
	IF i = - 1 THEN obj := NIL
	ELSE
		Files.ReadInt(r, l);
		Objects.GetName(lib.dict, l, name);
		IF name[0] = 0X THEN F := lib;   COPY(lib.name, name)   ELSE F := Objects.ThisLibrary(name)   END;
		IF F # NIL THEN
			F.GetObj(F, i, obj);
			IF obj = NIL THEN AddErr(obj, ErrRdRefNoObj)(* Warning: Object imported from does not exist (NIL pointer) *)
			END
		ELSE (* Warning: not found *)
			obj := NIL; AddErr(obj, ErrRdRefNotFound)
		END
	END
END ReadRef;


(** Store/load links to/from a file. *)
(*=Only (ref, lib) references to links are written. *)
(*= Format is chosen to match S3 Links *)

PROCEDURE StoreLinkObj* (VAR R: Files.Rider;   lib: Objects.Library;   listobj: Objects.Object);
	(*= special case: single object.  fake list of one element *)
BEGIN ErrCache := NIL;
	Files.Write(R, 33X);   (* magic number *)
	Files.WriteString(R, "?");
	WriteRef(R, lib, listobj);
	Files.WriteString(R, "")
END StoreLinkObj;

PROCEDURE LoadLinkObj* (VAR R: Files.Rider;   lib: Objects.Library;   VAR listobj: Objects.Object);
	(*= special case: single object.  fake list of one element *)
	VAR ch: CHAR;   s: ARRAY 32 OF CHAR;
BEGIN ErrCache := NIL;
	listobj := NIL;
	Files.Read(R, ch);
	ASSERT(ch = 33X);
	Files.ReadString(R, s);
	IF s # ""THEN
		ReadRef(R, lib, listobj);
		IF (listobj # NIL) & (listobj IS Objects.Dummy) THEN listobj := NIL END;
		Files.ReadString(R, s);
		ASSERT (s = "")
	END
END LoadLinkObj;

PROCEDURE StoreLinks* (VAR R: Files.Rider;   lib: Objects.Library;   list: Link);
BEGIN ErrCache := NIL;
	Files.Write(R, 33X);   (* magic number *)
	WHILE list # NIL DO
		Files.WriteString(R, "?");
		WriteRef(R, lib, list.obj);
		list := list.link
	END;
	Files.WriteString(R, "")
END StoreLinks;

(** Load links from a file. *)
PROCEDURE LoadLinks* (VAR R: Files.Rider;   lib: Objects.Library;   VAR list: Link);
	VAR ch: CHAR;   s: ARRAY 32 OF CHAR;   a, a0: Link;
BEGIN ErrCache := NIL;
	list := NIL;
	Files.Read(R, ch);
	ASSERT(ch = 33X);
	Files.ReadString(R, s);
	WHILE s # ""DO
		NEW(a);
		ReadRef(R, lib, a.obj);
		(*? IF (a.obj # NIL) & (a.obj IS Objects.Dummy) THEN a.obj := NIL END; *)
		(*! check handling of bad links *)
		IF list = NIL THEN list := a ELSE a0.link := a END;
		a0 := a;
		Files.ReadString(R, s)
	END
END LoadLinks;

PROCEDURE CopyPtr (VAR M: Objects.CopyMsg;   obj: Objects.Object): Objects.Object;
BEGIN
	IF obj = NIL THEN RETURN NIL
	ELSE
		IF M.id = Objects.deep THEN
			M.obj := NIL;   obj.handle(obj, M);   RETURN M.obj
		ELSE (* shallow *)
			RETURN obj
		END
	END
END CopyPtr;

(** Copy links.  Both shallow and deep copies are supported. *)
PROCEDURE CopyLinks* (VAR M: Objects.CopyMsg;   in: Link;   VAR out: Link);
	VAR L, a, a0: Link;
BEGIN
	L := in;   out := NIL;
	WHILE L # NIL DO
		NEW(a);
		a.obj := CopyPtr(M, L.obj);
		IF out = NIL THEN out := a ELSE a0.link := a END;
		a0 := a;
		L := L.link
	END
END CopyLinks;

PROCEDURE FindLinks* (links: Link;  VAR M: Objects.FindMsg); 	(* jb 4.8.01 *)
BEGIN
	WHILE (links # NIL) & (M.obj = NIL) DO
		IF links.obj # NIL THEN
			IF links.obj.handle # NIL THEN links.obj.handle (links.obj, M) END
		END;
		links := links.link
	END
END FindLinks;

PROCEDURE ForwardMsgToLinks* (links: Link;  VAR M: Objects.ObjMsg); 	(* jb 18.8.01 *)
BEGIN
	WHILE links # NIL DO
		IF links.obj # NIL THEN
			IF links.obj.handle # NIL THEN links.obj.handle (links.obj, M) END
		END;
		links := links.link
	END
END ForwardMsgToLinks;

PROCEDURE Bind* (obj: Objects.Object;  VAR msg: Objects.BindMsg);
BEGIN
	IF (obj # NIL) (* & (obj.lib # msg.lib)*)THEN (* fof 010419 *)
		IF obj.handle # NIL THEN
			obj.handle(obj, msg)
		ELSE
			Gadgets.BindObj(obj, msg.lib);   (*! fof 010419 *)
		END
	END
END Bind;

(** Bind all linked objects. *)
PROCEDURE BindLinks* (list: Link;   VAR M: Objects.BindMsg);
BEGIN
	WHILE list # NIL DO
		IF list.obj # NIL THEN
			ASSERT(list.obj.handle # NIL, 101);
			Bind(list.obj, M)   (* fof 0111, replaced list.obj.handle(list..obj,M) *)
		END;
		list := list.link
	END
END BindLinks;

(** Insert a link in a list. An existing link with the same name is discarded. *)
(*PROCEDURE InsertLink* (VAR list: Link; name: ARRAY OF CHAR; val: Link);
VAR l, p0: Link;
BEGIN
IF val # NIL THEN
COPY(name, val.name);
val.link := NIL;
IF list = NIL THEN
list := val
ELSE
p0 := NIL; l := list;
WHILE (l # NIL) & (l.name # name) DO p0 := l; l := l.link END;
IF l = NIL THEN (* at end of list *)
p0.link := val;
ELSE
IF p0 = NIL THEN (* in beginning of list *)
val.link := list.link; list := val
ELSE (* in middle of list *)
p0.link := val; val.link := l.link
END;
END;
END
END;
END InsertLink;*)

(*! Provide InsertObjFirst, InsertObjLast *)

PROCEDURE InsertObj* (VAR list: Link;   obj: Objects.Object);
	VAR p0, l, val: Link;
BEGIN
	NEW(val);
	IF val # NIL THEN
		val.obj := obj;  val.link := NIL;
		IF list = NIL THEN
			list := val
		ELSE
			p0 := NIL;   l := list;
			WHILE (l # NIL) DO p0 := l;   l := l.link END;
			IF l = NIL THEN (* at end of list *)
				p0.link := val
			ELSE
				IF p0 = NIL THEN (* in beginning of list *)
					val.link := list.link;   list := val
				ELSE (* in middle of list *)
					p0.link := val;   val.link := l.link
				END
			END
		END
	END
END InsertObj;

PROCEDURE InsertObjOnce* (VAR list: Link;   obj: Objects.Object);
	VAR p0, l, val: Link;
BEGIN
	NEW(val);
	IF val # NIL THEN
		val.obj := obj;  val.link := NIL;
		IF list = NIL THEN
			list := val
		ELSE
			p0 := NIL;   l := list;
			WHILE (l # NIL) & (l.obj # obj) DO p0 := l;   l := l.link END;
			IF l = NIL THEN (* at end of list *)
				p0.link := val
			ELSE
				IF p0 = NIL THEN (* in beginning of list *)
					val.link := list.link;   list := val
				ELSE (* in middle of list *)
					p0.link := val;   val.link := l.link
				END
			END
		END
	END
END InsertObjOnce;

(**  Find Obj in list. *)
PROCEDURE FindObj* (obj: Objects.Object;   list: Link): Link;
	(*= Find Obj in list. *)
BEGIN
	WHILE list # NIL DO
		IF obj = list.obj THEN RETURN list END;
		list := list.link
	END;
	RETURN NIL
END FindObj;

(** Delete first link to object *)
PROCEDURE DeleteLink* (VAR list: Link;   obj: Objects.Object);
	(*= Delete first link to object *)
	VAR a, p: Link;
BEGIN
	a := list;   p := NIL;
	WHILE (a # NIL) & (obj # a.obj) DO p := a;   a := a.link END;
	IF a # NIL THEN (* found *)
		IF p = NIL THEN (* first *)list := a.link
		ELSE p.link := a.link
		END
	END
END DeleteLink;

(** Forward a message to all linked objects in the list. *)
(**USE WITH CARE, MESSAGE CYCLES! *)
PROCEDURE ToLinks* (list: Link;   VAR M: Objects.ObjMsg);
BEGIN
	WHILE (list # NIL) DO
		IF list.obj # NIL THEN
			list.obj.handle(list.obj, M)
		END;
		list := list.link
	END
END ToLinks;

PROCEDURE InsertFirstLink* (VAR linkchain: Link;   newlink: Link);
	(*= Insert obj from link as first in linkchain, if not already inserted *)
	VAR s, n: Link;
BEGIN ASSERT(newlink # NIL);
	NEW(s);   s.obj := newlink.obj;    s.link := NIL;    (*s.prev:=NIL; *)
	IF linkchain = NIL THEN linkchain := s;    RETURN
	ELSE	s.link := linkchain;    n := linkchain;
		WHILE n # NIL DO
			IF n.obj = newlink.obj THEN RETURN ELSE
				n := n.link
			END  (* no duplicate here *)
		END;    (* WHILE *)
		linkchain := s
	END
END InsertFirstLink;

PROCEDURE InsertLastLink* (VAR linkchain: Link;   newlink: Link);
	(*= Insert obj from link as last in linkchain, if not already inserted *)
	VAR s, n: Link;
BEGIN ASSERT(newlink # NIL);
	NEW(s);   s.obj := newlink.obj;    s.link := NIL;    (*s.prev:=NIL; *)
	IF linkchain = NIL THEN linkchain := s;    RETURN
	ELSE	   n := linkchain;
		LOOP
			IF n.obj = newlink.obj THEN RETURN ELSE
				IF n.link = NIL THEN n.link := s;  RETURN
				ELSE
					n := n.link
				END
			END  (* no duplicate here *)
		END
	END
END InsertLastLink;

(*? this sequence needed ? inverted sequence? *)
PROCEDURE MakeSLink* (link: Link;  VAR obj: Objects.Object);
	(*= link is converted to slink chain, starting at obj. *)
	VAR curob: Objects.Object;
BEGIN
	IF (link = NIL) OR (link.obj = NIL) THEN obj := NIL
	ELSE
		obj := link.obj;
		WHILE link # NIL DO
			curob := link.obj;
			IF link.link # NIL THEN curob.slink := link.link.obj ELSE curob.slink := NIL END;
			link := link.link
		END
	END
END MakeSLink;

PROCEDURE MakeDLink* (link: Link;  VAR obj: Objects.Object);
	(*= link is converted to slink chain, starting at obj.
	Use with care: corrupts message chain*)
	VAR curob: Objects.Object;
BEGIN
	IF (link = NIL) OR (link.obj = NIL) THEN obj := NIL
	ELSE
		obj := link.obj;
		WHILE link # NIL DO
			curob := link.obj;
			IF link.link # NIL THEN curob.dlink := link.link.obj ELSE curob.slink := NIL END;
			link := link.link
		END
	END
END MakeDLink;

PROCEDURE GetLastObj* (link: Link): Objects.Object;
BEGIN
	IF link = NIL THEN RETURN NIL
	ELSE
		WHILE link.link # NIL DO link := link.link END;
		RETURN link.obj
	END
END GetLastObj;

PROCEDURE GetSLink* (obj: Objects.Object; VAR link: Link);
	VAR curlink: Link;
BEGIN
	IF obj = NIL THEN link := NIL
	ELSE
		NEW(link); curlink := link;
		WHILE obj # NIL DO
			curlink.obj := obj;
			IF obj.slink # NIL THEN NEW(curlink.link);
			curlink := curlink.link END;
			obj := obj.slink
		END
	END
END GetSLink;

PROCEDURE GetDLink* (obj: Objects.Object; VAR link: Link);
	VAR curlink: Link;
BEGIN
	IF obj = NIL THEN link := NIL
	ELSE
		NEW(link); curlink := link;
		WHILE obj # NIL DO
			curlink.obj := obj;
			IF obj.dlink # NIL THEN NEW(curlink.link);
			curlink := curlink.link END;
			obj := obj.dlink
		END
	END
END GetDLink;
(** Queue management  *)

PROCEDURE OpenQueue* (queue: Queue);
BEGIN ASSERT(queue # NIL);
	queue.first := NIL;
	queue.last := NIL;
	queue.count := 0
END OpenQueue;

PROCEDURE EnqueueFirst* (queue: Queue;   item: Link);
	(*= item.link must be NIL, ar a full queue should be added *)
	VAR tempitem: Link;
BEGIN IF item = NIL THEN RETURN END;
	ASSERT(queue # NIL, 100);  ASSERT((queue.first # NIL) OR (queue.count = 0), 101);
	tempitem := item;  INC(queue.count);
	WHILE tempitem.link # NIL DO tempitem := tempitem.link;  INC(queue.count)  END;
	IF queue.first = NIL THEN  queue.last := tempitem  END;
	tempitem.link := queue.first;
	queue.first := item
END EnqueueFirst;

PROCEDURE EnqueueLast* (queue: Queue;   item: Link);
	(*= item.link must be NIL, ar a full queue is added *)
BEGIN IF item = NIL THEN RETURN END;
	ASSERT(queue # NIL, 100); ASSERT((queue.first # NIL) OR (queue.count = 0), 101);
	IF queue.last = NIL THEN
		queue.first := item;
		queue.last := item
	ELSE
		queue.last.link := item; queue.last := item
	END;  	INC(queue.count);
	WHILE queue.last.link # NIL DO
		queue.last :=
		queue.last.link;   INC(queue.count)
	END
END EnqueueLast;

PROCEDURE Dequeue* (queue: Queue;   item: Link);
	(*? still to be defined: dequeue for item lists *)
	VAR l: Link;
BEGIN IF queue # NIL THEN
		ASSERT(queue.count > 0, 100);  ASSERT(item # NIL, 101);
		l := queue.first;   IF l = item THEN queue.first := l.link;   DEC(queue.count);
			IF l = queue.last THEN queue.last := NIL END;  RETURN
		ELSE
			WHILE ((l.link # item) &  (l.link # NIL)) DO l := l.link END;
			IF l.link = item THEN
				l.link := item.link;   DEC(queue.count);
				IF item.link = NIL THEN queue.last := l END;
			item.link := NIL END
		END (* ELSE *)
	END
END Dequeue;

PROCEDURE IsEmptyQueue* (queue: Queue): BOOLEAN;
BEGIN
	ASSERT((queue.first = NIL) OR ((queue.count > 0) & (queue.last # NIL)), 100);
	RETURN queue.first = NIL
END IsEmptyQueue;

(** Support routines, to avoid import of Strings *)
PROCEDURE SeqName* (stub: ARRAY OF CHAR; sep: CHAR; seqnr: LONGINT; VAR res: ARRAY OF CHAR);
CONST cseqlen = 4;
	VAR i: INTEGER;
BEGIN
	ASSERT(LEN(stub) + 1 + cseqlen < LEN(res), 100);
	ASSERT((seqnr < 10000) & (seqnr >= 0), 101);
	i := 0;  WHILE stub[i] # 0X DO res[i] := stub[i];  INC(i) END;
	res[i] := sep;  INC(i);
	res[i + 4] := 0X;
	res[i + 3] := CHR((seqnr MOD 10) + 30H);  seqnr := seqnr DIV 10;
	res[i + 2] := CHR((seqnr MOD 10) + 30H);  seqnr := seqnr DIV 10;
	res[i + 1] := CHR((seqnr MOD 10) + 30H);  seqnr := seqnr DIV 10;
	res[i] := CHR((seqnr MOD 10) + 30H)
END SeqName;

PROCEDURE NameToSeq* (name: ARRAY OF CHAR;  sep: CHAR; VAR stub: ARRAY OF CHAR; VAR seqnr: LONGINT);
	VAR i: INTEGER; xname: ARRAY 32 OF CHAR;  xch: CHAR;
BEGIN
	COPY(name, xname);
	seqnr := 0;
	i := 0;
	WHILE (name[i] # sep) & (name[i] # 0X) DO
		stub[i] := name[i];  INC(i)
	END;
	stub[i] := 0X;
	IF name[i] = 0X THEN RETURN END;
	INC(i); (*delim*)
	WHILE  name[i] # 0X DO xch := name[i];
		ASSERT(('0' <= name[i]) & ('9' >= name[i]), 100);
		seqnr := seqnr * 10 + ORD(name[i]) - 30H;  INC(i)
	END
END NameToSeq;

PROCEDURE LinkCount* (link: Link): LONGINT;
	VAR count: LONGINT;
BEGIN
	count := 0;
	WHILE link # NIL DO INC(count);  link := link.link END;
	RETURN count
END LinkCount;

(** Iterators *)
PROCEDURE DoHandleLinks* (VAR p: Link;  NameStub: ARRAY OF CHAR;  VAR M: Objects.LinkMsg);
	(*= set w. M.obj=NIL: remove*)
	VAR i, seqnr: LONGINT; stub, picname: ARRAY 32 OF CHAR; ploc, pprev: Link;
BEGIN
	ploc := p;
	IF M.id = Objects.enum THEN
		ASSERT(M.Enum # NIL, 100);
		i := 0;
		WHILE ploc # NIL DO INC(i);  SeqName(NameStub, ' ', i, picname);  M.Enum(picname); ploc := ploc.link END

	ELSIF M.id = Objects.get THEN
		NameToSeq(M.name, ' ', stub, seqnr);
		IF (stub # NameStub) OR (seqnr < 1) THEN (* no match: NOOP*)	(*	Gadgets.framehandle(F, M)*)
		ELSE (* match: try *)
			WHILE (ploc # NIL )  &  (seqnr > 1) DO DEC(seqnr);  ploc := ploc.link  END;
			IF ploc # NIL THEN M.obj := ploc.obj;  M.res := 0  ELSE (*Gadgets.framehandle(F, M);*)END
			END

		ELSIF M.id = Objects.set THEN
			(*Gadgets.framehandle(F, M)*)(*! still to fix. *)
			(*! check: p#NIL *)
			NameToSeq(M.name, ' ', stub, seqnr);  pprev := p;
			(*! support inclusion of links *)
			IF (stub # NameStub) OR (seqnr < 1) THEN
			ELSE
				IF (p = NIL) & (M.obj # NIL) THEN
					NEW(p);  (*? type may be to restricted ! *)  p.obj := M.obj;  p.flags := {};  M.res := 0;  RETURN
				END;
				IF (seqnr = 1) & (M.obj = NIL) & (p # NIL) THEN
					(*special case:remove first *)(*! check. 1 p#NIL? 2. set ok? *)p := p.link;  M.res := 0;  RETURN
				END;
				(*general case*)
				WHILE (ploc # NIL )  &  (seqnr > 1) DO DEC(seqnr);   pprev := ploc;  ploc := ploc.link  END;
				IF ploc # NIL THEN
					IF M.obj # NIL THEN (*set*)ploc.obj := M.obj; p.flags := {};  M.res := 0
					ELSE (*remove*)pprev.link := p.link
					END;
					M.res := 0
				ELSE (*Gadgets.framehandle(F, M);*)END
				END
			ELSE
				(*Gadgets.framehandle(F, M)*)
			END
		END DoHandleLinks;

	BEGIN
		HaltErrors
	END vyLinks.

