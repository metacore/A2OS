MODULE vyMatrixTypes IN Oberon;
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



(*! rename type specific functions, e.g. InsertNewRealRow...*)
(*! migrate to lower modules *)
IMPORT Reals IN A2, MathL IN A2, Texts, vyBase, vyIntVec, vyRealVec, vyLongrealVec, vyHostStrings, vyQFisher, vyHostTexts;

CONST
	idversion* = 'v0r0d3.gs';
TYPE

	(* tLabel=vyBase.tVector; *)
	label = ARRAY 32 OF CHAR;
	labels = POINTER TO ARRAY OF label;   (*! replace labels by vyTypesVector type *)

	par = RECORD
		min, max, mean: FLOAT64
	END;
	pars = POINTER TO ARRAY OF par;

	tRow = POINTER TO tRowDesc;
	tRowDesc = RECORD
		v: vyBase.tVector;
		next: tRow
	END;

	tMatrix* = POINTER TO tMatrixDesc;
	tMatrixDesc* = RECORD
		rows-, columns-: SIGNED32;
		transposed-: BOOLEAN;
		(* rowlabels*,collabels*:tLabel;*)
		rowlabels*, collabels*: labels;
		(*
		data:
		Get: PROCEDURE (me:tMatrix;row,col:SIGNED32):basetype;
		Set: PROCEDURE (me:tMatrix;row,col:SIGNED32; val:basetype);
		*)
		firstrow: tRow;
		rowcache: tRow;
		cachedrow: SIGNED32;
		rParsCache, cParsCache: pars
	END;

	tIntGetProc = PROCEDURE ( me: tMatrix;  row, col: SIGNED32 ): SIGNED16;
	tIntSetProc = PROCEDURE ( val: SIGNED16;  me: tMatrix;  row, col: SIGNED32 );
	tIntMatrix = POINTER TO tIntMatrixDesc;
	tIntMatrixDesc = RECORD (tMatrixDesc)
		Get: tIntGetProc;
		Set: tIntSetProc
	END;

	tRealGetProc = PROCEDURE ( me: tMatrix;  row, col: SIGNED32 ): FLOAT32;
	tRealSetProc = PROCEDURE ( val: FLOAT32;  me: tMatrix;  row, col: SIGNED32 );
	tRealMatrix = POINTER TO tRealMatrixDesc;
	tRealMatrixDesc = RECORD (tMatrixDesc)
		Get: tRealGetProc;
		Set: tRealSetProc
	END;

	VDist* = PROCEDURE ( v1, v2: vyBase.tVector ): FLOAT64;

	(*! substituting COPY for copyLabel yields a compiler crash in MacOberon S3R2.1 OPL *)
	PROCEDURE copyLabel( VAR l1, l2: label );
	VAR t: SIGNED16;
	BEGIN
		t := 0;
		WHILE (l1[t] # 0X) DO l2[t] := l1[t];  INC( t ) END;
		l2[t] := l1[t]
	END copyLabel;

	PROCEDURE InsertLabel( from: labels;  at: SIGNED32;  s: ARRAY OF CHAR ): labels;
	VAR NewLabels: labels;  t: SIGNED32;
	BEGIN
		NEW( NewLabels, LEN( from^ ) + 1 );
		FOR t := 0 TO at - 1 DO copyLabel( from[t], NewLabels[t] ) END;
		FOR t := at TO LEN( from^ ) - 1 DO copyLabel( from[t], NewLabels[t + 1] ) END;
		COPY( s, NewLabels[at] );  RETURN NewLabels
	END InsertLabel;

	PROCEDURE DoInsertNewRow( me: tMatrix;  at: SIGNED32;  typ: vyBase.OPTStruct );
	VAR i: SIGNED32;  next: tRow;  trow: tRow;
	BEGIN
	(* ASSERT(at<=me.rows,100); (* gs 28.01.97*) *)  (* in case of transposition m.rows plays the role of m.columns !!*)
		trow := me.firstrow;  i := 0;
		WHILE (i # at) & (trow.next # NIL ) DO  (* gs 28.01.97*)
			trow := trow.next;
			INC( i ) (* gs 28.01.97*)
		END;
		next := trow.next;  NEW( trow.next );  trow := trow.next;
		IF typ = vyBase.realtyp THEN trow.v := vyRealVec.New( me.columns )
		ELSIF typ = vyBase.inttyp THEN trow.v := vyIntVec.New( me.columns )
		ELSE HALT( 99 )
		END;
		trow.next := next
	END DoInsertNewRow;

	PROCEDURE DoInsertNewCol( me: tMatrix;  at: SIGNED32;  typ: vyBase.OPTStruct );
	VAR i: SIGNED32;  trow: tRow;
	BEGIN
		i := 0;  trow := me.firstrow;
		WHILE (trow # NIL ) DO
			IF typ = vyBase.realtyp THEN
				FOR i := me.columns TO at + 1 BY -1 DO vyRealVec.Set( vyRealVec.Get( trow.v, i - 1 ), trow.v, i ) END;
				vyRealVec.Set( 0, trow.v, at )
			ELSIF typ = vyBase.inttyp THEN
				FOR i := me.columns TO at + 1 BY -1 DO vyIntVec.Set( vyIntVec.Get( trow.v, i - 1 ), trow.v, i ) END;
				vyIntVec.Set( 0, trow.v, at )
			ELSE HALT( 99 )
			END;
			trow := trow.next
		END
	END DoInsertNewCol;

	PROCEDURE InsertNewRow*( me: tMatrix;  at: SIGNED32 );
	BEGIN
		IF ~me.transposed THEN DoInsertNewRow( me, at, vyBase.realtyp ) ELSE DoInsertNewCol( me, at, vyBase.realtyp ) END;
		INC( me.rows );  me.rowlabels := InsertLabel( me.rowlabels, at, "NEW" )
	END InsertNewRow;

	PROCEDURE InsertNewColumn*( me: tMatrix;  at: SIGNED32 );
	BEGIN
		IF me.transposed THEN DoInsertNewRow( me, at, vyBase.realtyp ) ELSE DoInsertNewCol( me, at, vyBase.realtyp ) END;
		INC( me.columns );  me.collabels := InsertLabel( me.collabels, at, "NEW" )
	END InsertNewColumn;

	PROCEDURE DoDeleteRow( M: tMatrix;  at: SIGNED32 );
	VAR i: SIGNED32;  trow: tRow;
	BEGIN
		trow := M.firstrow;  i := 0;
		IF at = 0 THEN M.firstrow := trow.next ELSE
			WHILE (i < at - 1) DO trow := trow.next;  INC( i ) END;
			trow.next := trow.next.next
		END;
		M.rParsCache := NIL;  M.cParsCache := NIL
	END DoDeleteRow;

	PROCEDURE DoDeleteColumn( M: tMatrix;  at: SIGNED32 );
	VAR trow: tRow;  i, t: SIGNED32;  rows, cols: SIGNED32;
	BEGIN
		IF M.transposed THEN rows := M.columns - 1;  cols := M.rows - 1 ELSE rows := M.rows - 1;  cols := M.columns - 1 END;
		trow := M.firstrow;
		FOR i := 0 TO rows DO
			FOR t := at TO cols DO vyRealVec.Set( vyRealVec.Get( trow.v, t + 1 ), trow.v, t ) END;
			trow := trow.next
		END;
		M.rParsCache := NIL;  M.cParsCache := NIL
	END DoDeleteColumn;

	PROCEDURE DeleteRow*( M: tMatrix;  at: SIGNED32 );
	VAR t: SIGNED32;
	BEGIN
		IF M.transposed THEN DoDeleteColumn( M, at ) ELSE DoDeleteRow( M, at ) END;
		DEC( M.rows );
		FOR t := at TO M.rows - 1 DO copyLabel( M.rowlabels[t + 1], M.rowlabels[t] ) END;
		M.cachedrow := 0;  M.rowcache := M.firstrow
	END DeleteRow;

	PROCEDURE DeleteColumn*( M: tMatrix;  at: SIGNED32 );
	VAR t: SIGNED32;
	BEGIN
		ASSERT ( at < M.columns, 100 );
		IF ~M.transposed THEN DoDeleteColumn( M, at ) ELSE DoDeleteRow( M, at ) END;
		DEC( M.columns );
		FOR t := at TO M.columns - 1 DO copyLabel( M.collabels[t + 1], M.collabels[t] ) END
	END DeleteColumn;
(** Integer **)
	PROCEDURE GetInt*( me: tMatrix;  row, col: SIGNED32 ): SIGNED16;
	BEGIN
		ASSERT ( me IS tIntMatrix, 100 );
		WITH me: tIntMatrix DO RETURN me.Get( me, row, col )
		END
	END GetInt;

	PROCEDURE SetInt*( val: SIGNED16;  me: tMatrix;  row, col: SIGNED32 );
	BEGIN
		ASSERT ( me IS tIntMatrix, 100 );
		WITH me: tIntMatrix DO me.Set( val, me, row, col )
		END
	END SetInt;

	PROCEDURE GetIRow*( M: tMatrix;  row: SIGNED32 ): vyBase.tVector;
	VAR v: vyBase.tVector;  t: SIGNED32;
	BEGIN
		v := vyIntVec.New( M.columns );
		FOR t := 0 TO M.columns - 1 DO vyIntVec.Set( GetInt( M, row, t ), v, t ) END;
		RETURN v
	END GetIRow;

	PROCEDURE GetICol*( M: tMatrix;  col: SIGNED32 ): vyBase.tVector;
	VAR v: vyBase.tVector;  t: SIGNED32;
	BEGIN
		v := vyIntVec.New( M.rows );
		FOR t := 0 TO M.rows - 1 DO vyIntVec.Set( GetInt( M, t, col ), v, t ) END;
		RETURN v
	END GetICol;

	PROCEDURE SetIRow*( v: vyBase.tVector;  M: tMatrix;  row: SIGNED32 );
	VAR t: SIGNED32;
	BEGIN
		FOR t := 0 TO M.columns - 1 DO
			SetInt( vyIntVec.Get( v, t ), M, row, t ) (*! use / implement Types CopyVector *)
		END
	END SetIRow;

	PROCEDURE SetICol*( v: vyBase.tVector;  M: tMatrix;  col: SIGNED32 );
	VAR t: SIGNED32;
	BEGIN
		FOR t := 0 TO M.rows - 1 DO
			SetInt( vyIntVec.Get( v, t ), M, t, col ) (*! use / implement Types CopyVector *)
		END
	END SetICol;

(** Real **)
	PROCEDURE GetReal*( me: tMatrix;  row, col: SIGNED32 ): FLOAT32;
	BEGIN
		ASSERT ( me IS tRealMatrix, 100 );
		WITH me: tRealMatrix DO RETURN me.Get( me, row, col )
		END
	END GetReal;

	PROCEDURE SetReal*( val: FLOAT32;  me: tMatrix;  row, col: SIGNED32 );
	BEGIN
		ASSERT ( me IS tRealMatrix, 100 );
		WITH me: tRealMatrix DO me.Set( val, me, row, col )
		END
	END SetReal;

	PROCEDURE GetRRow*( M: tMatrix;  row: SIGNED32 ): vyBase.tVector;
	VAR v: vyBase.tVector;  t: SIGNED32;
	BEGIN
		v := vyRealVec.New( M.columns );
		FOR t := 0 TO M.columns - 1 DO vyRealVec.Set( GetReal( M, row, t ), v, t ) END;
		RETURN v
	END GetRRow;

	PROCEDURE GetRCol*( M: tMatrix;  col: SIGNED32 ): vyBase.tVector;
	VAR v: vyBase.tVector;  t: SIGNED32;
	BEGIN
		v := vyRealVec.New( M.rows );
		FOR t := 0 TO M.rows - 1 DO vyRealVec.Set( GetReal( M, t, col ), v, t ) END;
		RETURN v
	END GetRCol;

	PROCEDURE SetRRow*( v: vyBase.tVector;  M: tMatrix;  row: SIGNED32 );
	VAR t: SIGNED32;
	BEGIN
		FOR t := 0 TO M.columns - 1 DO
			SetReal( vyRealVec.Get( v, t ), M, row, t ) (*! use / implement Types CopyVector *)
		END
	END SetRRow;

	PROCEDURE SetRCol*( v: vyBase.tVector;  M: tMatrix;  col: SIGNED32 );
	VAR t: SIGNED32;
	BEGIN
		FOR t := 0 TO M.rows - 1 DO
			SetReal( vyRealVec.Get( v, t ), M, t, col ) (*! use / implement Types CopyVector *)
		END
	END SetRCol;

	PROCEDURE InsertRow*( M: tMatrix;  rowv: vyBase.tVector;  at: SIGNED32 );
	BEGIN
		InsertNewRow( M, at );  SetRRow( rowv, M, at )
	END InsertRow;

	PROCEDURE AppendR*( M: tMatrix;  rowv: vyBase.tVector );
	(*= append a row to a matrix*)
	BEGIN
		InsertRow( M, rowv, M.rows )
	END AppendR;

	PROCEDURE InsertColumn*( M: tMatrix;  colv: vyBase.tVector;  at: SIGNED32 );
	BEGIN
		InsertNewColumn( M, at );  SetRCol( colv, M, at )
	END InsertColumn;

	PROCEDURE AppendC*( M: tMatrix;  colv: vyBase.tVector );
	(*= append a column to a matrix*)
	BEGIN
		InsertColumn( M, colv, M.columns )
	END AppendC;

	PROCEDURE rParsCache( M: tMatrix );
	VAR r, min, max, mean: FLOAT64;  row, i, l: SIGNED32;
	BEGIN
		NEW( M.rParsCache, M.rows );
		FOR row := 0 TO M.rows - 1 DO
			min := MAX( FLOAT32 );  max := MIN( FLOAT32 );  mean := 0;  l := M.columns;
			FOR i := 0 TO M.columns - 1 DO
				r := GetReal( M, row, i );
				IF ~Reals.IsNaNL( r ) THEN
					IF r < min THEN min := r END;
					IF r > max THEN max := r END;
					mean := mean + r
				ELSE DEC( l )
				END
			END;
			mean := mean / l;  M.rParsCache[row].min := min;  M.rParsCache[row].max := max;
			M.rParsCache[row].mean := mean
		END
	END rParsCache;

	PROCEDURE GetRPars*( M: tMatrix;  row: SIGNED32;  VAR min, max, mean: FLOAT64 );
	BEGIN
		IF M.rParsCache = NIL THEN rParsCache( M ) END;
		min := M.rParsCache[row].min;  max := M.rParsCache[row].max;  mean := M.rParsCache[row].mean
	END GetRPars;

	PROCEDURE cParsCache( M: tMatrix );
	VAR r, min, max, mean: FLOAT64;  col, i, l: SIGNED32;
	BEGIN
		NEW( M.cParsCache, M.columns );
		FOR col := 0 TO M.columns - 1 DO
			min := MAX( FLOAT32 );  max := MIN( FLOAT32 );  mean := 0;  l := M.rows;
			FOR i := 0 TO M.rows - 1 DO
				r := GetReal( M, i, col );
				IF ~Reals.IsNaNL( r ) THEN
					IF r < min THEN min := r END;
					IF r > max THEN max := r END;
					mean := mean + r
				ELSE DEC( l )
				END
			END;
			mean := mean / l;  M.cParsCache[col].min := min;  M.cParsCache[col].max := max;  M.cParsCache[col].mean := mean
		END
	END cParsCache;

	PROCEDURE GetCPars*( M: tMatrix;  col: SIGNED32;  VAR min, max, mean: FLOAT64 );
	BEGIN
		IF M.cParsCache = NIL THEN cParsCache( M ) END;
		min := M.cParsCache[col].min;  max := M.cParsCache[col].max;  mean := M.cParsCache[col].mean
	END GetCPars;

	PROCEDURE GetPars*( M: tMatrix;  VAR min, max, mean: FLOAT64 );
	VAR i, j: SIGNED32;  r: FLOAT64;  l: SIGNED32;
	BEGIN
		min := MAX( FLOAT32 );  max := MIN( FLOAT32 );  mean := 0;  l := M.rows;
		FOR j := 0 TO M.columns - 1 DO
			FOR i := 0 TO M.rows - 1 DO
				r := GetReal( M, i, j );
				IF ~Reals.IsNaNL( r ) THEN
					IF r < min THEN min := r END;
					IF r > max THEN max := r END;
					mean := mean + r
				ELSE DEC( l )
				END
			END
		END;
		mean := mean / l
	END GetPars;

	PROCEDURE DoGetReal( M: tMatrix;  row, col: SIGNED32 ): FLOAT32;
	VAR trow: tRow;  i, ilow: SIGNED32;
	BEGIN
		IF row >= M.cachedrow THEN ilow := M.cachedrow;  trow := M.rowcache ELSE ilow := 0;  trow := M.firstrow END;
		FOR i := ilow TO row - 1 DO trow := trow.next END;
		M.cachedrow := row;  M.rowcache := trow;  RETURN vyRealVec.Get( trow.v, col )
	END DoGetReal;

	PROCEDURE DoGetRealTransposed( me: tMatrix;  row, col: SIGNED32 ): FLOAT32;
	BEGIN
		RETURN DoGetReal( me, col, row )
	END DoGetRealTransposed;

	PROCEDURE DoSetReal( val: FLOAT32;  M: tMatrix;  row, col: SIGNED32 );
	VAR trow: tRow;  i, ilow: SIGNED32;
	BEGIN
		IF row >= M.cachedrow THEN ilow := M.cachedrow;  trow := M.rowcache ELSE ilow := 0;  trow := M.firstrow END;
		ASSERT ( trow # NIL );
		FOR i := ilow TO row - 1 DO trow := trow.next END;
		M.cachedrow := row;  M.rowcache := trow;  vyRealVec.Set( val, trow.v, col );  M.rParsCache := NIL;  M.cParsCache := NIL
	END DoSetReal;

	PROCEDURE DoSetRealTransposed( val: FLOAT32;  me: tMatrix;  row, col: SIGNED32 );
	BEGIN
		DoSetReal( val, me, col, row )
	END DoSetRealTransposed;

	PROCEDURE setRLabel*( s: ARRAY OF CHAR;  M: tMatrix;  row: SIGNED32 );
	BEGIN
		COPY( s, M.rowlabels[row] )
	END setRLabel;

	PROCEDURE setCLabel*( s: ARRAY OF CHAR;  M: tMatrix;  col: SIGNED32 );
	BEGIN
		COPY( s, M.collabels[col] )
	END setCLabel;

	PROCEDURE getRLabel*( VAR s: ARRAY OF CHAR;  M: tMatrix;  row: SIGNED32 );
	VAR i: SIGNED16;
	BEGIN
		i := 0;
		WHILE (M.rowlabels[row][i] # 0X) DO s[i] := M.rowlabels[row][i];  INC( i ) END;
		s[i] := 0X
	END getRLabel;

	PROCEDURE getCLabel*( VAR s: ARRAY OF CHAR;  M: tMatrix;  col: SIGNED32 );
	VAR i: SIGNED16;
	BEGIN
		i := 0;
		WHILE (M.collabels[col][i] # 0X) DO s[i] := M.collabels[col][i];  INC( i ) END;
		s[i] := 0X
	END getCLabel;

	PROCEDURE AdjustAccess( m: tMatrix );
	BEGIN
		ASSERT ( m IS tRealMatrix, 100 );   (*! support other base types *)
		WITH m: tRealMatrix DO
			IF m.transposed THEN m.Get := DoGetRealTransposed;  m.Set := DoSetRealTransposed
			ELSE m.Get := DoGetReal;  m.Set := DoSetReal
			END
		END;
		m.rParsCache := NIL;  m.cParsCache := NIL
	END AdjustAccess;

	PROCEDURE Transpose*( m: tMatrix );
	VAR temp: SIGNED32;  templ: labels;
	BEGIN
		m.transposed := ~m.transposed;  temp := m.rows;  m.rows := m.columns;  m.columns := temp;  templ := m.rowlabels;
		m.rowlabels := m.collabels;  m.collabels := templ;  AdjustAccess( m )
	END Transpose;

	PROCEDURE Init*( m: tMatrix;  rows, columns: SIGNED32 );
	VAR i: SIGNED32;  row: tRow;
	BEGIN
		m.rows := rows;  m.columns := columns;  m.transposed := FALSE;

		NEW( m.firstrow );  row := m.firstrow;  row.v := vyRealVec.New( columns );
		FOR i := 1 TO rows DO
			m.cachedrow := i - 1;  m.rowcache := row;  NEW( row.next );  row := row.next;  row.v := vyRealVec.New( columns )
		END;

		NEW( m.collabels, columns );  NEW( m.rowlabels, rows );
		FOR i := 0 TO rows - 1 DO m.rowlabels[i] := "R#";  vyHostStrings.AppendInt( i + 1, 1, m.rowlabels[i] ) END;
		FOR i := 0 TO columns - 1 DO m.collabels[i] := "C#";  vyHostStrings.AppendInt( i + 1, 1, m.collabels[i] ) END
	END Init;

	PROCEDURE NewRealMatrix*( rows, columns: SIGNED32 ): tMatrix;
	VAR M: tRealMatrix;
	BEGIN
		NEW( M );  Init( M, rows, columns );  AdjustAccess( M );  RETURN M
	END NewRealMatrix;

	(** matrix matrix distances **)
	(*! add correlation *)
(*! support NaNs *)

	PROCEDURE L1Dist*( v1, v2: vyBase.tVector ): FLOAT64;
	VAR temp: FLOAT64;  k: SIGNED32;
	BEGIN
		ASSERT ( v1.nrData = v2.nrData, 101 );
		temp := 0;
		FOR k := 0 TO v1.nrData - 1 DO
			IF v1 IS vyRealVec.tVector THEN
				WITH v1: vyRealVec.tVector DO temp := temp + ABS( vyRealVec.Get( v1, k ) - vyRealVec.Get( v2, k ) )
				END;
			ELSIF v1 IS vyLongrealVec.tVector THEN
				WITH v1: vyLongrealVec.tVector DO temp := temp + ABS( vyLongrealVec.Get( v1, k ) - vyLongrealVec.Get( v2, k ) )
				END;
			END
		END;
		RETURN temp
	END L1Dist;

	PROCEDURE L2Dist*( v1, v2: vyBase.tVector ): FLOAT64;
	VAR temp: FLOAT64;  k: SIGNED32;
	BEGIN
		ASSERT ( v1.nrData = v2.nrData, 101 );
		temp := 0;
		FOR k := 0 TO v1.nrData - 1 DO
			IF v1 IS vyRealVec.tVector THEN
				WITH v1: vyRealVec.tVector DO
					temp :=
						temp + (vyRealVec.Get( v1, k ) - vyRealVec.Get( v2, k )) * (vyRealVec.Get( v1, k ) - vyRealVec.Get( v2, k ))
				END;
			ELSIF v1 IS vyLongrealVec.tVector THEN
				WITH v1: vyLongrealVec.tVector DO
					temp :=
						temp +
						(vyLongrealVec.Get( v1, k ) - vyLongrealVec.Get( v2, k )) *
		    (vyLongrealVec.Get( v1, k ) - vyLongrealVec.Get( v2, k ))
				END;
			END
		END;
		RETURN temp
	END L2Dist;

	PROCEDURE CorrDist*( v1, v2: vyBase.tVector ): FLOAT64;
	VAR temp: FLOAT64;  xstat, ystat: vyQFisher.Stattyp;  xyssq: FLOAT64;  k: SIGNED32;
	BEGIN
		ASSERT ( v1.nrData = v2.nrData, 101 );
		temp := 0;  vyQFisher.initstat( xstat );  vyQFisher.initstat( ystat );  xyssq := 0;
		FOR k := 0 TO v1.nrData - 1 DO
			IF v1 IS vyRealVec.tVector THEN
				WITH v1: vyRealVec.tVector DO
					vyQFisher.Addbistat( vyRealVec.Get( v1, k ), vyRealVec.Get( v2, k ), xstat, ystat, xyssq )
				END;
			ELSIF v1 IS vyLongrealVec.tVector THEN
				WITH v1: vyLongrealVec.tVector DO
					vyQFisher.Addbistat( vyRealVec.Get( v1, k ), vyRealVec.Get( v2, k ), xstat, ystat, xyssq )
				END;
			END;
			temp := xstat.Ssq * ystat.Ssq;
			IF Reals.IsNaNL( temp ) THEN RETURN Reals.NaN( 0 ) END;
			IF (temp > 0) THEN temp := xyssq / MathL.sqrt( temp ) ELSE temp := 1 END
		END;
		RETURN temp
	END CorrDist;

	PROCEDURE NewRowDistMatrix*( data: tMatrix;  distf: VDist ): tMatrix;
	VAR M: tRealMatrix;  i, j: SIGNED32;  vi, vj: vyBase.tVector;  temp: FLOAT64;
	BEGIN
		NEW( M );  Init( M, data.rows, data.rows );  AdjustAccess( M );
		FOR i := 0 TO data.rows - 1 DO
			vi := GetRRow( data, i );
			FOR j := i TO data.rows - 1 DO
				vj := GetRRow( data, j );  temp := distf( vi, vj );  SetReal( SHORT( temp ), M, i, j );  SetReal( SHORT( temp ), M, j, i )
			END
		END;   (* i*)
		RETURN M
	END NewRowDistMatrix;

	PROCEDURE NewColDistMatrix*( data: tMatrix;  distf: VDist ): tMatrix;
	VAR M: tRealMatrix;  i, j: SIGNED32;  vi, vj: vyBase.tVector;  temp: FLOAT64;
	BEGIN
		NEW( M );  Init( M, data.columns, data.columns );  AdjustAccess( M );
		FOR i := 0 TO data.columns - 1 DO
			vi := GetRCol( data, i );
			FOR j := i TO data.columns - 1 DO
				vj := GetRCol( data, j );  temp := distf( vi, vj );  SetReal( SHORT( temp ), M, i, j );  SetReal( SHORT( temp ), M, j, i )
			END
		END;   (* i*)
		RETURN M
	END NewColDistMatrix;

	PROCEDURE WriteMatrix*( M: tMatrix );
	VAR cols, rows: SIGNED32;
		s: ARRAY 32 OF CHAR;
		i, j: SIGNED32;  row, col: SIGNED32;  r: FLOAT32;
	BEGIN
		vyHostTexts.WriteTableStyle( vyHostTexts.w );  cols := M.columns - 1;  rows := M.rows - 1;
		FOR i := 0 TO cols DO
			Texts.Write( vyHostTexts.w, 09X );  getCLabel( s, M, i );  Texts.Write( vyHostTexts.w, '[' );
			Texts.WriteString( vyHostTexts.w, s );  Texts.Write( vyHostTexts.w, ']' )
		END;
		Texts.WriteLn( vyHostTexts.w );
		FOR j := 0 TO rows DO
			getRLabel( s, M, j );  Texts.Write( vyHostTexts.w, '[' );  Texts.WriteString( vyHostTexts.w, s );
			Texts.Write( vyHostTexts.w, ']' );
			FOR i := 0 TO cols DO
				row := j;  col := i;  Texts.Write( vyHostTexts.w, 09X );  r := GetReal( M, row, col );
				vyHostTexts.WriteRealFix( vyHostTexts.w, r, 8, 3, 0 )
			END;
			Texts.WriteLn( vyHostTexts.w )
		END;
		Texts.WriteLn( vyHostTexts.w );  vyHostTexts.InsertLog( vyHostTexts.w.buf );
		vyHostTexts.WritePrevStyle( vyHostTexts.w )
	END WriteMatrix;

END vyMatrixTypes.