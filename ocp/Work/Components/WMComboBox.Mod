MODULE WMComboBox; (** AUTHOR "BohdanT"; PURPOSE "ComboBox visual component"; *)
IMPORT
	KernelLog, Modules, Strings,  UTF8Strings, WMMessages, 
	(* visual part *)
	
	WMRectangles, WMWindowManager, WMProperties, WMComponents, WMStandardComponents, WMEditors, 
	WMGraphics, WMEvents,
	WMStringGrids, WMGrids,WM := WMWindowManager;


TYPE
	String = Strings.String;
	(* generic sortable list *)
	ListElement* = POINTER TO RECORD
		text*:String;
		data*:ANY;
		visible-:BOOLEAN;
		next- : ListElement;
	END;

	(* return -1, if a < b; 0, if a = b; 1, if a > b *)
	CompareProc = PROCEDURE {DELEGATE} (a, b : ListElement) : LONGINT;

	Table* = OBJECT
	VAR 		
		list:ListElement;
		count-:LONGINT;

		PROCEDURE &New*;
		BEGIN
			count:=0;
			list:=NIL;
		END New;
		
		PROCEDURE Add*(s:String;d:ANY);
		VAR
			p:ListElement;
		BEGIN
			NEW(p);
			p.text:=s;
			p.data:=d;
			p.next:=list;
			p.visible:=TRUE;
			list:=p;
			INC(count);
		END Add;
	END Table;

TYPE
	ComboWindow*  = OBJECT (WMComponents.FormWindow)
	VAR 
		list : WMStringGrids.StringGrid;
		spacings : WMGrids.Spacings;
	
		filter:  String;
		table : Table;
		active:BOOLEAN;
		owner:ComboBox;
		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			ep: WMStandardComponents.Panel;
		BEGIN

			NEW(panel); panel.bounds.SetExtents(500, 160); panel.fillColor.Set(0); panel.takesFocus.Set(TRUE);
			NEW(table);
			
			(* edit panel *)
			NEW(ep); ep.alignment.Set(WMComponents.AlignClient); ep.fillColor.Set(LONGINT(0DDDD00EEH));
			panel.AddContent(ep);


			NEW(list); list.alignment.Set(WMComponents.AlignClient); 
			NEW(spacings, 1); spacings[0] := 500;
			list.SetExtKeyEventHandler(ListKeyPressed);
			list.Acquire;
			list.defaultRowHeight.Set(25);
			list.cellDist.Set(0);
			list.clCell.Set(LONGINT(0FFFFFFA0H));
			list.SetColSpacings(spacings);
			list.SetFont(WMGraphics.GetFont("Courier", 12, {}));
			list.model.Acquire;
			list.model.SetNofCols(1);
			
			list.model.Release;	
			list.Release;
			list.onClickSelected.Add(ClickSelected);
			ep.AddContent(list);
			RETURN panel
		END CreateForm;

		PROCEDURE &New*( owner : ComboBox);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			SELF.owner:=owner;
			vc := CreateForm();
			active:=FALSE;
			
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			list.Invalidate;
		END New;

		PROCEDURE ClickSelected(sender, data : ANY);
		VAR 
			p : ListElement;
		BEGIN
			IF (data # NIL) & (data IS ListElement) THEN
				p:=data(ListElement);
				owner.onClick.Call(p.data);
			END;
			ScheduleHide;
		END ClickSelected;


		PROCEDURE ListKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			IF keySym = 0FF0DH THEN handled := TRUE; 
					ScheduleHide;
			 END;
		END ListKeyPressed;
		
		PROCEDURE ScheduleHide;
		VAR msg : WMMessages.Message;
		BEGIN
			msg.msgType := WMMessages.MsgExt;
			msg.ext := SELF;
			IF ~sequencer.Add(msg) THEN KernelLog.String("ComboWindowsr out of sync") END;
		END ScheduleHide;
		
		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			ScheduleHide
		END FocusLost;
		
		PROCEDURE Hide;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Remove(SELF);
			active:=FALSE;
		END Hide;
		
		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) THEN
				IF (x.ext = SELF) THEN Hide
				END
			ELSE Handle^(x)
			END
		END Handle;
		
		PROCEDURE StartNewFilter*(filter : Strings.String);
		BEGIN
			SELF.filter := filter;
			PrepareList
		END StartNewFilter;

		PROCEDURE PrepareList;
		VAR i, vis : LONGINT; mask : ARRAY 128 OF CHAR; s : Strings.String;
		l:ListElement;
		BEGIN
			s := SELF.filter;
			mask := "";
			IF s # NIL THEN COPY(s^, mask) END;
			IF mask = "" THEN
				l:=table.list;i:=0;
				WHILE l#NIL DO l.visible := TRUE;INC(i);l:=l.next END;
				vis := i;
			ELSE
				IF mask[Strings.Length(mask)] # "*" THEN Strings.Append(mask, "*") END;
				IF mask[0] # "*" THEN Strings.Concat("*",mask,mask) END;
				
				vis := 0;
				l:=table.list;
				WHILE l#NIL DO 
					IF Strings.Match(mask, l.text^) THEN
						l.visible := TRUE;
						INC(vis)
					ELSE l.visible := FALSE
					END;
					l:=l.next;
				END;
			END;

			list.model.Acquire;
			list.model.SetNofRows(vis);

			vis := 0;
			l:=table.list;
			WHILE l#NIL DO 
				IF l.visible THEN
					list.model.SetCellText(0, vis, l.text);
					list.model.SetCellData(0, vis, l);

					INC(vis)
				END;
				l:=l.next;
			END;
			list.SetTopPosition(0, 0, TRUE);
			list.model.Release;
		END PrepareList;


	END ComboWindow;

	ComboBox* = OBJECT(WMEditors.TextField)
	VAR
		tb:WMStandardComponents.Button;
		filterProp : WMProperties.StringProperty;
		cw:ComboWindow;
		text:ARRAY 255 OF CHAR;
		onClick- : WMEvents.EventSource;

		PROCEDURE OnClickDown*(sender, data:ANY);
		BEGIN
			IF ~cw.active THEN
				SELF.SetFocus;
				TextChanged(NIL,NIL);
			ELSE
				cw.ScheduleHide 
			END;
		END OnClickDown;
		
		PROCEDURE Show;
		VAR manager :WM.WindowManager;
			x,y:LONGINT;

		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			ToWMCoordinates(0, bounds.GetTop(), x, y);
			manager.Add(x, y+bounds.GetHeight() , cw, {WMWindowManager.FlagHidden, WMWindowManager.FlagStayOnTop,WM.FlagNoFocus});
			cw.active:=TRUE;
		END Show;

		PROCEDURE AddItem*(s:String;d:ANY);
		BEGIN
			cw.table.Add(s,d);
			Invalidate;
		END AddItem;
		

		PROCEDURE FocusReceived*;
		BEGIN
			FocusReceived^;
		END FocusReceived;

		
		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			IF cw.active THEN
				cw.ScheduleHide 
			END;
		END FocusLost;
		
		PROCEDURE &Init*;
		BEGIN
			Init^;
