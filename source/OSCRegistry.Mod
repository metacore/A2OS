(* Copyright 2005-2006, Markus Heule, ETH Zurich *)

MODULE OSCRegistry;  (** AUTHOR "heulemar"; PURPOSE "OpenSoundControl: Registry of OSC-Address-Space"; *)

(*

	This module contains an OSCRegistry, which holds the current OSC Address Space. This registry is normally used as address space
	for an OSCService, but you can use it also for your own implementation.

	It offers methods to register a new method in the address 	space and to remove existing ones. This methods will eventually be called
	through the 'Run'-method, which also does all the needed pattern matching during message dispatching, as it's described
	in the OSC Specification.

	All registred methods must have a compatible signature to OSCMethodHandler.

	Note: This registry can be accessed concurrently from multiple active objects.

*)

	IMPORT Strings, OSC, KernelLog;

	CONST
		ContainerInitalArraysize = 4;

		rootadr = "/";
		rootname = "<root>";
		dumpident = "  ";

		OK* = 0;
		BadClassUsed = 99;
		ImplementatonError = 101;

		Trace* = FALSE;
		LogErrors* = TRUE;


	TYPE
		String* = Strings.String;

		OSCMethodHandler = PROCEDURE { DELEGATE } (m: OSC.OSCMessage); (* This handler is used to call the user functions *)

		(* This class is a common superclass of OSCMethodContainer and OSCMethod. This class contains shared code and enables
			arrays with containers or methods as members. *)
		OSCMethodTree = OBJECT
			VAR
				fullname-: String; (* stores the full address. eg: '/mixer/channel1/volume'. Mostly for convenience  *)
				name-: String; (* stores onlhy the last part of the full address. eg: 'volume'. This is used during pattern matching *)

			PROCEDURE &InitOSCMethodTree*(fullname, name: String);
			BEGIN
					SELF.name := name;
					SELF.fullname := fullname;
			END InitOSCMethodTree;

			(* Searches in s[pos..end] for the next '/'. *)
			PROCEDURE nextAddrPartIndex(s: String; pos: SIGNED16; VAR nextpos: SIGNED16 );
			BEGIN
				ASSERT(s[pos] = '/');
				(* skip '/' *)
				nextpos := pos+1;
				WHILE (s[nextpos] # '/') & (s[nextpos] # 0X) DO
					INC(nextpos);
				END;
			END nextAddrPartIndex;

			(* dumps this element. As this class should never be used, this function traps *)
			PROCEDURE dump(ident: SIGNED16); BEGIN HALT(BadClassUsed); END dump;

		END OSCMethodTree;

		Childs = POINTER TO ARRAY OF OSCMethodTree;

		(* This class represents an OSC Container. *)
		OSCMethodContainer = OBJECT(OSCMethodTree)
			VAR
				size: SIGNED16; (* the actual number of elements in the childs array. *)
				childs: Childs;

			PROCEDURE &Init*(fullname, name: String);
			BEGIN
				InitOSCMethodTree(fullname, name);
				size := 0;
				NEW(childs, ContainerInitalArraysize)
			END Init;

			(* This message matches the pattern in the address of the message m with all the stored childs.
				pos: actual position in the OSC address adr. equals to the first character of the current part of the address
				adr == m.address *)
			PROCEDURE runMessage(adr: String; pos: SIGNED16; m: OSC.OSCMessage);
			VAR
				i: SIGNED16;
				name: String;
				nextpos: SIGNED16;
				element: OSCMethodTree;
			BEGIN
				nextAddrPartIndex(adr, pos, nextpos);
				name := Strings.Substring(pos+1, nextpos, adr^); (* extract current pattern *)
				FOR i := 0 TO size-1 DO (* try to match all childs *)
					IF match(name, childs[i].name) THEN
						element := childs[i];
						IF (adr[nextpos] = '/') & (element IS OSCMethodContainer) THEN
							WITH element: OSCMethodContainer DO
								element.runMessage(adr, nextpos, m);
							END;
						ELSIF (adr[nextpos] = 0X) & (element IS OSCMethod) THEN
							WITH element: OSCMethod DO
								element.runMessage(m);
							END;
						END;
					END;
				END;
			END runMessage;

			(* deletes a method. removes also all containers, that are not needed anymore.
				returns the number of deleted objects.
				pos is the actual position in the address string adr. *)
			PROCEDURE deleteMethod(adr: String; pos: SIGNED16): SIGNED16;
				VAR
					element: OSCMethodTree;
					name: String;
					nextpos, elementpos: SIGNED16;
					count: SIGNED16;
			BEGIN
				nextAddrPartIndex(adr, pos, nextpos);
				name := Strings.Substring(pos+1, nextpos, adr^);
				element := searchpos(name, elementpos);
				IF element = NIL THEN
					RETURN 0; (* method not found *)
				ELSIF (adr[nextpos] = 0X) & (element IS OSCMethod) THEN
					(* found method to delete *)
					childs[elementpos] := childs[size-1];
					childs[size-1] := NIL;
					DEC(size);
					RETURN 1;
				ELSIF (adr[nextpos] = '/') & (element IS OSCMethodContainer) THEN
					(* delete recursively *)
					WITH element: OSCMethodContainer DO
						count := element.deleteMethod(adr, nextpos);
						IF element.size = 0 THEN
							(* delete container *)
							childs[elementpos] := childs[size-1];
							childs[size-1] := NIL;
							DEC(size); INC(count);
						END;
						RETURN count;
					END;
				END;
				(* something odd occured, we should never get here. *)
				HALT(ImplementatonError);
			END deleteMethod;

			(* adds a method to the OSC Address Space. Creates interior nodes as needed.
				returns the inserted OSCMethod or NIL on failure. *)
			PROCEDURE insertMethod(adr: String; pos: SIGNED16; method: OSCMethodHandler): OSCMethod;
				VAR
					nextpos: SIGNED16;
					subaddr, name: String;
					newcontainer: OSCMethodContainer;
					newmethod: OSCMethod;
					element: OSCMethodTree;
			BEGIN
				nextAddrPartIndex(adr, pos, nextpos);
				(* do not allow the empty string *)
				IF nextpos = pos + 1 THEN RETURN NIL END;
				name := Strings.Substring(pos+1, nextpos, adr^);
				element := search(name);
				(* if not found add it *)
				IF element = NIL THEN
					(* add new Child or Container *)
					IF size = LEN(childs) THEN SELF.grow END;
					IF adr[nextpos] = 0X THEN (* adding a new OSCMethod *)
						NEW(newmethod, adr, name, method);
						childs[size] := newmethod;
						INC(size);
						RETURN newmethod;
					ELSE (* adding a new container *)
						subaddr := Strings.Substring(0, nextpos, adr^);
						NEW(newcontainer, subaddr, name);
						childs[size] := newcontainer;
						INC(size);
						RETURN newcontainer.insertMethod(adr, nextpos, method);
					END;
				ELSE
					(* match found on position i *)
					IF adr[nextpos] = 0X THEN
						(* There is already a container or method with this name *)
						RETURN NIL
					ELSE
						IF element IS OSCMethodContainer THEN
							WITH element: OSCMethodContainer DO
								RETURN element.insertMethod(adr, nextpos, method);
							END
						ELSE
							(* insert called on a method *)
							RETURN NIL;
						END
					END;
				END;
				RETURN NIL;
			END insertMethod;

			(* searches for a child with name as the last pattern. Returns the corresponding Method or Container *)
			PROCEDURE search(name: String): OSCMethodTree;
			VAR i: SIGNED16;
			BEGIN
				RETURN searchpos(name, i);
			END search;

			(* searches for a child with name as the last pattern.
				Returns the corresponding Method or Container and the index of it in the childs array (in pos) *)
			PROCEDURE searchpos(name: String; VAR pos: SIGNED16): OSCMethodTree;
			VAR i: SIGNED16;
			BEGIN
				FOR i := 0 TO SELF.size - 1 DO
					IF Strings.Equal(name, childs[i].name) THEN
						pos := i;
						RETURN childs[i];
					END;
				END;
				RETURN NIL;
			END searchpos;

			(* used internally to increase the size of the childs array. *)
			PROCEDURE grow;
				VAR
					newchilds: Childs;
					i: SIGNED16;
			BEGIN
				NEW(newchilds, LEN(childs)*2);
				FOR i := 0 TO size-1 DO
					newchilds[i] := childs[i];
				END;
				childs := newchilds;
			END grow;

			(* match function adopted vom OSC-pattern-match.c of the OSC-Kit by Matt Wright, see licence below.
				This function is called when an character class is encountered during matching.
				patternpos is the index of the classes opening '['.
				namepos points to character to match next in the current name. *)
			PROCEDURE matchcclass(name: String; namepos: SIGNED16; pattern: String; patternpos: SIGNED16): BOOLEAN;
			VAR
				n, p: SIGNED16;
				negated, result, done: BOOLEAN;
			BEGIN
				n := namepos; p := patternpos;
				INC(p); (* skip '[' *)
				negated := FALSE;
				IF pattern[p] = '!' THEN
					negated := TRUE;
					INC(p);
				END;
				done := FALSE;
				WHILE (~done) &(pattern[p] # ']') DO
					IF pattern[p] = 0X THEN
						(* unterminated '[' *)
						RETURN FALSE;
					END;
					IF (pattern[p+1] = '-') & (pattern[p+2] # 0X) THEN
						IF (name[n] >= pattern[p]) & (name[n] <= pattern[p+2]) THEN
							result := ~ negated;
							(* EXIT *)
							done := TRUE;
						END;
					ELSIF name[n] = pattern[p] THEN
						result := ~ negated;
						(* EXIT *)
						done := TRUE;
					END;
					IF ~ done THEN INC(p); END;
				END;
				IF pattern[p] = ']' THEN
					result := negated;
				END;
				IF ~ result THEN RETURN FALSE; END;

				(* skip rest of pattern *)
				WHILE pattern[p] # ']' DO
					IF pattern[p] = 0X THEN
						(* unterminated '[' *)
						RETURN FALSE;
					END;
					INC(p);
				END;

				RETURN matchpos(name, n+1, pattern, p+1);
			END matchcclass;

			(* match function adopted vom OSC-pattern-match.c of the OSC-Kit by Matt Wright, see licence below.
				 This function is called then a list of strings is encountered in the pattern during matching.
				 patternpos points to the lists opening '{'.
				 namepos is the index of the next character to match in name. *)
			PROCEDURE matchlist(name: String; namepos: SIGNED16; pattern: String; patternpos: SIGNED16): BOOLEAN;
			VAR
				restofpattern, p, n: SIGNED16;
			BEGIN
				p := patternpos; n := namepos;
				(* find rest of pattern *)
				restofpattern := p;
				WHILE pattern[restofpattern] # '}' DO
					IF pattern[restofpattern] = 0X THEN
						(* pattern ended, althought { was open *)
						RETURN FALSE;
					END;
					INC(restofpattern);
				END;
				INC(restofpattern); (* skip } *)
				INC(p); (* skip { *)
				LOOP
					IF pattern[p] = ',' THEN
						IF matchpos(name, n, pattern, restofpattern) THEN
							RETURN TRUE;
						ELSE
							n := namepos;
							INC(p);
						END;
					ELSIF pattern[p] = '}' THEN
						RETURN matchpos(name, n, pattern, restofpattern);
					ELSIF pattern[p] = name[n] THEN
						INC(p); INC(n);
					ELSE
						n := namepos;
						WHILE (pattern[p] # ',' ) & (pattern[p] # '}') DO INC(p); END;
						IF pattern[p] = ',' THEN INC(p); END;
					END;
				END;
				HALT(99);
			END matchlist;

			(* match function adopted vom OSC-pattern-match.c of the OSC-Kit by Matt Wright, see licence below.
				This function tries to match a name with a pattern. Returns TRUE iff a match is possible.
				name: The name to match; pattern: The pattern, which is tried to match with name.
				namepos: The index of the next character to match in name.
				patternpos: The index of the next character in pattern to match with name. *)
			PROCEDURE matchpos(name: String; namepos: SIGNED16; pattern: String; patternpos: SIGNED16): BOOLEAN;
			VAR
				p, n: SIGNED16;
			BEGIN
				n := namepos;
				p := patternpos;
				ASSERT(name # NIL); (* ASSERT(Strings.Length(name) >= n); *)
				ASSERT(pattern # NIL); (* ASSERT(Strings.Length(pattern) >= p); *)
				IF pattern[p] = 0X THEN RETURN name[n] = 0X; END;
				IF name[n] = 0X THEN
					IF pattern[p] = '*' THEN
						RETURN matchpos(name, n, pattern, p+1);
					ELSE
						RETURN FALSE;
					END;
				END;
				CASE pattern[p] OF
					'?': RETURN matchpos(name, n+1, pattern, p+1);
				|	'*':
						IF matchpos(name, n, pattern, p+1) THEN
							RETURN TRUE;
						ELSE
							RETURN matchpos(name, n+1, pattern, p);
						END;
				|	']':
						IF LogErrors THEN
							KernelLog.String("Unmatched ] in Pattern: "); KernelLog.String(pattern^);
							KernelLog.String(" at position: "); KernelLog.Int(p, 3);
						END;
						RETURN FALSE;
				|	'}':
						IF LogErrors THEN
							KernelLog.String("Unmatched } in Pattern: "); KernelLog.String(pattern^);
							KernelLog.String(" at position: "); KernelLog.Int(p, 3);
						END;
						RETURN FALSE;
				|	'[':	RETURN matchcclass(name, n, pattern, p);
				|	'{':	RETURN matchlist(name, n, pattern, p);
				ELSE
					IF name[n] = pattern[p] THEN
						RETURN matchpos(name, n+1, pattern, p+1);
					ELSE
						RETURN FALSE;
					END;
				END;
				(* We should never get here *)
				HALT(ImplementatonError);
			END matchpos;

			(* match function adopted vom OSC-pattern-match.c of the OSC-Kit by Matt Wright, see licence below.
				this function starts a matching of pattern with name. *)
			PROCEDURE match(name, pattern: String): BOOLEAN;
			BEGIN
				RETURN matchpos(name, 0, pattern, 0);
			END match;

(* Copyright 1998. The Regents of the University of California (Regents).
All Rights Reserved.

Written by Matt Wright, The Center for New Music and Audio Technologies, University of California, Berkeley.

Permission to use, copy, modify, distribute, and distribute modified versions of this software and its documentation without fee and without a signed licensing agreement, is hereby granted,
provided that the above copyright notice, this paragraph and the following two paragraphs appear in all copies, modifications, and distributions.

IN NO EVENT SHALL REGENTS BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT
OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF REGENTS HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

REGENTS SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
THE SOFTWARE AND ACCOMPANYING DOCUMENTATION, IF ANY, PROVIDED HEREUNDER IS PROVIDED "AS IS". REGENTS HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

The OpenSound Control WWW page is http://www.cnmat.berkeley.edu/OpenSoundControl *)

			(* dumps this container *)
			PROCEDURE dump(ident: SIGNED16);
			VAR i: SIGNED16;
			BEGIN
				FOR i := 0 TO ident DO KernelLog.String(dumpident); END;
				KernelLog.String("Container: "); KernelLog.String(SELF.fullname^);
				KernelLog.String("{ name: "); KernelLog.String(SELF.name^);
				KernelLog.String(" size: "); KernelLog.Int(SELF.size, 5);
				KernelLog.String(" LEN(childs): "); KernelLog.Int(LEN(childs), 5);
				KernelLog.Ln;
				FOR i := 0 TO size-1 DO childs[i].dump(ident+1); END;
				FOR i := 0 TO ident DO KernelLog.String(dumpident); END;
				KernelLog.String("}"); KernelLog.Ln
			END dump;

		END OSCMethodContainer;

		(* This class represents a leaf in the OSC Address Space. *)
		OSCMethod = OBJECT(OSCMethodTree)
			VAR
				method: OSCMethodHandler;

			PROCEDURE &InitMethod*(fullname, name: String; m: OSCMethodHandler);
			BEGIN
				InitOSCMethodTree(fullname, name);
				SELF.method := m;
			END InitMethod;

			(* runs the associated method handler with a OSCMessage. *)
			PROCEDURE runMessage(m: OSC.OSCMessage);
			BEGIN
				ASSERT(SELF.method # NIL);
				SELF.method(m);
			END runMessage;

			PROCEDURE dump(ident: SIGNED16);
			VAR i: SIGNED16;
			BEGIN
				FOR i := 0 TO ident DO KernelLog.String(dumpident); END;
				KernelLog.String("Method: "); KernelLog.String(SELF.fullname^);
				KernelLog.String("{ name: "); KernelLog.String(SELF.name^);
				KernelLog.String(" }"); KernelLog.Ln;
			END dump;

		END OSCMethod;

		(* This objecttype represents an OSC Address Space.
			Note: Concurrent access to this object will be serialized correctly. *)
		TYPE OSCRegistry* = OBJECT
			VAR
				root: OSCMethodContainer;

			PROCEDURE &Init*;
			VAR
				rootadr2, rootname2: String;
			BEGIN
				rootadr2 := Strings.NewString(rootadr);
				rootname2 := Strings.NewString(rootname);
				NEW(root, rootadr2,  rootname2);
			END Init;

			(* inserts a function: '/foo/bar' into the address space. Adds containers if needed *)
			PROCEDURE AddMethod*(adr: String; method: OSCMethodHandler);
			VAR
				insertedmethod: OSCMethod;
			BEGIN
				IF ~ OSC.CheckOSCAdr(adr) THEN RETURN END;
				insertedmethod := root.insertMethod(adr, 0, method);
				RETURN;
			END AddMethod;

			(* removes the method with the address adr (if found), removes also any unneded interior nodes *)
			PROCEDURE RemoveMethod*(adr: String);
			VAR
				i: SIGNED16;
			BEGIN
				i := root.deleteMethod(adr, 0);
			END RemoveMethod;

			(* runs a Message, includes also Pattern matching *)
			PROCEDURE Run*(m: OSC.OSCMessage);
			BEGIN
				root.runMessage(m.address, 0, m);
			END Run;

			(* dumps the whole registry *)
			PROCEDURE DumpRegistry*;
			VAR
				ident: SIGNED16;
			BEGIN
				ident := 0;
				KernelLog.String("Dump of registry starts:"); KernelLog.Ln;
				root.dump(ident);
				KernelLog.String("Dump of registry done"); KernelLog.Ln;
			END DumpRegistry;

		END OSCRegistry;

	(* test procedures *)
	PROCEDURE Test*;
	VAR
		reg: OSCRegistry;
		adr: String;
	BEGIN
		KernelLog.String("Running test:");
		adr := Strings.NewString("/containerA/containerA1/methodM1");
		NEW(reg);
		reg.AddMethod(adr, DummyHandler);
		adr := Strings.NewString("/containerA/methodM2");
		reg.AddMethod(adr, DummyHandler);
		adr := Strings.NewString("/containerA/containerA1/methodM1");
		reg.AddMethod(adr, DummyHandler);
		reg.AddMethod(Strings.NewString("/containerA/methodM3"), DummyHandler);
		reg.AddMethod(Strings.NewString("/containerA/methodM4"), DummyHandler);
		reg.AddMethod(Strings.NewString("/containerA/methodM5"), DummyHandler);
		reg.AddMethod(Strings.NewString("/containerA/methodM6"), DummyHandler);
		reg.DumpRegistry;
		reg.RemoveMethod(Strings.NewString("/containerA/methodM2"));
		reg.RemoveMethod(Strings.NewString("/containerA/containerA1/methodM1"));
		reg.RemoveMethod(Strings.NewString("/containerB"));
		reg.DumpRegistry;
		KernelLog.String(" done"); KernelLog.Ln;
	END Test;

	PROCEDURE TestMatcher*;
	VAR
		container: OSCMethodContainer;
	BEGIN
		NEW(container, NIL, NIL);
		KernelLog.Boolean(container.match(Strings.NewString('abcd'), Strings.NewString('abcd'))); KernelLog.Ln;
		KernelLog.Boolean(container.match(Strings.NewString('abcde'), Strings.NewString('abcd'))); KernelLog.Ln;
		KernelLog.Boolean(container.match(Strings.NewString('abcd'), Strings.NewString('abcd?'))); KernelLog.Ln;
		KernelLog.Boolean(container.match(Strings.NewString('abcd'), Strings.NewString('ab?d'))); KernelLog.Ln;
		KernelLog.Boolean(container.match(Strings.NewString('abcd'), Strings.NewString('ab*'))); KernelLog.Ln;
		KernelLog.Boolean(container.match(Strings.NewString('abcd'), Strings.NewString('a*d'))); KernelLog.Ln;
		KernelLog.Boolean(container.match(Strings.NewString('abcd'), Strings.NewString('a[a-d]cd'))); KernelLog.Ln;
		KernelLog.Boolean(container.match(Strings.NewString('abcd'), Strings.NewString('a*[b]*{xx,yy,cd,aa}*'))); KernelLog.Ln;
	END TestMatcher;

	(* a dummy handler, prints out the message when Trace is enabled, othervise it will be silently ignored *)
	PROCEDURE DummyHandler*(m: OSC.OSCMessage);
	BEGIN
		IF Trace THEN
			KernelLog.String("Called dummy handler with message: "); KernelLog.Ln;
			m.dump(0);
		END;
	END DummyHandler;

END OSCRegistry.

OSCRegistry.Test ~
OSCRegistry.TestMatcher ~
