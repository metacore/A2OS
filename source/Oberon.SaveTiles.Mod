(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
SaveTiles: A sample fader for SaveScreen.
1999.11.01 - Ben Smith-Mannschott
	- initial version
1999.11.03
	- the same tile will no longer slide twice in a row.
1999.11.05
	- now supports configuration: rowCount, columnCount, speed
	- tiles from outside edges are no longer a different size.
2000.03.31
	- added constant defFrameRate
*)


MODULE SaveTiles IN Oberon;

	IMPORT Modules, Display, In, Out, SaveScreen;

	TYPE
		NeighborList = ARRAY 4 OF RECORD col, row: SIGNED16 END;

	CONST
		versionString = "SaveTiles 1999.11.05";
		maxSpeed = 64;
		minSpeed = 1;
		defSpeed = 16;

		maxColumnCount = 16;
		minColumnCount = 4;
		defColumnCount = 8;

		maxRowCount = 12;
		minRowCount = 3;
		defRowCount = 6;

		defFrameRate = 20;

	VAR
		tiles: RECORD
			cols, rows: SIGNED16;	(* number of columns and rows of tiles *)
			colw, rowh: SIGNED16;	(* width/heigh of rows/columns *)
			ecol, erow: SIGNED16;	(* the column/row location of the empty tile *)
			pecol, perow: SIGNED16;	(* col/row of previous position of empty tile, used to prevent repeats *)
			(* for controlling animation of sliding tile *)
			cx, cy: SIGNED16;	(* current x and y position of sliding tile *)
			tx, ty: SIGNED16;	(* target x and y position of sliding tile, so we know we're done.*)
			dx, dy: SIGNED16;	(* direction/speed to move tile per frame *)
		END;

		rowCount: SIGNED16;
		columnCount: SIGNED16;
		speed: SIGNED16;




	PROCEDURE GetTilePos(col, row: SIGNED16; VAR x, y: SIGNED16);
	BEGIN
		x := col * tiles.colw; y := row * tiles.rowh;
	END GetTilePos;

	PROCEDURE GetNeighbors(col, row: SIGNED16; VAR neighbors: NeighborList; VAR n: SIGNED16);
	BEGIN
		n := 0;
		IF col > 0 THEN
			neighbors[n].col := col - 1;
			neighbors[n].row := row;
			IF (neighbors[n].col # tiles.pecol) OR (neighbors[n].row # tiles.perow) THEN INC(n) END;
		END;
		IF col < tiles.cols - 1 THEN
			neighbors[n].col := col + 1;
			neighbors[n].row := row;
			IF (neighbors[n].col # tiles.pecol) OR (neighbors[n].row # tiles.perow) THEN INC(n) END;
		END;
		IF row > 0 THEN
			neighbors[n].col := col;
			neighbors[n].row := row - 1;
			IF (neighbors[n].col # tiles.pecol) OR (neighbors[n].row # tiles.perow) THEN INC(n) END;
		END;
		IF row < tiles.rows - 1 THEN
			neighbors[n].col := col;
			neighbors[n].row := row + 1;
			IF (neighbors[n].col # tiles.pecol) OR (neighbors[n].row # tiles.perow) THEN INC(n) END;
		END;
	END GetNeighbors;

	PROCEDURE ChooseSlidingTile;
		VAR
			neigh: NeighborList;
			n: SIGNED16;
	BEGIN
		GetTilePos(tiles.ecol, tiles.erow, tiles.tx, tiles.ty);
		Display.ReplConst(Display.FG, tiles.tx, tiles.ty, tiles.colw, tiles.rowh, Display.replace);
		GetNeighbors(tiles.ecol, tiles.erow, neigh, n);
		n := SaveScreen.Rand(n);
		GetTilePos(neigh[n].col, neigh[n].row, tiles.cx, tiles.cy);
		IF tiles.cx < tiles.tx THEN tiles.dx := speed
		ELSIF tiles.cx > tiles.tx THEN tiles.dx := -speed
		ELSE tiles.dx := 0
		END;
		IF tiles.cy < tiles.ty THEN tiles.dy := speed
		ELSIF tiles.cy > tiles.ty THEN tiles.dy := -speed
		ELSE tiles.dy := 0
		END;
		tiles.pecol := tiles.ecol;
		tiles.perow := tiles.erow;
		tiles.ecol := neigh[n].col;
		tiles.erow := neigh[n].row;
	END ChooseSlidingTile;

	PROCEDURE StartTiles;
		VAR
			slackW, slackH, i: SIGNED16;
	BEGIN
		Display.ReplPattern(Display.FG, Display.grey1,
			Display.Left, Display.Bottom, Display.Width, Display.Height, Display.paint);

		SaveScreen.SetFrameRate(defFrameRate);
		tiles.cols := columnCount; tiles.rows := rowCount;

		slackW := Display.Width MOD tiles.cols;
		slackH := Display.Height MOD tiles.rows;
		Display.ReplConst(Display.FG,
			Display.Left + Display.Width - slackW, Display.Bottom, slackW, Display.Height,
			Display.replace);
		Display.ReplConst(Display.FG,
			Display.Left, Display.Bottom + Display.Height - slackH, Display.Width, slackH,
			Display.replace);

		tiles.colw := Display.Width DIV tiles.cols;
		tiles.rowh := Display.Height DIV tiles.rows;

		FOR i := 0 TO tiles.cols  DO
			Display.ReplConst(Display.FG, i * tiles.colw - 1, Display.Bottom, 3, Display.Height, Display.replace);
		END;
		FOR i := 0 TO tiles.rows DO
			Display.ReplConst(Display.FG, Display.Left, i * tiles.rowh - 1, Display.Width, 3, Display.replace);
		END;

		tiles.pecol := -1;
		tiles.perow := -1;

		tiles.ecol := SaveScreen.Rand(tiles.cols);
		tiles.erow := SaveScreen.Rand(tiles.rows);

		ChooseSlidingTile;
	END StartTiles;


	PROCEDURE StepTiles;
	BEGIN
		IF (tiles.cx = tiles.tx) & (tiles.cy = tiles.ty) THEN
			ChooseSlidingTile
		ELSE
			IF ABS(tiles.tx - tiles.cx) < ABS(tiles.dx) THEN tiles.dx := tiles.tx - tiles.cx END;
			IF ABS(tiles.ty - tiles.cy) < ABS(tiles.dy) THEN tiles.dy := tiles.ty - tiles.cy END;
			Display.CopyBlock(tiles.cx, tiles.cy, tiles.colw, tiles.rowh, tiles.cx+tiles.dx, tiles.cy+tiles.dy, Display.replace);
			IF tiles.dx > 0 THEN
				Display.ReplConst(Display.FG, tiles.cx, tiles.cy, tiles.dx, tiles.rowh, Display.replace);
			ELSIF tiles.dx < 0 THEN
				Display.ReplConst(Display.FG, tiles.cx + tiles.colw + tiles.dx, tiles.cy, -tiles.dx, tiles.rowh, Display.replace);
			END;
			IF tiles.dy > 0 THEN
				Display.ReplConst(Display.FG, tiles.cx, tiles.cy, tiles.colw, tiles.dy, Display.replace);
			ELSIF tiles.dy < 0 THEN
				Display.ReplConst(Display.FG, tiles.cx, tiles.cy + tiles.rowh + tiles.dy, tiles.colw, -tiles.dy, Display.replace);
			END;
			INC(tiles.cx, tiles.dx);
			INC(tiles.cy, tiles.dy);
		END;
	END StepTiles;

	PROCEDURE StopTiles;
	END StopTiles;


	PROCEDURE Install*;	(** {name value} *)
		VAR name: ARRAY 32 OF CHAR; n: SIGNED16;
	BEGIN
		In.Open;
		LOOP
			In.Name(name); IF ~In.Done THEN EXIT END;
			In.Int(n); IF ~In.Done THEN EXIT END;
			IF (name = "speed") THEN
				speed := SaveScreen.Limit(minSpeed, n, maxSpeed)
			ELSIF (name = "columnCount") THEN
				columnCount := SaveScreen.Limit(minColumnCount, n, maxColumnCount)
			ELSIF (name = "rowCount") THEN
				rowCount := SaveScreen.Limit(minRowCount, n, maxRowCount)
			END;
		END;
		SaveScreen.InstallFader(StartTiles, StepTiles, StopTiles);
	END Install;

	PROCEDURE Remove;
	BEGIN
		SaveScreen.RemoveFader(StartTiles, StepTiles, StopTiles);
	END Remove;

	PROCEDURE Configuration*;
	BEGIN
		Out.String("SaveTiles:"); Out.Ln;
		Out.String("    speed "); Out.Int(speed, 0); Out.Ln;
		Out.String("    columnCount "); Out.Int(columnCount, 0); Out.Ln;
		Out.String("    rowCount "); Out.Int(rowCount, 0); Out.Ln;
	END Configuration;

BEGIN
	Modules.InstallTermHandler(Remove);
	speed := defSpeed;
	columnCount := defColumnCount;
	rowCount := defRowCount;
	Out.String(versionString); Out.Ln;
END SaveTiles.

