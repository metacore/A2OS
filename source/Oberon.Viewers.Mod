(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Viewers IN Oberon;	(** portable *) (*JG 4.8.93*)

(**
The module viewers provide the data type for implementing the tiled viewers
of the Oberon system. Each track of the Oberon system consists of a number of viewers.
*)

    IMPORT Objects, Display;

    TYPE
	   Viewer* = POINTER TO ViewerDesc;
	   ViewerDesc* = RECORD (Display.FrameDesc)
	       state*: SIGNED16;
	        (** state > 1: displayed
	  	  state = 1: filler
	  	  state = 0: closed
	  	  state < 0: suspended.*)
  	 END;

  	 Track = POINTER TO TrackDesc;
	   TrackDesc = RECORD (ViewerDesc)
	     under: Display.Frame
  	 END;

    VAR
      curW*: SIGNED16;	(** Current width of the logical display. *)
      minH*: SIGNED16;	(** Minimum viewer height. *)
      DH: SIGNED16;
      FillerTrack: Track; FillerViewer, buf: Viewer; (*for closed viewers*)
      bcF: Display.Frame;  bcLev: SIGNED32;

	(** Open a new viewer V with top at Y in track X. *)
    PROCEDURE Open* (V: Viewer; X, Y: SIGNED16);
	    VAR T, u, v: Display.Frame; M: Display.ControlMsg; N: Display.ModifyMsg;
    BEGIN
	    IF (V.state = 0) & (X < MAX(SIGNED16)) THEN
          IF Y > DH THEN Y := DH END;
		  T := FillerTrack.next;
		  WHILE X >= T.X + T.W DO T := T.next END;
		  u := T.dsc; v := u.next;
		  WHILE Y > v.Y + v.H DO u := v; v := u.next END;
          IF Y < v.Y + minH THEN Y := v.Y + minH END;
		  IF (v.next.Y # 0) & (Y > v.Y + v.H - minH) THEN
            WITH v: Viewer DO
		      V.X := T.X; V.W := T.W; V.Y := v.Y; V.H := v.H;
		  	M.F := NIL; M.id := Display.suspend;
              v.handle(v, M); v.state := 0; buf := v;
		      V.next := v.next; u.next := V;
		      V.state := 2
            END
		  ELSE
		    V.X := T.X; V.W := T.W; V.Y := v.Y; V.H := Y - v.Y;
		    N.F := v; N.id := Display.reduce;
            N.Y := Y; N.H := v.Y + v.H - Y;
            v.handle(v, N); v.Y := N.Y; v.H := N.H;
			V.next := v; u.next := V;
		    V.state := 2
		  END
	    END
    END Open;

	(** Expand or shrink a viewer vertically to new top Y. *)
    PROCEDURE Change* (V: Viewer; Y: SIGNED16);
	    VAR v: Display.Frame; M: Display.ModifyMsg;
    BEGIN
	    IF V.state > 1 THEN
		   IF Y > DH THEN Y := DH END;
		   v := V.next;
		   IF (v.next.Y # 0) & (Y > v.Y + v.H - minH) THEN
		  	Y := v.Y + v.H - minH
		  END;
          IF Y > v.Y THEN
			  M.F := v; M.id := Display.reduce;
              M.Y := Y; M.H := v.Y + v.H - Y;
              v.handle(v, M); v.Y := M.Y; v.H := M.H;
			  V.H := Y - V.Y
		  ELSIF Y >= V.Y + minH THEN
			  M.F := v; M.id := Display.extend;
              M.Y := Y; M.H := v.Y + v.H - Y;
              v.handle(v, M); v.Y := M.Y; v.H := M.H;
			  V.H := Y - V.Y
		  END
	   END
    END Change;

    PROCEDURE RestoreTrack (S: Display.Frame);
	    VAR T, t, v: Display.Frame; M: Display.ControlMsg;
	BEGIN
		WITH S: Track DO
		   t := S.next;
		    WHILE t.next.X # S.X DO t := t.next END;
		    T := S.under;
		    WHILE T.next # NIL DO T := T.next END;
		    t.next := S.under; T.next := S.next;
		    M.F := NIL; M.id := Display.restore;
		    REPEAT t := t.next;
			    v := t.dsc;
			    REPEAT v := v.next; v.handle(v, M);
				    WITH v: Viewer DO v.state := - v.state END
			    UNTIL v = t.dsc
		    UNTIL t = T
		 END
     END RestoreTrack;

	(** Remove viewer V from the display. *)
    PROCEDURE Close* (V: Viewer);
	    VAR T, U: Display.Frame; M: Display.ControlMsg; N: Display.ModifyMsg; safe: BOOLEAN;
    BEGIN
    	IF V = NIL THEN	(* called from System.Trap *)
    		IF (bcF = NIL) OR ~(bcF IS Viewer) THEN	(* can not do anything *)
    			bcF := NIL; bcLev := 0;
    			RETURN
    		END;
    		V := bcF(Viewer);	(* close the outermost viewer *)
    		safe := FALSE; bcF := NIL; bcLev := 0
    	ELSE
    		safe := TRUE	(* normal case *)
    	END;
        IF V.state > 1 THEN
            U := V.next; T := FillerTrack;
		    REPEAT T := T.next UNTIL V.X < T.X + T.W;
            IF (T(Track).under = NIL) OR (U.next # V) THEN
		        IF safe THEN
		        	M.F := NIL; M.id := Display.suspend;
                	V.handle(V, M)
                END;
                V.state := 0; buf := V;
                N.F := U; N.id := Display.extend;
                N.Y := V.Y; N.H := V.H + U.H;
		        U.handle(U, N); U.Y := N.Y; U.H := N.H;
		  	  WHILE U.next # V DO U := U.next END;
    	        U.next := V.next
            ELSE (*close track*)
		        M.F := NIL; M.id := Display.suspend;
    	        IF safe THEN V.handle(V, M) END;
                V.state := 0; buf := V;
		        U.handle(U, M); U(Viewer).state := 0;
		    	RestoreTrack(T)
            END
        END
     END Close;

	(** Recall most recently closed viewer. *)
    PROCEDURE Recall* ( VAR V: Viewer);
    BEGIN V := buf
    END Recall;

	(** Return viewer located at display coordinates X, Y. *)
    PROCEDURE This* (X, Y: SIGNED16): Viewer;
	    VAR T, V: Display.Frame;
    BEGIN
	    IF (X < MAX(SIGNED16)) & (Y < DH) THEN
	  	  T := FillerTrack;
		    REPEAT T := T.next UNTIL X < T.X + T.W;
		    V := T.dsc;
		    REPEAT V := V.next UNTIL Y < V.Y + V.H;
		    RETURN V(Viewer)
	    ELSE RETURN NIL
	    END
    END This;

	(** Return next upper neighbour of V in a track. *)
    PROCEDURE Next* (V: Viewer): Viewer;
    BEGIN RETURN V.next(Viewer)
    END Next;

	(** In the track at X locate the following viewers: filler fil, bottom-most viewer, an
	alternative viewer alt of height >= H, and the viewer with the maximum height. *)
    PROCEDURE Locate* (X, H: SIGNED16; VAR fil, bot, alt, max: Display.Frame);
	    VAR T, V: Display.Frame;
    BEGIN
	    IF X < MAX(SIGNED16) THEN
		    T := FillerTrack;
		    REPEAT T := T.next UNTIL X < T.X + T.W;
		    fil := T.dsc; bot := fil.next;
		    IF bot.next # fil THEN
			    alt := bot.next; V := alt.next;
			    WHILE (V # fil) & (alt.H < H) DO
				    IF V.H > alt.H THEN alt := V END; V := V.next
			    END
		    ELSE alt := bot
		    END;
		    max := T.dsc; V := max.next;
			WHILE V # fil DO
			    IF V.H > max.H THEN max := V END; V := V.next
		    END
	    END
    END Locate;

	(** Append to the current logical display and init track of width W and height H, and install filler. *)
    PROCEDURE InitTrack* (W, H: SIGNED16; Filler: Viewer);
	    VAR S: Display.Frame; T: Track;
	BEGIN
        IF Filler.state = 0 THEN
	        Filler.X := curW; Filler.W := W; Filler.Y := 0; Filler.H := H;
	        Filler.state := 1;
	        Filler.next := Filler;
	    	NEW(T);
		    T.X := curW; T.W := W; T.Y := 0; T.H := H;
		    T.dsc := Filler; T.under := NIL;
	        FillerViewer.X := curW + W; FillerViewer.W := MAX(SIGNED16) - FillerViewer.X;
		    FillerTrack.X := FillerViewer.X; FillerTrack.W := FillerViewer.W;
	        S := FillerTrack;
            WHILE S.next # FillerTrack DO S := S.next END;
		    S.next := T; T.next := FillerTrack;
            curW := curW + W
        END
    END InitTrack;

	(** Open new track overlaying span of [X, X +W[. *)
    PROCEDURE OpenTrack* (X, W: SIGNED16; Filler: Viewer);
	    VAR newT: Track; S, T, t, v: Display.Frame; M: Display.ControlMsg;
    BEGIN
	    IF (X < MAX(SIGNED16)) & (Filler.state = 0) THEN
		    S := FillerTrack; T := S.next;
		    WHILE X >= T.X + T.W DO S := T; T := S.next END;
		    WHILE X + W > T.X + T.W DO T := T.next END;
		    M.F := NIL; M.id := Display.suspend;
		    t := S;
		    REPEAT t := t.next; v := t.dsc;
			    REPEAT v := v.next;
                    WITH v: Viewer DO v.state := -v.state; v.handle(v, M) END
				UNTIL v = t.dsc
			UNTIL t = T;
		    Filler.X := S.next.X; Filler.W := T.X + T.W - S.next.X; Filler.Y := 0; Filler.H := DH;
			Filler.state := 1;
			Filler.next := Filler;
			NEW(newT);
			newT.X := Filler.X; newT.W := Filler.W; newT.Y := 0; newT.H := DH;
		    newT.dsc := Filler; newT.under := S.next; S.next := newT;
		    newT.next := T.next; T.next := NIL
	    END
    END OpenTrack;

	(** Close track at X and restore overlaid tracks. *)
    PROCEDURE CloseTrack* (X: SIGNED16);
	    VAR T, V: Display.Frame; M: Display.ControlMsg;
    BEGIN
	    IF X < MAX(SIGNED16) THEN
		    T := FillerTrack;
		    REPEAT T := T.next UNTIL X < T.X + T.W;
		    IF T(Track).under # NIL THEN
			    M.F := NIL; M.id := Display.suspend; V := T.dsc;
			    REPEAT V := V.next; V.handle(V, M); V(Viewer).state := 0 UNTIL V = T.dsc;
		  	  RestoreTrack(T)
		    END
	    END
    END CloseTrack;

	PROCEDURE Broadcast (VAR M: Display.FrameMsg);
	    VAR F, V: Display.Frame;
	BEGIN M.res := MIN(SIGNED16); Objects.Stamp(M);
        Display.ResetClip; F := FillerTrack.next;
	    WHILE (F # FillerTrack) & (M.res < 0) DO V := F.dsc;
		   REPEAT V := V.next; M.dlink := NIL; M.x := 0; M.y := 0;
		   	IF bcLev = 0 THEN bcF := V END;	(* remember outermost frame *)
		   	INC(bcLev); V.handle(V, M); DEC(bcLev)
           UNTIL (V = F.dsc) OR (M.res >= 0) ;
		   F := F.next
	    END;
	    IF bcLev = 0 THEN bcF := NIL END;
	    Display.Update
	END Broadcast;

BEGIN
    DH := Display.Height;
    NEW(FillerViewer);
    FillerViewer.X := 0; FillerViewer.W := MAX(SIGNED16); FillerViewer.Y := 0; FillerViewer.H := DH;
    FillerViewer.next := FillerViewer;
    NEW(FillerTrack);
    FillerTrack.X := 0; FillerTrack.W := MAX(SIGNED16); FillerTrack.Y := 0; FillerTrack.H := DH;
    FillerTrack.dsc := FillerViewer;
    FillerTrack.next := FillerTrack;
    buf := NIL; curW := 0; minH := 1;
    Display.Broadcast := Broadcast; bcF := NIL; bcLev := 0
END Viewers.

(** Remarks:

1. Each track consists of a filler and a set of viewers linked together in a ring
(with the next field) with the filler as sentinel. The filler is the top-most viewer
in a track and covers the remainding part of the track the viewers do not cover.
The set of tracks form the root objects of the display space.

2. Tracks can overlay each other. Closing a track exposes the track (and viewers)
lying below it. Overlayed tracks and viewers do not receive message broadcasts
in the display space. Before being overlayed, the contents of a track receive a
Display.ControlMsg with id set to suspend.

3. The logical display increases from X coordinate 0 onwards through multiple
physical displays. Opening a new display involves adding a tracks beyond curW
(typically a system and user track). Oberon uses a single coordinate system to
address all the different displays. Note that many Oberon systems restrict the
size of the display to the size of the host window.

4. Changing the top coordinate of a viewer with Change results in a
Display.ModifyMsg with id set to reduce or extend (in size) being sent
to the viewer contents (located in V.dsc).

5. The ratio of user and system track width is 5:3.

6. Programmers seldom need to use the Viewers module. Higher level modukes
like Documents provide a simpler display abstraction.

*)
