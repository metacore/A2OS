MODULE Huffman;  (** AUTHOR GF;  PURPOSE "Huffman compression";  *)

IMPORT Streams;
	
TYPE 
	BitReader = OBJECT
		VAR
			in: Streams.Reader;
			curByte, curBit: LONGINT;
			
			PROCEDURE &New( r: Streams.Reader );
			BEGIN
				in := r;  curBit := -1;  curByte := 0
			END New;
			
			PROCEDURE Initialize;
			BEGIN
				curBit := -1;  curByte := 0
			END Initialize;
			
			PROCEDURE Bit( ): LONGINT;
			VAR
				bit: LONGINT;  ch: CHAR;
			BEGIN
				IF curBit < 0 THEN
					in.Char( ch );  curByte := ORD( ch );  curBit := 7
				END;
				bit := ASH( curByte, -curBit ) MOD 2;
				DEC( curBit );
				RETURN bit
			END Bit;
	
	END BitReader;
	
	
TYPE
	BitWriter = OBJECT
		VAR
			out: Streams.Writer;
			curByte, curBit: LONGINT;
			
			PROCEDURE &New( w: Streams.Writer );
			BEGIN
				out := w;  curBit := 0;  curByte := 0
			END New;
			
			PROCEDURE Bit( bit: LONGINT );
			BEGIN
				curByte := 2*curByte + bit;
				INC( curBit );
				IF curBit > 7 THEN
					out.Char( CHR( curByte ) );  curByte := 0;  curBit := 0
				END
			END Bit;
		
			PROCEDURE Finish;	(* flush last few bits *)
			BEGIN
				WHILE curBit # 0 DO  Bit( 0 )  END;
				out.Update
			END Finish;
				
	END BitWriter;
	
	
TYPE	
	PatternCounts = ARRAY 256 OF LONGINT;		(* scaled to 0 .. 101H *)
	
	Pattern = RECORD  patt, weight: LONGINT  END;
	PatternWeights = POINTER TO ARRAY OF Pattern;		(* weights of patterns contained in block *)
	
	HuffCode = RECORD  bits, val: LONGINT  END;
	
TYPE	
	Node = OBJECT 
		VAR 
			weight: LONGINT;
			pattern: LONGINT;		(* node pattern if node is leaf *)
			left, right: Node;		(* both NIL in case of leaf *)
									
			PROCEDURE &Init( patt, w: LONGINT );
			BEGIN
				pattern := patt;  weight := w;  left := NIL;  right := NIL
			END Init;
			
			PROCEDURE AddChildren( l, r: Node );
			BEGIN
				left := l;  right := r;  weight := l.weight + r.weight
			END AddChildren;
			
	END Node;
	
	
TYPE
	Encoder* = OBJECT			
		VAR
			w: Streams.Writer;
			out: BitWriter;
			codeTable: ARRAY 256 OF HuffCode;
		
			
			
			PROCEDURE &New*( output: Streams.Writer );
			BEGIN
				w := output;
				NEW( out, w )
			END New;
			
			
			PROCEDURE WriteFrequencies( pw: PatternWeights );
			VAR i, n: LONGINT;
				pc: PatternCounts;
			BEGIN
				n := LEN( pw^ );
				IF n < 128 THEN
					w.Char( CHR( n ) );
					FOR i := 0 TO n - 1 DO  w.RawNum( pw[i].weight );  w.Char( CHR( pw[i].patt ) )  END
				ELSE
					w.Char( 0X );
					FOR i := 0 TO 255 DO  pc[i] := 0  END;
					FOR i := 0 TO n -1 DO  pc[pw[i].patt] := pw[i].weight  END;
					FOR i := 0 TO 255 DO  w.RawNum( pc[i] )  END
				END;
			END WriteFrequencies;
			
			
			PROCEDURE CountPatterns( CONST source: ARRAY OF CHAR; len: LONGINT ): PatternWeights;
			VAR 
				i: LONGINT;  pc: PatternCounts;
			BEGIN
				FOR i := 0 TO 255 DO  pc[i] := 0  END;
				FOR i := 0 TO len - 1 DO  INC( pc[ORD( source[i] )] )  END;
				FOR i := 0 TO 255 DO  
					IF pc[i] > 0 THEN (* scale => [1..101H] *)
						pc[i] := 100H * pc[i] DIV len + 1;
					END;
				END;
				RETURN ContainedPatterns( pc )
			END CountPatterns;
			
			
			PROCEDURE BuildCodeTable( pw: PatternWeights );
			VAR 
				initval: HuffCode;
				tree: Node;
			
				PROCEDURE Traverse( node: Node;  code: HuffCode );
				BEGIN
					IF node.left = NIL THEN  (* leaf *)
						codeTable[node.pattern] := code;
					ELSE
						INC( code.bits );  
						code.val := 2*code.val;  Traverse( node.right, code );	(* ..xx0 *)
						code.val := code.val + 1;  Traverse( node.left, code );	(* ..xx1 *)
					END;
				END Traverse;
			
			BEGIN
				tree := BuildTree( pw );
				initval.bits := 0;  initval.val := 0;
				Traverse( tree, initval );
			END BuildCodeTable;	
			
			
			PROCEDURE PutCode( code: HuffCode );
			VAR len, val: LONGINT;
			BEGIN
				len := code.bits;  val := code.val;
				WHILE len > 0 DO
					DEC( len );  out.Bit( ASH( val, -len ) MOD 2 )
				END
			END PutCode;
			
			
			PROCEDURE CompressBlock*( CONST source: ARRAY OF CHAR; len: LONGINT );
			VAR 
				i: LONGINT;
				pw: PatternWeights;
			BEGIN
				pw := CountPatterns( source, len );
				WriteFrequencies( pw );
				BuildCodeTable( pw );
				FOR i := 0 TO len - 1 DO  PutCode( codeTable[ORD( source[i] )] )  END;
				out.Finish;
			END CompressBlock;
				
	END Encoder;
	
	