(*			takesFocus.Set(TRUE);*)

			fillColor.Set(WMGraphics.White);
			NEW(filterProp, ListFilterProt, NIL, NIL); properties.Add(filterProp);

			NEW(tb);
			tb.bounds.SetExtents(20, 20);
			tb.alignment.Set(WMComponents.AlignRight);
(*					tb.imageName.Set(img);*)
			tb.imageName.Set(Strings.NewString("WMDebugger/WMDebugger.zip://Down.png"));
			tb.onClick.Add (OnClickDown);
			AddContent(tb);

			SELF.onChanged.Add(TextChanged);

			SELF.onEnter.Add(Ok);
			text:="";
			SELF.SetAsString(text);
			
			(* events *)
			NEW(onClick, SELF, Strings.NewString("onClick"), NIL, SELF.StringToCompCommand); events.Add(onClick);

			
			NEW(cw, SELF);
		END Init;
		
		PROCEDURE TextChanged*(sender, data:ANY);
		VAR
			l:ListElement;
			str : ARRAY 128 OF CHAR;
		BEGIN
			NEW(l);
			l.next:=cw.table.list;
			Sort(l, Compare);
			cw.table.list:=l.next;
			SELF.GetAsString(str);
			filterProp.Set(Strings.NewString(str));
			IF ~cw.active THEN
				Show;
			END;
			(* avoid recursion 
			edit.text.onTextChanged.Remove(TextChanged);
			edit.text.onTextChanged.Add(TextChanged)*)
		END TextChanged;

		PROCEDURE Ok*(sender, data:ANY);
		BEGIN
			cw.ScheduleHide
		END Ok;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
		END PointerLeave;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; VAR keySym : LONGINT);
		BEGIN
(*			IF keySym = 0FF54H THEN Show END; Cursor Down *)
			KeyEvent^(ucs, flags, keySym);
			PointerLeave;
		END KeyEvent;
		PROCEDURE PropertyChanged*(sender, data : ANY);
		BEGIN

			IF (data = filterProp) THEN
				cw.StartNewFilter(filterProp.Get())
			ELSE PropertyChanged^(sender, data)
			END
		END PropertyChanged;
		PROCEDURE Finalize*; (** PROTECTED *)
		BEGIN
			IF cw.active THEN
				cw.ScheduleHide
			END;
			Finalize^;
		END Finalize;

	END ComboBox;

