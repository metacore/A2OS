MODULE AdaptiveHuffman;	(** AUTHOR GF; PUROSE "adaptive Huffman coding" *)

(* adaptive Huffman compression, Vitter's algorithm *)

IMPORT Streams;

CONST
	AlphabetSize* = 256;	(* byte *)
	BlockSize* = 8*1024;
	ScaleSize = 2*1024;
	
	Encode = 0;  Decode = 1;

TYPE
	Index = INTEGER;		(* 16-bit integer to keep the table small *)
	Symbol = LONGINT;
	
	Node = RECORD
		weight: LONGINT;		(* node weight	*)
		up: Index;				(* next node up the tree	*)
		down: Index;			(* pair of down nodes	*)
		pattern: Symbol		(* node pattern	*)
	END;


	HuffmanCoder = OBJECT		
	VAR
		mode: SHORTINT;		(* encode, decode *)
		in: Streams.Reader;	(* input from archive *)
		out: Streams.Writer;	(* output to archive *)
		curByte, curBit: LONGINT;
		
		esc: Index;		(* the current tree height	*)
		root: Index;         (* the root of the tree	*)
		map: ARRAY AlphabetSize OF Index;			(* mapping for symbols to nodes	*)
		table: ARRAY 2*AlphabetSize + 4 OF Node;	(* the coding table	*)
		
		
		
		PROCEDURE &New( m: SHORTINT; input: Streams.Reader;  output: Streams.Writer );
		BEGIN
			ASSERT( m IN {Encode, Decode} );
			mode := m;
			IF mode = Encode THEN  out := output  ELSE  in := input  END;
		END New;
		
		PROCEDURE Initialize;
		VAR  i: Index;
		BEGIN
			root := 2*AlphabetSize + 4 - 1;  curByte := 0;
			IF mode = Encode THEN  curByte := 0;  curBit := 0  ELSE  curBit := -1  END;
			FOR i := 0 TO root DO
				table[i].up := 0;  table[i].down := 0;  table[i].pattern := 0;  table[i].weight := 0
			END;
			FOR i := 0 TO AlphabetSize - 1 DO  map[i]  := 0  END;
			esc := root;
		END Initialize;		
		
		
		PROCEDURE Finish;	(* flush last few bits *)
		BEGIN
			ASSERT( mode = Encode );
			WHILE curBit # 0 DO  PutBit( 0 )  END;
			out.Update
		END Finish;
		
		
		
		PROCEDURE GetBit( ): LONGINT;
		VAR
			bit: LONGINT;  ch: CHAR;
		BEGIN
			IF curBit < 0 THEN
				in.Char( ch );  curByte := ORD( ch );  curBit := 7
			END;
			bit := ASH( curByte, -curBit ) MOD 2;
			DEC( curBit );
			RETURN bit
		END GetBit;
		
		PROCEDURE PutBit( bit: LONGINT );
		BEGIN
			curByte := 2*curByte + bit;
			INC( curBit );
			IF curBit > 7 THEN
				out.Char( CHR( curByte ) );  curByte := 0;  curBit := 0
			END
		END PutBit;
		
		
		PROCEDURE GetPattern(  ): Symbol;
		VAR  sym, i, bit: LONGINT;
		BEGIN
			sym := 0;  bit := 1;
			FOR i := 1 TO 8 DO
				IF GetBit() = 1 THEN  sym := sym + bit  END;
				bit := bit * 2;
			END;
			RETURN sym
		END GetPattern;
		
		
		(*  send the bits for an escaped symbol	*)
		PROCEDURE PutPattern( sym: Symbol );
		VAR i: LONGINT;
		BEGIN
			FOR i := 1 TO 8 DO
				PutBit( sym MOD 2 );  sym := sym DIV 2;
			END
		END PutPattern;

		
		(*	split escape node to incorporate new symbol	*)
		PROCEDURE AddSymbol( sym: Symbol ): Index;
		VAR  pair, node: Index;
		BEGIN
			ASSERT( esc > 1 );
			pair := esc;  node := esc - 1;  esc := esc - 2 ;
			
			table[pair].down := node;  table[pair].weight := 1;  
			
			table[node].up := pair;
			table[node].down := 0;  table[node].weight := 0;  table[node].pattern := sym; 
			
			table[esc].up := pair;
			table[esc].down := 0;  table[esc].weight := 0;  
			
			map[sym] := node;
			
			RETURN node;
		END AddSymbol;		
		

		(*  swap leaf to group leader position return symbol's new node	*)
		PROCEDURE GroupLeader( node: Index ): Index;
		VAR
			leader: Index;
			weight: LONGINT;
			sym, prev:  Symbol;
		BEGIN
			weight := table[node].weight;  leader := node;
			WHILE (leader < root) & (weight = table[leader + 1].weight) DO  INC( leader )  END;
			IF leader # node THEN  
				(*	swap the leaf nodes	*)
				sym := table[node].pattern;
				prev := table[leader].pattern;
				table[leader].pattern := sym;
				table[node].pattern := prev;
				map[sym] := leader;
				map[prev] := node;
			END;
			RETURN leader
		END GroupLeader;		
				

		(*	slide internal node up over all leaves of equal weight; 
			or exchange leaf with next smaller weight internal node.
			return node's new position	*)
		PROCEDURE SlideNode( node: Index ): Index;
		VAR  next: Index;  swap: Node;
		BEGIN
			swap := table[node];  next := node + 1;
			(* if we're sliding an internal node, find the highest possible leaf to exchange with	*)
			IF ODD( swap.weight ) THEN
				WHILE swap.weight > table[next+1].weight DO  INC( next )  END
			END;
			(*	swap the two nodes	*)
			table[node] := table[next];  table[next] := swap;
			table[next].up := table[node].up;  table[node].up := swap.up;

			(*	repair the symbol map and tree structure	*)
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


		(*	increment symbol weight and re balance the tree.	*)
		PROCEDURE IncWeight( node: Index );
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
				internal nodes work upwards from their initial positions; while symbol nodes slide over first,
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
		END IncWeight;
		
			
		(*  scale all weights and rebalance the tree,
		    zero weight nodes are removed from the tree by sliding them out the rank list	*)
		PROCEDURE Scale;
		VAR  node, prev: Index;  weight: LONGINT;
		
			PROCEDURE Weight( idx: Index ): LONGINT;
			VAR w: LONGINT;
			BEGIN
				w := table[idx].weight;
				IF ODD( w ) THEN  RETURN w - 1  ELSE  RETURN w  END
			END Weight;
			
		BEGIN
			node := esc + 1;
			(*	work up the tree from the escape node scaling weights by the value of bits	*)
			WHILE node <= root DO
				(*	recompute the weight of internal nodes; slide down and out any unused ones	*)
				weight := table[node].weight;
				IF ODD( weight ) THEN
					weight := Weight( table[node].down ) + Weight( table[node].down-1 ) + 1
				ELSE
					(*	remove zero weight leaves by incrementing esc and removing them from the symbol map 	*)
					weight := weight DIV 2;
					IF ODD( weight ) THEN  DEC( weight )  END;
					IF weight = 0 THEN
						map[table[node].pattern] := 0;  INC( esc, 2 );
					END
				END;
				(*	slide the scaled node back down over any previous nodes with larger weights	*)
				table[node].weight := weight;
				prev := node - 1;
				WHILE weight < table[prev].weight DO  IGNORE SlideNode( prev );  DEC( prev )  END;
				INC( node )
			END;
			(*	prepare a new escape node	*)
			table[esc].down := 0;  table[esc].weight := 0;
		END Scale;
		
	
		(*	encode the next symbol	*)
		PROCEDURE EncodeByte( ch: CHAR );
		VAR
			code, n: LONGINT;  
			up, idx, node: Index;  sym: Symbol;
		BEGIN
			ASSERT( mode = Encode );
			(*	for a new symbol, direct the receiver to the escape node	*)
			sym := ORD( ch );
			node := map[sym];  idx := node; 
			IF idx = 0 THEN  idx := esc  END;
			ASSERT( idx # 0 );
			(*	accumulate the code bits by working up the tree from the node to the root	*)
			code := 1;  n := 0;  up := table[idx].up;
			WHILE up # 0 DO
				code := code * 2;  INC( n );
				IF ODD( idx ) THEN  INC( code )  END;
				idx := up;  up := table[idx].up	
			END;
			(*	send the code, root selector bit first	*)
			WHILE n > 0 DO
				PutBit( code MOD 2 );  code := code DIV 2;
				DEC( n )
			END;
			(*	send pattern and incorporate it into the tree	*)
			IF node = 0 THEN
				PutPattern( sym );
				node := AddSymbol( sym );
			END;
			(*	adjust and re-balance the tree	*)
			IncWeight( node );
		END EncodeByte;


		(*	decode the next symbol	*)
		PROCEDURE DecodeByte( ): CHAR;
		VAR
			node, down: Index; 
			sym: Symbol;
		BEGIN
			ASSERT( mode = Decode );
			(*	work down the tree from the root until reaching either a leaf or the escape node.  
			A one bit means go left, a zero means go right.	*)
			node := root;  down := table[node].down;
			WHILE down # 0 DO
				IF GetBit( ) = 1 THEN  
					node := down-1
				ELSE
					node := down;
				END;
				down := table[node].down;
			END;
			(*	sent to the escape node	*)
			IF node = esc THEN
				sym := GetPattern( );  
				node := AddSymbol( sym );
			ELSE
				sym := table[node].pattern
			END;
			(*	adjust and re-balance the tree	*)
			IncWeight( node );
			RETURN CHR( sym );
		END DecodeByte;
		
	END HuffmanCoder;



TYPE
	Encoder* =OBJECT
		VAR
			huff: HuffmanCoder;
			out: Streams.Writer;
			
			PROCEDURE & New*( archive: Streams.Writer );
			BEGIN
				NEW( huff, Encode, NIL, archive );
				out := archive
			END New;
			
			PROCEDURE CompressBlock*( CONST source: ARRAY OF CHAR; len: LONGINT );
			VAR  i: LONGINT;
			BEGIN
				out.RawNum( len );
				huff.Initialize;	
				i := 0;
				WHILE i < len DO
					huff.EncodeByte( source[i] );  INC( i );
					IF (i MOD ScaleSize = 0) & ((len-i) >= ScaleSize) THEN  huff.Scale  END
				END;
				huff.Finish
			END CompressBlock;

	END Encoder;
	
	
	
TYPE
	Decoder* =OBJECT
		VAR
			huff: HuffmanCoder;
			input: Streams.Reader;
			
			PROCEDURE & New*( archive: Streams.Reader );
			BEGIN
				NEW( huff, Decode, archive, NIL );
				input := archive
			END New;
			
			PROCEDURE ExtractBlock*( VAR buf: ARRAY OF CHAR ): LONGINT;
			VAR  i, blockSize: LONGINT; 
			BEGIN
				input.RawNum( blockSize );
				IF blockSize = 0 THEN (* end of stream *) RETURN 0  END;
				huff.Initialize;  
				i := 0;
				WHILE i < blockSize DO
					buf[i] := huff.DecodeByte( );  INC( i );
					IF (i MOD ScaleSize = 0) & ((blockSize-i) >= ScaleSize) THEN  huff.Scale  END
				END;
				RETURN blockSize
			END ExtractBlock;

	END Decoder;
	
	
END AdaptiveHuffman.


