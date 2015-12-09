module Huffman; (** AUTHOR GF; PURPOSE "files and streams compression"; *)

import Streams, Commands, Files, Strings, Kernel;

const 
	BlockSize = 8*1024;
	HTag = 00FF00F1H ;
	
type 
	HuffmanNode = object 
		var 
			frequency: longint;
			left, right: HuffmanNode;		(* both nil in case of leaf *)
			pattern: char;						
		
		procedure & Init( patt: char; freq: longint );
		begin
			pattern := patt;  frequency := freq;  left := nil;  right := nil
		end Init;
		
		procedure AddChildren( l, r: HuffmanNode );
		begin
			left := l;  right := r;  frequency := l.frequency + r.frequency
		end AddChildren;
			
	end HuffmanNode;
	
	
	Codebits = record
		bitsize: longint;
		val: longint
	end;
	
	CodeTable = array 256 of Codebits;
	
		
	HuffmanCode = object
		var 
			wsize, bitsize: longint;
			buffer: pointer to array BlockSize div 2 of longint;
			lastval, lastbits: longint;
		
		procedure &Init;
		begin  
			new( buffer );  Clear
		end Init;
		
		procedure Clear;
		begin
			wsize := 0;  lastval := 0;  lastbits := 0
		end Clear;
		
		
		procedure AppendBits( const bits: Codebits );
		var 
			bitsize, val, addval, addbits, shift: longint;
		begin
			bitsize := bits.bitsize;  val := bits.val;
			if lastbits + bitsize > 32 then
				addbits := 32 - lastbits;  shift := bitsize - addbits;
				addval := lsh( val, -shift );
				lastval := lsh( lastval, addbits ) + addval;
				dec( bitsize, addbits );  dec( val, lsh( addval, shift ) );
				buffer[wsize] := lastval;  inc( wsize );  lastval := 0;  lastbits := 0
			end;
			lastval := lsh( lastval, bitsize ) + val;  inc( lastbits, bitsize );
			if lastbits = 32 then
				buffer[wsize] := lastval;  inc( wsize );  lastval := 0;  lastbits := 0
			end
		end AppendBits;
		
		
		procedure WriteCode( w: Streams.Writer );
		var i: longint;
		begin
			bitsize := 32*wsize + lastbits;
			if lastbits > 0 then  
				buffer[wsize] := ash( lastval, 32 - lastbits );  inc( wsize ); 
			end;
			
			w.RawLInt( bitsize );
			for i := 0 to wsize - 1 do  w.RawLInt( buffer[i] )  end;
			w.Update
		end WriteCode;
		
		
		procedure ReadCode( r: Streams.Reader );
		var i, n: longint;
		begin
			Clear;
			r.RawLInt( bitsize );  n := (bitsize + 31) div 32;
			for i := 0 to n - 1 do  r.RawLInt( buffer[i] )  end
		end ReadCode;
		
		
		procedure Decode( tree: HuffmanNode;  w: Streams.Writer );
		var i, x: longint; n: HuffmanNode;
		begin
			i := 0;
			repeat
				n := tree; 
				repeat
					if i mod 32 = 0 then  x := buffer[i div 32]  end;
					if ash( x, i mod 32 ) < 0 then  n := n.left  else  n := n.right  end;
					inc( i )
				until n.left = nil;	(* leaf *)
				w.Char( n.pattern )
			until i >= bitsize;
			w.Update
		end Decode;
	
	end HuffmanCode;
		

	Pattern = record
		frequency: longint;
		pattern: char
	end;
	
	PatternFrequencies = pointer to array of Pattern;		(* ordered by frequency *)
	
	
	procedure Encode*( r: Streams.Reader;  w: Streams.Writer );
	var 
		buffer: HuffmanCode;  i, n, needed, ofs, got, chunksize, timeout: longint;
		codeTable: array 256 of Codebits;
		pf: PatternFrequencies;
		plaintext: array BlockSize of char;
		timer: Kernel.Timer;
	begin 
		new( buffer );  new( timer );
		w.RawLInt( HTag );
		loop
			if r is Files.Reader then
				r.Bytes( plaintext, 0, BlockSize, chunksize );
			else
				(* give reader some time (~3 sec) to accumulate data *)
				timeout := 100;  ofs := 0;  needed := BlockSize;
				repeat  n := r.Available( );
					if n > 0 then
						if n > needed then  n := needed  end;
						r.Bytes( plaintext, ofs, n, got );  inc( ofs, got );  dec( needed, got )
					end;
					if needed > 0 then 
						if timeout <= 1600 then  timer.Sleep( timeout );  timeout := 2*timeout
						else  needed := 0
						end;  
					end;
				until needed = 0;
				chunksize := ofs
			end;
			if chunksize < 1 then  exit  end;
			pf := CountPatterns( plaintext, chunksize );
			InitCodeTable( codeTable, NewHuffmanTree( pf ) );
			buffer.Clear; 
			for i := 0 to chunksize - 1 do  
				buffer.AppendBits( codeTable[ord( plaintext[i] )] );
			end;
			WriteFrequencies( pf, w );
			buffer.WriteCode( w );
			w.Update
		end
	end Encode;
	
		
	procedure Decode*( r: Streams.Reader;  w: Streams.Writer; var msg: array of char ): boolean;
	var 
		tree: HuffmanNode;
		buffer: HuffmanCode;
		tag: longint;
	begin 
		r.RawLInt( tag );
		if tag # HTag  then
			msg := "Huffman.Decode: bad input (compressed stream expected)"; 
			return false
		end;
		new( buffer );
		while r.Available( ) >= 11 do
			tree := NewHuffmanTree( ReadFrequencies( r ) );
			buffer.ReadCode( r );
			buffer.Decode( tree,  w )
		end;
		return true
	end Decode;
		
	
	procedure CountPatterns( const block: array of char; blksize: longint ): PatternFrequencies;
	var 
		i, n, start: longint;
		a: array 256 of Pattern;
		pf: PatternFrequencies;
		
			procedure Quicksort( low, high: longint );  
			var 
				i, j, m: longint;  tmp: Pattern;
			begin
				if low < high then
					i := low;  j := high;  m := (i + j) div 2;
					repeat
						while a[i].frequency < a[m].frequency do  inc( i )  end;
						while a[j].frequency > a[m].frequency do  dec( j )  end;
						if i <= j then
							if i = m then  m := j
							elsif j = m then  m := i
							end;
							tmp := a[i];  a[i] := a[j];  a[j] := tmp;
							inc( i );  dec( j )
						end;
					until i > j;
					Quicksort( low, j );  Quicksort( i, high )
				end
			end Quicksort;
	
	begin
		for i := 0 to 255 do  a[i].pattern := chr( i );  a[i].frequency := 0  end;
		for i := 0 to blksize - 1 do  inc( a[ord( block[i] )].frequency )  end;
		for i := 0 to 255 do  
			if a[i].frequency > 0 then (* scale => [1..101H] *)
				a[i].frequency := 100H * a[i].frequency div blksize + 1;
			end
		end;
		Quicksort( 0, 255 );	(* sort patterns by frequency *)
		i := 0;
		while a[i].frequency = 0 do  inc( i )  end; 	(* skip unused patterns *)
		n := 256 - i;  start := i;
		new( pf, n );
		for i := 0 to n - 1 do  pf[i] := a[start + i]  end;
		return pf
	end CountPatterns;
		
	
	procedure NewHuffmanTree( pf: PatternFrequencies ): HuffmanNode;
	var 
		i, start, top: longint;  n, n2: HuffmanNode;
		a: pointer to array of HuffmanNode;
		patt: char;
	begin
		new( a, len( pf^ ) );  top := len( pf^ ) - 1;
		for i := 0 to top do  new( a[i], pf[i].pattern, pf[i].frequency )  end;
		if top = 0 then  
			(* the whole, probably last small block contains only a single pattern *)
			patt := chr( (ord( a[0].pattern ) + 1) mod 256 );	(* some different pattern *)
			new( n, 0X, 0 );  new( n2, patt, 0 );  n.AddChildren( n2, a[0] );
		else
			start := 0;  
			while start < top do  
				new( n, 0X, 0 );  n.AddChildren( a[start], a[start+1] ); 
				i := start + 1;  
				while (i < top) & (a[i+1].frequency < n.frequency) do  a[i] := a[i+1];  inc( i )  end;
				a[i] := n;  
				inc( start );
			end
		end;
		return n
	end NewHuffmanTree;
	
	
	procedure InitCodeTable( var table: CodeTable; huffmanTree: HuffmanNode );
	var 
		start: Codebits;
	
		procedure Traverse( node: HuffmanNode;  bits: Codebits );
		begin
			if node.left = nil then  (* leaf *)
				table[ord( node.pattern )] := bits;
			else
				inc( bits.bitsize );  
				bits.val := 2*bits.val;  Traverse( node.right, bits );	(* ..xx0 *)
				bits.val := bits.val + 1;  Traverse( node.left, bits );	(* ..xx1 *)
			end;
		end Traverse;
	
	begin
		start.bitsize := 0;  start.val := 0;
		Traverse( huffmanTree, start );
	end InitCodeTable;
	
	
	procedure ReadFrequencies( r: Streams.Reader ): PatternFrequencies;
	var
		i, n: longint; 
		pf: PatternFrequencies;
	begin
		r.RawNum( n );  
		new( pf, n );
		for i := 0 to n - 1 do
			r.RawNum( pf[i].frequency );  r.Char( pf[i].pattern ); 
		end;
		return pf
	end ReadFrequencies;
	
	procedure WriteFrequencies( pf: PatternFrequencies; w: Streams.Writer );
	var i, n: longint;
	begin
		n := len( pf^ );
		w.RawNum( n );
		for i := 0 to n - 1 do 
			w.RawNum( pf[i].frequency );  w.Char( pf[i].pattern );
		end;
	end WriteFrequencies;
	
	
	procedure OpenNewFile( const name: array of char ): Files.File;
	var
		name2: array 128 of char;  res: longint;
	begin
		if Files.Old( name ) # nil then
			copy( name, name2);  Strings.Append( name2, ".Bak" );
			Files.Rename( name, name2, res )
		end;
		return Files.New( name )
	end OpenNewFile;
	
	
	procedure EncodeFile*( c: Commands.Context );
	var
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2: array 128 of char;
	begin
		if c.arg.GetString( name1 ) then
			if ~c.arg.GetString( name2 ) then
				name2 := name1;
				Strings.Append( name2, ".hc" )
			end;
			f1 := Files.Old( name1 );
			if f1 # nil then
				Files.OpenReader( r, f1, 0 ); 
				f2 := OpenNewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				Encode( r, w );
				w.Update;
				Files.Register( f2 )
			else
				c.error.String( "could not open file  " ); c.error.String( name1 ); c.error.Ln
			end
		else
			c.error.String( "usage: Huffman.EncodeFile filename [filename] ~ " ); c.error.Ln;
		end;
		c.error.Update
	end EncodeFile;
	
	
	procedure DecodeFile*( c: Commands.Context );
	var
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2, msg: array 128 of char;
	begin
		if c.arg.GetString( name1 ) then
			if ~c.arg.GetString( name2 ) then
				name2 := name1;
				if Strings.EndsWith( ".hc", name2 ) then  name2[Strings.Length( name2 ) - 3] := 0X
				else Strings.Append( name2, ".uncomp" )
				end;
			end;
			f1 := Files.Old( name1 );
			if f1 # nil then
				Files.OpenReader( r, f1, 0 );	 
				f2 := OpenNewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				if Decode( r, w, msg ) then
					w.Update;
					Files.Register( f2 )	
				else
					c.error.String( msg ); c.error.Ln
				end
			else
				c.error.String( "could not open file  " ); c.error.String( name1 ); c.error.Ln
			end
		else
			c.error.String( "usage: Huffman.DecodeFile filename [filename] ~ " ); c.error.Ln;
		end;
		c.error.Update
	end DecodeFile;
	


end Huffman.


	Huffman.EncodeFile   Huffman.mod ~
	Huffman.EncodeFile   Huffman.Obj ~
	Huffman.EncodeFile   uebung01.pdf ~
		
	Huffman.DecodeFile   Huffman.mod.hc  TTT.mod ~
	Huffman.DecodeFile   Huffman.Obj.hc  TTT.Obj ~
	Huffman.DecodeFile   uebung01.pdf.hc  TTT.pdf ~
	
	SystemTools.Free Huffman ~
