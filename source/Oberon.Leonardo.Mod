(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Leonardo IN Oberon; (** portable **)	(* eos  *)

	(**
		Model of the Leonardo figure editor
	**)

	IMPORT
		Files, Display, Objects, Texts, Oberon, Strings, Gadgets, GfxMatrix, GfxRegions, Gfx;


	CONST
		get* = 1; reset* = 2; validate* = 3;	(** select message **)
		integrate* = 1; delete* = 2; clone* = 3;	(** control message **)
		up* = 1; down* = 2; top* = 3; bottom* = 4; reverse* = 5;	(** priority message **)
		active* = 1; passive* = 2; marksonly* = 3; marked* = 4;	(** render message **)
		accumulate* = 2;	(** matrix message **)
		inside* = 1; overlap* = 2; project* = 3;	(** locate message **)
		apply* = 1; notify* = 2;	(** transform message **)

		border* = 12;	(** number of display units around shape bounding box available for rendering selection marks **)


	TYPE
		(** graphical objects **)
		Shape* = POINTER TO ShapeDesc;
		ShapeDesc* = RECORD (Objects.ObjDesc)
			cont*: Shape;	(** shape containing this shape **)
			up*, down*: Shape;	(** predecessor and successor in doubly linked list **)
			llx*, lly*, urx*, ury*: FLOAT32;	(** bounding box in global coordinates **)
			bw*: FLOAT32;	(** border width (additional space around box affected by rendering) **)
			sel*: BOOLEAN;	(** true if shape or one of its components is selected **)
			marked*: BOOLEAN;	(** true if shape is temporarily marked **)
		END;

		(** container shapes containing component shapes **)
		Container* = POINTER TO ContainerDesc;
		ContainerDesc* = RECORD (ShapeDesc)
			bottom*, top*: Shape;	(** bottommost and topmost component shape **)
			subsel*: BOOLEAN;	(** true if at least one component is selected **)
		END;

		Figure* = POINTER TO FigureDesc;

		(** layers within a figure **)
		Layer* = POINTER TO LayerDesc;
		LayerDesc* = RECORD (ContainerDesc)
			fig*: Figure;	(** figure that layer is part of **)
			name*: ARRAY 16 OF CHAR;	(** layer name **)
			display*, print*, align*: BOOLEAN;	(** flags **)
		END;

		Command = POINTER TO CommandDesc;

		(** figure model **)
		FigureDesc* = RECORD (Objects.ObjDesc)
			bottom*, top*: Shape;	(** layers containing shapes **)
			active*: Layer;	(** currently editable layer **)
			seltime*: SIGNED32;	(** time of current selection, negative for empty selection **)
			damage: GfxRegions.Region;	(* accumulated area that should be updated *)
			bw: FLOAT32;	(* maximal border width around damage area *)
			lockLevel: SIGNED16;	(* number of times updates have been disabled *)
			cmdLevel: SIGNED16;	(* number of nested commands that are currently open *)
			maxCmds, nofCmds: SIGNED16;	(* maximal and current number of undoable commands retained *)
			curCmd: Command;	(* current command *)
			firstCmd: Command;	(* first command that can still be undone *)
			undoCmd: Command;	(* command to undo next *)
		END;

		(** undoable commands **)
		Action* = POINTER TO ActionDesc;
		ActionProc* = PROCEDURE (fig: Figure; action: Action);
		ActionDesc* = RECORD
			do*, undo*: ActionProc;	(* handler for executing and undoing actions *)
			link: Action;	(* link to next action *)
		END;

		CommandDesc = RECORD
			next, prev: Command;	(* links to next and previous command *)
			actions, done, last: Action;	(* list of actions *)
		END;

		ControlAction* = POINTER TO ControlActionDesc;
		ControlActionDesc* = RECORD (ActionDesc)
			down, bottom, top, up: Shape;
			cont: Container;
		END;

		AttrAction = POINTER TO AttrActionDesc;
		AttrActionDesc = RECORD (ActionDesc)
			shape: Shape;	(* affected shape *)
			name: ARRAY 32 OF CHAR;	(* attribute name *)
		END;

		IntAction = POINTER TO IntActionDesc;
		IntActionDesc = RECORD (AttrActionDesc)
			int: SIGNED32;
		END;

		RealAction = POINTER TO RealActionDesc;
		RealActionDesc = RECORD (AttrActionDesc)
			real: FLOAT32;
		END;

		StringAction = POINTER TO StringActionDesc;
		StringActionDesc = RECORD (AttrActionDesc)
			str: ARRAY 64 OF CHAR;
		END;

		(** figure update message **)
		UpdateMsg* = RECORD (Display.FrameMsg)
			fig*: Figure;	(** affected figure **)
			reg*: GfxRegions.Region;	(** affected area **)
			bw*: FLOAT32;	(** border around affected area **)
		END;

		(** shape messages **)
		ShapeMsg* = RECORD (Objects.ObjMsg)
			fig*: Figure;	(** containing figure **)
		END;

		UnmarkMsg = RECORD (ShapeMsg)
			(* currently private, only used to unmark transformed shapes in CancelTransform *)
		END;

		SelectMsg* = RECORD (ShapeMsg)
			id*: SIGNED16;	(** get/reset/validate **)
			res*: Shape;	(** linked list of shapes which handled 'get' (in top-down order) **)
		END;

		ControlMsg* = RECORD (ShapeMsg)
			id*: SIGNED16;	(** integrate/delete/clone **)
			bottom*, top*: Shape;	(** shape list for consume (in) and clone (out) **)
			cont*, up*, down*: Shape;	(** position where to integrate **)
		END;

		OrderMsg* = RECORD (ShapeMsg)
			id*: SIGNED16;	(** up/down/top/bottom/reverse **)
		END;

		(** shape messages transporting a local coordinate system **)
		LocalizedMsg* = RECORD (ShapeMsg)
			lgm*: GfxMatrix.Matrix;	(** conversion from local to global coordinates **)
		END;

		ValidateMsg* = RECORD (LocalizedMsg)
		END;

		CoordMsg* = RECORD (LocalizedMsg)
			dest*: Shape;	(** destination shape **)
			res*: GfxMatrix.Matrix;	(** local to global transformation of destination shape **)
		END;

		ConsumeMsg* = RECORD (LocalizedMsg)
			llx*, lly*, urx*, ury*: FLOAT32;	(** target location (in global coordinates) **)
			bottom*, top*: Shape;	(** shapes to consume **)
			slgm*: GfxMatrix.Matrix;	(** source shape's coordinate space **)
			recv*: Shape;	(** consuming target shape **)
		END;

		RenderMsg* = RECORD (LocalizedMsg)
			id*: SIGNED16;	(** active/passive/marksonly/marked **)
			ctxt*: Gfx.Context;	(** associated context **)
			gsm*: GfxMatrix.Matrix;	(** conversion from global to standard coordinates **)
			llx*, lly*, urx*, ury*: FLOAT32;	(** clip rectangle (in global coordinates) **)
		END;

		LocateMsg* = RECORD (LocalizedMsg)
			id*: SIGNED16;	(** inside/overlap/project **)
			llx*, lly*, urx*, ury*: FLOAT32;	(** rectangle within which to locate (in global coordinates) **)
			res*: Shape;	(** linked list of shapes which handled message (in top-down order) **)
			x*, y*: FLOAT32;	(** point to project **)
			px*, py*: FLOAT32;	(** projected coordinates **)
		END;

		TransformMsg* = RECORD (LocalizedMsg)
			id*: SIGNED16;	(** apply/notify **)
			notify*: BOOLEAN;	(** to be set by receiver if additional notify cycle is necessary **)
			mat*: GfxMatrix.Matrix;	(** transformation matrix in global coordinates **)
		END;

		MatrixMsg* = RECORD (LocalizedMsg)
			dest*: Shape;	(** destination shape **)
			x0*, y0*, x1*, y1*, tol*: FLOAT32;	(** drag vector and locate tolerance (in global coordinates) **)
			done*: BOOLEAN;	(** set by destination shape **)
			mat*: GfxMatrix.Matrix;	(** resulting global transformation matrix **)
		END;

		(** shape message for broadcasts in display space **)
		BroadcastMsg* = RECORD (Display.FrameMsg)
			(**
				empty base type, but is propagated within shape hierarchy
				affected shapes should just mark themselves; after the broadcast, a validate message is sent to all shapes
			**)
		END;


	VAR
		W: Texts.Writer;


	(**--- Updates ---**)

	PROCEDURE Update (fig: Figure);
		VAR um: UpdateMsg;
	BEGIN
		um.F := NIL; um.fig := fig; um.reg := fig.damage; um.bw := fig.bw;
		Display.Broadcast(um);
		GfxRegions.Clear(fig.damage); fig.bw := 0
	END Update;

	(** disable broadcast of update messages (nested calls allowed) **)
	PROCEDURE DisableUpdate* (fig: Figure);
	BEGIN
		INC(fig.lockLevel)
	END DisableUpdate;

	(** re-enable update broadcasts; pending updates are immediately broadcast **)
	PROCEDURE EnableUpdate* (fig: Figure);
	BEGIN
		DEC(fig.lockLevel);
		IF (fig.lockLevel = 0) & ~GfxRegions.Empty(fig.damage) THEN
			Update(fig)
		END
	END EnableUpdate;

	(** update rectangle **)
	PROCEDURE UpdateRect* (fig: Figure; llx, lly, urx, ury, bw: FLOAT32);
		VAR llu, llv, uru, urv: SIGNED16;
	BEGIN
		IF (llx < urx) & (lly < ury) THEN
			llu := SHORT(ENTIER(llx)); llv := SHORT(ENTIER(lly));
			uru := -SHORT(ENTIER(-urx)); urv := -SHORT(ENTIER(-ury));
			IF fig.lockLevel > 0 THEN
				GfxRegions.AddRect(fig.damage, llu, llv, uru, urv);
				IF bw > fig.bw THEN fig.bw := bw END
			ELSE
				GfxRegions.SetToRect(fig.damage, llu, llv, uru, urv);
				fig.bw := bw;
				Update(fig)
			END
		END
	END UpdateRect;

	(** update shape area **)
	PROCEDURE UpdateShape* (fig: Figure; shape: Shape);
	BEGIN
		IF (shape.llx < shape.urx) & (shape.lly < shape.ury) THEN
			UpdateRect(fig, shape.llx, shape.lly, shape.urx, shape.ury, shape.bw)
		ELSIF shape IS Layer THEN	(* empty layer must generate updates, too *)
			UpdateRect(fig, GfxRegions.LBound, GfxRegions.LBound, GfxRegions.UBound, GfxRegions.UBound, 0)
		END
	END UpdateShape;


	(**--- Selection ---**)

	PROCEDURE ValidateSelection* (fig: Figure);
		VAR sm: SelectMsg; layer: Shape;
	BEGIN
		sm.id := validate;
		fig.handle(fig, sm);
		layer := fig.bottom; WHILE (layer # NIL) & ~layer(Layer).subsel DO layer := layer.up END;
		IF layer # NIL THEN fig.seltime := Oberon.Time()	(* layer contains selected shapes *)
		ELSE fig.seltime := -1
		END;
	END ValidateSelection;

	(** return current selection as a linked list of shapes **)
	PROCEDURE Selection* (fig: Figure): Shape;
		VAR sm: SelectMsg;
	BEGIN
		Objects.Stamp(sm); sm.id := get; sm.res := NIL;
		IF fig.seltime >= 0 THEN
			fig.handle(fig, sm)
		END;
		RETURN sm.res
	END Selection;

	(** select linked list of shapes **)
	PROCEDURE Select* (fig: Figure; shapes: Shape);
		VAR obj: Objects.Object; sh: Shape;
	BEGIN
		IF shapes # NIL THEN
			DisableUpdate(fig);
			obj := shapes;
			WHILE obj # NIL DO
				sh := obj(Shape); sh.sel := TRUE; obj := obj.slink;
				UpdateShape(fig, sh)
			END;
			ValidateSelection(fig);
			EnableUpdate(fig)
		END
	END Select;

	(** deselect linked list of shapes **)
	PROCEDURE Deselect* (fig: Figure; shapes: Shape);
		VAR obj: Objects.Object; sm: SelectMsg;
	BEGIN
		IF shapes # NIL THEN
			DisableUpdate(fig);
			obj := shapes; sm.fig := fig; sm.id := reset;
			WHILE obj # NIL DO
				obj.handle(obj, sm); obj := obj.slink
			END;
			ValidateSelection(fig);
			EnableUpdate(fig)
		END
	END Deselect;

	(** make selection empty **)
	PROCEDURE ClearSelection* (fig: Figure);
		VAR sm: SelectMsg;
	BEGIN
		IF fig.seltime >= 0 THEN
			DisableUpdate(fig);
			sm.id := reset; fig.handle(fig, sm);
			fig.seltime := -1;
			EnableUpdate(fig)
		END
	END ClearSelection;

	(** mark shapes in selection **)
	PROCEDURE MarkSelection* (fig: Figure);
		VAR sm: SelectMsg; obj: Objects.Object;
	BEGIN
		IF fig.seltime >= 0 THEN
			Objects.Stamp(sm); sm.id := get; sm.res := NIL; fig.handle(fig, sm);
			obj := sm.res;
			WHILE obj # NIL DO
				obj(Shape).marked := TRUE; obj := obj.slink
			END
		END
	END MarkSelection;


	(**--- Commands ---**)

	(** validate all shapes in figure **)
	PROCEDURE Validate* (fig: Figure);
		VAR vm: ValidateMsg;
	BEGIN
		DisableUpdate(fig);
		Objects.Stamp(vm); fig.handle(fig, vm);
		EnableUpdate(fig)
	END Validate;

	PROCEDURE InvertActions (cmd: Command);
		VAR cur, link: Action;
	BEGIN
		cur := cmd.actions; cmd.actions := NIL;
		WHILE cur # NIL DO
			link := cur.link; cur.link := cmd.actions; cmd.actions := cur; cur := link
		END
	END InvertActions;

	PROCEDURE DoActions (fig: Figure; cmd: Command);
		VAR cur: Action;
	BEGIN
		InvertActions(cmd);
		DisableUpdate(fig);
		ClearSelection(fig);
		cur := cmd.actions;
		WHILE cur # NIL DO
			cur.do(fig, cur); cur := cur.link
		END;
		ValidateSelection(fig); Validate(fig);
		EnableUpdate(fig)
	END DoActions;

	PROCEDURE UndoActions (fig: Figure; cmd: Command);
		VAR cur: Action;
	BEGIN
		InvertActions(cmd);
		DisableUpdate(fig);
		ClearSelection(fig);
		cur := cmd.actions;
		WHILE cur # NIL DO
			cur.undo(fig, cur); cur := cur.link
		END;
		ValidateSelection(fig); Validate(fig);
		EnableUpdate(fig)
	END UndoActions;

	(** begin a new command (nested calls allowed) **)
	PROCEDURE BeginCommand* (fig: Figure);
	BEGIN
		INC(fig.cmdLevel);
		IF fig.cmdLevel = 1 THEN
			NEW(fig.curCmd)
		END
	END BeginCommand;

	(** add an action to the current command **)
	PROCEDURE AddAction* (fig: Figure; action: Action);
		VAR cmd: Command;
	BEGIN
		ASSERT((action.do # NIL) & (action.undo # NIL), 100);
		ASSERT(fig.cmdLevel > 0, 101);
		action.link := NIL;
		cmd := fig.curCmd;
		IF cmd.last = NIL THEN cmd.actions := action
		ELSE cmd.last.link := action
		END;
		cmd.last := action
	END AddAction;

	(** cancel the current command and revert all changes it may already have applied **)
	PROCEDURE CancelCommand* (fig: Figure);
		VAR cmd: Command;
	BEGIN
		cmd := fig.curCmd;
		IF cmd.actions # NIL THEN
			IF cmd.done # NIL THEN cmd.done.link := NIL; cmd.last := cmd.done
			ELSE cmd.actions := NIL; cmd.last := NIL
			END
		END;
		IF (fig.cmdLevel = 1) & (cmd.actions # NIL) THEN
			UndoActions(fig, cmd)
		END;
		DEC(fig.cmdLevel)
	END CancelCommand;

	(** commit current command and execute actions **)
	PROCEDURE EndCommand* (fig: Figure);
		VAR cmd: Command; cur: Action;
	BEGIN
		cmd := fig.curCmd;
		IF cmd.actions # NIL THEN
			DisableUpdate(fig);
			IF cmd.done # NIL THEN cur := cmd.done.link	(* don't re-execute actions of nested commands *)
			ELSE cur := cmd.actions
			END;
			WHILE cur # NIL DO
				cur.do(fig, cur); cur := cur.link
			END;
			cmd.done := cmd.last;	(* last action that has been executed *)
			ValidateSelection(fig); Validate(fig);
			IF fig.cmdLevel = 1 THEN
				fig.undoCmd.next := cmd; cmd.prev := fig.undoCmd; cmd.next := NIL;
				fig.undoCmd := cmd; fig.curCmd := NIL;
				IF fig.nofCmds = fig.maxCmds THEN fig.firstCmd := fig.firstCmd.next; fig.firstCmd.prev := NIL
				ELSE INC(fig.nofCmds)
				END
			END;
			EnableUpdate(fig)
		END;
		DEC(fig.cmdLevel)
	END EndCommand;

	(** undo next undoable command **)
	PROCEDURE Undo* (fig: Figure);
		VAR cmd: Command;
	BEGIN
		ASSERT(fig.cmdLevel = 0, 100);
		cmd := fig.undoCmd;
		IF cmd.prev # NIL THEN
			fig.undoCmd := cmd.prev;
			UndoActions(fig, cmd);
			DEC(fig.nofCmds)
		END
	END Undo;

	(** redo most recently undone command **)
	PROCEDURE Redo* (fig: Figure);
		VAR cmd: Command;
	BEGIN
		ASSERT(fig.cmdLevel = 0, 100);
		cmd := fig.undoCmd.next;
		IF cmd # NIL THEN
			fig.undoCmd := cmd;
			DoActions(fig, cmd);
			INC(fig.nofCmds)
		END
	END Redo;


	(**--- Shape Attributes ---**)

	PROCEDURE DoBoolAction (fig: Figure; act: Action);
		VAR ba: AttrAction; am: Objects.AttrMsg;
	BEGIN
		ba := act(AttrAction);
		am.id := Objects.get; COPY(ba.name, am.name); am.res := -1; ba.shape.handle(ba.shape, am);
		am.b := ~am.b;
		am.id := Objects.set; am.res := -1; ba.shape.handle(ba.shape, am);
		ba.shape.sel := TRUE; ba.shape.marked := TRUE
	END DoBoolAction;

	(** set boolean attribute value with undoable action **)
	PROCEDURE SetBool* (fig: Figure; shape: Shape; name: ARRAY OF CHAR; val: BOOLEAN);
		VAR am: Objects.AttrMsg; ba: AttrAction;
	BEGIN
		am.id := Objects.get; COPY(name, am.name); am.res := -1; shape.handle(shape, am);
		IF (am.res >= 0) & (am.class = Objects.Bool) & (am.b # val) THEN
			NEW(ba); ba.shape := shape; COPY(name, ba.name); ba.do := DoBoolAction; ba.undo := DoBoolAction;
			AddAction(fig, ba)
		END
	END SetBool;

	PROCEDURE DoIntAction (fig: Figure; act: Action);
		VAR ia: IntAction; am: Objects.AttrMsg; val: SIGNED32;
	BEGIN
		ia := act(IntAction);
		am.id := Objects.get; COPY(ia.name, am.name); am.res := -1; ia.shape.handle(ia.shape, am);
		val := am.i; am.i := ia.int; ia.int := val;
		am.id := Objects.set; am.res := -1; ia.shape.handle(ia.shape, am);
		ia.shape.sel := TRUE; ia.shape.marked := TRUE
	END DoIntAction;

	(** set integer attribute value with undoable action **)
	PROCEDURE SetInt* (fig: Figure; shape: Shape; name: ARRAY OF CHAR; val: SIGNED32);
		VAR am: Objects.AttrMsg; ia: IntAction;
	BEGIN
		am.id := Objects.get; COPY(name, am.name); am.res := -1; shape.handle(shape, am);
		IF (am.res >= 0) & (am.class = Objects.Int) & (am.i # val) THEN
			NEW(ia); ia.shape := shape; COPY(name, ia.name); ia.int := val; ia.do := DoIntAction; ia.undo := DoIntAction;
			AddAction(fig, ia)
		END
	END SetInt;

	PROCEDURE DoRealAction (fig: Figure; act: Action);
		VAR ra: RealAction; am: Objects.AttrMsg; val: FLOAT32;
	BEGIN
		ra := act(RealAction);
		am.id := Objects.get; COPY(ra.name, am.name); am.res := -1; ra.shape.handle(ra.shape, am);
		val := am.x; am.x := ra.real; ra.real := val;
		am.id := Objects.set; am.res := -1; ra.shape.handle(ra.shape, am);
		ra.shape.sel := TRUE; ra.shape.marked := TRUE
	END DoRealAction;

	(** set real attribute value with undoable action **)
	PROCEDURE SetReal* (fig: Figure; shape: Shape; name: ARRAY OF CHAR; val: FLOAT32);
		VAR am: Objects.AttrMsg; ra: RealAction;
	BEGIN
		am.id := Objects.get; COPY(name, am.name); am.res := -1; shape.handle(shape, am);
		IF (am.res >= 0) & (am.class = Objects.Real) & (am.x # val) THEN
			NEW(ra); ra.shape := shape; COPY(name, ra.name); ra.real := val; ra.do := DoRealAction; ra.undo := DoRealAction;
			AddAction(fig, ra)
		END
	END SetReal;

	PROCEDURE DoStringAction (fig: Figure; act: Action);
		VAR sa: StringAction; am: Objects.AttrMsg; val: ARRAY 64 OF CHAR;
	BEGIN
		sa := act(StringAction);
		am.id := Objects.get; COPY(sa.name, am.name); am.res := -1; sa.shape.handle(sa.shape, am);
		COPY(am.s, val); COPY(sa.str, am.s); COPY(val, sa.str);
		am.id := Objects.set; am.res := -1; sa.shape.handle(sa.shape, am);
		sa.shape.sel := TRUE; sa.shape.marked := TRUE
	END DoStringAction;

	(** set string attribute value with undoable action **)
	PROCEDURE SetString* (fig: Figure; shape: Shape; name, val: ARRAY OF CHAR);
		VAR am: Objects.AttrMsg; sa: StringAction;
	BEGIN
		am.id := Objects.get; COPY(name, am.name); am.res := -1; shape.handle(shape, am);
		IF (am.res >= 0) & (am.class = Objects.String) & (am.s # val) THEN
			NEW(sa); sa.shape := shape; COPY(name, sa.name); COPY(val, sa.str); sa.do := DoStringAction; sa.undo := DoStringAction;
			AddAction(fig, sa)
		END
	END SetString;

	(** set color value with undoable action **)
	PROCEDURE SetColor* (fig: Figure; shape: Shape; col: Display.Color);
		VAR r, g, b: SIGNED16;
	BEGIN
		Display.GetColor(col, r, g, b);
		SetInt(fig, shape, "Red", r); SetInt(fig, shape, "Green", g); SetInt(fig, shape, "Blue", b)
	END SetColor;

	(** set matrix value with undoable action; element numbers are appended to base name **)
	PROCEDURE SetMatrix* (fig: Figure; shape: Shape; name: ARRAY OF CHAR; mat: GfxMatrix.Matrix);
		VAR l, row, col: SIGNED16; attr: ARRAY 66 OF CHAR;
	BEGIN
		l := 0; WHILE name[l] # 0X DO attr[l] := name[l]; INC(l) END; attr[l+2] := 0X;
		FOR row := 0 TO 2 DO
			attr[l] := CHR(ORD("0") + row);
			FOR col := 0 TO 1 DO
				attr[l+1] := CHR(ORD("0") + col);
				SetReal(fig, shape, attr, mat[row, col])
			END
		END
	END SetMatrix;


	(**--- Transformations ---**)

	PROCEDURE Exchange (a: AttrAction);
		VAR am: Objects.AttrMsg; i: SIGNED32; r: FLOAT32; s: ARRAY 64 OF CHAR;
	BEGIN
		am.id := Objects.get; COPY(a.name, am.name); am.res := -1; a.shape.handle(a.shape, am);
		CASE am.class OF
		| Objects.Int: i := am.i; am.i := a(IntAction).int; a(IntAction).int := i
		| Objects.Real: r := am.x; am.x := a(RealAction).real; a(RealAction).real := r;
		| Objects.String: COPY(am.s, s); COPY(a(StringAction).str, am.s); COPY(s, a(StringAction).str)
		| Objects.Bool: am.b := ~am.b
		ELSE
		END;
		am.id := Objects.set; am.res := -1; a.shape.handle(a.shape, am);
	END Exchange;

	(** begin transformation by applying matrix to shape list and marking affected shapes **)
	PROCEDURE BeginTransform* (fig: Figure; list: Shape; VAR mat: GfxMatrix.Matrix);
		VAR obj: Objects.Object; cmd: Command; done, cur: Action; tm: TransformMsg;
	BEGIN
		BeginCommand(fig);
		obj := list; WHILE obj # NIL DO obj(Shape).marked := TRUE; obj := obj.slink END;
		cmd := fig.curCmd; done := cmd.done;
		tm.id := apply; tm.mat := mat;
		REPEAT
			Objects.Stamp(tm); tm.notify := FALSE; fig.handle(fig, tm);
			IF done # NIL THEN cur := done.link ELSE cur := cmd.actions END;
			WHILE cur # NIL DO
				IF cur IS AttrAction THEN Exchange(cur(AttrAction)) END;
				done := cur; cur := cur.link
			END;
			tm.id := notify
		UNTIL ~tm.notify
	END BeginTransform;

	(** cancel current transformation **)
	PROCEDURE CancelTransform* (fig: Figure);
		VAR cmd: Command; cur: Action; um: UnmarkMsg;
	BEGIN
		cmd := fig.curCmd;
		IF cmd.done # NIL THEN cur := cmd.done.link ELSE cur := cmd.actions END;
		WHILE cur # NIL DO
			IF cur IS AttrAction THEN Exchange(cur(RealAction)) END;
			cur := cur.link
		END;
		fig.handle(fig, um);
		CancelCommand(fig)
	END CancelTransform;

	(** commit current transformation **)
	PROCEDURE EndTransform* (fig: Figure);
		VAR cmd: Command; cur: Action;
	BEGIN
		cmd := fig.curCmd;
		IF cmd.done # NIL THEN cur := cmd.done.link ELSE cur := cmd.actions END;
		WHILE cur # NIL DO	(* undo FLOAT32 actions *)
			IF cur IS RealAction THEN Exchange(cur(RealAction)) END;
			cur := cur.link
		END;
		EndCommand(fig)	(* redo all actions and validate *)
	END EndTransform;

	(** transform list of shapes by matrix **)
	PROCEDURE Transform* (fig: Figure; list: Shape; VAR mat: GfxMatrix.Matrix);
	BEGIN
		BeginTransform(fig, list, mat);
		EndTransform(fig)
	END Transform;


	(**--- Control ---**)

	(** integrate a linked list of shapes (top-down) **)
	PROCEDURE Integrate* (fig: Figure; shapes: Shape);
		VAR cm: ControlMsg; obj: Objects.Object; s: Shape;
	BEGIN
		DisableUpdate(fig); BeginCommand(fig);
		ClearSelection(fig);
		cm.id := integrate; cm.bottom := shapes; cm.top := shapes;
		obj := shapes.slink;
		WHILE obj # NIL DO
			s := obj(Shape); s.up := cm.bottom; cm.bottom.down := s; cm.bottom := s;
			obj := obj.slink
		END;
		cm.cont := fig.active; cm.down := fig.active.top; cm.up := NIL; fig.handle(fig, cm);
		EndCommand(fig); EnableUpdate(fig)
	END Integrate;

	(** delete linked list of shapes **)
	PROCEDURE Delete* (fig: Figure; shapes: Shape);
		VAR obj: Objects.Object; cm: ControlMsg;
	BEGIN
		obj := shapes;
		WHILE obj # NIL DO
			obj(Shape).marked := TRUE; obj := obj.slink
		END;
		BeginCommand(fig);
		cm.id := delete; fig.handle(fig, cm);
		EndCommand(fig)
	END Delete;

	(** create a copy of a linked list of shapes within a figure **)
	PROCEDURE Clone* (fig: Figure; shapes: Shape; VAR copy: Shape);
		VAR obj: Objects.Object; cm: ControlMsg; um: UnmarkMsg; s: Shape;
	BEGIN
		obj := shapes;
		WHILE obj # NIL DO
			obj(Shape).marked := TRUE; obj := obj.slink
		END;
		Objects.Stamp(cm); cm.id := clone; cm.bottom := NIL; cm.top := NIL;
		fig.handle(fig, cm);
		fig.handle(fig, um);
		s := cm.bottom; copy := NIL;
		WHILE s # NIL DO
			s.slink := copy; copy := s; s := s.up
		END
	END Clone;

	(** consume list of shapes in target shape located at (x, y) **)
	PROCEDURE Consume* (fig: Figure; llx, lly, urx, ury: FLOAT32; shapes: Shape; VAR recv: Shape);
		VAR obj, link: Objects.Object; crd: CoordMsg; cm: ConsumeMsg;
	BEGIN
		obj := shapes; shapes := NIL;
		WHILE obj # NIL DO
			link := obj.slink; obj.slink := shapes; shapes := obj(Shape); obj := link
		END;
		BeginCommand(fig); recv := NIL; obj := shapes;
		WHILE obj # NIL DO
			Objects.Stamp(cm); cm.llx := llx; cm.lly := lly; cm.urx := urx; cm.ury := ury;
			cm.bottom := obj(Shape); cm.top := cm.bottom; obj := obj.slink;
			WHILE (obj # NIL) & (obj = cm.top.up) DO
				link := obj.slink; obj.slink := cm.top; cm.top := obj(Shape); obj := link
			END;
			crd.dest := cm.bottom; crd.res := GfxMatrix.Identity; fig.handle(fig, crd);
			cm.slgm := crd.res; cm.recv := NIL;
			fig.handle(fig, cm);
			recv := cm.recv
		END;
		EndCommand(fig)
	END Consume;


	(**--- Render ---**)

	(** render figure on context **)
	PROCEDURE Render* (fig: Figure; id: SIGNED16; ctxt: Gfx.Context);
		VAR rm: RenderMsg; gdm, dsm: GfxMatrix.Matrix;
	BEGIN
		Objects.Stamp(rm); rm.id := id; rm.ctxt := ctxt;
		Gfx.GetClipRect(ctxt, rm.llx, rm.lly, rm.urx, rm.ury);
		gdm := ctxt.ctm; Gfx.ResetCTM(ctxt);
		GfxMatrix.Invert(ctxt.ctm, dsm);
		GfxMatrix.Concat(gdm, dsm, rm.gsm);
		Gfx.SetCTM(ctxt, gdm);
		fig.handle(fig, rm)
	END Render;


	(**--- Locate ---**)

	(** locate shapes in figure **)
	PROCEDURE Locate* (fig: Figure; id: SIGNED16; llx, lly, urx, ury: FLOAT32): Shape;
		VAR lm: LocateMsg;
	BEGIN
		Objects.Stamp(lm); lm.id := id; lm.llx := llx; lm.lly := lly; lm.urx := urx; lm.ury := ury; lm.res := NIL;
		fig.handle(fig, lm);
		RETURN lm.res
	END Locate;

	(** project point (x, y) to nearest shape within rectangle (llx, lly, urx, ury) **)
	PROCEDURE Project* (fig: Figure; x, y, llx, lly, urx, ury: FLOAT32; VAR px, py: FLOAT32; VAR res: Shape);
		VAR lm: LocateMsg;
	BEGIN
		Objects.Stamp(lm); lm.id := project; lm.res := NIL; lm.x := x; lm.y := y; lm.px := x; lm.py := y;
		lm.llx := llx; lm.lly := lly; lm.urx := urx; lm.ury := ury;
		fig.handle(fig, lm);
		px := lm.px; py := lm.py; res := lm.res
	END Project;


	(**--- Standard Handles ---**)

	(** draw default shape handles (in local coordinates) **)
	PROCEDURE DrawHandles* (llx, lly, urx, ury: FLOAT32; VAR rm: RenderMsg);
		VAR ctm, lsmat: GfxMatrix.Matrix; col: Gfx.Color; mx, my: FLOAT32;

		PROCEDURE draw (x, y: FLOAT32);
		BEGIN
			GfxMatrix.Apply(lsmat, x, y, x, y);	(* map local to standard coordinates *)
			Gfx.DrawRect(rm.ctxt, x-2, y-2, x+2, y+2, {Gfx.Fill})
		END draw;

	BEGIN
		ctm := rm.ctxt.ctm; Gfx.ResetCTM(rm.ctxt);	(* context maps standard to device coordinates *)
		col := rm.ctxt.fillCol; Gfx.SetFillColor(rm.ctxt, Gfx.DGrey);
		mx := 0.5*(llx + urx); my := 0.5*(lly + ury);
		GfxMatrix.Concat(rm.lgm, rm.gsm, lsmat);
		draw(llx, ury); draw(mx, ury); draw(urx, ury);
		draw(llx, my); draw(urx, my);
		draw(llx, lly); draw(mx, lly); draw(urx, lly);
		Gfx.SetFillColor(rm.ctxt, col); Gfx.SetCTM(rm.ctxt, ctm)
	END DrawHandles;

	(** project point to default shape handles (in local coordinates) **)
	PROCEDURE ProjectToHandles* (shape: Shape; llx, lly, urx, ury: FLOAT32; VAR lm: LocateMsg);
		VAR dmin, mx, my: FLOAT32;

		PROCEDURE project (x, y: FLOAT32);
			VAR dx, dy, d: FLOAT32;
		BEGIN
			GfxMatrix.Apply(lm.lgm, x, y, x, y);	(* convert point to global coordinates *)
			IF (lm.llx <= x) & (x <= lm.urx) & (lm.lly <= y) & (y <= lm.ury) THEN
				dx := x - lm.x; dy := y - lm.y; d := dx * dx + dy * dy;
				IF d < dmin THEN
					dmin := d; lm.px := x; lm.py := y; lm.res := shape
				END
			END
		END project;

	BEGIN
		dmin := MAX(FLOAT32);
		mx := 0.5*(llx + urx); my := 0.5*(lly + ury);
		project(mx, my);
		project(llx, lly); project(llx, ury); project(urx, ury); project(urx, lly);
		project(mx, lly); project(mx, ury); project(llx, my); project(urx, my)
	END ProjectToHandles;

	(** get transformation bound to clicked handle point **)
	PROCEDURE GetHandleMatrix* (llx, lly, urx, ury: FLOAT32; VAR msg: MatrixMsg);
		VAR glmat: GfxMatrix.Matrix; mx, my, llu, llv, uru, urv: FLOAT32;

		PROCEDURE translate;
		BEGIN
			GfxMatrix.Init(msg.mat, 1, 0, 0, 1, msg.x1 - msg.x0, msg.y1 - msg.y0);
			msg.done := TRUE
		END translate;

		(*
		PROCEDURE rotate;
			VAR x, y, dx0, dy0, dx1, dy1, t: FLOAT32;
		BEGIN
			GfxMatrix.Apply(msg.lgm, mx, my, x, y);
			dx0 := msg.x0 - x; dy0 := msg.y0 - y;
			dx1 := msg.x1 - x; dy1 := msg.y1 - y;
			t := Math.sqrt((dx1 * dx1 + dy1 * dy1)/(dx0 * dx0 + dy0 * dy0));
			GfxMatrix.Get2PointTransform(x, y, x, y, msg.x0, msg.y0, x + dx1/t, y + dy1/t, msg.mat);
			msg.done := TRUE
		END rotate;
		*)

		PROCEDURE scale (ox, oy: FLOAT32);
			VAR x0, y0, x1, y1: FLOAT32; m: GfxMatrix.Matrix;
		BEGIN
			GfxMatrix.Apply(glmat, msg.x0, msg.y0, x0, y0); GfxMatrix.Apply(glmat, msg.x1, msg.y1, x1, y1);
			GfxMatrix.ScaleAt(msg.lgm, ox, oy, (x1 - ox)/(x0 - ox), (y1 - oy)/(y0 - oy), m);
			GfxMatrix.Concat(glmat, m, msg.mat);
			msg.done := TRUE
		END scale;

		PROCEDURE hscale (ox, oy: FLOAT32);
			VAR x0, y0, x1, y1: FLOAT32; m: GfxMatrix.Matrix;
		BEGIN
			GfxMatrix.Apply(glmat, msg.x0, msg.y0, x0, y0); GfxMatrix.Apply(glmat, msg.x1, msg.y1, x1, y1);
			GfxMatrix.ScaleAt(msg.lgm, ox, oy, (x1 - ox)/(x0 - ox), 1, m);
			GfxMatrix.Concat(glmat, m, msg.mat);
			msg.done := TRUE
		END hscale;

		PROCEDURE vscale (ox, oy: FLOAT32);
			VAR x0, y0, x1, y1: FLOAT32; m: GfxMatrix.Matrix;
		BEGIN
			GfxMatrix.Apply(glmat, msg.x0, msg.y0, x0, y0); GfxMatrix.Apply(glmat, msg.x1, msg.y1, x1, y1);
			GfxMatrix.ScaleAt(msg.lgm, ox, oy, 1, (y1 - oy)/(y0 - oy), m);
			GfxMatrix.Concat(glmat, m, msg.mat);
			msg.done := TRUE
		END vscale;

	BEGIN
		mx := 0.5*(llx + urx); my := 0.5*(lly + ury);
		GfxMatrix.Invert(msg.lgm, glmat);
		GfxMatrix.ApplyToRect(glmat, msg.x0 - msg.tol, msg.y0 - msg.tol, msg.x0 + msg.tol, msg.y0 + msg.tol, llu, llv, uru, urv);
		IF (llu <= mx) & (mx <= uru) THEN
			IF (llv <= my) & (my <= urv) THEN translate
			ELSIF (llv <= lly) & (lly <= urv) THEN vscale(mx, ury)
			ELSIF (llv <= ury) & (ury <= urv) THEN vscale(mx, lly)
			(*ELSE rotate*)
			END
		ELSIF (llu <= llx) & (llx <= uru) THEN
			IF (llv <= my) & (my <= urv) THEN hscale(urx, my)
			ELSIF (llv <= lly) & (lly <= urv) THEN scale(urx, ury)
			ELSIF (llv <= ury) & (ury <= urv) THEN scale(urx, lly)
			END
		ELSIF (llu <= urx) & (urx <= uru) THEN
			IF (llv <= my) & (my <= urv) THEN hscale(llx, my)
			ELSIF (llv <= lly) & (lly <= urv) THEN scale(llx, ury)
			ELSIF (llv <= ury) & (ury <= urv) THEN scale(llx, lly)
			END
		(*ELSIF (llv <= my) & (my <= urv) THEN rotate*)
		END
	END GetHandleMatrix;


	(**--- Shapes ---**)

	(** return figure that shape is part of **)
	PROCEDURE ContainingFigure* (shape: Shape): Figure;
	BEGIN
		IF shape = NIL THEN RETURN NIL END;
		WHILE shape.cont # NIL DO shape := shape.cont END;
		IF shape IS Layer THEN RETURN shape(Layer).fig
		ELSE RETURN NIL
		END
	END ContainingFigure;

	(** get local coordinate system of shape **)
	PROCEDURE GetCoordSystem* (shape: Shape; VAR lgm: GfxMatrix.Matrix);
		VAR cm: CoordMsg; fig: Figure;
	BEGIN
		cm.dest := shape; cm.res := GfxMatrix.Identity;
		fig := ContainingFigure(shape);
		IF fig # NIL THEN fig.handle(fig, cm) END;
		lgm := cm.res
	END GetCoordSystem;

	(** default shape handler **)
	PROCEDURE ShapeAttr* (shape: Shape; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("XMin"); msg.Enum("XMax");
			msg.Enum("YMin"); msg.Enum("YMax");
			msg.Enum("Border")
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "XMin" THEN msg.class := Objects.Real; msg.x := shape.llx; msg.res := 0
			ELSIF msg.name = "XMax" THEN msg.class := Objects.Real; msg.x := shape.urx; msg.res := 0
			ELSIF msg.name = "YMin" THEN msg.class := Objects.Real; msg.x := shape.lly; msg.res := 0
			ELSIF msg.name = "YMax" THEN msg.class := Objects.Real; msg.x := shape.ury; msg.res := 0
			ELSIF msg.name = "Border" THEN msg.class := Objects.Real; msg.x := shape.bw; msg.res := 0
			END
		END
	END ShapeAttr;

	PROCEDURE CopyShape* (VAR msg: Objects.CopyMsg; from, to: Shape);
	BEGIN
		to.handle := from.handle;
		to.llx := from.llx; to.lly := from.lly; to.urx := from.urx; to.ury := from.ury; to.bw := from.bw
	END CopyShape;

	PROCEDURE HandleShape* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR shape, copy: Shape; cm: Objects.CopyMsg; am: Objects.AttrMsg; ver: SIGNED32; int: SIGNED16; real: FLOAT32;
	BEGIN
		shape := obj(Shape);
		IF msg IS UnmarkMsg THEN
			shape.marked := FALSE
		ELSIF msg IS ShapeMsg THEN
			IF msg IS SelectMsg THEN
				WITH msg: SelectMsg DO
					IF (msg.id = get) & shape.sel THEN
						shape.slink := msg.res; msg.res := shape
					ELSIF (msg.id = reset) & shape.sel THEN
						shape.sel := FALSE;
						UpdateShape(msg.fig, shape)
					END
				END
			ELSIF msg IS ControlMsg THEN
				WITH msg: ControlMsg DO
					IF (msg.id = clone) & shape.marked THEN
						cm.stamp := msg.stamp; cm.id := Objects.shallow; shape.handle(shape, cm);
						copy := cm.obj(Shape);
						IF msg.bottom = NIL THEN msg.bottom := copy
						ELSE msg.top.up := copy
						END;
						copy.down := msg.top; msg.top := copy
					END
				END
			ELSIF msg IS ValidateMsg THEN
				WITH msg: ValidateMsg DO
					IF shape.marked THEN
						shape.marked := FALSE; shape.cont.marked := TRUE
					END
				END
			ELSIF msg IS CoordMsg THEN
				WITH msg: CoordMsg DO
					IF msg.dest = shape THEN
						msg.res := msg.lgm
					END
				END
			END
		ELSIF msg IS Objects.AttrMsg THEN
			ShapeAttr(shape, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Down") THEN msg.obj := shape.down; msg.res := 0
				ELSIF (msg.id = Objects.get) & (msg.name = "Up") THEN msg.obj := shape.up; msg.res := 0
				END
			END
		ELSIF msg IS Objects.FindMsg THEN
			WITH msg: Objects.FindMsg DO
				am.id := Objects.get; am.name := "Name"; am.res := -1;
				shape.handle(shape, am);
				IF (am.res >= 0) & (am.class = Objects.String) & (am.s = msg.name) THEN
					msg.obj := shape
				END
			END
		ELSIF msg IS Objects.BindMsg THEN
			Gadgets.BindObj(shape, msg(Objects.BindMsg).lib)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 2)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					IF ver = 1 THEN
						Files.ReadInt(msg.R, int); Files.ReadInt(msg.R, int); Files.ReadInt(msg.R, int); Files.ReadInt(msg.R, int);
						Files.ReadReal(msg.R, real)
					END
				END
			END
		END
	END HandleShape;

	(** initialize default shape fields **)
	PROCEDURE InitShape* (shape: Shape; handle: Objects.Handler);
	BEGIN
		shape.handle := handle;
		shape.cont := NIL; shape.up := NIL; shape.down := NIL;
		shape.llx := MAX(FLOAT32); shape.lly := MAX(FLOAT32); shape.urx := MIN(FLOAT32); shape.ury := MIN(FLOAT32); shape.bw := 0;
		shape.sel := FALSE; shape.marked := FALSE
	END InitShape;


	(**--- Containers ---**)

	(** forward message to list of componets **)
	PROCEDURE ToComponents* (bottom: Shape; VAR msg: Objects.ObjMsg);
	BEGIN
		WHILE bottom # NIL DO
			bottom.handle(bottom, msg); bottom := bottom.up
		END
	END ToComponents;

	(** copy list of components **)
	PROCEDURE CopyComponents* (VAR msg: Objects.CopyMsg; srcbot: Shape; VAR dstbot, dsttop: Shape);
		VAR shape: Shape; cm: Objects.CopyMsg;
	BEGIN
		dstbot := NIL; dsttop := NIL; shape := srcbot;
		IF shape # NIL THEN
			cm.stamp := msg.stamp; cm.id := msg.id;
			shape.handle(shape, cm);
			dstbot := cm.obj(Shape); dsttop := dstbot;
			shape := shape.up;
			WHILE shape # NIL DO
				cm.obj := NIL; shape.handle(shape, cm);
				dsttop.up := cm.obj(Shape); dsttop.up.down := dsttop; dsttop := dsttop.up;
				shape := shape.up
			END
		END
	END CopyComponents;

	(** store components on rider **)
	PROCEDURE WriteComponents* (VAR r: Files.Rider; lib: Objects.Library; bottom: Shape);
	BEGIN
		WHILE bottom # NIL DO
			Gadgets.WriteRef(r, lib, bottom); bottom := bottom.up
		END;
		Gadgets.WriteRef(r, lib, NIL)
	END WriteComponents;

	(** read components from rider **)
	PROCEDURE ReadComponents* (VAR r: Files.Rider; lib: Objects.Library; VAR bottom, top: Shape);
		VAR obj: Objects.Object;
	BEGIN
		bottom := NIL; top := NIL;
		REPEAT
			Gadgets.ReadRef(r, lib, obj)
		UNTIL (obj = NIL) OR (obj IS Shape);
		IF obj # NIL THEN
			bottom := obj(Shape); top := bottom;
			Gadgets.ReadRef(r, lib, obj);
			WHILE obj # NIL DO
				IF obj IS Shape THEN
					top.up := obj(Shape); top.up.down := top; top := top.up
				END;
				Gadgets.ReadRef(r, lib, obj)
			END
		END
	END ReadComponents;

	(** compute bounding box and maximal border width of component list **)
	PROCEDURE GetComponentsBox* (bottom: Shape; VAR llx, lly, urx, ury, bw: FLOAT32);
	BEGIN
		llx := MAX(FLOAT32); lly := MAX(FLOAT32); urx := MIN(FLOAT32); ury := MIN(FLOAT32); bw := 0;
		WHILE bottom # NIL DO
			IF bottom.llx < llx THEN llx := bottom.llx END;
			IF bottom.lly < lly THEN lly := bottom.lly END;
			IF bottom.urx > urx THEN urx := bottom.urx END;
			IF bottom.ury > ury THEN ury := bottom.ury END;
			IF bottom.bw > bw THEN bw := bottom.bw END;
			bottom := bottom.up
		END
	END GetComponentsBox;

	(** default container handler **)
	PROCEDURE SelectContainer* (cont: Container; VAR msg: SelectMsg);
		VAR cur: Shape; sm: SelectMsg;
	BEGIN
		IF (msg.id = get) & cont.sel THEN
			IF cont.subsel THEN ToComponents(cont.bottom, msg)
			ELSE cont.slink := msg.res; msg.res := cont
			END
		ELSIF (msg.id = reset) & cont.sel THEN
			IF cont.subsel THEN
				ToComponents(cont.bottom, msg);
				cont.sel := FALSE; cont.subsel := FALSE
			ELSE
				cont.sel := FALSE;
				UpdateShape(msg.fig, cont)
			END
		ELSIF msg.id = validate THEN
			ToComponents(cont.bottom, msg);
			cur := cont.bottom; WHILE (cur # NIL) & cur.sel DO cur := cur.up END;
			IF (cont.bottom # NIL) & (cur = NIL) THEN	(* all components selected *)
				sm.fig := msg.fig; sm.id := reset;
				ToComponents(cont.bottom, sm);
				cont.subsel := FALSE;
				IF ~cont.sel THEN
					UpdateShape(msg.fig, cont);
					cont.sel := TRUE
				END
			ELSE
				cur := cont.bottom; WHILE (cur # NIL) & ~cur.sel DO cur := cur.up END;
				cont.subsel := cur # NIL;
				IF cont.subsel & ~cont.sel THEN
					cont.sel := TRUE;
					UpdateShape(msg.fig, cont)
				END
			END
		END
	END SelectContainer;

	PROCEDURE ConsumeAction (fig: Figure; action: Action);
		VAR act: ControlAction; cur: Shape;
	BEGIN
		act := action(ControlAction);
		act.bottom.down := act.down; act.top.up := act.up;
		IF act.down # NIL THEN act.down.up := act.bottom ELSE act.cont.bottom := act.bottom END;
		IF act.up # NIL THEN act.up.down := act.top ELSE act.cont.top := act.top END;
		cur := act.bottom;
		REPEAT
			cur.cont := act.cont; cur.marked := TRUE; cur.sel := TRUE; cur := cur.up
		UNTIL cur = act.up
	END ConsumeAction;

	PROCEDURE DeleteAction (fig: Figure; action: Action);
		VAR act: ControlAction; cur: Shape; sm: SelectMsg;
	BEGIN
		act := action(ControlAction);
		act.bottom.down := NIL; act.top.up := NIL;
		IF act.down # NIL THEN act.down.up := act.up ELSE act.cont.bottom := act.up END;
		IF act.up # NIL THEN act.up.down := act.down ELSE act.cont.top := act.down END;
		cur := act.bottom; sm.fig := fig; sm.id := reset;
		REPEAT
			IF cur.sel THEN cur.handle(cur, sm)	(* deselect and update *)
			ELSE UpdateShape(fig, cur)	(* update now before shape is gone *)
			END;
			cur.cont := NIL; cur := cur.up
		UNTIL cur = NIL;
		act.cont.sel := TRUE; act.cont.marked := TRUE
	END DeleteAction;

	PROCEDURE AddConsumeAction* (fig: Figure; down, bottom, top, up: Shape; cont: Container);
		VAR act: ControlAction;
	BEGIN
		NEW(act); act.do := ConsumeAction; act.undo := DeleteAction;
		act.down := down; act.bottom := bottom; act.top := top; act.up := up; act.cont := cont;
		AddAction(fig, act)
	END AddConsumeAction;

	PROCEDURE AddDeleteAction* (fig: Figure; down, bottom, top, up: Shape; cont: Container);
		VAR act: ControlAction;
	BEGIN
		NEW(act); act.do := DeleteAction; act.undo := ConsumeAction;
		act.down := down; act.bottom := bottom; act.top := top; act.up := up; act.cont := cont;
		AddAction(fig, act)
	END AddDeleteAction;

	PROCEDURE ControlContainer* (cont: Container; VAR msg: ControlMsg);
		VAR bottom, top: Shape;
	BEGIN
		IF msg.id = integrate THEN
			IF msg.cont = cont THEN
				AddConsumeAction(msg.fig, msg.down, msg.bottom, msg.top, msg.up, cont)
			ELSE
				ToComponents(cont.bottom, msg)
			END
		ELSIF msg.id = delete THEN
			ToComponents(cont.bottom, msg);
			bottom := cont.bottom;
			WHILE bottom # NIL DO
				top := bottom;
				IF bottom.marked THEN
					WHILE (top # cont.top) & top.up.marked DO top := top.up END;
					AddDeleteAction(msg.fig, bottom.down, bottom, top, top.up, cont)
				END;
				bottom := top.up
			END
		ELSIF msg.id = clone THEN
			IF cont.marked THEN
				HandleShape(cont, msg)
			ELSE
				ToComponents(cont.bottom, msg)
			END
		END
	END ControlContainer;

	PROCEDURE OrderContainer* (cont: Container; VAR msg: OrderMsg);
		VAR b, t, next, d, u: Shape;
	BEGIN
		ToComponents(cont.bottom, msg);
		b := cont.bottom;
		WHILE (b # NIL) & ~b.marked DO b := b.up END;
		WHILE b # NIL DO
			t := b;
			WHILE (t.up # NIL) & t.up.marked DO t := t.up END;
			IF (msg.id = up) & (t.up # NIL) THEN
				BeginCommand(msg.fig);
				AddDeleteAction(msg.fig, b.down, b, t, t.up, cont);
				AddConsumeAction(msg.fig, t.up, b, t, t.up.up, cont);
				EndCommand(msg.fig);
				next := t
			ELSIF (msg.id = down) & (b.down # NIL) THEN
				next := b.down;
				BeginCommand(msg.fig);
				AddDeleteAction(msg.fig, b.down, b, t, t.up, cont);
				AddConsumeAction(msg.fig, b.down.down, b, t, b.down, cont);
				EndCommand(msg.fig)
			ELSIF (msg.id = top) & (t.up # NIL) THEN
				next := t.up;
				BeginCommand(msg.fig);
				AddDeleteAction(msg.fig, b.down, b, t, t.up, cont);
				AddConsumeAction(msg.fig, cont.top, b, t, NIL, cont);
				EndCommand(msg.fig)
			ELSIF (msg.id = bottom) & (b.down # NIL) THEN
				next := b.down;
				BeginCommand(msg.fig);
				AddDeleteAction(msg.fig, b.down, b, t, t.up, cont);
				AddConsumeAction(msg.fig, NIL, b, t, cont.bottom, cont);
				EndCommand(msg.fig)
			ELSIF msg.id = reverse THEN
				next := t.up; d := b.down; u := t.up;
				WHILE b # t DO
					AddDeleteAction(msg.fig, d, b, b, b.up, cont);
					AddConsumeAction(msg.fig, t, b, b, u, cont);
					u := b; b := b.up
				END
			ELSE
				next := t.up
			END;
			b := next;
			WHILE (b # NIL) & ~b.marked DO b := b.up END
		END
	END OrderContainer;

	PROCEDURE ConsumeContainer* (cont: Container; VAR msg: ConsumeMsg);
	BEGIN
		IF (msg.recv = NIL) & (msg.llx <= cont.urx + cont.bw) & (cont.llx - cont.bw <= msg.urx) &
			(msg.lly <= cont.ury + cont.bw) & (cont.lly - cont.bw <= msg.ury)
		THEN
			ToComponents(cont.bottom, msg)
		END
	END ConsumeContainer;

	PROCEDURE RenderContainer* (cont: Container; VAR msg: RenderMsg);
		VAR ctm: GfxMatrix.Matrix;
	BEGIN
		IF (msg.llx <= cont.urx + cont.bw) & (cont.llx - cont.bw <= msg.urx) &
			(msg.lly <= cont.ury + cont.bw) & (cont.lly - cont.bw <= msg.ury)
		THEN
			ToComponents(cont.bottom, msg);
			IF (msg.id IN {active, marksonly}) & cont.sel THEN
				ctm := msg.ctxt.ctm; Gfx.ResetCTM(msg.ctxt); Gfx.Concat(msg.ctxt, msg.gsm);
				DrawHandles(cont.llx, cont.lly, cont.urx, cont.ury, msg);
				Gfx.SetCTM(msg.ctxt, ctm)
			END
		END
	END RenderContainer;

	PROCEDURE ValidateContainer* (cont: Container; VAR msg: ValidateMsg);
	BEGIN
		ToComponents(cont.bottom, msg);
		IF cont.marked THEN
			IF cont.sel THEN
				UpdateShape(msg.fig, cont)	(* update handles *)
			END;
			GetComponentsBox(cont.bottom, cont.llx, cont.lly, cont.urx, cont.ury, cont.bw);
			cont.marked := FALSE; cont.cont.marked := TRUE;
			IF cont.sel THEN
				UpdateShape(msg.fig, cont)	(* update handles *)
			END
		END
	END ValidateContainer;

	PROCEDURE GetContainerCoords* (cont: Container; VAR msg: CoordMsg);
	BEGIN
		IF (msg.dest # cont) &
			(cont.llx <= msg.dest.llx) & (msg.dest.urx <= cont.urx) &
			(cont.lly <= msg.dest.lly) & (msg.dest.lly <= cont.ury)
		THEN
			ToComponents(cont.bottom, msg)
		END
	END GetContainerCoords;

	PROCEDURE LocateContainer* (cont: Container; VAR msg: LocateMsg);
		VAR res: Shape; lgm: GfxMatrix.Matrix;
	BEGIN
		IF (msg.llx <= cont.urx) & (cont.llx <= msg.urx) & (msg.lly <= cont.ury) & (cont.lly <= cont.ury) THEN
			IF msg.id = inside THEN
				IF (msg.llx <= cont.llx) & (cont.urx <= msg.urx) & (msg.lly <= cont.lly) & (cont.ury <= msg.ury) THEN
					cont.slink := msg.res; msg.res := cont
				ELSE
					ToComponents(cont.bottom, msg)
				END
			ELSIF msg.id = overlap THEN
				res := msg.res;
				ToComponents(cont.bottom, msg);
				IF (msg.res # res) & ~cont.sel THEN	(* locate container instead of component unless container selected *)
					cont.slink := msg.res; msg.res := cont
				END
			ELSIF msg.id = project THEN
				lgm := msg.lgm; msg.lgm := GfxMatrix.Identity;
				ProjectToHandles(cont, cont.llx, cont.lly, cont.urx, cont.ury, msg);
				msg.lgm := lgm;
				ToComponents(cont.bottom, msg)
			END
		END
	END LocateContainer;

	PROCEDURE TransformContainer* (cont: Container; VAR msg: TransformMsg);
		VAR s: Shape;
	BEGIN
		IF msg.id = apply THEN
			IF cont.marked THEN
				s := cont.bottom;
				WHILE s # NIL DO
					IF ~s.marked THEN s.marked := TRUE; msg.notify := TRUE END;
					s := s.up
				END
			END
		END;
		ToComponents(cont.bottom, msg)
	END TransformContainer;

	PROCEDURE GetContainerMatrix* (cont: Container; VAR msg: MatrixMsg);
	BEGIN
		IF (msg.dest # cont) &
			(cont.llx <= msg.dest.llx) & (msg.dest.urx <= cont.urx) &
			(cont.lly <= msg.dest.lly) & (msg.dest.lly <= cont.ury)
		THEN
			ToComponents(cont.bottom, msg)
		END
	END GetContainerMatrix;

	PROCEDURE CopyContainer* (VAR msg: Objects.CopyMsg; from, to: Container);
		VAR cur: Shape;
	BEGIN
		CopyShape(msg, from, to);
		CopyComponents(msg, from.bottom, to.bottom, to.top);
		cur := to.bottom;
		WHILE cur # NIL DO
			cur.cont := to; cur := cur.up
		END
	END CopyContainer;

	PROCEDURE HandleContainer* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR cont: Container; ver: SIGNED32; cur: Shape;
	BEGIN
		cont := obj(Container);
		IF msg IS ShapeMsg THEN
			IF msg IS SelectMsg THEN
				SelectContainer(cont, msg(SelectMsg))
			ELSIF msg IS ControlMsg THEN
				ControlContainer(cont, msg(ControlMsg))
			ELSIF msg IS OrderMsg THEN
				OrderContainer(cont, msg(OrderMsg))
			ELSIF msg IS ValidateMsg THEN
				ValidateContainer(cont, msg(ValidateMsg))
			ELSIF msg IS CoordMsg THEN
				GetContainerCoords(cont, msg(CoordMsg))
			ELSIF msg IS ConsumeMsg THEN
				ConsumeContainer(cont, msg(ConsumeMsg))
			ELSIF msg IS RenderMsg THEN
				RenderContainer(cont, msg(RenderMsg))
			ELSIF msg IS LocateMsg THEN
				LocateContainer(cont, msg(LocateMsg))
			ELSIF msg IS TransformMsg THEN
				TransformContainer(cont, msg(TransformMsg))
			ELSIF msg IS MatrixMsg THEN
				GetContainerMatrix(cont, msg(MatrixMsg))
			ELSE
				HandleShape(cont, msg);
				ToComponents(cont.bottom, msg)
			END
		ELSIF msg IS BroadcastMsg THEN
			ToComponents(cont.bottom, msg)
		ELSIF msg IS Objects.AttrMsg THEN
			ShapeAttr(cont, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			WITH msg: Objects.LinkMsg DO
				IF (msg.id = Objects.get) & (msg.name = "Bottom") THEN msg.obj := cont.bottom; msg.res := 0
				ELSIF (msg.id = Objects.get) & (msg.name = "Top") THEN msg.obj := cont.top; msg.res := 0
				ELSE HandleShape(cont, msg)
				END
			END
		ELSIF msg IS Objects.FindMsg THEN
			ToComponents(cont.bottom, msg); HandleShape(cont, msg)
		ELSIF msg IS Objects.BindMsg THEN
			ToComponents(cont.bottom, msg); HandleShape(cont, msg)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				HandleShape(cont, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					WriteComponents(msg.R, cont.lib, cont.bottom)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					ReadComponents(msg.R, cont.lib, cont.bottom, cont.top);
					cur := cont.bottom;
					WHILE cur # NIL DO
						cur.cont := cont; cur := cur.up
					END;
					GetComponentsBox(cont.bottom, cont.llx, cont.lly, cont.urx, cont.ury, cont.bw)
				END
			END
		ELSE
			HandleShape(cont, msg)
		END
	END HandleContainer;

	(** initialize default container fields **)
	PROCEDURE InitContainer* (cont: Container; handle: Objects.Handler; bottom, top: Shape);
	BEGIN
		InitShape(cont, handle);
		cont.bottom := bottom; cont.top := top;
		GetComponentsBox(bottom, cont.llx, cont.lly, cont.urx, cont.ury, cont.bw);
		WHILE bottom # NIL DO
			bottom.cont := cont; bottom := bottom.up
		END
	END InitContainer;


	(**--- Layers ---**)

	PROCEDURE LayerAttr (layer: Layer; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Name"); msg.Enum("Display"); msg.Enum("Print"); msg.Enum("Align")
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "Leonardo.NewLayer"; msg.res := 0
			ELSIF msg.name = "Item" THEN
				msg.class := Objects.String; msg.res := 0;
				msg.s := "Layer["; Strings.Append(msg.s, layer.name); Strings.AppendCh(msg.s, "]")
			ELSIF msg.name = "Name" THEN msg.class := Objects.String; COPY(layer.name, msg.s); msg.res := 0
			ELSIF msg.name = "Display" THEN msg.class := Objects.Bool; msg.b := layer.display; msg.res := 0
			ELSIF msg.name = "Print" THEN msg.class := Objects.Bool; msg.b := layer.print; msg.res := 0
			ELSIF msg.name = "Align" THEN msg.class := Objects.Bool; msg.b := layer.align; msg.res := 0
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Name" THEN
				IF msg.class = Objects.String THEN COPY(msg.s, layer.name); msg.res := 0 END
			ELSIF msg.name = "Display" THEN
				IF msg.class = Objects.Bool THEN layer.display := msg.b; msg.res := 0 END
			ELSIF msg.name = "Print" THEN
				IF msg.class = Objects.Bool THEN layer.print := msg.b; msg.res := 0 END
			ELSIF msg.name = "Align" THEN
				IF msg.class = Objects.Bool THEN layer.align := msg.b; msg.res := 0 END
			END
		END;
		HandleContainer(layer, msg)
	END LayerAttr;

	PROCEDURE CopyLayer* (VAR msg: Objects.CopyMsg; from, to: Layer);
	BEGIN
		CopyContainer(msg, from, to);
		COPY(from.name, to.name); to.display := from.display; to.print := from.print; to.align := from.align
	END CopyLayer;

	PROCEDURE HandleLayer* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR layer, copy: Layer; cur: Shape; ver: SIGNED32; dummy: BOOLEAN;
	BEGIN
		layer := obj(Layer);
		IF msg IS ShapeMsg THEN
			IF msg IS SelectMsg THEN
				WITH msg: SelectMsg DO
					IF msg.id = get THEN
						ToComponents(layer.bottom, msg)	(* layers are never part of the selection *)
					ELSIF msg.id = reset THEN
						IF layer.subsel THEN
							ToComponents(layer.bottom, msg); layer.subsel := FALSE
						END;
						layer.sel := FALSE
					ELSIF msg.id = validate THEN
						ToComponents(layer.bottom, msg);
						cur := layer.bottom; WHILE (cur # NIL) & ~cur.sel DO cur := cur.up END;
						layer.subsel := cur # NIL;
						IF layer.sel THEN
							UpdateShape(msg.fig, layer); layer.sel := FALSE
						END
					ELSE
						SelectContainer(layer, msg)
					END
				END
			ELSIF msg IS ValidateMsg THEN
				WITH msg: ValidateMsg DO
					ToComponents(layer.bottom, msg);
					IF layer.marked THEN
						GetComponentsBox(layer.bottom, layer.llx, layer.lly, layer.urx, layer.ury, layer.bw);
						layer.marked := FALSE
					END
				END
			(*ELSIF msg IS ConsumeMsg THEN
				WITH msg: ConsumeMsg DO
					IF layer = msg.fig.active THEN
						HandleContainer(layer, msg);
						IF msg.recv = NIL THEN
							cur := msg.bottom; WHILE cur # msg.top.up DO cur.marked := TRUE; cur := cur.up END;
							cm.id := delete; msg.fig.handle(msg.fig, cm);
							AddConsumeAction(msg.fig, layer.top, msg.bottom, msg.top, NIL, layer);
							msg.recv := layer
						END
					END
				END*)
			ELSIF msg IS RenderMsg THEN
				WITH msg: RenderMsg DO
					IF (msg.id IN {active, marksonly, marked}) & layer.display OR (msg.id = passive) & layer.print THEN
						ToComponents(layer.bottom, msg)
					END
				END
			ELSIF msg IS LocateMsg THEN
				WITH msg: LocateMsg DO
					IF (msg.id = project) & layer.align OR (msg.id IN {inside, overlap}) & (layer = msg.fig.active) THEN
						ToComponents(layer.bottom, msg)
					END
				END
			ELSE
				HandleContainer(layer, msg)
			END
		ELSIF msg IS Objects.AttrMsg THEN
			LayerAttr(layer, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # layer.stamp THEN
					NEW(copy); layer.dlink := copy; layer.stamp := msg.stamp;
					CopyLayer(msg, layer, copy);
				END;
				msg.obj := layer.dlink
			END
		ELSIF msg IS Objects.FindMsg THEN
			WITH msg: Objects.FindMsg DO
				IF msg.name = layer.name THEN msg.obj := layer END
			END
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				HandleContainer(layer, msg);
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 2);
					Files.WriteString(msg.R, layer.name);
					Files.WriteBool(msg.R, layer.display); Files.WriteBool(msg.R, layer.print);
					Files.WriteBool(msg.R, layer.align)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					IF ver IN {1, 2} THEN
						Files.ReadString(msg.R, layer.name);
						Files.ReadBool(msg.R, layer.display); Files.ReadBool(msg.R, layer.print);
						Files.ReadBool(msg.R, layer.align);
						IF ver = 1 THEN Files.ReadBool(msg.R, dummy) END
					END
				END
			END
		ELSE
			HandleContainer(layer, msg)
		END
	END HandleLayer;

	(** initialize layer shape **)
	PROCEDURE InitLayer* (layer: Layer; name: ARRAY OF CHAR; display, print, align: BOOLEAN);
	BEGIN
		InitContainer(layer, HandleLayer, NIL, NIL);
		COPY(name, layer.name); layer.display := display; layer.print := print; layer.align := align
	END InitLayer;

	(** layer generator **)
	PROCEDURE NewLayer*;
		VAR layer: Layer;
	BEGIN
		NEW(layer); InitLayer(layer, "???", FALSE, FALSE, FALSE);
		Objects.NewObj := layer
	END NewLayer;

	PROCEDURE ConsumeLayer (fig: Figure; act: Action);
		VAR ca: ControlAction; layer: Layer;
	BEGIN
		ca := act(ControlAction); layer := ca.bottom(Layer);
		layer.down := ca.down; layer.up := ca.up;
		IF ca.down # NIL THEN ca.down.up := layer ELSE fig.bottom := layer END;
		IF ca.up # NIL THEN ca.up.down := layer ELSE fig.top := layer END;
		layer.fig := fig; layer.marked := TRUE; fig.active := layer;
		UpdateShape(fig, layer)
	END ConsumeLayer;

	PROCEDURE RemoveLayer (fig: Figure; act: Action);
		VAR ca: ControlAction; layer: Layer;
	BEGIN
		ca := act(ControlAction); layer := ca.bottom(Layer);
		layer.down := NIL; layer.up := NIL;
		IF ca.down # NIL THEN ca.down.up := ca.up ELSE fig.bottom := ca.up END;
		IF ca.up # NIL THEN ca.up.down := ca.down ELSE fig.top := ca.down END;
		fig.active := ca.top(Layer); layer.fig := NIL;
		UpdateShape(fig, layer)
	END RemoveLayer;

	(** add a new top layer and activate it **)
	PROCEDURE AddLayer* (fig: Figure; layer: Layer);
		VAR ca: ControlAction;
	BEGIN
		BeginCommand(fig);
		NEW(ca); ca.do := ConsumeLayer; ca.undo := RemoveLayer;
		ca.bottom := layer; ca.top := fig.active; ca.down := fig.top; ca.up := NIL; AddAction(fig, ca);
		EndCommand(fig)
	END AddLayer;

	(** delete active layer **)
	PROCEDURE DeleteLayer* (fig: Figure);
		VAR ca: ControlAction;
	BEGIN
		IF (fig.active.up # NIL) OR (fig.active.down # NIL) THEN
			BeginCommand(fig);
			NEW(ca); ca.do := RemoveLayer; ca.undo := ConsumeLayer;
			ca.bottom := fig.active; ca.down := fig.active.down; ca.up := fig.active.up;
			IF ca.up # NIL THEN ca.top := ca.up ELSE ca.top := ca.down END;
			AddAction(fig, ca);
			EndCommand(fig)
		END
	END DeleteLayer;

	(** move active layer up **)
	PROCEDURE MoveLayerUp* (fig: Figure);
		VAR ca: ControlAction;
	BEGIN
		IF fig.active.up # NIL THEN
			BeginCommand(fig);
			NEW(ca); ca.do := RemoveLayer; ca.undo := ConsumeLayer;
			ca.bottom := fig.active; ca.down := fig.active.down; ca.up := fig.active.up;
			IF ca.up # NIL THEN ca.top := ca.up ELSE ca.top := ca.down END;
			AddAction(fig, ca);
			NEW(ca); ca.do := ConsumeLayer; ca.undo := RemoveLayer;
			ca.bottom := fig.active; ca.down := fig.active.up; ca.up := ca.down.up;
			IF ca.up # NIL THEN ca.top := ca.up ELSE ca.top := ca.down END;
			AddAction(fig, ca);
			EndCommand(fig)
		END
	END MoveLayerUp;

	(** move active layer down **)
	PROCEDURE MoveLayerDown* (fig: Figure);
		VAR ca: ControlAction;
	BEGIN
		IF fig.active.down # NIL THEN
			BeginCommand(fig);
			NEW(ca); ca.do := RemoveLayer; ca.undo := ConsumeLayer;
			ca.bottom := fig.active; ca.down := fig.active.down; ca.up := fig.active.up;
			IF ca.up # NIL THEN ca.top := ca.up ELSE ca.top := ca.down END;
			AddAction(fig, ca);
			NEW(ca); ca.do := ConsumeLayer; ca.undo := RemoveLayer;
			ca.bottom := fig.active; ca.up := fig.active.down; ca.down := ca.up.down;
			IF ca.up # NIL THEN ca.top := ca.up ELSE ca.top := ca.down END;
			AddAction(fig, ca);
			EndCommand(fig)
		END
	END MoveLayerDown;


	(**--- Figures ---**)

	(** figure handler **)
	PROCEDURE FigureAttr (fig: Figure; VAR msg: Objects.AttrMsg);
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("UndoLimit")
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Gen" THEN msg.class := Objects.String; msg.s := "Leonardo.NewFigure"; msg.res := 0
			ELSIF msg.name = "UndoLimit" THEN msg.class := Objects.Int; msg.i := fig.maxCmds; msg.res := 0
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "UndoLimit" THEN
				IF msg.class = Objects.String THEN
					Strings.StrToInt(msg.s, msg.i);
					IF msg.i > 0 THEN msg.class := Objects.Int END
				END;
				IF (msg.class = Objects.Int) & (msg.i >= 0) THEN
					fig.maxCmds := SHORT(msg.i); msg.res := 0;
					IF fig.cmdLevel = 0 THEN	(* trim number of undoable commands *)
						WHILE fig.nofCmds > fig.maxCmds DO
							fig.firstCmd := fig.firstCmd.next; DEC(fig.nofCmds)
						END;
						fig.firstCmd.prev := NIL
					END
				END
			END
		END
	END FigureAttr;

	PROCEDURE FigureLinks (fig: Figure; VAR msg: Objects.LinkMsg);
		VAR obj: Objects.Object; b, t: Shape;
	BEGIN
		IF msg.id = Objects.enum THEN
			msg.Enum("Bottom"); msg.Enum("Top"); msg.Enum("Active")
		ELSIF msg.id = Objects.get THEN
			IF msg.name = "Bottom" THEN msg.obj := fig.bottom; msg.res := 0
			ELSIF msg.name = "Top" THEN msg.obj := fig.top; msg.res := 0
			ELSIF msg.name = "Active" THEN msg.obj := fig.active; msg.res := 0
			END
		ELSIF msg.id = Objects.set THEN
			IF msg.name = "Bottom" THEN
				obj := msg.obj;
				IF (obj # NIL) & (obj IS Layer) THEN
					b := obj(Shape); t := b;
					WHILE (t.up # NIL) & (t.up IS Layer) DO t := t.up END;
					IF (b.down = NIL) & (t.up = NIL) THEN
						fig.bottom := b; fig.top := t; fig.active := t(Layer); msg.res := 0
					END
				END
			ELSIF msg.name = "Top" THEN
				obj := msg.obj;
				IF (obj # NIL) & (obj IS Layer) THEN
					t := obj(Shape); b := t;
					WHILE (b.down # NIL) & (b.down IS Layer) DO b := b.down END;
					IF (b.down = NIL) & (t.up = NIL) THEN
						fig.bottom := b; fig.top := t; fig.active := t(Layer); msg.res := 0
					END
				END
			ELSIF msg.name = "Active" THEN
				b := fig.bottom;
				WHILE b # NIL DO
					IF b = msg.obj THEN
						fig.active := b(Layer); msg.res := 0
					END;
					b := b.up
				END
			END
		END
	END FigureLinks;

	PROCEDURE CopyFigure* (VAR msg: Objects.CopyMsg; from, to: Figure);
		VAR cur: Shape;
	BEGIN
		to.handle := from.handle;
		CopyComponents(msg, from.bottom, to.bottom, to.top);
		cur := to.bottom; WHILE cur # NIL DO cur(Layer).fig := to; cur := cur.up END;
		to.active := from.active.dlink(Layer);
		to.seltime := MIN(SIGNED32);
		to.lockLevel := 0; NEW(to.damage); GfxRegions.Init(to.damage, GfxRegions.Winding);
		to.cmdLevel := 0; to.maxCmds := from.maxCmds; to.nofCmds := 0;
		NEW(to.undoCmd); to.firstCmd := to.undoCmd; to.curCmd := NIL
	END CopyFigure;

	PROCEDURE HandleFigure* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR fig, copy: Figure; bm: Objects.BindMsg; len, ver: SIGNED32; id: CHAR; lib: Objects.Library; s: Shape;
	BEGIN
		fig := obj(Figure);
		IF msg IS ShapeMsg THEN
			WITH msg: ShapeMsg DO
				msg.fig := fig;
				IF msg IS LocalizedMsg THEN
					WITH msg: LocalizedMsg DO
						msg.lgm := GfxMatrix.Identity
					END
				END;
				ToComponents(fig.bottom, msg)
			END
		ELSIF msg IS BroadcastMsg THEN
			ToComponents(fig.bottom, msg);
			Validate(fig)
		ELSIF msg IS Objects.AttrMsg THEN
			FigureAttr(fig, msg(Objects.AttrMsg))
		ELSIF msg IS Objects.LinkMsg THEN
			FigureLinks(fig, msg(Objects.LinkMsg))
		ELSIF msg IS Objects.CopyMsg THEN
			WITH msg: Objects.CopyMsg DO
				IF msg.stamp # fig.stamp THEN
					NEW(copy); fig.dlink := copy; fig.stamp := msg.stamp;
					CopyFigure(msg, fig, copy)
				END;
				msg.obj := fig.dlink
			END
		ELSIF msg IS Objects.FindMsg THEN
			ToComponents(fig.bottom, msg)
		ELSIF msg IS Objects.BindMsg THEN
			Gadgets.BindObj(fig, msg(Objects.BindMsg).lib)
		ELSIF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.store THEN
					Files.WriteNum(msg.R, 1);
					NEW(bm.lib); Objects.OpenLibrary(bm.lib);
					ToComponents(fig.bottom, bm);
					Objects.StoreLibrary(bm.lib, Files.Base(msg.R), Files.Pos(msg.R), len);
					Files.Set(msg.R, Files.Base(msg.R), Files.Pos(msg.R) + len);
					WriteComponents(msg.R, bm.lib, fig.bottom);
					Gadgets.WriteRef(msg.R, bm.lib, fig.active);
					Files.WriteInt(msg.R, fig.maxCmds)
				ELSIF msg.id = Objects.load THEN
					Files.ReadNum(msg.R, ver);
					Files.Read(msg.R, id);
					NEW(lib); Objects.OpenLibrary(lib);
					Objects.LoadLibrary(lib, Files.Base(msg.R), Files.Pos(msg.R), len);
					Files.Set(msg.R, Files.Base(msg.R), Files.Pos(msg.R) + len);
					ReadComponents(msg.R, lib, fig.bottom, fig.top);
					Gadgets.ReadRef(msg.R, lib, obj);
					IF (obj # NIL) & (obj IS Layer) THEN fig.active := obj(Layer)
					ELSE fig.active := fig.top(Layer)
					END;
					s := fig.bottom;
					WHILE s # NIL DO
						IF s IS Layer THEN s(Layer).fig := fig END;
						s := s.up
					END;
					Files.ReadInt(msg.R, fig.maxCmds)
				END
			END
		END
	END HandleFigure;

	(** initialize empty figure with default layer "Main" **)
	PROCEDURE InitFigure* (fig: Figure);
		VAR layer: Layer;
	BEGIN
		fig.handle := HandleFigure;
		NEW(layer); InitLayer(layer, "Main", TRUE, TRUE, TRUE); layer.fig := fig;
		fig.bottom := layer; fig.top := layer; fig.active := layer;
		fig.seltime := MIN(SIGNED32);
		fig.lockLevel := 0; NEW(fig.damage); GfxRegions.Init(fig.damage, GfxRegions.Winding);
		fig.cmdLevel := 0; fig.maxCmds := 200; fig.nofCmds := 0;
		NEW(fig.undoCmd); fig.firstCmd := fig.undoCmd; fig.curCmd := NIL
	END InitFigure;

	(** figure generator **)
	PROCEDURE NewFigure*;
		VAR fig: Figure;
	BEGIN
		NEW(fig); InitFigure(fig);
		Objects.NewObj := fig
	END NewFigure;


	(**--- Legacy Support ---**)

	PROCEDURE NewDoc*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoDocs.New")
	END NewDoc;

	PROCEDURE HandleRuler (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR frame: Gadgets.Frame; ver: SIGNED32;
	BEGIN
		frame := obj(Gadgets.Frame);
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				IF msg.id = Objects.load THEN
					Gadgets.framehandle(frame, msg);
					Files.ReadNum(msg.R, ver);
					ASSERT(ver = 1, 110);
					Gadgets.ReadRef(msg.R, frame.lib, obj);
					IF (obj = NIL) OR ~(obj IS Gadgets.Frame) THEN
						obj := Gadgets.CreateObject("LeoFrames.NewFrame")
					END;
					IF (obj # NIL) & (obj IS Gadgets.Frame) THEN
						frame.dsc := obj(Gadgets.Frame)
					END
				ELSIF frame.dsc # NIL THEN
					frame.dsc.handle(frame.dsc, msg)
				END
			END
		ELSIF msg IS Objects.BindMsg THEN
			Gadgets.BindObj(frame, msg(Objects.BindMsg).lib)
		ELSIF frame.dsc # NIL THEN
			frame.dsc.handle(frame.dsc, msg)
		END
	END HandleRuler;

	PROCEDURE NewRuler*;
		VAR frame: Gadgets.Frame;
	BEGIN
		NEW(frame); frame.handle := HandleRuler;
		Objects.NewObj := frame
	END NewRuler;


BEGIN
	Texts.OpenWriter(W);
	Texts.WriteString(W, "Leonardo 2.01/eos 22.06.2000"); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
END Leonardo.
