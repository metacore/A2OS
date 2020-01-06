MODULE BWHCompressor;  (* GF *)

(* This is an A2 port of the (BlackBox) compressor 'Pac/Comp3.Mod' created by Gerard Meunier *)

(*
Mthode de compactage utilisant deux codages combins :
	- tri de bloc (Burrows-Wheeler 1994) ;
	- compression par codage de Huffman adaptatif.
La premire mthode est d'abord utilise, et sa sortie est ensuite code par la deuxime.
Le codage de Huffman est contrl par un test de Kolmogorov-Smirnov, qui assure la validit des statistiques utilises par l'algorithme.
Rfrences :
-	Burrows, M., & Wheeler, D.J., "A block-sorting lossless data compression algorithm", Technical Report 124, Digital SRC Research Report, 1994.
-	Larsson, N.J., "Extended application of suffix trees to data compression", in Data Compression Conference, pages190-199, April 1996.
-	Huffman, D. A., "A method for the construction of minimum-redundacy codes", Proceedings of the IRE, Volume 40, Numro 9, Septembre 1952, pages 1098-1101.
-	Knuth, D. E., "The art of computer programming", Addison-Wesley, Volume 2, pages 45-52.
*)

IMPORT  Streams, NextPrime, MoveToFront, BitStreams, Commands;

CONST
	VersionTag = 0F0E1H;

	Sentinel = MIN( SIGNED8 ) - 1;

	ByteSize = 8;
	ByteMax = ASH( 1, ByteSize ) - 1; (* 255 *)

	Nil = MAX( INTEGER );

	CodeBits = ByteSize + 1; (* 9 *)
	NbHuff = ByteMax + 2; (* 257 *)

	PosBits = 20;
	BufSize = ASH( 1, PosBits ) - 2; (* 0FFFFEH *)

	maxFreq = 1346269;
	maxCompte = 1024;
	Rac1 = 23; (* Rac1: smallest integer >= sqrt(maxCompte / 2) *)
	Rac2 = 32; (* Rac2: smallest integer >= sqrt(maxCompte) *)
	DMaxF1 = 2560;
	DMaxF = DMaxF1 * 1000;