(** Merge-sort a single-linked list. The root element is a dummy node *)
(* Algorithm by Simon Tatham *)
PROCEDURE Sort(root: ListElement; compare : CompareProc);	(* root is dummy node *)
VAR m, n, np, nq: LONGINT; p, q, tail: ListElement;
BEGIN
	n := 1;
	REPEAT
		p := root.next; q := p; tail := root; m := 0;
		WHILE p # NIL DO	(* merge sorted lists of length n into sorted lists of length 2*n (sort of) *)
			np := 0;	(* step q over <= n nodes *)
			REPEAT q := q.next; INC(np) UNTIL (q = NIL) OR (np = n);
			nq := n; INC(m);
			LOOP	(* merge list p with np nodes and list q with <= nq nodes at end of tail *)
				IF (np # 0) & ((nq = 0) OR (q = NIL) OR (compare(p, q) <= 0)) THEN
					tail.next := p; tail := p; p := p.next; DEC(np)
				ELSIF (nq # 0) & (q # NIL) THEN
					tail.next := q; tail := q; q := q.next; DEC(nq)
				ELSE	(* (np = 0) & ((nq = 0) OR (q = NIL)) *)
					EXIT
				END
			END;
			tail.next := NIL; p := q
		END;
		n := n*2
	UNTIL m <= 1
END Sort;

PROCEDURE Compare(a, b: ListElement) : LONGINT;
BEGIN
	RETURN UTF8Strings.Compare(a.text^, b.text^);
END Compare;

(*Test section*)
TYPE
	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		cb:ComboBox;
		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents(800, 700);
			panel.fillColor.Set(LONGINT(0FFFFFFFFH));
			NEW(cb);
			cb.bounds.SetWidth (300);
			cb.bounds.SetHeight (20);
						
			cb.AddItem(Strings.NewString("Noah"),NIL);
			cb.AddItem(Strings.NewString("Ethan"),NIL);
			cb.AddItem(Strings.NewString("Mason"),NIL);
			cb.AddItem(Strings.NewString("Logan"),NIL);
			cb.AddItem(Strings.NewString("Lucas"),NIL);
			cb.AddItem(Strings.NewString("Jacob"),NIL);
			cb.AddItem(Strings.NewString("Aiden"),NIL);
			cb.AddItem(Strings.NewString("Jackson "),NIL);
			cb.AddItem(Strings.NewString("Jack"),NIL);
			cb.AddItem(Strings.NewString("Elijah"),NIL);
			cb.AddItem(Strings.NewString("Benjamin"),NIL);
			cb.AddItem(Strings.NewString("James"),NIL);
			cb.AddItem(Strings.NewString("Luke"),NIL);
			cb.AddItem(Strings.NewString("William "),NIL);

			cb.AddItem(Strings.NewString("Olivia"),NIL);
			cb.AddItem(Strings.NewString("Sophia"),NIL);
			cb.AddItem(Strings.NewString("Ava"),NIL);
			cb.AddItem(Strings.NewString("Isabella "),NIL);
			cb.AddItem(Strings.NewString("Mia"),NIL);
			cb.AddItem(Strings.NewString("Charlotte"),NIL);
			cb.AddItem(Strings.NewString("Emily"),NIL);
			cb.AddItem(Strings.NewString("Abigail  "),NIL);
			cb.AddItem(Strings.NewString("Harper"),NIL);
			cb.AddItem(Strings.NewString("Avery"),NIL);
			cb.AddItem(Strings.NewString("Madison"),NIL);
			cb.AddItem(Strings.NewString("Ella"),NIL);
			cb.AddItem(Strings.NewString("Amelia"),NIL);
			cb.AddItem(Strings.NewString("Lily"),NIL);

			panel.AddContent(cb);
			RETURN panel
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm ();
			Init (vc.bounds.GetWidth (), vc.bounds.GetHeight (), FALSE);
			SetContent (vc);
			WM.DefaultAddWindow (SELF);
			SetTitle (Strings.NewString ("GUIPatW1"));
		END New;


	END Window;

VAR 
	winstance : Window;
	ListFilterProt : WMProperties.StringProperty;

PROCEDURE InitPrototypes;
BEGIN
	NEW(ListFilterProt, NIL, Strings.NewString("Filter"), Strings.NewString("display list filter"));
END InitPrototypes;

PROCEDURE Open*;
BEGIN
	IF winstance = NIL THEN NEW (winstance); END;	(* Only one window may be instantiated. *)
END Open;

PROCEDURE Cleanup;
BEGIN
	IF 	winstance # NIL THEN
		winstance.Close ();
		winstance := NIL
	END;
END Cleanup;

BEGIN
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup)
END WMComboBox.


SystemTools.Free WMComboBox ~
WMComboBox.Open ~
