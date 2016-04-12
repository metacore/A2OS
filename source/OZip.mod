module OZip; (** AUTHOR GF; PURPOSE "files and streams compression tool"; *)

import Streams, Commands, Files, Strings, Kernel, Log := KernelLog;

const 
	BlockSize = 8*1024;
	ComprTag = longint(0FEFD1F2FH);
	Suffix = ".oz";
	
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
			buffer: pointer to array BlockSize div 3 of longint;
			lastval, lastbits: longint;
		
		procedure &Init;
		begin  
			new( buffer );  Clear
		end Init;
		
		procedure Clear;
		begin
			wsize := 0;  lastval := 0;  lastbits := 0
		end Clear;
		
		
		
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
				
		procedure EncodeBlock( const tab: CodeTable;  const buf: array of char;  length: longint );
		var i: longint;
		begin
			Clear;
			for i := 0 to length - 1 do AppendBits( tab[ord( buf[i] )] )  end
		end EncodeBlock;
		
		procedure DecodeBlock( tree: HuffmanNode;  var buf: array of char;  var length: longint );
		var i, x, pos: longint; n: HuffmanNode; 
		begin
			i := 0;  pos := 0;
			repeat
				n := tree; 
				repeat
					if i mod 32 = 0 then  x := buffer[i div 32]  end;
					if ash( x, i mod 32 ) < 0 then  n := n.left  else  n := n.right  end;
					inc( i )
				until n.left = nil;	(* leaf *)
				buf[pos] := n.pattern;  inc( pos )
			until i >= bitsize;
			length := pos
		end DecodeBlock;
	
	end HuffmanCode;
		

	Pattern = record
		frequency: longint;
		pattern: char
	end;
	
	PatternArray = array 256 of Pattern;
	PatternFrequencies = pointer to array of Pattern;		(* ordered by frequency *)
	
	MTFList = pointer to record
		next: MTFList;
		byte: char;
	end;
	
	
	procedure Compress*( r: Streams.Reader;  w: Streams.Writer );
	var 
		huff: HuffmanCode;  n, needed, ofs, got, chunksize, timeout: longint;
		codeTable: CodeTable;
		pf: PatternFrequencies;
		bwIndex: longint;
		buffer: pointer to array of char;
		timer: Kernel.Timer;
	begin 
		new( huff );  new( timer );  new( buffer, BlockSize );
		w.RawLInt( ComprTag );
		loop
			if r is Files.Reader then
				r.Bytes( buffer^, 0, BlockSize, chunksize );
			else
				(* give reader some time (~3 sec) to accumulate data *)
				timeout := 100;  ofs := 0;  needed := BlockSize;
				repeat  n := r.Available( );
					if n > 0 then
						if n > needed then  n := needed  end;
						r.Bytes( buffer^, ofs, n, got );  inc( ofs, got );  dec( needed, got )
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
			BWEncode( buffer^, chunksize, bwIndex );
			pf := CountPatterns( buffer^, chunksize );
			WriteFrequencies( pf, w );
			InitCodeTable( codeTable, BuildHuffmanTree( pf ) );
			huff.EncodeBlock( codeTable, buffer^, chunksize );
			huff.WriteCode( w );
			w.RawLInt( bwIndex );
			w.Update;
			if r is Files.Reader then  Log.Char( '.' )  end
		end
	end Compress;
	
	
		
	procedure Uncompress*( r: Streams.Reader;  w: Streams.Writer;  var msg: array of char ): boolean;
	var 
		tree: HuffmanNode;
		huff: HuffmanCode;
		buffer: pointer to array of char;
		tag, chunksize, i, bwIndex: longint;
	begin 
		r.RawLInt( tag );
		if tag # ComprTag  then
			msg := "OZip.Uncompress: bad input (compressed stream expected)"; 
			return false
		end;
		new( huff ); new( buffer, BlockSize );
		while r.Available( ) >= 15 (* min size of a compressed block *) do
			tree := BuildHuffmanTree( ReadFrequencies( r ) );
			huff.ReadCode( r );
			huff.DecodeBlock( tree,  buffer^, chunksize );
			r.RawLInt( bwIndex );
			BWDecode( buffer^, chunksize, bwIndex );
			for i := 0 to chunksize - 1 do  w.Char( buffer[i] )  end
		end;
		w.Update;
		return true
	end Uncompress;
		
	
	procedure BuildPatternFrequencies( var a: PatternArray ): PatternFrequencies;
	var 
		i, n, start: longint;
		pf: PatternFrequencies;
		
		procedure SortPF( low, high: longint );  
		var 
			i, j, m: longint;  tmp: Pattern;
		begin
			if low < high then
				i := low;  j := high;  m := (i + j) div 2;
				repeat
					while a[i].frequency < a[m].frequency do  inc( i )  end;
					while a[j].frequency > a[m].frequency do  dec( j )  end;
					if i <= j then
						if i = m then  m := j  elsif j = m then  m := i  end;
						tmp := a[i];  a[i] := a[j];  a[j] := tmp;
						inc( i );  dec( j )
					end;
				until i > j;
				SortPF( low, j );  SortPF( i, high )
			end
		end SortPF;
		
	begin
		SortPF( 0, 255 );	(* sort patterns by frequency *)
		i := 0;
		while a[i].frequency = 0 do  inc( i )  end; 	(* skip unused patterns *)
		n := 256 - i;  start := i;
		new( pf, n );
		for i := 0 to n - 1 do  pf[i] := a[start + i]  end;
		return pf
	end BuildPatternFrequencies;
	
	procedure CountPatterns( const block: array of char; blksize: longint ): PatternFrequencies;
	var 
		i: longint;  a: PatternArray;
	begin
		for i := 0 to 255 do  a[i].pattern := chr( i );  a[i].frequency := 0  end;
		for i := 0 to blksize - 1 do  inc( a[ord( block[i] )].frequency )  end;
		for i := 0 to 255 do  
			if a[i].frequency > 0 then (* scale => [1..101H] *)
				a[i].frequency := 100H * a[i].frequency div blksize + 1;
			end
		end;
		return BuildPatternFrequencies( a )
	end CountPatterns;
		
	
	procedure BuildHuffmanTree( pf: PatternFrequencies ): HuffmanNode;
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
	end BuildHuffmanTree;
	
	
	procedure InitCodeTable( var table: CodeTable; huffmanTree: HuffmanNode );
	var 
		start: Codebits; i: longint;
	
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
		for i := 0 to 255 do  table[i].bitsize := 0;  table[i].val := 0  end;
		start.bitsize := 0;  start.val := 0;
		Traverse( huffmanTree, start );
	end InitCodeTable;
	
	
	procedure ReadFrequencies( r: Streams.Reader ): PatternFrequencies;
	var i, n: longint; 
		pf: PatternFrequencies;
		a: PatternArray;
	begin
		r.RawNum( n );  
		if n > 0 then
			new( pf, n );
			for i := 0 to n - 1 do  r.RawNum( pf[i].frequency );  r.Char( pf[i].pattern )  end
		else
			for i := 0 to 255 do  a[i].pattern := chr( i );  r.RawNum( a[i].frequency )  end;
			pf := BuildPatternFrequencies( a )
		end;
		return pf
	end ReadFrequencies;
	
	procedure WriteFrequencies( pf: PatternFrequencies; w: Streams.Writer );
	var i, n: longint;
		a: array 256 of longint;
	begin
		n := len( pf^ );
		if n < 128 then
			w.RawNum( n );
			for i := 0 to n - 1 do  w.RawNum( pf[i].frequency );  w.Char( pf[i].pattern )  end
		else
			w.RawNum( 0 );
			for i := 0 to 255 do  a[i] := 0  end;
			for i := 0 to n -1 do  a[ord( pf[i].pattern )] := pf[i].frequency  end;
			for i := 0 to 255 do  w.RawNum( a[i] )  end
		end
	end WriteFrequencies;
	
	
	(* Borrows Wheeler Transformation, Encode*)
	procedure BWEncode( var buf: array of char; length: longint; var index: longint );
	type
		Rotation = record 
			shift: longint; 
			lastbyte: char  
		end;
	var 
		r: pointer to array of Rotation;
		i, j: longint;
	
		procedure Less( a, b: longint ): boolean;
		var i, x1, x2, i1, i2: longint;  c1, c2: char;
		begin
			i := 0; x1 := r[a].shift;  x2 := r[b].shift;
			repeat
				i1 := x1 + i;  if i1 >= length then  dec( i1, length )  end;
				i2 := x2 + i;  if i2 >= length then  dec( i2, length )  end;
				c1 := buf[i1];  c2 := buf[i2];
				if c1 < c2 then  return true  elsif c1 > c2 then  return false  end;
				inc( i )
			until i = length;
			return false
		end Less;
				
		procedure SortR( lo, hi: longint );
		var i, j, m: longint;  tmp: Rotation;
		begin
			if lo < hi then
				i := lo;  j := hi;  m := (lo + hi) div 2;
				repeat
					while Less( i, m ) do  inc( i )  end;  
					while Less( m, j ) do  dec( j )  end;
					if i <= j then
						if m = i then  m := j  elsif  m = j then  m := i  end;
						tmp := r[i];  r[i] := r[j];  r[j] := tmp;
						inc( i );  dec( j )
					end
				until i > j;
				SortR( lo, j );  SortR( i, hi )
			end
		end SortR;
		
	begin
		new( r, length );
		for i := 0 to length - 1 do
			r[i].shift := i; 
			if i = 0 then  j := length - 1  else  j := i - 1  end;
			r[i].lastbyte := buf[j]
		end;
		SortR( 0, length -1 );
		(* replace buffer by column L *)
		for i := 0 to length -1 do  buf[i] := r[i].lastbyte  end;
		(* find index of the original row *)
		index := 0;  while r[index].shift # 0 do  inc( index )  end;
		MTFEncode( buf, length )
	end BWEncode;
	
			
	(* Borrows Wheeler Transformation, Decode*)	
	procedure BWDecode( var buf: array of char; length, index: longint );
	var 
		l, f: pointer to array of char;; 
		lc, fc: pointer to array of longint;
		xn: array 256 of longint;  i, j, n: longint;
		ch: char;
		
		procedure SortF( lo, hi: longint );
		var i, j, m: longint;  tmp: char;
		begin
			if lo < hi then
				i := lo;  j := hi;  m := (lo + hi) div 2;
				repeat
					while f[i] < f[m] do  inc( i )  end;  
					while f[m] < f[j] do  dec( j )  end;
					if i <= j then
						if m = i then  m := j  elsif m = j then  m := i  end;
						tmp := f[i];  f[i] := f[j];  f[j] := tmp;
						inc( i );  dec( j )
					end
				until i > j;
				SortF( lo, j );  SortF( i, hi )
			end
		end SortF;
		
	begin
		MTFDecode( buf, length );
		new( l, length );  new( f, length ); new( lc, length );  new( fc, length );
		for i := 0 to 255 do  xn[i] := 0  end;
		for i := 0 to length - 1 do 
			l[i] := buf[i];  f[i] := l[i];
			j := ord( l[i] );  lc[i] := xn[j];  inc( xn[j] )
		end;
		SortF( 0, length - 1 );
		for i := 0 to 255 do  xn[i] := 0  end;
		for i := 0 to length - 1 do 
			j := ord( f[i] );  fc[i] := xn[j];  inc( xn[j] )
		end;
		for i := 0 to length - 1 do
			ch := f[index];  n := fc[index];  buf[i] := ch;  index := 0;
			while (l[index] # ch) or (lc[index] # n) do  inc( index )  end
		end;
	end BWDecode;
	
	
	(* Borrows Wheeler move to front *)	
	procedure MTFEncode( var buf: array of char;  length: longint );
	var alpha, l, m: MTFList;  i, k: longint;  ch: char;
	begin
		alpha := nil;
		for i := 0 to 255 do
			new( l );  l.next := alpha;  l.byte := chr( 255 - i );  alpha := l;
		end;
		for i := 0 to length - 1 do
			ch := buf[i];
			if alpha.byte = ch then  k := 0
			else
				l := alpha;  m := alpha.next;  k := 1;
				while m.byte # ch do  inc( k );  l := m;  m := m.next  end;
				l.next := m.next;  m.next := alpha;  alpha := m
			end;
			buf[i] := chr( k )
		end
	end MTFEncode;
			
	(* Borrows Wheeler move to front *)	
	procedure MTFDecode( var buf: array of char;  length: longint );
	var alpha, l, m: MTFList;  i, c: longint;  ch: char; 
	begin
		alpha := nil;
		for i := 0 to 255 do
			new( l );  l.next := alpha;  l.byte := chr( 255 - i );  alpha := l;
		end;
		for i := 0 to length - 1 do
			ch := buf[i];
			if ch # 0X then 
				c := ord( ch );  l := alpha;
				while c > 1 do  l := l.next;  dec( c )  end;
				m := l.next;  l.next := m.next;  m.next := alpha;  
				alpha := m
			end;
			buf[i] := alpha.byte;
		end
	end MTFDecode;
	
	
	procedure NewFile( const name: array of char ): Files.File;
	var
		name2: array 128 of char;  res: longint;
	begin
		if Files.Old( name ) # nil then
			copy( name, name2);  Strings.Append( name2, ".Bak" );
			Files.Rename( name, name2, res );
			Log.String( "Backup created in " ); Log.String( name2 );  Log.Ln
		end;
		return Files.New( name )
	end NewFile;
	
	
	procedure CompressFile*( c: Commands.Context );
	var
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2: array 128 of char;
	begin
		if c.arg.GetString( name1 ) then
			if ~c.arg.GetString( name2 ) then
				name2 := name1;  Strings.Append( name2, Suffix )
			end;
			f1 := Files.Old( name1 );
			if f1 # nil then
				Files.OpenReader( r, f1, 0 ); 
				f2 := NewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				Compress( r, w );  w.Update;  Files.Register( f2 );
				Log.Ln;
				Log.String( "Compression finished, outfile = " );  Log.String( name2 );  Log.Ln; 
			else
				c.error.String( "could not open file  " );  c.error.String( name1 );  c.error.Ln
			end
		else
			c.error.String( "usage: OZip.CompressFile infile [outfile] ~ " );  c.error.Ln;
		end;
		c.error.Update
	end CompressFile;
	
	
	procedure UncompressFile*( c: Commands.Context );
	var
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2, msg: array 128 of char;
	begin
		if c.arg.GetString( name1 ) then
			if ~c.arg.GetString( name2 ) then
				name2 := name1;
				if Strings.EndsWith( Suffix, name2 ) then  name2[Strings.Length( name2 ) - 3] := 0X
				else  Strings.Append( name2, ".uncomp" )
				end
			end;
			f1 := Files.Old( name1 );
			if f1 # nil then
				Files.OpenReader( r, f1, 0 );	 
				f2 := NewFile( name2 );  Files.OpenWriter( w, f2, 0 );
				if Uncompress( r, w, msg ) then
					w.Update;  Files.Register( f2 )	
				else
					c.error.String( msg );  c.error.Ln
				end
			else
				c.error.String( "could not open file  " );  c.error.String( name1 );  c.error.Ln
			end
		else
			c.error.String( "usage: OZip.UncompressFile infile [outfile] ~ " );  c.error.Ln;
		end;
		c.error.Update
	end UncompressFile;
	
end OZip.


	OZip.CompressFile   OZip.mod ~
	OZip.CompressFile   OZip.Obj ~
	OZip.CompressFile   summary.pdf ~
		
	OZip.UncompressFile   OZip.mod.oz  TTT.mod ~
	OZip.UncompressFile   OZip.Obj.oz  TTT.Obj ~
	OZip.UncompressFile   summary.pdf.oz  TTT.pdf ~
	
	SystemTools.Free OZip  ~
	

