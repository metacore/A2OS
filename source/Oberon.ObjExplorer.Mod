(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ObjExplorer IN Oberon; (* ejz,  *)
	IMPORT Objects, Display, Strings, Texts, Oberon, Attributes, Gadgets, ListRiders, ListModels, ListGadgets, Columbus;

	TYPE
		Item = POINTER TO ItemDesc;
		ItemDesc = RECORD (ListRiders.StringDesc)
			obj: Objects.Object
		END;
		ObjList = POINTER TO ObjListDesc;
		ObjListDesc = RECORD
			obj: Objects.Object;
			next: ObjList
		END;

	VAR
		objList: ObjList;
		enumObj, dlink, curList: Objects.Object;

	PROCEDURE FindObj(obj: Objects.Object): BOOLEAN;
		VAR
			C: ListRiders.ConnectMsg;
			R: ListRiders.Rider;
			pos: SIGNED32;
	BEGIN
		C.R := NIL; Objects.Stamp(C); curList.handle(curList, C);
		R := C.R; pos := 0;
		WHILE ~R.eol DO
			IF R.d(Item).obj = obj THEN
				RETURN TRUE
			END;
			INC(pos); R.do.Set(R, pos)
		END;
		RETURN FALSE
	END FindObj;

	PROCEDURE AddObj(obj: Objects.Object);
		VAR o: ObjList;
	BEGIN
		IF FindObj(obj) & ~(dlink IS Gadgets.View) THEN
			(* Desktop & NamePlate *)
			RETURN
		END;
		o := objList;
		WHILE (o # NIL) & (o.obj # obj) DO
			o := o.next
		END;
		IF o = NIL THEN
			NEW(o); o.obj := obj;
			o.next := objList; objList := o
		END
	END AddObj;

	PROCEDURE WriteObj(R: ListRiders.Rider; obj: Objects.Object; pos: SIGNED32);
		VAR
			item: Item;
			gen, name: Objects.Name;
	BEGIN
		NEW(item); item.obj := obj; item.s := "";
		IF (obj.lib # NIL) & (obj.lib.name # "") THEN
			COPY(obj.lib.name, item.s);
			Strings.AppendCh(item.s, ".");
			Objects.GetName(obj.lib.dict, obj.ref, name);
			IF name = "" THEN
				Strings.IntToStr(obj.ref, name)
			END
		ELSE
			Attributes.GetString(obj, "Name", name)
		END;
		IF name # "" THEN
			Strings.Append(item.s, name);
			Strings.AppendCh(item.s, " ")
		END;
		Attributes.GetString(obj, "Gen", gen);
		Strings.Append(item.s, "(");
		Strings.Append(item.s, gen);
		Strings.AppendCh(item.s, ")");
		R.do.Set(R, pos);
		R.do.Write(R, item)
	END WriteObj;

	PROCEDURE EnumObjs(CONST name: ARRAY OF CHAR);
		VAR L: Objects.LinkMsg;
	BEGIN
		L.id := Objects.get; COPY(name, L.name); L.obj := NIL;
		enumObj.handle(enumObj, L);
		IF L.obj # NIL THEN
			AddObj(L.obj)
		END
	END EnumObjs;

	PROCEDURE Object(R: ListRiders.Rider; obj: Objects.Object; pos: SIGNED32);
		VAR
			linkR: ListRiders.Rider;
			L: Objects.LinkMsg;
			Fi: Texts.Finder;
			F: Display.Frame;
			bakObj, bakDlink, o: Objects.Object;
			bakList, list: ObjList;
			n: SIGNED32;
	BEGIN
		linkR := NIL; n := 0;
		WriteObj(R, obj, pos);
		R.do.Set(R, pos);
		bakList := objList; objList := NIL;
		bakObj := enumObj; enumObj := obj;
		bakDlink := dlink; dlink := obj;
		IF (obj IS Display.Frame) & (obj(Display.Frame).dsc # NIL) THEN
			F := obj(Display.Frame).dsc;
			WHILE F # NIL DO
				AddObj(F); F := F.next
			END
		ELSIF obj IS Texts.Text THEN
			Texts.OpenFinder(Fi, obj(Texts.Text), 0);
			Texts.FindObj(Fi, o);
			WHILE ~Fi.eot DO
				AddObj(o); Texts.FindObj(Fi, o)
			END
		END;
		L.id := Objects.enum; L.Enum := EnumObjs;
		obj.handle(obj, L);
		list := objList; objList := bakList;
		enumObj := bakObj; dlink := bakDlink;
		IF list # NIL THEN
			linkR := R.do.Desc(R, NIL);
			WHILE list # NIL DO
				linkR.do.Set(linkR, n);
				Object(linkR, list.obj, n);
				INC(n); list := list.next
			END;
		END
	END Object;

	PROCEDURE Inspect*;
		VAR
			F: Display.Frame;
			R: ListRiders.Rider;
			C: ListRiders.ConnectMsg;
			list: Objects.Object;
	BEGIN
		F := Oberon.MarkedFrame();
		list := Gadgets.FindObj(Gadgets.context, "List");
		WITH list: ListModels.List DO
			curList := list;
			ListModels.InitList(list, FALSE);
			objList := NIL;
			C.R := NIL; Objects.Stamp(C); list.handle(list, C); R := C.R;
			Object(R, F, 0);
			Gadgets.Update(list);
			curList := NIL
		END
	END Inspect;

	PROCEDURE ShowObj*;
		VAR
			S: Attributes.Scanner;
			list: Objects.Object;
			C: ListRiders.ConnectMsg;
			R: ListRiders.Rider;
			line: ListGadgets.Line;
	BEGIN
		list := Gadgets.FindObj(Gadgets.context, "List");
		C.R := NIL; Objects.Stamp(C); list.handle(list, C); R := C.R;
		Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
		Attributes.Scan(S);
		IF S.class = Attributes.Int THEN
			R.do.Seek(R, S.i);
			IF (R.d # NIL) & (R.d IS Item) THEN
				Columbus.InspectObj(R.d(Item).obj)
			END
		ELSE
			list := Gadgets.FindObj(Gadgets.context, "ListF");
			WITH list: ListGadgets.Frame DO
				line := list.lines;
				REPEAT
					IF line.sel THEN
						R.do.Seek(R, line.key);
						Columbus.InspectObj(R.d(Item).obj)
					END;
					line := line.next
				UNTIL line = list.lines
			END
		END
	END ShowObj;

END ObjExplorer.

ObjExplorer.Panel