TYPE
	Decoder* = OBJECT
		VAR
			r: Streams.Reader;
			in: BitReader;
			tree: Node;
		
			PROCEDURE &New*( input: Streams.Reader );
			BEGIN
				r := input;  
				NEW( in, r )
			END New;
			
			
			PROCEDURE ReadFrequencies( r: Streams.Reader ): PatternWeights;
			VAR 
				i, n: LONGINT;  c: CHAR;
				pw: PatternWeights;
				pc: PatternCounts;
			BEGIN
				r.Char( c );  n := ORD( c );
				IF n > 0 THEN
					NEW( pw, n );
					FOR i := 0 TO n - 1 DO  r.RawNum( pw[i].weight );  r.Char( c );  pw[i].patt := ORD( c )  END
				ELSE
					FOR i := 0 TO 255 DO  r.RawNum( pc[i] )  END;
					pw := ContainedPatterns( pc )
				END;
				RETURN pw
			END ReadFrequencies;
		
			
			PROCEDURE ExtractBlock*( VAR buf: ARRAY OF CHAR; len: LONGINT );
			VAR 
				i: LONGINT;  n: Node;
			BEGIN
				tree := BuildTree( ReadFrequencies( r ) );
				in.Initialize;
				i := 0; 
				REPEAT
					n := tree; 
					REPEAT
						IF in.Bit() = 1 THEN  n := n.left  ELSE  n := n.right  END;
					UNTIL n.left = NIL;	(* leaf *)
					buf[i] := CHR( n.pattern );  INC( i )
				UNTIL i >= len;
			END ExtractBlock;
				
	END Decoder;
	
	
	
	
	
	(* sort patterns by weight, omit unused patterns *)
	PROCEDURE ContainedPatterns( VAR pc: PatternCounts ): PatternWeights;
	VAR 
		i, n, start: LONGINT;  
		pw: PatternWeights;
		a: ARRAY 256 OF Pattern;
		
		PROCEDURE Sort( low, high: LONGINT );  
		VAR 
			i, j, m: LONGINT;  tmp: Pattern;
		BEGIN
			IF low < high THEN
				i := low;  j := high;  m := (i + j) DIV 2;
				REPEAT
					WHILE a[i].weight < a[m].weight DO  INC( i )  END;
					WHILE a[j].weight > a[m].weight DO  DEC( j )  END;
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
		FOR i := 0 TO 255 DO  a[i].patt := i;  a[i].weight := pc[i]  END;
		Sort( 0, 255 );	(* sort patterns by weight *)
		i := 0;
		WHILE a[i].weight = 0 DO  INC( i )  END; 	(* skip unused patterns *)
		n := 256 - i;  start := i;
		NEW( pw, n );
		FOR i := 0 TO n - 1 DO  pw[i] := a[start + i]  END;
		RETURN pw
	END ContainedPatterns;

	
	PROCEDURE BuildTree( pw: PatternWeights ): Node;
	VAR 
		i, start, top: LONGINT;  node, n2: Node;
		a: POINTER TO ARRAY OF Node;
		patt: LONGINT;
	BEGIN
		NEW( a, LEN( pw^ ) );  top := LEN( pw^ ) - 1;
		FOR i := 0 TO top DO  NEW( a[i], pw[i].patt, pw[i].weight )  END;
		IF top = 0 THEN  
			(* the whole, probably last small block contains only a single pattern *)
			patt := (a[0].pattern + 1) MOD 256;	(* some different pattern *)
			NEW( node, 0, 0 );  NEW( n2, patt, 0 );  node.AddChildren( n2, a[0] );
		ELSE
			start := 0;  
			WHILE start < top DO  
				NEW( node, 0, 0 );  node.AddChildren( a[start], a[start+1] ); 
				i := start + 1;  
				WHILE (i < top) & (a[i+1].weight < node.weight) DO  a[i] := a[i+1];  INC( i )  END;
				a[i] := node;  
				INC( start );
			END
		END;
		RETURN node
	END BuildTree;	
	

END Huffman.

