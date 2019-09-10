MODULE SortDemo;	(** AUTHOR "GF"; PURPOSE "animated sort demo" *)

(* this is an extended A2-port of the SortDemo done by W.Weck in 1993 for Oberon V4 *)

IMPORT
	Raster, Random, WMRectangles, Strings, WMMessages, WMDialogs,
	WM := WMWindowManager, WMComponents, WMStandardComponents,
	Log := KernelLog, Clock, Kernel, Machine;

CONST
	N = 120;  ElemSize = 5;
	MaxConcurrentSorters = 5;	(* assuming we have 6 processor cores *)
	WindowSize = N*ElemSize;

TYPE
	ElementType = SIGNED32;
	Index = SIGNED16;
	SortValues = ARRAY N OF ElementType;

	SortArray =  OBJECT (WM.BufferWindow)
	VAR
		cw: ControlWindow;
		white, grey, col1, yellow: Raster.Pixel;

		mode: Raster.Mode;

		sortname: ARRAY 32 OF CHAR;
		delay: SIGNED32;
		ha, hb: Index;  (* highlighted elements *)
		concurrent: BOOLEAN;  concSorters: SIGNED32;
		nofcomps, nofswaps, nofmoves: SIGNED32;
		compareWeight, swapWeight: FLOAT64; (* in relation to element move *)
		timer: Kernel.Timer;

		data, backup: SortValues;
		highlighted: ARRAY N OF BOOLEAN;


		PROCEDURE &New( win: ControlWindow );
		BEGIN
			cw := win;
			Init( WindowSize, WindowSize, FALSE );
			manager := WM.GetDefaultManager();
			manager.Add( 40, 250, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing} );
			SetTitle( Strings.NewString( "SortArray" ) );
			Raster.SetRGB( white, 255, 255, 255 );
			Raster.SetRGB( yellow, 255, 255, 0 );
			Raster.SetRGB( grey, 110, 110, 110 );
			Raster.SetRGB( col1, 210, 140, 75 );

			Raster.InitMode( mode, Raster.srcCopy );

			concSorters :=  0;  concurrent := FALSE;
			delay := 16;  NEW( timer );
			compareWeight := 3.0;  swapWeight := 2.4;
			ShowWeightings;

			OrderData;  backup :=data;
		END New;


		PROCEDURE Handle*( VAR x: WMMessages.Message );
		BEGIN
			IF x.msgType = WMMessages.MsgClose THEN  cw.Close  ELSE  Handle^( x )  END
		END Handle;

		PROCEDURE Pause;
		VAR t: Kernel.Timer;
		BEGIN
			IF delay > 0 THEN
				IF ~concurrent THEN  timer.Sleep( delay )
				ELSE
					NEW( t );  t.Sleep( delay )
				END
			END
		END Pause;

		PROCEDURE ShowWeightings;
		VAR digits: ARRAY 8 OF CHAR;
		BEGIN
			Log.Ln;
			Log.String( "SortDemo weightings: element move = 1, element swap =");
			Strings.FloatToStr( swapWeight, 3, 1, 0, digits );
			Log.String( digits );
			Log.String( ", compare =" );
			Strings.FloatToStr( compareWeight, 3, 1, 0, digits );
			Log.String( digits );  Log.Ln;
		END ShowWeightings;

		PROCEDURE AdjWeightings;
		VAR digits: ARRAY 8 OF CHAR;
		BEGIN
			Strings.FloatToStr( compareWeight, 3, 1, 0, digits );
			IF WMDialogs.QueryString( "Input compare weight", digits ) = 0 THEN
				Strings.StrToFloat( digits, compareWeight )
			END;
			Strings.FloatToStr( swapWeight, 3, 1, 0, digits );
			IF WMDialogs.QueryString( "Input swap weight", digits ) = 0 THEN
				Strings.StrToFloat( digits, swapWeight )
			END;
			ShowWeightings
		END AdjWeightings;


		PROCEDURE InitSort;
		BEGIN
			nofcomps := 0;  nofswaps := 0;  nofmoves := 0;
			backup := data
		END InitSort;

		PROCEDURE FinishSort;
		BEGIN
			UnHighlight( ha ); UnHighlight( hb );
			Log.String( sortname );  Log.String( ":  " );
			Log.Int( nofcomps, 1 );  Log.String( " compares,  " );
			Log.Int( nofswaps, 1 );  Log.String( " swaps,  " );
			Log.Int( nofmoves, 1 );  Log.String( " moves,  total effort: " );
			Log.Int( ENTIER( nofcomps*compareWeight) + ENTIER(nofswaps*swapWeight) + nofmoves, 0 );  Log.Ln;
		END FinishSort;


		PROCEDURE DrawElement( n: Index );
		VAR
			x, y, len: SIGNED32;
		BEGIN
			len := data[n];
			x := ElemSize*n;  y := WindowSize - 1 - ElemSize*len;
			IF len < N THEN  Raster.Fill( img, x, 0, x+ElemSize, y, white, mode )  END;
			Raster.Fill( img, x, y+1, x+ElemSize, y+ElemSize+1, col1, mode );
			IF len > 1 THEN
				Raster.Fill( img, x, y+ElemSize+1, x+1, WindowSize, white, mode );
				Raster.Fill( img, x+1, y+ElemSize+1, x+ElemSize-1, WindowSize, grey, mode );
				Raster.Fill( img, x+ElemSize-1, y+ElemSize+1, x+ElemSize, WindowSize, white, mode );
			END;
			Invalidate( WMRectangles.MakeRect( x, 0, x+ElemSize, WindowSize ) );
			highlighted[n] := FALSE;
		END DrawElement;


		PROCEDURE UnHighlight( n: Index );
		VAR
			x, y, len: SIGNED32;
		BEGIN
			IF highlighted[n] THEN
				len := data[n];
				x := ElemSize*n;  y := WindowSize - 1 - ElemSize*len;
				IF len > 1 THEN
					Raster.Fill( img, x+1, y+ElemSize+1, x+ElemSize-1, WindowSize, grey, mode );
				END;
				Invalidate( WMRectangles.MakeRect( x, 0, x+ElemSize, WindowSize ) );
				highlighted[n] := FALSE;
			END
		END UnHighlight;

		PROCEDURE Highlight( n: Index );
		VAR
			x, y, len: SIGNED32;
		BEGIN
			IF ~highlighted[n] THEN
				len := data[n];
				x := ElemSize*n;  y := WindowSize - 1 - ElemSize*len;
				IF len > 1 THEN
					Raster.Fill( img, x+1, y+ElemSize+1, x+ElemSize-1, WindowSize, yellow, mode )
				END;
				Invalidate( WMRectangles.MakeRect( x, 0, x+ElemSize, WindowSize ) );
				highlighted[n] := TRUE;
			END
		END Highlight;

		PROCEDURE Highlight2( a, b: Index );
		BEGIN
			IF ~concurrent THEN
				IF (ha # a) & (ha # b) THEN  UnHighlight( ha )  END;
				IF (hb # a) & (hb # b) THEN  UnHighlight( hb )  END;
			END;
			Highlight( a );  Highlight( b );
			ha := a;  hb := b;
			Pause
		END Highlight2;


		PROCEDURE Randomize( n: SIGNED16 );
		VAR i, j, k: Index;
			random: Random.Generator;
			t, d: SIGNED32;
		BEGIN
			NEW( random );  Clock.Get( t, d );  random.InitSeed( t );
			FOR i := 1 TO n DO
				j := SHORT( random.Dice( N ) );
				k := SHORT( random.Dice( N ) );
				Swap( j, k );
			END
		END Randomize;


		PROCEDURE OrderData;
		VAR i: Index;
		BEGIN
			FOR i := 0 TO N-1 DO  data[i] := i + 1;  DrawElement( i )  END;
		END OrderData;

		PROCEDURE RevOrderData;
		VAR i: Index;
		BEGIN
			FOR i := 0 TO N-1 DO  data[i] := N - i;  DrawElement( i )  END;
		END RevOrderData;

		PROCEDURE BadOrder;	(* worst case for quicksort *)
		VAR i, m: Index;
		BEGIN
			m := (N - 1) DIV 2;
			FOR i := 0 TO m-1 DO  data[i] := i + 1  END;
			data[m] := N;
			FOR i := m+1 TO N-1 DO  data[i] := i   END;
			FOR i := 0 TO N-1 DO  DrawElement( i )  END;
		END BadOrder;

		PROCEDURE PrevOrder;
		VAR i: Index;
		BEGIN
			data := backup;
			FOR i := 0 TO N-1 DO  DrawElement( i )  END;
		END PrevOrder;


		PROCEDURE DecSpeed;
		BEGIN
			IF delay # 0 THEN  delay := 2*delay  ELSE  delay := 4 END;
		END DecSpeed;

		PROCEDURE IncSpeed;
		BEGIN
			IF delay > 4 THEN  delay := delay DIV 2   ELSE  delay := 0 END;
		END IncSpeed;



		PROCEDURE Swap( i, j: Index );
		VAR tmp: SIGNED32;
		BEGIN
			IF i # j THEN
				tmp := data[i];  data[i] := data[j];  data[j] := tmp;
				DrawElement( i );  DrawElement( j );
				Machine.AtomicInc( nofswaps )
			END
		END Swap;


		PROCEDURE Less( i, j: Index ): BOOLEAN;
		BEGIN
			IF delay > 0 THEN
				Highlight2( i, j );
			END;
			Machine.AtomicInc( nofcomps );
			RETURN data[i] < data[j];
		END Less;



		PROCEDURE BubbleSort( lo, hi: Index );
		VAR i: Index;  swaps: SIGNED32;
		BEGIN
			REPEAT
				swaps := 0;
				FOR i := lo TO hi - 1 DO
					IF Less( i + 1, i )  THEN  Swap( i, i + 1 );  INC( swaps )  END
				END;
			UNTIL swaps = 0
		END BubbleSort;


		PROCEDURE BubbleSortOptim( lo, hi: Index );
		VAR i, first, last: Index;  swaps: SIGNED32;
		BEGIN
			first := lo;  last := hi - 1;
			LOOP
				swaps := 0;
				FOR i := first TO last DO
					IF Less( i + 1, i )  THEN  Swap( i, i + 1 );  INC( swaps );  last := i  END
				END;
				IF swaps = 0 THEN  EXIT  END;
				swaps := 0;
				FOR i := last TO first + 1 BY -1 DO
					IF Less( i, i - 1 )  THEN  Swap( i, i - 1 );  INC( swaps );  first := i  END
				END;
				IF swaps = 0 THEN  EXIT  END;
			END
		END BubbleSortOptim;


		PROCEDURE SelectSort( lo, hi: Index );
		VAR i, j, min: Index;
		BEGIN
			FOR i := lo TO hi DO
				min := i;
				FOR j := i + 1 TO hi DO
					IF Less( j, min ) THEN  min := j  END
				END;
				IF i # min THEN  Swap( i, min )  END
			END
		END SelectSort;


		PROCEDURE ShellSort( lo, hi: Index );
		VAR i, j, h: Index;
		BEGIN
			i := 4;  h := 1;
			WHILE (lo+i) <= hi DO  i := i*2;  h := h*2 + 1  END;
			WHILE h # 0 DO
				i := lo + h;
				WHILE i <= hi DO
					j := i - h;
					WHILE (j >= lo) & Less( j + h, j ) DO  Swap( j, j + h );  j := j - h  END;
					INC( i )
				END;
				h := (h - 1) DIV 2
			END;
		END ShellSort;


		PROCEDURE InsertSort( lo, hi: Index );
		VAR
			x, l, m, ip, i: Index;
			tmp: ElementType;
		BEGIN
			x := lo + 1;
			WHILE x <= hi DO
				IF Less( x, x - 1 )THEN
					(* find insert position ip, binary search *)
					ip := x - 1;  l := lo;
					WHILE l < ip DO
						m := (l + ip) DIV 2;
						IF Less( x, m ) THEN  ip := m  ELSE  l := m + 1  END
					END;
					(* insert data[x] at position ip *)
					tmp := data[x];  i := x;
					REPEAT
						data[i] := data[i - 1];  DrawElement( i );  INC( nofmoves );  DEC( i )
					UNTIL i = ip;
					data[ip] := tmp;  DrawElement( ip );  Pause;
					DEC( nofmoves );  INC( nofswaps )
				END;
				INC( x )
			END
		END InsertSort;


		PROCEDURE QuickSort( lo, hi: Index );
		VAR
			i, j, m: Index;
		BEGIN
			IF lo < hi THEN
				i := lo;  j := hi;  m := (lo + hi) DIV 2;
				REPEAT
					WHILE Less( i, m ) DO  INC( i )  END;
					WHILE Less( m, j ) DO  DEC( j )  END;
					IF i <= j THEN
						IF m = i THEN  m := j  ELSIF m = j THEN  m := i  END;
						Swap( i, j );  INC( i );  DEC( j )
					END
				UNTIL i > j;
				QuickSort( lo, j );  QuickSort( i, hi )
			END;
		END QuickSort;



		PROCEDURE QuickSortOptim( lo, hi: Index );
		VAR i, j, m: Index;  n: SIGNED32;
		BEGIN
			IF lo < hi THEN
				n := hi - lo + 1;
				IF n = 2 THEN
					IF Less( hi, lo ) THEN  Swap( lo, hi )  END
				ELSIF (n < 16) & (compareWeight > 1.7) THEN
					InsertSort( lo, hi )  (* less expensive compares! *)
				ELSE
					(* QuickSort *)
					i := lo;  j := hi;  m := (lo + hi) DIV 2;
					REPEAT
						WHILE Less( i, m ) DO  INC( i )  END;
						WHILE Less( m, j ) DO  DEC( j )  END;
						IF i <= j THEN
							IF m = i THEN  m := j  ELSIF m = j THEN  m := i  END;
							Swap( i, j );  INC( i );  DEC( j )
						END
					UNTIL i > j;
					QuickSortOptim( lo, j );  QuickSortOptim( i, hi )
				END
			END;
		END QuickSortOptim;


		PROCEDURE QuickSortConc( lo, hi: Index );
		VAR
			i, j, m: Index;
			csorter: ConcurrentSorter;
		BEGIN
			IF lo < hi THEN
				i := lo;  j := hi;  m := (lo + hi) DIV 2;
				REPEAT
					WHILE Less( i, m ) DO  UnHighlight( i );  INC( i )  END;  UnHighlight( i );
					WHILE Less( m, j ) DO  UnHighlight( j );  DEC( j )  END;  UnHighlight( j );
					UnHighlight( m );
					IF i <= j THEN
						IF m = i THEN  m := j  ELSIF m = j THEN  m := i  END;
						Swap( i, j );  INC( i );  DEC( j )
					END
				UNTIL i > j;
				IF concSorters < MaxConcurrentSorters THEN
					NEW( csorter, SELF, lo, j );  QuickSortConc( i, hi )
				ELSE
					QuickSortConc( lo, j );  QuickSortConc( i, hi )
				END
			END;
		END QuickSortConc;


		PROCEDURE DoBubbleSort;
		BEGIN
			sortname := "BubbleSort";
			BubbleSort( 0, N-1 )
		END DoBubbleSort;

		PROCEDURE DoBubbleSortOptim;
		BEGIN
			sortname := "BubbleSort optim.";
			BubbleSortOptim( 0, N-1 )
		END DoBubbleSortOptim;

		PROCEDURE DoSelectSort;
		BEGIN
			sortname := "SelectSort";
			SelectSort( 0, N-1 )
		END DoSelectSort;


		PROCEDURE DoShellSort;
		BEGIN
			sortname := "ShellSort";
			ShellSort( 0, N-1 )
		END DoShellSort;


		PROCEDURE DoInsertSort;
		BEGIN
			sortname := "InsertSort";
			InsertSort( 0, N-1 )
		END DoInsertSort;


		PROCEDURE DoQuickSort;
		BEGIN
			sortname := "QuickSort";
			QuickSort( 0, N-1 );
		END DoQuickSort;

		PROCEDURE DoQuickSortOptim;
		BEGIN
			sortname := "QuickSort optim.";
			QuickSortOptim( 0, N - 1 );
		END DoQuickSortOptim;

		PROCEDURE DoQuickSortConc;
		VAR t: Kernel.Timer;
		BEGIN
			sortname := "QuickSort conc.";
			concurrent := TRUE;  concSorters := 0;
			QuickSortConc( 0, N-1 );
			(* now wait until all concurrent activities have finished *)
			NEW( t );  WHILE concSorters > 0 DO  t.Sleep( 50 )  END;
			concurrent := FALSE;
		END DoQuickSortConc;



		PROCEDURE HeapSort;
		VAR l, r: Index;

			PROCEDURE Sift( l, r: Index );
			VAR i, j: Index;
			BEGIN
				i := l;  j := 2*l + 1;
				IF (j + 1 < r) & Less( j, j + 1 ) THEN  INC( j )  END;
				WHILE (j < r) & ~Less( j, i ) DO
					Swap( i, j );
					i := j;  j := 2*j + 1;
					IF (j + 1 < r) & Less( j, j + 1 ) THEN  INC( j )  END
				END
			END Sift;

		BEGIN
			sortname := "HeapSort";
			r := N;  l := N DIV 2;
			WHILE l > 0 DO  DEC( l );  Sift( l, r )  END;
			WHILE r > 0 DO  DEC( r );  Swap( 0, r );  Sift( 0, r )  END;
		END HeapSort;



		PROCEDURE SmoothSort;  	(* W.Weck 21 Jan 93, SmoothSort due to E.W.Dijkstra, J.Gutknecht *)
		VAR q, r, p, b, c: Index;

			PROCEDURE up( VAR b, c: Index );
			VAR b1: Index;
			BEGIN  b1 := b;  b := b + c + 1;  c := b1
			END up;

			PROCEDURE down( VAR b, c: Index );
			VAR c1: Index;
			BEGIN  c1 := c;  c := b - c - 1;  b := c1
			END down;

			PROCEDURE sift( r, b, c: Index );
			VAR r1: Index;
			BEGIN
				WHILE b >= 3 DO  r1 := r - b + c;
					IF Less( r1, r - 1 ) THEN  r1 := r - 1;  down( b, c )  END;
					IF Less( r, r1 ) THEN  Swap( r, r1 );  r := r1;  down( b, c )  ELSE  b := 1  END
				END
			END sift;

			PROCEDURE trinkle( r, p, b, c: Index );
			VAR r1, r2: Index;
			BEGIN
				WHILE p > 0 DO
					WHILE ~ODD( p ) DO  p := p DIV 2;  up( b, c )  END;
					r2 := r - b;
					IF (p = 1) OR ~Less( r, r2 ) THEN  p := 0
					ELSE  p := p - 1;
						IF b = 1 THEN  Swap( r, r2 );  r := r2
						ELSE  r1 := r - b + c;
							IF Less( r1, r - 1 ) THEN  r1 := r - 1;  down( b, c );  p := p*2  END;
							IF ~Less( r2, r1 ) THEN  Swap( r, r2 );  r := r2  ELSE  Swap( r, r1 );  r := r1;  down( b, c );  p := 0  END
						END
					END
				END;
				sift( r, b, c )
			END trinkle;

			PROCEDURE semiTrinkle( r, p, b, c: Index );
			VAR r1: Index;
			BEGIN  r1 := r - c;
				IF Less( r, r1 ) THEN  Swap( r, r1 );  trinkle( r1, p, b, c )  END
			END semiTrinkle;

		BEGIN
			sortname := "SmoothSort";
			q := 1;  r := 0;  p := 1;  b := 1;  c := 1;
			WHILE q # N DO
				IF p MOD 8 = 3 (* p = ... 011 *) THEN
					sift( r, b, c );  p := (p + 1) DIV 4;  up( b, c );  up( b, c ) (* b >= 3 *)
				ELSE  (* p = ... 01 *)
					IF (q + c) < N THEN  sift( r, b, c )  ELSE  trinkle( r, p, b, c )  END;
					down( b, c );  p := p*2;
					WHILE b # 1 DO  down( b, c );  p := p*2  END;
					p := p + 1
				END;
				q := q + 1;  r := r + 1
			END;
			trinkle( r, p, b, c );
			WHILE q # 1 DO  q := q - 1;  p := p - 1;
				IF b = 1 THEN  r := r - 1;
					WHILE ~ODD( p ) DO  p := p DIV 2;  up( b, c )  END
				ELSE  (* b >= 3 *)  r := r - b + c;
					IF p > 0 THEN  semiTrinkle( r, p, b, c )  END;
					down( b, c );  p := p*2 + 1;  r := r + c;  semiTrinkle( r, p, b, c );  down( b, c );  p := p*2 + 1
				END
			END;
		END SmoothSort;


	END SortArray;


TYPE
	ConcurrentSorter = OBJECT
	VAR
		lo, hi: Index;
		av: SortArray;

		PROCEDURE &Init ( a: SortArray;  low, high: Index );
		BEGIN
			av := a;
			lo := low; hi := high;
		END Init;

	BEGIN {ACTIVE}
		Machine.AtomicInc( av.concSorters );
		av.QuickSortConc( lo, hi );
		Machine.AtomicDec( av.concSorters )
	END ConcurrentSorter;


TYPE
	SortStarter = OBJECT
	TYPE
		SortProcedure = PROCEDURE {DELEGATE};
	VAR
		sort: SortProcedure;
		av: SortArray;
		running, terminated: BOOLEAN;

		PROCEDURE &Init( a: SortArray );
		BEGIN
			sort := NIL;  av := a;
			running := FALSE;  terminated := FALSE
		END Init;

		PROCEDURE Start( proc: SortProcedure );
		BEGIN
			IF ~running THEN
				BEGIN {EXCLUSIVE}  sort := proc  END
			END
		END Start;

		PROCEDURE Terminate;
		BEGIN {EXCLUSIVE}
			terminated := TRUE
		END Terminate;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE}
			REPEAT
				AWAIT( (sort # NIL) OR terminated );
				IF ~terminated THEN
					running := TRUE;
					av.InitSort;  sort;  av.FinishSort;
					running := FALSE;
				END;
				sort := NIL
			UNTIL terminated
		END
	END SortStarter;

TYPE
	ControlWindow = OBJECT( WMComponents.FormWindow )
		VAR
			toolbar: WMStandardComponents.Panel;
			button : WMStandardComponents.Button;

			av: SortArray;
			sorter: SortStarter;


			PROCEDURE &New;
			VAR vc: WMComponents.VisualComponent;
			BEGIN
				vc := CreateForm();
				Init( vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE );
				SetContent( vc );
				SetTitle( WM.NewString( "Sort Demo" ) );
				WM.DefaultAddWindow( SELF );
				NEW( av, SELF );
				NEW( sorter, av )
			END New;

			PROCEDURE Handle*( VAR x: WMMessages.Message );
			BEGIN
				IF x.msgType = WMMessages.MsgClose THEN  Close  ELSE  Handle^( x )  END
			END Handle;

			PROCEDURE Close*;
			BEGIN
				sorter.Terminate;  av.Close;  Close^
			END Close;


			PROCEDURE CreateForm( ): WMComponents.VisualComponent;
			VAR
				panel: WMStandardComponents.Panel;
				label : WMStandardComponents.Label;
			BEGIN
				NEW( panel );
					panel.bounds.SetWidth( 560 );
					panel.bounds.SetHeight( 80 );
					panel.fillColor.Set( SIGNED32( 0FFFFFFFFH ) );


				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( SIGNED32( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 70 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Array init: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);


				NEW( button );
					button.bounds.SetWidth( 70 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " order " );
					button.onClick.Add( Order );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 70 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rev. order " );
					button.onClick.Add( RevOrder );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 70 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( "bad order" );
					button.onClick.Add( BadOrder );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 70 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( "prev. order" );
					button.onClick.Add( PrevOrder );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 70 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rand 10 " );
					button.onClick.Add( Rand10 );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 70 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rand 100 " );
					button.onClick.Add( Rand100 );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 70 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rand 200 " );
					button.onClick.Add( Rand200 );
				toolbar.AddContent( button );

				panel.AddContent( toolbar );

				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( SIGNED32( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 70 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Sorter: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);


				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Bubble " );
					button.onClick.Add( StartBubbleSort );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Select " );
					button.onClick.Add( StartSelectSort );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Shell " );
					button.onClick.Add( StartShellSort );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 90 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Quick " );
					button.onClick.Add( StartQuickSort );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Heap " );
					button.onClick.Add( StartHeapSort );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Smooth " );
					button.onClick.Add( StartSmoothSort );
				toolbar.AddContent( button );

				panel.AddContent( toolbar );


				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( SIGNED32( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 70 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Sorter: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);


				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( "opt Bubble" );
					button.onClick.Add( StartBubbleSortOptim );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( "Insert" );
					button.onClick.Add( StartInsertSort );
				toolbar.AddContent( button );

				NEW( label );
					label.bounds.SetWidth( 80 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);

				NEW( button );
					button.bounds.SetWidth( 125 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " optim. Quick " );
					button.onClick.Add( StartQuickSortOptim );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 125 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " concurrent Quick " );
					button.onClick.Add( StartQuickSortConc );
				toolbar.AddContent( button );

				panel.AddContent( toolbar );



				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( SIGNED32( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 70 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Speed: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);


				NEW( button );
					button.bounds.SetWidth( 40 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " - " );
					button.onClick.Add( DecSpeed );
				toolbar.AddContent( button );


				NEW( button );
					button.bounds.SetWidth( 40 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " + " );
					button.onClick.Add( IncSpeed );
				toolbar.AddContent( button );


				NEW( label );
					label.bounds.SetWidth( 80 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);

				NEW( button );
					button.bounds.SetWidth( 160 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( "adjust weightings" );
					button.onClick.Add( AdjWeightings );
				toolbar.AddContent( button );


				panel.AddContent( toolbar );

				RETURN panel
			END CreateForm;


			PROCEDURE Order( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.OrderData  END
			END Order;

			PROCEDURE RevOrder( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.RevOrderData  END
			END RevOrder;

			PROCEDURE BadOrder( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.BadOrder  END
			END BadOrder;

			PROCEDURE PrevOrder( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.PrevOrder  END
			END PrevOrder;


			PROCEDURE Rand10( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.Randomize( 10 )  END
			END Rand10;

			PROCEDURE Rand100( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.Randomize( 100 )  END
			END Rand100;

			PROCEDURE Rand200( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.Randomize( 200 )  END
			END Rand200;


			PROCEDURE IncSpeed( sender, data: ANY );
			BEGIN
				av.IncSpeed
			END IncSpeed;

			PROCEDURE DecSpeed( sender, data: ANY );
			BEGIN
				av.DecSpeed
			END DecSpeed;

			PROCEDURE AdjWeightings( sender, data: ANY );
			BEGIN
				av.AdjWeightings
			END AdjWeightings;

			PROCEDURE StartBubbleSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoBubbleSort )
			END StartBubbleSort;

			PROCEDURE StartBubbleSortOptim( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoBubbleSortOptim )
			END StartBubbleSortOptim;

			PROCEDURE StartInsertSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoInsertSort )
			END StartInsertSort;

			PROCEDURE StartSelectSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoSelectSort )
			END StartSelectSort;


			PROCEDURE StartQuickSortOptim( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoQuickSortOptim )
			END StartQuickSortOptim;

			PROCEDURE StartShellSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoShellSort )
			END StartShellSort;


			PROCEDURE StartQuickSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoQuickSort )
			END StartQuickSort;


			PROCEDURE StartQuickSortConc( sender, data: ANY );
			BEGIN
				sorter.Start( av.DoQuickSortConc )
			END StartQuickSortConc;


			PROCEDURE StartHeapSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.HeapSort )
			END StartHeapSort;


			PROCEDURE StartSmoothSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.SmoothSort )
			END StartSmoothSort;

	END ControlWindow;



VAR
	w: ControlWindow;

	PROCEDURE Open*;
	BEGIN
		IF w # NIL THEN  w.Close  END;
		NEW( w )
	END Open;


END SortDemo.

----------------------------------------------------

		SortDemo.Open

		System.Free SortDemo ~