TYPE
	MTF = MoveToFront.MTF;
	
	Buffer = POINTER TO ARRAY OF CHAR;
	TSI = POINTER TO ARRAY OF INTEGER;

	Huffman = OBJECT
		VAR
			nbN,
			compte1: INTEGER;
			fils: TSI;
			freq,
			p,
			f,
			compte2,
			freqN,
			filsN: TSI;
		
		PROCEDURE InitTree;
		VAR
			i: INTEGER;
		BEGIN 
			NEW( freq, 2*NbHuff + 1 );
			NEW( fils, 2*NbHuff + 1 );
			NEW( p, NbHuff );
			NEW( f, NbHuff + 2 );
			NEW( compte2, NbHuff );
			nbN := 1;
			freq[0] := 1;
			fils[0] := -(NbHuff + 1);
			FOR i := 0 TO NbHuff DO  f[i] := Nil  END;
			f[NbHuff + 1] := 0;
			compte1 := 0;
			FOR i := 0 TO NbHuff - 1 DO  compte2[i] := 0  END;
		END InitTree;
			
		
		PROCEDURE Ajoute( c: INTEGER );
		VAR
			i, j, q: INTEGER;
			m: INTEGER;
		BEGIN 
			q := nbN - 1;  
			i := nbN;  INC( nbN );
			j := nbN;  INC( nbN );
			freq[i] := freq[q];
			m := fils[q];  fils[i] := m;
			p[i DIV 2] := q;
			f[-m] := i;
			fils[q] := j DIV 2;
			freq[j] := 0;  fils[j] := -c;
			f[c] := j;
		END Ajoute;
		

		PROCEDURE MAJTree( c: INTEGER );
		VAR
			i, j, n, q, k, x, y: INTEGER;

			PROCEDURE OrdonneTree;
			VAR
				i, j, n, m: INTEGER;

				PROCEDURE ArrangeHeap( fin: INTEGER );
				VAR
					i, j, n, m: INTEGER;
				BEGIN 
					i := 0;
					n := freqN[0];  m := filsN[0];
					LOOP
						j := 2 * i + 1;
						IF j > fin THEN  EXIT  END;
						IF (j < fin) & (freqN[j + 1] < freqN[j]) THEN  INC( j )  END;
						IF n <= freqN[j] THEN  EXIT  END;
						freqN[i] := freqN[j];  filsN[i] := filsN[j];
						i := j;
					END;
					freqN[i] := n;  filsN[i] := m;
				END ArrangeHeap;
		
			BEGIN (*OrdonneTree*)
				n := (nbN + 1) DIV 2;  i := nbN;  j := 0;
				IF (freqN = NIL) OR (LEN( freqN ) < n) THEN
					NEW( freqN, n );
					NEW( filsN, n );
				END;
				REPEAT
					DEC( i );  m := fils[i];
					IF m <= 0 THEN
						freqN[j] := (freq[i] + 1) DIV 2;
						filsN[j] := m;
						INC( j );
					END;
				UNTIL j = n;
				i := nbN - 1;
				LOOP
					freq[i] := freqN[0];
					m := filsN[0];  fils[i] := m;
					IF m <= 0 THEN  f[-m] := i  ELSE  p[m - 1] := i  END;
					IF i = 0 THEN  EXIT  END;
					DEC( n );
					freqN[0] := freqN[n];  filsN[0] := filsN[n];
					ArrangeHeap( n - 1 );
					DEC( i );
					freq[i] := freqN[0];
					m := filsN[0];  fils[i] := m;
					IF m <= 0 THEN  f[-m] := i  ELSE  p[m - 1] := i  END;
					INC( freqN[0], freq[i + 1] );  filsN[0] := (i + 1) DIV 2;
					ArrangeHeap( n - 1 );
					DEC( i );
				END;
			END OrdonneTree;


			PROCEDURE Echange( i, j: INTEGER );
			VAR
				n, mi, mj: INTEGER;
			BEGIN 
				mi := fils[i];
				IF mi <= 0 THEN  f[-mi] := j  ELSE  p[mi - 1] := j  END;
				mj := fils[j];
				IF mj <= 0 THEN  f[-mj] := i  ELSE  p[mj - 1] := i  END;
				fils[i] := mj;  fils[j] := mi;
				n := freq[i];  freq[i] := freq[j];  freq[j] := n;
			END Echange;
			
			
			PROCEDURE Fq( j: INTEGER ): INTEGER;
			CONST
				ecart1 = 1000;  ecart2 = 120;  ecart3 = 110;
			VAR
				q, t, r, s: INTEGER;
			BEGIN
				t := j * maxCompte DIV (j + maxCompte) * 100;
				q := Rac1 * 10;  r := Rac2 * 10;
				REPEAT
					s := (q + r) DIV 2;
					IF s*s < t THEN  q := s + 1  ELSE  r := s  END;
				UNTIL q = r;
				q := 2*q - 1;
				q := DMaxF DIV (ecart1*q DIV 20 + ecart2 + ecart3*20 DIV q);	
				RETURN q
			END Fq;

		BEGIN (*MAJTree( c )*)
			i := f[c];
			REPEAT
				INC( freq[i] );
				j := i;  n := freq[i];
				WHILE freq[j - 1] < n DO  DEC( j )  END;
				IF j < i THEN
					Echange( i, j );  i := j;
				END;
				i := p[(i - 1) DIV 2];
			UNTIL i = 0;
			INC( freq[0] );
			INC( compte1 );
			IF compte1 = maxCompte THEN
				j := freq[0];
				IF j >= maxFreq - maxCompte THEN
					OrdonneTree;
				ELSE
					x := 0;  y := 0;
					IF f[NbHuff + 1] # Nil THEN  DEC( j )  END;
					k := j DIV 2;  q :=Fq( j );
					i := 0;
					LOOP
						n := f[i];
						IF n # Nil THEN
							n := freq[n];
							INC( x, n );
							DEC( n, compte2[i] );
							INC( y, n );
							IF ABS( (x*maxCompte + k) DIV j - y ) > q THEN
								OrdonneTree;
								EXIT;
							END;
						END;
						IF i = NbHuff - 1 THEN  EXIT  END;
						INC( i );
					END;
				END;
				compte1 := 0;
				FOR i := 0 TO NbHuff - 1 DO
					n := f[i];
					IF n = Nil THEN
						compte2[i] := 0
					ELSE
						compte2[i] := freq[n];
					END;
				END;
			END;
		END MAJTree;

		
	END Huffman;
	
	

	HuffmanOut = OBJECT (Huffman)
		VAR
			arch: BitStreams.BitWriter;
			
		PROCEDURE &Initialize( archive: Streams.Writer );
		BEGIN
			NEW( arch, archive );
			InitTree
		END Initialize;

		PROCEDURE OutHuf( val: INTEGER );
		VAR
			i, path, len: INTEGER;
		BEGIN 
			len := 0; path := 0;
			i := f[val];
			IF i = Nil THEN
				i := f[NbHuff + 1];
			END;
			WHILE i > 0 DO
				path := path + ASH( (i MOD 2), len );  INC( len );
				i := p[(i - 1) DIV 2];
			END;
			arch.OutBits( path, len );
			IF f[val] = Nil THEN
				arch.OutBits( val, CodeBits );
				IF nbN > 2*NbHuff THEN
					f[val] := f[NbHuff + 1];
					f[NbHuff + 1] := Nil;
					fils[f[val]] := -val;
					RETURN;
				END;
				Ajoute( val );
			END;
			MAJTree( val );	
		END OutHuf;

	END HuffmanOut;
	
	

	HuffmanIn = OBJECT (Huffman)
		VAR
			arch: BitStreams.BitReader;
			
			
		PROCEDURE &Initialize( archive: Streams.Reader );
		BEGIN
			NEW( arch, archive );
			InitTree
		END Initialize;

		PROCEDURE InHuf( ): INTEGER;
		VAR
			q: INTEGER;
		BEGIN 
			q := 0;
			LOOP
				q := fils[q];
				IF q <= 0 THEN  q := -q;  EXIT  END;
				q := 2*q - arch.InBit();
			END;
			IF q = NbHuff + 1 THEN
				q := arch.InBits( CodeBits );
				IF nbN > 2*NbHuff THEN
					f[q] := f[NbHuff + 1];
					f[NbHuff + 1] := Nil;
					fils[f[q]] := -q;
					RETURN q;
				END;
				Ajoute( q );	
			END;
			MAJTree(  q );
			RETURN q;
		END InHuf;

	END HuffmanIn;



	Compressor = OBJECT (HuffmanOut)
	VAR
		buf: Buffer;
		hash, key, depth, posit, suf: TSI;
		available, nbHash, nbNodes: INTEGER;
		hash2: SET32;
		
		PROCEDURE &Initialize( archive: Streams.Writer );
		BEGIN
			Initialize^( archive );
			NEW( buf, BufSize )
		END Initialize;
		
		PROCEDURE Key( pere, c: INTEGER ): INTEGER;
		BEGIN 
			RETURN pere*100H + SIGNED8(c) + 128
		END Key;

		PROCEDURE Pere( key: INTEGER ): INTEGER;
		BEGIN 
			RETURN ABS(key) DIV 100H;
		END Pere;

		PROCEDURE Car( key: INTEGER ): INTEGER;
		BEGIN 
			IF key < 0 THEN
				RETURN 0
			END;
			RETURN key MOD 100H + 1;
		END Car;
		
		
		PROCEDURE Search( skey: INTEGER; VAR pere, pos: INTEGER ): BOOLEAN;
		VAR
			n: INTEGER;

			PROCEDURE Hash( key: INTEGER ): INTEGER;
			BEGIN 
				RETURN key MOD nbHash;
			END Hash;

			PROCEDURE Hash2( key: INTEGER ): INTEGER;
			BEGIN 
				RETURN INTEGER( SET32(key) * hash2) + 1;
			END Hash2;

		BEGIN (*Search*)
			key[nbNodes] := skey;
			pere := Hash( skey );
			pos := hash[pere];
			IF key[pos] # skey THEN
				n := Hash2( skey );
				REPEAT
					DEC( pere, n );
					IF pere < 0 THEN
						INC( pere, nbHash );
					END;
					pos := hash[pere];
				UNTIL key[pos] = skey;
			END;
			RETURN pos < nbNodes;
		END Search;
		

		PROCEDURE SearchIns( root: INTEGER; c, pos: INTEGER ): BOOLEAN;
		VAR
			pere, p, skey: INTEGER;
		BEGIN 
			IF c = Sentinel THEN
				(*ASSERT(root > 0);*)
				key[pos] := -Key( root, 0 );
				RETURN FALSE;
			END;
			skey := Key( root, c );
			IF ~Search( skey, pere, p ) THEN
				hash[pere] := pos;
				key[pos] := skey;
				RETURN FALSE;
			END;
			RETURN TRUE;
		END SearchIns;
		
		PROCEDURE Replace( pere, p, q: INTEGER );
		BEGIN
			hash[pere] := q;
			key[q] := key[p];
		END Replace;

		PROCEDURE First( root: INTEGER ): INTEGER;
		BEGIN 
			(*ASSERT( root # Nil );*)
			RETURN depth[root]
		END First;

		PROCEDURE Next( pos: INTEGER ): INTEGER;
		BEGIN 
			(*ASSERT(pos # Nil);*)
			RETURN hash[pos];
		END Next;	
		
		PROCEDURE AInit( size: INTEGER );
		VAR
			i, j: INTEGER;
		BEGIN
			IF (key = NIL) OR (nbNodes # size) THEN
				nbHash := NextPrime.Calc( ENTIER(size * 1.3) );
				i := 1;
				REPEAT
					j := i;  i := 2*i;
				UNTIL i >= nbHash;
				hash2 := SET32( j - 1 );
				nbNodes := size;
			END;
			IF (key = NIL) OR (LEN(key) <= size) THEN
				NEW( hash, nbHash );
				NEW( key, size + 1 );
			END;
			FOR i := 0 TO nbHash - 1 DO
				hash[i] := size;
			END;
		END AInit;		
		
		
		PROCEDURE Sort( size: INTEGER; VAR root: INTEGER );
		VAR
			v, nil, r, ins, proj, front, d, p, q, u: INTEGER;
			b: BOOLEAN;
			c: INTEGER;

			PROCEDURE TrieNoeuds( VAR noeuds: ARRAY OF INTEGER );
			VAR
				cars: ARRAY ByteMax + 2 OF INTEGER;
				i, j, k, f, c: INTEGER;
			BEGIN 
				FOR i := 0 TO ByteMax + 1 DO
					cars[i] := -1;
				END;
				FOR i := available + 1 TO 2 * size - 1 DO
					c := Car( key[i] );
					hash[i] := cars[c];
					cars[c] := i;
				END;
				noeuds[root] := Nil;
				FOR i := available + 1 TO size - 1 DO
					noeuds[i] := Nil;
				END;
				FOR i := ByteMax + 1 TO 0 BY - 1 DO
					j := cars[i];
					WHILE j >= 0 DO
						k := hash[j];
						f := Pere( key[j] );
						hash[j] := noeuds[f];
						noeuds[f] := j;
						j := k;
					END;
				END;
			END TrieNoeuds;

		BEGIN (*Sort*)
			AInit( 2*size );
			IF (depth = NIL) OR (LEN(depth) < size) THEN
				NEW( depth, size );
				NEW( posit, size );
				NEW( suf, size );
			END;
			nil := 0;
			available := size - 1;
			root := 1;
			depth[root] := 0;
			posit[root] := 0;
			suf[root] := nil;
			depth[nil] := -1;
			front := 0;
			ins := root;
			proj := 0;
			WHILE front < size DO
				IF front = size - 1 THEN
					c := Sentinel;
				ELSE
					c := SIGNED8(ORD( buf[front] ))
				END;
				v := nil;
				LOOP
					 LOOP
						IF proj = 0 THEN
							r := nil;
							EXIT;
						END;
						IF ins = nil THEN
							r := root;
						ELSE
							b := Search( Key( ins, SIGNED8(ORD( buf[front - proj] )) ), q, r );  (*ASSERT( b );*)
						END;
						IF r >= size THEN  EXIT  END;
						d := depth[r] - depth[ins];
						IF proj < d THEN  EXIT  END;
						DEC( proj, d );
						ins := r;
					END;			
					IF r # nil THEN
						IF r >= size THEN
							p := r - size + depth[ins];
						ELSE
							p := posit[r];
						END;
						INC( p, proj );
						IF SIGNED8(ORD( buf[p] )) = c THEN  EXIT  END;
						u := available;  DEC( available );
						depth[u] := depth[ins] + proj;
						posit[u] := front - proj;
						(*ASSERT((r # root) & (ins # nil));*)
						Replace(q, r, u);
						b := SearchIns( u, SIGNED8(ORD( buf[p] )), r );  (*ASSERT( ~b );*)
						IF r < size THEN
							INC( posit[r], proj );
						END;
						b := SearchIns( u, c, front - depth[u] + size );  (*ASSERT( ~b );*)
					ELSIF (ins = nil) OR SearchIns( ins, c, front - depth[ins] + size ) THEN  
						EXIT;
					ELSE
						u := ins;
					END;
					suf[v] := u;  v := u;
					ins := suf[ins];
				END;
				suf[v] := ins;
				INC( proj );  INC( front );
			END;
			TrieNoeuds( depth^ );
		END Sort;			
			
	END Compressor;


	PROCEDURE Compress* ( input: Streams.Reader; output: Streams.Writer );
	VAR
		mtf: MTF;
		co: Compressor;
		beg, root: INTEGER;
		len: SIZE;

		PROCEDURE Export( n: INTEGER );
		BEGIN 
			REPEAT
				IF ODD( n ) THEN
					co.OutHuf( 0 );
				ELSE
					co.OutHuf( 1 );
				END;
				n := (n - 1) DIV 2;
			UNTIL n = 0;
		END Export;

		PROCEDURE WritePac( q: INTEGER; VAR m: INTEGER );
		VAR
			n: INTEGER;
		BEGIN 
			n := ORD( mtf.Encode( co.buf[q - 1]) );
			IF n = 0 THEN
				INC( m );
			ELSE
				IF m > 0 THEN
					Export( m );  m := 0;
				END;
				co.OutHuf( n + 1 );
			END;
		END WritePac;

		PROCEDURE Parcours( root, size: INTEGER ): INTEGER;
		VAR
			m, p, q, index, level, beg: INTEGER;
		BEGIN 
			index := 0; level := -1;
			p := co.First( root );
			WHILE p < size DO
				INC( level );  co.suf[level] := p;  p := co.First( p )
			END;
			m := 0;
			LOOP
				IF p >= size THEN
					q := p - size;
					IF q = 0 THEN
						beg := index;
					ELSE
						WritePac( q, m );
					END;
					INC( index );
				END;
				q := co.Next( p );
				IF q # Nil THEN
					p := q;
					WHILE p < size DO
						INC( level );  co.suf[level] := p;  p := co.First( p )
					END;
				ELSE
					REPEAT
						IF level < 0 THEN
							(*ASSERT(index = size);*)
							IF m > 0 THEN  Export( m )  END;
							RETURN beg
						END;
						p := co.suf[level];  DEC( level );
						p := co.Next( p );
					UNTIL p # Nil;
					WHILE p < size DO
						INC( level );  co.suf[level] := p;  p := co.First( p )
					END;
				END;
			END;
		END Parcours;

	BEGIN (*Compress*)
		NEW( co, output );
		NEW( mtf );  mtf.Initialize;
		
		co.arch.OutBits( VersionTag, 16 );
		REPEAT
			input.Bytes( co.buf^, 0, BufSize, len );
			IF len # 0 THEN
				co.arch.OutBit( 1 );
				co.Sort( INTEGER(len + 1), root );
				beg := Parcours( root, INTEGER(len + 1) );
				co.OutHuf( NbHuff );
				co.arch.OutBits( beg, PosBits )
			END;
		UNTIL len < BufSize;
		co.arch.OutBit( 0 );
		co.arch.Finish;
	END Compress;
	
	
	PROCEDURE Error( CONST msg: ARRAY OF CHAR );
	VAR 
		c: Commands.Context;
	BEGIN
		c := Commands.GetContext();
		c.out.Update;
		c.error.String( msg ); c.error.Ln; c.error.Update
	END Error;



	PROCEDURE Expand* ( input: Streams.Reader; output: Streams.Writer );
	VAR
		mtf: MTF; 
		huff: HuffmanIn;
		n, p, j: INTEGER;
		buf: Buffer;
		T: TSI;
		counts: ARRAY ByteMax + 1 OF INTEGER;
		ch: CHAR;

		PROCEDURE Counts( size: INTEGER );
		VAR
			i: SIZE;
			n, p: INTEGER;
		BEGIN 
			FOR i := 0 TO ByteMax DO  counts[i] := 0  END;
			FOR i := 0 TO size - 1 DO
				INC( counts[SIGNED8(ORD( buf[i] )) + 128] )
			END;
			n := 0;
			FOR i := 0 TO ByteMax DO
				p := counts[i];
				counts[i] := n;
				INC( n, p );
			END;
		END Counts;

		PROCEDURE CalcT( size: INTEGER );
		VAR
			i, j: INTEGER;
		BEGIN 
			NEW( T, size );
			FOR i := 0 TO size - 1 DO
				j := SIGNED8(ORD( buf[i] )) + 128;	
				T[counts[j]] := i;  INC( counts[j] );
			END;
		END CalcT;

		PROCEDURE ReorderOut( size: INTEGER );
		VAR
			i, q, n: INTEGER;
		BEGIN
			q := huff.arch.InBits( PosBits );
			i := T[q - 1];
			output.Char( buf[i] );
			FOR n := 1 TO size - 1 DO
				IF i < q THEN  DEC( i )  END;
				i := T[i];
				output.Char( buf[i] )
			END;
			output.Update
		END ReorderOut;

		PROCEDURE Import( VAR n: INTEGER ): INTEGER;
		VAR
			m, a, b: INTEGER;
		BEGIN 
			m := 0;  a := 1;
			WHILE n <= 1 DO
				b := 2*a;
				IF n = 0 THEN  INC( m, a )  ELSE  INC( m, b )  END;
				a := b;
				n := huff.InHuf();
			END;
			RETURN m;
		END Import;

	BEGIN (*Expand*)
		NEW( huff, input );  huff.InitTree;
		NEW( mtf );  mtf.Initialize;
		NEW( buf, BufSize );
		
		IF huff.arch.InBits( 16 ) # VersionTag THEN
			Error( "BWHCompressor.Expand: wrong input" );
			RETURN
		END;
		
		WHILE huff.arch.InBit() # 0 DO
			p := 0;
			LOOP
				n := huff.InHuf();
				j := Import( n );
				IF j > 0 THEN
					ch := mtf.Decode( 0X );
					REPEAT
						buf[p] := ch;  INC( p ); 
						DEC( j );
					UNTIL j = 0;
				END;
				IF n = NbHuff THEN  EXIT  END;
				buf[p] := mtf.Decode( CHR(n - 1) );  INC( p )
			END;
			Counts( p );  CalcT( p );
			ReorderOut( p );
		END;
	END Expand;


END BWHCompressor.


