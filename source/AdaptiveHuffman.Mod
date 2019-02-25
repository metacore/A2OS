MODULE AdaptiveHuffman;	(** AUTHOR GF; PUROSE "adaptive Huffman coding" *)

(* adaptive Huffman compression, Vitter's FGK algorithm *)

IMPORT Streams;

CONST
	AlphabetSize = 256;		(* byte *)
	BlockSize* = 8*1024;
	ScaleLimit = 4*1024;
	
	Encode = 0;  Decode = 1;

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
	HuffmanCoder = OBJECT		
		TYPE
			Index = INTEGER;		(* 16-bit integer to keep the table small *)
			Pattern = INTEGER;
			Node = RECORD
				weight: INTEGER;		(* node weight	*)
				pattern: Pattern;		(* node pattern (if weight is even, leaf node)	*)
				up: Index;				(* next node up the tree	*)
				down: Index			(* pair of down nodes (if weight is odd, internal node)	*)
			END;
		VAR
			mode: SHORTINT;	(* Encode, Decode *)
			in: BitReader;		(* input from archive *)
			out: BitWriter;	(* output to archive *)
			
			esc: Index;		(* the current escape node	*)
			root: Index;         (* the root of the tree	*)
			map: ARRAY AlphabetSize OF Index;			(* mapping of patterns to nodes	*)
			table: ARRAY 2*AlphabetSize + 2 OF Node;	(* the Huffman tree	*)
		
		
		
		PROCEDURE &New( m: SHORTINT;  input: Streams.Reader;  output: Streams.Writer );
		BEGIN
			ASSERT( m IN {Encode, Decode} );
			mode := m;
			IF mode = Encode THEN  NEW( out, output )  ELSE  NEW( in, input )  END;
		END New;
		
		PROCEDURE Initialize;
		VAR  i: Index;
		BEGIN
			root := 2*AlphabetSize + 2 - 1; 
			FOR i := 0 TO root DO
				table[i].up := 0;  table[i].down := 0;  table[i].pattern := 0;  table[i].weight := 0
			END;
			FOR i := 0 TO AlphabetSize - 1 DO  map[i]  := 0  END;
			esc := root;
			IF mode = Decode THEN  in.Initialize  END
		END Initialize;		
		
		PROCEDURE Finish;	
		BEGIN
			ASSERT( mode = Encode );
			out.Finish  (* flush last few bits *)
		END Finish;	

		
		PROCEDURE GetPattern(  ): Pattern;
		VAR  i: INTEGER;  patt: Pattern;
		BEGIN
			patt := 0; 
			FOR i := 0 TO 7 DO
				IF in.Bit() = 1 THEN  patt := patt + INTEGER(ASH( 1, i ))  END;
			END;
			RETURN patt
		END GetPattern;
		
		PROCEDURE PutPattern( patt: Pattern );
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO 7 DO
				out.Bit( patt MOD 2 );  patt := patt DIV 2;
			END
		END PutPattern;

		
		(* split escape node to incorporate a new pattern *)
		PROCEDURE AddPattern( patt: Pattern ): Index;
		VAR  pair, node: Index;
		BEGIN
			ASSERT( esc > 1 );
			pair := esc;  node := esc - 1;  esc := esc - 2 ;
			
			table[pair].down := node;  table[pair].weight := 1;  
			
			table[node].up := pair;
			table[node].down := 0;  table[node].weight := 0;  table[node].pattern := patt; 
			
			table[esc].up := pair;
			table[esc].down := 0;  table[esc].weight := 0;  
			
			map[patt] := node;
			
			RETURN node;
		END AddPattern;		
		

		(* swap leaf to group leader position, return pattern's new node *)
		PROCEDURE GroupLeader( node: Index ): Index;
		VAR
			leader: Index;
			weight: LONGINT;
			patt, prev:  Pattern;
		BEGIN
			weight := table[node].weight;  leader := node;
			WHILE (leader < root) & (weight = table[leader + 1].weight) DO  INC( leader )  END;
			IF leader # node THEN  
				(* swap the leaf nodes *)
				patt := table[node].pattern;
				prev := table[leader].pattern;
				table[leader].pattern := patt;
				table[node].pattern := prev;
				map[patt] := leader;
				map[prev] := node;
			END;
			RETURN leader
		END GroupLeader;		
				

		(*	slide internal node up over all leaves of equal weight
			or exchange leaf with next smaller weight internal node.
			return node's new position	*)
		PROCEDURE SlideNode( node: Index ): Index;
		VAR  next: Index;  swap: Node;
		BEGIN
			swap := table[node];  next := node + 1;
			(* if we're sliding an internal node, find the highest possible leaf to exchange with *)
			IF ODD( swap.weight ) THEN
				WHILE swap.weight > table[next+1].weight DO  INC( next )  END
			END;
			(* swap the two nodes *)
			table[node] := table[next];  table[next] := swap;
			table[next].up := table[node].up;  table[node].up := swap.up;
			(* repair the pattern map and tree structure *)
			IF ODD( swap.weight ) THEN
				table[swap.down].up := next;
				table[swap.down - 1].up := next;
				map[table[node].pattern] := node;
			ELSE
				table[table[node].down - 1].up := node;
				table[table[node].down].up := node;
				map[swap.pattern] := next;
			END;
			RETURN next;
		END SlideNode;		


		(* increment pattern weight and re balance the tree. *)
		PROCEDURE IncrementWeight( node: Index );
		VAR  up: Index;
		BEGIN
			(*	obviate swapping a parent with its child: increment the leaf and proceed directly to its parent.
				otherwise, promote leaf to group leader position in the tree	*)
			IF table[node].up = node + 1 THEN
				INC( table[node].weight, 2 );  INC( node );
			ELSE
				node := GroupLeader( node )
			END;
			(*	increase the weight of each node and slide over any smaller weights ahead of it until reaching the root.
				internal nodes work upwards from their initial positions; while pattern nodes slide over first,
				then work up from their final positions.	*)
			INC( table[node].weight, 2 );  up := table[node].up;
			WHILE up # 0 DO
				WHILE table[node].weight > table[node + 1].weight DO  node := SlideNode( node)  END;
				IF ODD( table[node].weight) THEN
					node := up
				ELSE
					node := table[node].up
				END;
				INC( table[node].weight, 2 );  up := table[node].up
			END;
		END IncrementWeight;
		
			
		(*  scale all weights and rebalance the tree,
		    zero weight nodes are removed from the tree	*)
		PROCEDURE Scale;
		VAR  node, prev: Index;  weight: INTEGER;
		
			PROCEDURE Weight( idx: Index ): INTEGER;
			VAR w: INTEGER;
			BEGIN
				w := table[idx].weight;
				IF ODD( w ) THEN  RETURN w - 1  ELSE  RETURN w  END
			END Weight;
			
		BEGIN
			node := esc + 1;
			(* work up the tree from the escape node scaling weights *)
			WHILE node <= root DO
				weight := table[node].weight;
				IF ODD( weight ) THEN
					(* recompute the weight of internal nodes *)
					weight := Weight( table[node].down ) + Weight( table[node].down-1 ) + 1
				ELSE
					(* remove zero weight leaves and remove them from the pattern map *)
					weight := weight DIV 2;
					IF ODD( weight ) THEN  DEC( weight )  END;
					IF weight = 0 THEN
						map[table[node].pattern] := 0;  INC( esc, 2 );
					END
				END;
				(* slide the scaled node back down over any previous nodes with larger weights *)
				table[node].weight := weight;
				prev := node - 1;
				WHILE weight < table[prev].weight DO  IGNORE SlideNode( prev );  DEC( prev )  END;
				INC( node )
			END;
			(* prepare a new escape node *)
			table[esc].down := 0;  table[esc].weight := 0;
		END Scale;
		
		
		
	
		PROCEDURE EncodeByte( ch: CHAR );
		VAR
			code, bits: LONGINT;  
			cur, node: Index;  patt: Pattern;
		BEGIN
			patt := ORD( ch );  node := map[patt];  
			
			(* accumulate the code bits by working up from the node to the root	*)
			cur := node;  code := 0;  bits := 0;
			IF cur = 0 THEN  cur := esc  END;
			WHILE table[cur].up # 0 DO
				IF ODD( cur ) THEN  code := code*2 + 1  ELSE  code := code*2  END;
				INC( bits );  cur := table[cur].up	
			END;
			(* send the code *)
			WHILE bits > 0 DO
				out.Bit( code MOD 2 );  code := code DIV 2;
				DEC( bits )
			END;
			IF node = 0 THEN
				(* send the new pattern and incorporate it into the tree *)
				PutPattern( patt );  node := AddPattern( patt );
			END;
			IncrementWeight( node );
		END EncodeByte;


		PROCEDURE ExtractByte( ): CHAR;
		VAR
			node, down: Index; 
			patt: Pattern;
		BEGIN
			(* work down the tree from the root until reaching either a leaf or the escape node *)
			node := root;  down := table[node].down;
			WHILE down # 0 DO
				IF in.Bit( ) = 1 THEN  node := down - 1  ELSE  node := down  END;
				down := table[node].down;
			END;
			IF node = esc THEN
				(* add the new pattern to the tree *)
				patt := GetPattern( );  node := AddPattern( patt )
			ELSE
				patt := table[node].pattern
			END;
			IncrementWeight( node );
			RETURN CHR( patt );
		END ExtractByte;
		
	END HuffmanCoder;



TYPE
	Encoder* =OBJECT
		VAR
			huff: HuffmanCoder;
			
			PROCEDURE & New*( archive: Streams.Writer );
			BEGIN
				NEW( huff, Encode, NIL, archive );
			END New;
			
			PROCEDURE CompressBlock*( CONST source: ARRAY OF CHAR; len: LONGINT );
			VAR  i: LONGINT;
			BEGIN
				huff.Initialize;	
				i := 0;
				WHILE i < len DO
					huff.EncodeByte( source[i] );  INC( i );
					IF (i MOD ScaleLimit = 0) & ((len-i) >= ScaleLimit) THEN  huff.Scale  END
				END;
				huff.Finish
			END CompressBlock;

	END Encoder;
	
	
	
TYPE
	Decoder* =OBJECT
		VAR
			huff: HuffmanCoder;
			
			PROCEDURE & New*( archive: Streams.Reader );
			BEGIN
				NEW( huff, Decode, archive, NIL );
			END New;
			
			PROCEDURE ExtractBlock*( VAR buf: ARRAY OF CHAR; len: LONGINT );
			VAR  i: LONGINT; 
			BEGIN
				huff.Initialize;  
				i := 0;
				WHILE i < len DO
					buf[i] := huff.ExtractByte( );  INC( i );
					IF (i MOD ScaleLimit = 0) & ((len - i) >= ScaleLimit) THEN  huff.Scale  END
				END;
			END ExtractBlock;

	END Decoder;
	
	
END AdaptiveHuffman.


