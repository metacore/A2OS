MODULE Huffman;  (** AUTHOR GF;  PURPOSE "Huffman compression";  *)

IMPORT Streams;

CONST
	BlockSize = 8*1024;
	
TYPE 
	
	Pattern = RECORD  pattern, freq: LONGINT  END;
	
	PatternCounts = ARRAY 256 OF Pattern;
	PatternFrequencies = POINTER TO ARRAY OF Pattern;		(* ordered by frequency *)
	
	
	
	Node = OBJECT 
		VAR 
			freq: LONGINT;
			left, right: Node;		(* both NIL in case of leaf *)
			pattern: LONGINT;						
		
		PROCEDURE & Init( patt, f: LONGINT );
		BEGIN
			pattern := patt;  freq := f;  left := NIL;  right := NIL
		END Init;
		
		PROCEDURE AddChildren( l, r: Node );
		BEGIN
			left := l;  right := r;  freq := l.freq + r.freq
		END AddChildren;
			
	END Node;
	
	
	
	Encoder* = OBJECT
		TYPE
			HCode = RECORD  len, val: LONGINT  END;
		VAR
			w: Streams.Writer;
			codeTable: ARRAY 256 OF HCode;
			buffer: ARRAY 2*BlockSize OF CHAR;
			byte, curBit, bpos: LONGINT;
			
			
			PROCEDURE &New*( output: Streams.Writer );
			BEGIN
				w := output;
			END New;
			
			PROCEDURE Initialize( CONST source: ARRAY OF CHAR; len: LONGINT );
			VAR pf: PatternFrequencies;
			BEGIN
				pf := CountPatterns( source, len );
				WriteFrequencies( pf );
				BuildCodeTable( BuildTree( pf ) );				
				byte := 0;  bpos := 0;  curBit := 7;
			END Initialize;
			
			
			PROCEDURE WriteFrequencies( pf: PatternFrequencies );
			VAR i, n: LONGINT;
				a: ARRAY 256 OF LONGINT;
			BEGIN
				n := LEN( pf^ );
				IF n < 128 THEN
					w.Char( CHR( n ) );
					FOR i := 0 TO n - 1 DO  
						w.RawNum( pf[i].freq );  w.Char( CHR( pf[i].pattern ) )  
					END
				ELSE
					w.Char( 0X );
					FOR i := 0 TO 255 DO  a[i] := 0  END;
					FOR i := 0 TO n -1 DO  a[pf[i].pattern] := pf[i].freq  END;
					FOR i := 0 TO 255 DO  w.RawNum( a[i] )  END
				END
			END WriteFrequencies;
			
			
			PROCEDURE CountPatterns( CONST source: ARRAY OF CHAR; len: LONGINT ): PatternFrequencies;
			VAR 
				i: LONGINT;  a: PatternCounts;
			BEGIN
				FOR i := 0 TO 255 DO  a[i].pattern := i;  a[i].freq := 0  END;
				FOR i := 0 TO len - 1 DO  INC( a[ORD( source[i] )].freq )  END;
				FOR i := 0 TO 255 DO  
					IF a[i].freq > 0 THEN (* scale => [1..101H] *)
						a[i].freq := 100H * a[i].freq DIV len + 1;
					END
				END;
				RETURN SortPatterns( a )
			END CountPatterns;
			
			
			PROCEDURE BuildCodeTable( tree: Node );
			VAR 
				initval: HCode; i: LONGINT;
			
				PROCEDURE Traverse( node: Node;  code: HCode );
				BEGIN
					IF node.left = NIL THEN  (* leaf *)
						codeTable[node.pattern] := code;
					ELSE
						INC( code.len );  
						code.val := 2*code.val;  Traverse( node.right, code );	(* ..xx0 *)
						code.val := code.val + 1;  Traverse( node.left, code );	(* ..xx1 *)
					END;
				END Traverse;
			
			BEGIN
				FOR i := 0 TO 255 DO  codeTable[i].len := 0;  codeTable[i].val := 0  END;
				initval.len := 0;  initval.val := 0;
				Traverse( tree, initval );
			END BuildCodeTable;	
			
			
			PROCEDURE AppendBit( bit: LONGINT );
			BEGIN
				IF bit # 0 THEN  byte := byte + ASH( 1, curBit )  END;
				DEC( curBit );
				IF curBit < 0 THEN
					buffer[bpos] := CHR( byte );  INC( bpos );
					byte := 0; curBit := 7
				END
			END AppendBit;
			
			
			PROCEDURE Append( code: HCode );
			VAR len, val: LONGINT;
			BEGIN
				len := code.len;  val := code.val;
				WHILE len > 0 DO
					DEC( len );  AppendBit( ASH( val, -len ) MOD 2 )
				END
			END Append;
			
			
			PROCEDURE CompressBlock*( CONST source: ARRAY OF CHAR; len: LONGINT );
			VAR i, codesize: LONGINT;
			BEGIN
				Initialize( source, len );
				FOR i := 0 TO len - 1 DO  Append( codeTable[ORD( source[i] )] )  END;
				
				codesize := 8*bpos;
				IF curBit # 7 THEN  
					INC( codesize, (7 - curBit) );
					buffer[bpos] := CHR( byte );  INC( bpos ); 
				END;
				
				w.RawNum( codesize );
				FOR i := 0 TO bpos - 1 DO  w.Char( buffer[i] )  END;
				w.Update
			END CompressBlock;
				
	END Encoder;
	
	
	
	Decoder* = OBJECT
		VAR
			codesize: LONGINT;	(* bits! *)
			r: Streams.Reader;
			tree: Node;
			byte, curBit: LONGINT;
		
			PROCEDURE &New*( input: Streams.Reader );
			BEGIN
				r := input;  
			END New;
			
			PROCEDURE Initialize;
			VAR  pf: PatternFrequencies;
			BEGIN
				pf := ReadFrequencies( r );
				tree := BuildTree( pf );
				r.RawNum( codesize );
				curBit := -1
			END Initialize;
			
			
			PROCEDURE ReadFrequencies( r: Streams.Reader ): PatternFrequencies;
			VAR i, n: LONGINT;  c: CHAR;
				pf: PatternFrequencies;
				a: PatternCounts;
			BEGIN
				r.Char( c );  n := ORD( c );
				IF n > 0 THEN
					NEW( pf, n );
					FOR i := 0 TO n - 1 DO  r.RawNum( pf[i].freq );  r.Char( c );  pf[i].pattern := ORD( c )  END
				ELSE
					FOR i := 0 TO 255 DO  a[i].pattern := i;  r.RawNum( a[i].freq )  END;
					pf := SortPatterns( a )
				END;
				RETURN pf
			END ReadFrequencies;
		
		
			PROCEDURE GetBit( ): LONGINT;
			VAR bit: LONGINT;  c: CHAR;
			BEGIN
				IF curBit < 0 THEN
					r.Char( c );  byte := ORD( c );  curBit := 7
				END;
				bit := ASH( byte, -curBit ) MOD 2;  DEC( curBit );
				RETURN bit
			END GetBit;	
			
			
			PROCEDURE ExtractBlock*( VAR buf: ARRAY OF CHAR; VAR len: LONGINT );
			VAR 
				i: LONGINT;  n: Node;
			BEGIN
				Initialize;  i := 0;  len := 0;
				REPEAT
					n := tree; 
					REPEAT
						IF GetBit() # 0 THEN  n := n.left  ELSE  n := n.right  END;
						INC( i )
					UNTIL n.left = NIL;	(* leaf *)
					buf[len] := CHR( n.pattern );  INC( len )
				UNTIL i >= codesize;
			END ExtractBlock;
				
	END Decoder;
	
	
	
	
	
	(* sort patterns by frequency, omit unused patterns *)
	PROCEDURE SortPatterns( VAR a: PatternCounts ): PatternFrequencies;
	VAR 
		i, n, start: LONGINT;  pf: PatternFrequencies;
		
		PROCEDURE Sort( low, high: LONGINT );  
		VAR 
			i, j, m: LONGINT;  tmp: Pattern;
		BEGIN
			IF low < high THEN
				i := low;  j := high;  m := (i + j) DIV 2;
				REPEAT
					WHILE a[i].freq < a[m].freq DO  INC( i )  END;
					WHILE a[j].freq > a[m].freq DO  DEC( j )  END;
					IF i <= j THEN
						IF i = m THEN  m := j  ELSIF j = m THEN  m := i  END;
						tmp := a[i];  a[i] := a[j];  a[j] := tmp;
						INC( i );  DEC( j )
					END;
				UNTIL i > j;
				Sort( low, j );  Sort( i, high )
			END
		END Sort;
		
	BEGIN
		Sort( 0, 255 );	(* sort patterns by frequency *)
		i := 0;
		WHILE a[i].freq = 0 DO  INC( i )  END; 	(* skip unused patterns *)
		n := 256 - i;  start := i;
		NEW( pf, n );
		FOR i := 0 TO n - 1 DO  pf[i] := a[start + i]  END;
		RETURN pf
	END SortPatterns;

	
	PROCEDURE BuildTree( pf: PatternFrequencies ): Node;
	VAR 
		i, start, top: LONGINT;  node, n2: Node;
		a: POINTER TO ARRAY OF Node;
		patt: LONGINT;
	BEGIN
		NEW( a, LEN( pf^ ) );  top := LEN( pf^ ) - 1;
		FOR i := 0 TO top DO  NEW( a[i], pf[i].pattern, pf[i].freq )  END;
		IF top = 0 THEN  
			(* the whole, probably last small block contains only a single pattern *)
			patt := (a[0].pattern + 1) MOD 256;	(* some different pattern *)
			NEW( node, 0, 0 );  NEW( n2, patt, 0 );  node.AddChildren( n2, a[0] );
		ELSE
			start := 0;  
			WHILE start < top DO  
				NEW( node, 0, 0 );  node.AddChildren( a[start], a[start+1] ); 
				i := start + 1;  
				WHILE (i < top) & (a[i+1].freq < node.freq) DO  a[i] := a[i+1];  INC( i )  END;
				a[i] := node;  
				INC( start );
			END
		END;
		RETURN node
	END BuildTree;	
	

END Huffman.

