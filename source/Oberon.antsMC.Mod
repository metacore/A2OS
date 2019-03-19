MODULE antsMC IN Oberon;   (** fof  **)
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




(* generic markov chain *)

IMPORT Objects, Gadgets, Files, vyBase, vyRanBase, vyHostTexts, antsObjects,  (* vyRanParksMiller, *) vyLinks,
	antsCommands, vyName, antsConstRandom, aM := antsMessages, antsRandom;

TYPE
	Msg* = RECORD (Objects.ObjMsg)
		gen*: vyRanBase.tRandom;
		error*: BOOLEAN;
		errormsg*: ARRAY 256 OF CHAR;
		pos*: LONGINT;
		temp*: LONGREAL
	END;

	InitMsg* = RECORD (Msg) END;
	StepMsg* = RECORD (Msg)
		steps-: LONGINT
	END;

	Seed* = POINTER TO SeedDesc;
	SeedDesc* = RECORD
		pos-: LONGINT;
		seed: vyRanBase.tSeed;
		seedval-: LONGINT;   (* replace by generic seed from vyRanBase *)
		next-: Seed;
		prev-: Seed (* seed is a list, not a tree. prev stored for variable start point of list. *)
	END;

	Chain* = OBJECT (*  POINTER TO ChainDesc;
	ChainDesc* = RECORD (vyBase.ObjDesc) *) (vyBase.Object)
		VAR
		pos-: LONGINT;
		first, prev, next, last: LONGINT;   (* to be held consistently:  first,pos,next *)

		seed-: Seed;
		gen-: vyRanBase.tRandom;

		Kernels: vyLinks.Link;
		initgen-: vyLinks.Link;
		initseed: vyRanBase.tSeed;

		error: BOOLEAN;
			PROCEDURE (*c: Chain*)forward*( n: LONGINT );
	VAR n1, n2: LONGINT;
	BEGIN
		SELF.error := FALSE;
		ASSERT ( n >= 0, 101 );
		IF (SELF.pos = SELF.first) & (SELF.pos # SELF.next) THEN
			ApplyInit( SELF, SELF.error );  Gadgets.Update( SELF );
			IF SELF.error THEN RETURN END;
			SyncSeed( SELF );  SELF.next := SELF.pos + 1;  GetNextSeedPos( SELF, SELF.next )
		END;
		IF (SELF.pos + n) > SELF.next THEN
			n1 := (SELF.next - SELF.pos);  n2 := (SELF.pos + n - SELF.next);
			WHILE n1 > 0 DO
				ApplyKernel( SELF, SELF.error );  Gadgets.Update( SELF );
				IF SELF.error THEN RETURN END;
				INC( SELF.pos );  DEC( n1 )
			END;
			SyncSeed( SELF );  INC( SELF.next );  GetNextSeedPos( SELF, SELF.next );  SELF.forward( n2 )
		ELSE
			WHILE n > 0 DO
				ApplyKernel( SELF, SELF.error );  Gadgets.Update( SELF );
				IF SELF.error THEN RETURN END;
				INC( SELF.pos );  DEC( n )
			END;
			vyBase.Update( SELF );  Gadgets.Update( SELF )
		END;
		SyncSeed( SELF );  SELF.next := SELF.pos + 1;  GetNextSeedPos( SELF, SELF.next );
		IF SELF.pos > SELF.last THEN SELF.last := SELF.pos END
	END forward;

	PROCEDURE (*c: Chain*)moveTo*( pos: LONGINT );
	BEGIN
		IF pos > SELF.pos THEN SELF.forward( pos - SELF.pos ) END
	END moveTo;

	PROCEDURE (*c: Chain*)toNext*( ): BOOLEAN;
	BEGIN
		IF SELF.next < MAX( LONGINT ) THEN
			SELF.forward( SELF.next - SELF.pos );
			IF SELF.error THEN RETURN FALSE ELSE RETURN TRUE END
		ELSE RETURN FALSE
		END
	END toNext;

	PROCEDURE (*c: Chain*)toLast*;
	BEGIN
		WHILE (SELF.toNext()) DO END
	END toLast;

	PROCEDURE (*c: Chain*)jumpTo*( to: LONGINT );
	(* if to is in range and seed memorized then seed is set otherwise new seed is memorized at pos to *)
	BEGIN
		SELF.error := FALSE;  SELF.pos := to;
		IF SELF.pos < SELF.first THEN SELF.first := SELF.pos END;
		SyncSeed( SELF );  SELF.next := SELF.pos + 1;  GetNextSeedPos( SELF, SELF.next );  SELF.forward( 0 )
		(*
	vyBase.Update(c); Gadgets.Update(c);
	done in forward
	*)
	END jumpTo;

	PROCEDURE (*c: Chain*)toFirst*;
	BEGIN
		SELF.jumpTo( SELF.first )
	END toFirst;

	PROCEDURE (*c: Chain*)repeat*;
	VAR pos: LONGINT;
	BEGIN
		GetMinPos( SELF.seed, pos );  SELF.jumpTo( pos );  SELF.toLast
	END repeat;

	PROCEDURE (*c: Chain*)init*;
	VAR inits: vyLinks.Link;
	BEGIN
		SELF.pos := 0;  SELF.seed := NIL;  SELF.next := 0;  SELF.last := 0;  SELF.prev := 0;  SELF.first := 0;  SELF.gen := antsRandom.default;
		SELF.error := FALSE;  inits := SELF.initgen;
		IF (inits # NIL ) & (inits.obj # NIL ) THEN SELF.initseed := inits.obj( vyRanBase.tRandom ).seed END;   (* next init seed *)

		SELF.handle := Handler;  SELF.lib := NIL
	END init;

	PROCEDURE (*c: Chain*)Add*( Kernel: vyBase.Object );
	VAR l1, l2: vyLinks.Link;
	BEGIN
		l1 := SELF.Kernels;  l2 := SELF.initgen;
		IF l1 = NIL THEN
			NEW( SELF.Kernels );  SELF.Kernels.obj := Kernel;  NEW( SELF.initgen );  SELF.initgen.obj := SELF.gen;  SELF.initseed := SELF.gen.seed.Copy();  RETURN
		END;
		WHILE (l1.link # NIL ) DO l1 := l1.link;  l2 := l2.link END;
		NEW( l1.link );  NEW( l2.link );  l1.link.obj := Kernel;  l2.link.obj := SELF.gen

	END Add;

	PROCEDURE (*c: Chain*)Remove*( Kernel: vyBase.Object );
	VAR l1, l2, l1p, l2p: vyLinks.Link;
	BEGIN
		l1 := SELF.Kernels;  l2 := SELF.initgen;
		IF l1 = NIL THEN RETURN
		ELSIF l1.obj = Kernel THEN l1 := l1.link;  l2 := l2.link
		END;

		l1p := l1;  l2p := l2;  l1 := l1.link;  l2 := l2.link;

		WHILE l1 # NIL DO
			IF l1.obj = Kernel THEN l1p.link := l1.link;  l2p.link := l2.link;  RETURN END;
			l1p := l1;  l2p := l2;  l1 := l1.link;  l2 := l2.link
		END
	END Remove;

	PROCEDURE (*c: Chain*)getKernel*( num: LONGINT ): vyBase.Object;
	VAR l1: vyLinks.Link;
	BEGIN
		l1 := SELF.Kernels;
		WHILE (num > 0) & (l1 # NIL ) DO l1 := l1.link;  DEC( num ) END;
		IF (l1 = NIL ) OR (l1.obj = NIL ) THEN RETURN NIL ELSE RETURN l1.obj( vyBase.Object ) END
	END getKernel;

	END Chain;
		Transition* = PROCEDURE ( c: Chain;  n: LONGINT );

VAR
	stop*: BOOLEAN;

	PROCEDURE GetSeedCopy( gen: vyRanBase.tRandom ): vyRanBase.tSeed;
	VAR copy: vyRanBase.tSeed;
	BEGIN
		copy := gen.seed.Copy();  RETURN copy
	END GetSeedCopy;

	PROCEDURE SetSeedCopy( gen: vyRanBase.tRandom;  seed: vyRanBase.tSeed );
	VAR copy: vyRanBase.tSeed;
	BEGIN
		IF seed = NIL THEN RETURN END;
		copy := seed.Copy();  gen.SetSeed( gen, copy )
	END SetSeedCopy;



(*
PROCEDURE RGetSeed (gen: vyRanBase.tRandom): LONGINT;
VAR tempseed: vyRanBase.tSeed;
BEGIN
gen.GetSeed(gen, tempseed);
RETURN tempseed(vyRanBase.tLongintSeed).val
END RGetSeed;

PROCEDURE RSetSeed (gen: vyRanBase.tRandom; nr: LONGINT);
VAR tempseed: vyRanBase.tSeed;
BEGIN
gen.GetSeed(gen, tempseed);
tempseed(vyRanBase.tLongintSeed).val := nr;
END RSetSeed;
*)

	PROCEDURE RSetGenerator( gen: vyRanBase.tRandom );
	BEGIN
		antsRandom.SetGen( gen )
	END RSetGenerator;

	PROCEDURE CheckError( m: Msg;  VAR error: BOOLEAN );
	BEGIN
		IF m.error THEN
			error := TRUE;  vyHostTexts.Note( vyHostTexts.cAlert, "Sampler fatal error:" );  vyHostTexts.Note( vyHostTexts.cAlert, m.errormsg );
			vyHostTexts.NoteSI( vyHostTexts.cAlert, "Markov Chain stopped at pos ", m.pos )
		END
	END CheckError;

	PROCEDURE ApplyKernel( c: Chain;  VAR error: BOOLEAN );
	VAR msg: StepMsg;  l: vyLinks.Link;  tseed: vyRanBase.tSeed;
	BEGIN
		error := FALSE;   (* seed := RGetSeed(c.gen); *) tseed := GetSeedCopy( c.gen );  l := c.Kernels;
		WHILE l # NIL DO
			ASSERT ( l.obj # NIL , 100 );
			ASSERT ( l.obj.handle # NIL , 101 );
			msg.pos := c.pos - c.first;  msg.gen := c.gen;  msg.steps := 1;  msg.error := FALSE;  msg.dlink := c;
			SetSeedCopy( c.gen, tseed );
			(*
		RSetSeed(c.gen,seed);
		*)
			RSetGenerator( c.gen );
			(* antsObjects.SetGen(c.gen);*)
			l.obj.handle( l.obj, msg );  CheckError( msg, error );  l := l.link
		END
	END ApplyKernel;

	PROCEDURE ApplyInit(  c: Chain;  VAR error: BOOLEAN );
	VAR msg: InitMsg;  l, inits: vyLinks.Link;  gen: vyRanBase.tRandom;  tseed: vyRanBase.tSeed;
	BEGIN
		gen := vyRanBase.RandomGenerator;
		error := FALSE;   (* seed := RGetSeed(c.gen); *)
		IF c.initseed # NIL THEN tseed := c.initseed.Copy() ELSE tseed := NIL END;
		l := c.Kernels;  inits := c.initgen;
		WHILE l # NIL DO
			ASSERT ( l.obj # NIL , 100 );
			ASSERT ( l.obj.handle # NIL , 101 );

			IF inits.obj # NIL THEN
				RSetGenerator( inits.obj( vyRanBase.tRandom ) );  msg.gen := inits.obj( vyRanBase.tRandom );
				msg.error := FALSE;  msg.dlink := c;
				SetSeedCopy( msg.gen, tseed );   (* RSetSeed(c.gen,seed);*)
				(* RSetGenerator(c.gen); *)
				l.obj.handle( l.obj, msg );  CheckError( msg, error )
			END;
			(*
		msg.error := FALSE; msg.dlink := c;
		RSetGenerator(c.gen);
		SetSeedCopy(c.gen,tseed); (* RSetSeed(c.gen,seed); *)
		l.obj.handle(l.obj,msg);
		CheckError(msg,error);
		*)
			l := l.link;  inits := inits.link
		END;
		antsRandom.SetGen( gen )
	END ApplyInit;

	PROCEDURE Insert( VAR s: Seed;  VAR temp: Seed );
	(* insert seed temp to seed chain s if new else copy seed from chain to temp *)
	VAR prev, next: Seed;
	BEGIN
		WHILE (s # NIL ) & (s.pos < temp.pos) DO prev := s;  s := s.next;  next := s END;
		WHILE (s # NIL ) & (s.pos > temp.pos) DO next := s;  s := s.prev;  prev := s END;
		IF (s # NIL ) & (s.pos = temp.pos) THEN temp.seedval := s.seedval;  temp := s
		ELSE
			temp.next := next;  temp.prev := prev;
			IF next # NIL THEN next.prev := temp END;
			IF prev # NIL THEN prev.next := temp END
		END;
		s := temp
	END Insert;

	PROCEDURE SyncSeed( c: Chain );
	(* If seed detected at pos, seed is set again otherwise new seed is memorized at pos *)
	VAR insert: Seed;
	BEGIN
		NEW( insert );   (* insert.seed := GetSeedCopy(c.gen); *)  (* insert.seedval := RGetSeed(c.gen);     *)
		insert.pos := c.pos;  Insert( c.seed, insert );

		IF insert.seed = NIL THEN insert.seed := GetSeedCopy( c.gen )
		END;

		(* RSetSeed(c.gen,insert.seedval); *)
		SetSeedCopy( c.gen, insert.seed )
	END SyncSeed;

	PROCEDURE GetMinPos(s: Seed;  VAR pos: LONGINT );
	(* get first position of chain *)
	BEGIN
		IF s = NIL THEN pos := MIN( LONGINT );  RETURN END;
		WHILE s.prev # NIL DO s := s.prev END;
		pos := s.pos
	END GetMinPos;

	PROCEDURE StoreSeed( VAR R: Files.Rider;  s: Seed );
	VAR pos: LONGINT;
	BEGIN
		Files.WriteInt( R, 1 );
		(* old
	GetMinPos(s, pos);
	WHILE s # NIL DO
	Files.WriteLInt(R, s.pos);    Files.WriteLInt(R, s.seedval);    s := s.next
	END;
	Files.WriteLInt(R, MIN(LONGINT));    Files.WriteLInt(R, MIN(LONGINT))
	*)
		GetMinPos( s, pos );
		WHILE s # NIL DO Files.WriteLInt( R, s.pos );  s.seed.Store( R );  s := s.next END;
		Files.WriteLInt( R, MIN( LONGINT ) )
	END StoreSeed;

	PROCEDURE LoadSeed( VAR R: Files.Rider;  VAR s: Seed;  allocs: vyRanBase.tRandom );
	VAR pos, val: LONGINT;  insert: Seed;  version: INTEGER;
	BEGIN
		Files.ReadInt( R, version );
		IF version < 1 THEN
			Files.ReadLInt( R, pos );  Files.ReadLInt( R, val );
			WHILE (pos # MIN( LONGINT )) DO
				NEW( insert );  insert.pos := pos;  insert.seedval := val;  Insert( s, insert );  Files.ReadLInt( R, pos );
				Files.ReadLInt( R, val );  insert.seed := allocs.AllocSeed()
			END;
			RETURN
		END;

		Files.ReadLInt( R, pos );
		WHILE (pos # MIN( LONGINT )) DO
			NEW( insert );  insert.pos := pos;  insert.seed := allocs.AllocSeed();  insert.seed.Load( R, allocs.seedVersion );
			Insert( s, insert );  Files.ReadLInt( R, pos )
		END

	END LoadSeed;

	PROCEDURE Load( VAR R: Files.Rider;  s: Chain );
	VAR objsub: Objects.Object;  version: INTEGER;
	BEGIN
		IF stop THEN HALT( 100 ) END;
		Files.ReadInt( R, version );  Gadgets.ReadRef( R, s.lib, objsub );
		WITH objsub: vyRanBase.tRandom DO s.gen := objsub
		END;
		Files.ReadLInt( R, s.pos );  Files.ReadLInt( R, s.first );  Files.ReadLInt( R, s.prev );  Files.ReadLInt( R, s.next );
		Files.ReadLInt( R, s.last );  LoadSeed( R, s.seed, s.gen );  vyLinks.LoadLinks( R, s.lib, s.Kernels );
		vyLinks.LoadLinks( R, s.lib, s.initgen );
		IF (s.initgen # NIL ) & (s.initgen.obj # NIL ) THEN
			s.initseed := s.initgen.obj( vyRanBase.tRandom ).seed;   (* default init seed *)
			IF version > 0 THEN aM.dS( "Loading init seed" );  s.initseed.Load( R, s.initgen.obj( vyRanBase.tRandom ).seedVersion ) END
		END
	END Load;

	PROCEDURE Store( VAR R: Files.Rider;  s: Chain );
	BEGIN
		Files.WriteInt( R, 1 );  Gadgets.WriteRef( R, s.lib, s.gen );  Files.WriteLInt( R, s.pos );  Files.WriteLInt( R, s.first );
		Files.WriteLInt( R, s.prev );  Files.WriteLInt( R, s.next );  Files.WriteLInt( R, s.last );  StoreSeed( R, s.seed );
		vyLinks.StoreLinks( R, s.lib, s.Kernels );  vyLinks.StoreLinks( R, s.lib, s.initgen );
		IF (s.initgen # NIL ) & (s.initgen.obj # NIL ) THEN s.initseed.Store( R ) END
	END Store;

	PROCEDURE Handler*( o: Objects.Object;  VAR M: Objects.ObjMsg );
	BEGIN
		WITH o: Chain DO
			IF M IS vyBase.UpdateMessage THEN
				WITH M: vyBase.UpdateMessage DO vyBase.Update( o );  Gadgets.Update( o );
				END;
			ELSIF M IS Objects.FileMsg THEN
				WITH M: Objects.FileMsg DO
					IF M.id = Objects.load THEN vyBase.objecthandle( o, M );  Load( M.R, o )
					ELSIF M.id = Objects.store THEN vyBase.objecthandle( o, M );  Store( M.R, o )
					END;
				END;
			ELSIF M IS Objects.BindMsg THEN
				WITH M: Objects.BindMsg DO
				(*IF o.bindcount <4 THEN *)
					IF o.lib # M.lib THEN
						vyBase.objecthandle( o, M );  vyLinks.BindLinks( o.Kernels, M );  vyLinks.BindLinks( o.initgen, M )
					END;
					antsObjects.Bind( o.gen, M );
				END;
			ELSIF M IS Objects.LinkMsg THEN
				WITH M: Objects.LinkMsg DO
					vyLinks.DoHandleLinks( o.Kernels, "Kernel", M );
					IF M.id = Objects.enum THEN M.Enum( "RanGen" )
					ELSIF M.id = Objects.get THEN
						IF M.name = "RanGen" THEN M.obj := o.gen;  M.res := 0 END
					END;
					vyBase.objecthandle( o, M );
				END;
			ELSIF M IS Objects.AttrMsg THEN
				WITH M: Objects.AttrMsg DO
					IF M.id = Objects.enum THEN
						M.Enum( "Gen" );  M.Enum( "pos" );  M.Enum( "seedval" );  M.Enum( "first" );  M.Enum( "last" );  vyBase.objecthandle( o, M )
					ELSIF M.id = Objects.get THEN
						IF M.name = "Gen" THEN COPY( 'antsMC.Gen', M.s );  M.class := Objects.String;  M.res := 0;  RETURN
						ELSIF M.name = "pos" THEN M.i := o.pos;  M.class := Objects.Int;  M.res := 0
						ELSIF M.name = "first" THEN M.i := o.first;  M.class := Objects.Int;  M.res := 0
						ELSIF M.name = "last" THEN M.i := o.last;  M.class := Objects.Int;  M.res := 0

						ELSIF M.name = "seedval" THEN
							IF o.seed # NIL THEN M.i := o.seed.seedval ELSE M.i := MAX( LONGINT ) END;
							M.class := Objects.Int;  M.res := 0
						ELSE vyBase.objecthandle( o, M )
						END
					ELSIF M.id = Objects.set THEN
						IF M.name = "pos" THEN
							IF M.class = Objects.Int THEN o.jumpTo( M.i );  M.res := 0 END
						ELSE vyBase.objecthandle( o, M )
						END
					ELSE vyBase.objecthandle( o, M )
					END
				END;
			ELSE vyBase.objecthandle( o, M )
			END
		END
	END Handler;

	PROCEDURE GetNextTo( VAR s: Seed;  VAR pos: LONGINT );
	BEGIN
		IF pos = s.pos THEN RETURN
		ELSIF pos < s.pos THEN
			IF (s.prev = NIL ) THEN pos := s.pos;  RETURN
			ELSIF (pos > s.prev.pos) THEN pos := s.pos;  RETURN
			ELSE s := s.prev
			END
		ELSIF pos > s.pos THEN
			IF (s.next = NIL ) THEN pos := MAX( LONGINT );  RETURN
			ELSIF (pos < s.next.pos) THEN s := s.next;  pos := s.pos;  RETURN
			ELSE s := s.next
			END
		END;
		GetNextTo( s, pos )
	END GetNextTo;

	PROCEDURE GetNextSeedPos( c: Chain;  VAR pos: LONGINT );
	BEGIN
		GetNextTo( c.seed, pos )
	END GetNextSeedPos;


	PROCEDURE Gen*;
	VAR c: Chain;
	BEGIN
		aM.cmd;  NEW( c );  c.handle := Handler;  Objects.NewObj := c;  c.init;  antsObjects.Register( c ) (* c.bindcount := 0; *)
	END Gen;

	PROCEDURE New*;
	VAR l: antsCommands.tScanList;  name: vyName.tNameArray;  c: Chain;
	BEGIN
		l := antsCommands.ScanFromPar( "name=NAME # create new markov chain" );
		IF antsCommands.ExpectNameFromKeyword( l, "name", name ) THEN
			Gen;  c := Objects.NewObj( Chain );  vyName.RegisterNamed( c, name )
		END
	END New;

	PROCEDURE DoApplyInit*( gen: vyRanBase.tRandom;  c: Chain;  kernel: vyBase.Object );
	VAR link, gens: vyLinks.Link;
	BEGIN
		link := c.Kernels;  gens := c.initgen;
		WHILE link # NIL DO
			IF link.obj = kernel THEN gens.obj := gen;  aM.vS( "Set Init Random to kernel" ) END;
			link := link.link;  gens := gens.link
		END
	END DoApplyInit;

	PROCEDURE ApplyConstInit*;
	VAR const, max: LONGINT;  obj, kernel: vyBase.Object;  gen: vyRanBase.tRandom;  l: antsCommands.tScanList;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ Kernel=OBJ [const=INT max=INT] # use Constant as InitRanGen for Kernel in chain" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectObjectFromKeyword( l, "Kernel", kernel ) THEN
			gen := antsRandom.default;
			IF antsCommands.GetNumberFromKeyword( l, "const", const ) & antsCommands.GetNumberFromKeyword( l, "max", max ) THEN
			ELSE const := 0;  max := 1
			END;
			DoApplyInit( antsConstRandom.New( const, max ), obj( Chain ), kernel );  obj( Chain ).toFirst()
		END
	END ApplyConstInit;

	PROCEDURE ApplyDefaultInit*;
	VAR obj, kernel: vyBase.Object;  l: antsCommands.tScanList;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ Kernel=OBJ # use Kernel RanGen as InitRanGen for Kernel in chain" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectObjectFromKeyword( l, "Kernel", kernel ) THEN
			DoApplyInit( obj( Chain ).gen, obj( Chain ), kernel );  obj( Chain ).toFirst()
		END
	END ApplyDefaultInit;

	PROCEDURE ApplyNoInit*;
	VAR obj, kernel: vyBase.Object;  l: antsCommands.tScanList;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ Kernel=OBJ # use no init  for Kernel in chain" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) & antsCommands.ExpectObjectFromKeyword( l, "Kernel", kernel ) THEN
			DoApplyInit( NIL , obj( Chain ), kernel );  obj( Chain ).toFirst()
		END
	END ApplyNoInit;

	PROCEDURE Add*;
	VAR l: antsCommands.tScanList;  c, obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ kernel=OBJ # Add Kernel <kernel> in Chain <name>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) & antsCommands.ExpectObjectFromKeyword( l, "kernel", obj ) THEN
			WITH c: Chain DO c.Add( obj );  vyBase.Subscribe( c, obj )
			END
		END
	END Add;

	PROCEDURE Remove*;
	VAR l: antsCommands.tScanList;  c, obj: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ kernel=OBJ # Remove Kernel <kernel> from Chain <name>" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) & antsCommands.ExpectObjectFromKeyword( l, "kernel", obj ) THEN
			WITH c: Chain DO c.Remove( obj );  vyBase.UnSubscribe( c, obj )
			END
		END
	END Remove;

	PROCEDURE Forward*;
	VAR l: antsCommands.tScanList;  c: vyBase.Object;  num, rep, i: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ num=INT [repeat=INT] # move chain <name> forward <num> [repeated]" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) & antsCommands.ExpectNumberFromKeyword( l, "num", num ) THEN
			WITH c: Chain DO
				IF ~antsCommands.GetNumberFromKeyword( l, "repeat", rep ) THEN rep := 1 END;
				FOR i := 1 TO rep DO c.forward( num ) END
			END
		END
	END Forward;

	PROCEDURE Jump*;
	VAR l: antsCommands.tScanList;  c: vyBase.Object;  num: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ num=INT# jump to pos <num> of <chain> without apllying kernels" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) & antsCommands.ExpectNumberFromKeyword( l, "to", num ) THEN
			WITH c: Chain DO c.jumpTo( num )
			END
		END
	END Jump;

	PROCEDURE MoveTo*;
	VAR l: antsCommands.tScanList;  c: vyBase.Object;  num: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ num=INT# forward (if possible) to pos <num> of <chain> " );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) & antsCommands.ExpectNumberFromKeyword( l, "to", num ) THEN
			WITH c: Chain DO c.moveTo( num )
			END
		END
	END MoveTo;

	PROCEDURE Init*;
	VAR l: antsCommands.tScanList;  c: vyBase.Object;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ # jump to first pos of chain and apply init distribution" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) THEN
			WITH c: Chain DO
				c.init();  c.jumpTo( 0 ) (* vyBase.Update(c); Gadgets.Update(c); *)
			END
		END
	END Init;

	PROCEDURE Repeat*;
	VAR l: antsCommands.tScanList;  c: vyBase.Object;  rep, i: LONGINT;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ [repeat=INT] # Repeat execution of chain from start to end [repeatedly]" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) THEN
			WITH c: Chain DO
				IF ~antsCommands.GetNumberFromKeyword( l, "repeat", rep ) THEN rep := 1 END;
				FOR i := 1 TO rep DO c.repeat() END
			END
		END
	END Repeat;

	PROCEDURE WriteSeeds*;
	VAR l: antsCommands.tScanList;  c: vyBase.Object;  this: Seed;
	BEGIN
		l := antsCommands.ScanFromPar( "name=OBJ # Write seeds in chain to Log" );
		IF antsCommands.ExpectObjectFromKeyword( l, "name", c ) THEN
			WITH c: Chain DO
				this := c.seed;
				WHILE (this.prev # NIL ) DO this := this.prev END;
				aM.SSS( "Seeds of ", "name", " _" );
				WHILE (this # NIL ) DO aM.SISI( "", this.pos, "", this.seedval );  this := this.next END
			END
		END
	END WriteSeeds;

BEGIN
	aM.launch;  stop := FALSE;
END antsMC.
System.Free antsKernel antsMC ~
antsMC.TestChain ~

antsMC.New Chain ~
antsGibbs.DefineGibbsSampler Kernel 100 ~
antsMC.Add Chain Kernel ~
antsMC.Forward Chain 100 1000~
antsMC.Jump Chain 00 ~
antsMC.Init Chain ~

Voyager.Show Chain as antsObjectView ~
antsObjects.WriteAttributes Chain ~

antsMC.ApplyConstInit Chain Kernel 0 1 ~
antsMC.ApplyDefaultInit Chain Kernel ~
antsMC.ApplyNoInit Chain Kernel ~
