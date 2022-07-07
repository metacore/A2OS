module SmallPT; (** AUTHOR ""; PURPOSE ""; *)

import
	MathL, Strings, Files, Commands, Streams, Codecs;

const
	eps = 1.E-4; (* Epsilon for comparisons *)
	samps = 64; (* Number of samples. The bigger, the better, but slower *)

type
	(**
		Base type that may represent
		a point (x,y,z), a vector (x,y,z),
		a color (r,g,b)
		or any set of 4 values
		for that vector operations should
		be applied.
		From this point of view 4th member
		involved in all operations also.
	*)
	Vec = array [4] of float64;

	Buf = array [*] of Vec;

	Ray = record
		o, d: Vec;
	end;

	(** Reflection type (DIFFuse, SPECular, REFRactive) *)
	Refl = enum
		DIFF, SPEC, REFR
	end;

	Sphere = object
	var
		r2: float64; (* radius^2 *)
		p, e, c: Vec; (* position, emission, color *)
		refl: Refl; (* reflection type (DIFFuse, SPECular, REFRactive) *)

	procedure &New(rad: float64; const p, e, c: Vec; refl: Refl);
	begin
		r2 := rad * rad; self.p := p; self.e := e; self.c := c; self.refl := refl
	end New;

	(** Returns distance, 0 if no hit *)
	procedure intersect(const r: Ray): float64;
	begin
		(* Solve t^2*d.d + 2*t*(o-p).d + (o-p).(o-p)-R^2 = 0 *)
		var op := p - r.o : Vec;
		var b := op +* r.d, det := b * b - (op +* op) + r2 : float64;
		if det < 0 then
			return 0
		end;
		det := MathL.sqrt(det);
		var t := b - det : float64;
		if t > eps then
			return t
		else
			t := b + det;
			if t > eps then
				return t
			else
				return 0
			end
		end
	end intersect;

	end Sphere;

	ERandArray = array [4] of unsigned16;

	Chars = array of char;

	operator "+"(const a1, a2: Chars): Strings.String;
	begin
		return Strings.ConcatToNew(a1, a2)
	end "+";

	procedure do_rand48(var seed: ERandArray);
	const
		_shift = signed8(sizeof(unsigned16) * 8);
		_mult = [unsigned16(0E66DH), unsigned16(0DEECH), unsigned16(05H)];
		_add = unsigned16(0BH);
	var
		accu: unsigned32;
		temp: array 2 of unsigned16;
	begin
		accu := unsigned32(_mult[0]) * unsigned32(seed[0]) + unsigned32(_add);
		temp[0] := unsigned16(accu);
		accu := shr(accu, _shift);
		accu := accu + (unsigned32(_mult[0]) * unsigned32(seed[1]) +
			unsigned32(_mult[1]) * unsigned32(seed[0]));
		temp[1] := unsigned16(accu);
		accu := shr(accu, _shift);
		accu := accu + (unsigned32(_mult[0]) * unsigned32(seed[2]) +
			unsigned32(_mult[1]) * unsigned32(seed[1]) +
			unsigned32(_mult[2]) * unsigned32(seed[0]));
		seed[0] := temp[0];
		seed[1] := temp[1];
		seed[2] := unsigned16(accu)
	end do_rand48;

var
	intpower_16 := intpower(2.0, -16) : float64;
	intpower_32 := intpower(2.0, -32) : float64;
	intpower_48 := intpower(2.0, -48) : float64;

	vNull := [0, 0, 0, 0] : Vec;
	vIdentity := [1, 1, 1, 1] : Vec;

	gamma_table : array 256 of unsigned8;

	spheres: array [*] of Sphere;

	procedure intpower(base : float64; exponent : signed8) : float64;
	var
		i: signed32;
		res: float64;
	begin
		if (base = 0.0) & (exponent = 0) then
			return 1
		else
			i := abs(exponent);
			res := 1.0;
			while i > 0 do
				while ~odd(i) do
					i := shr(i, 1);
					base := base * base
				end;
				dec(i);
				res := res * base
			end;
			if exponent < 0 then
				res := 1.0 / res
			end
		end;
		return res
	end intpower;

	procedure erand48(var seed: ERandArray): float64;
	begin
		do_rand48(seed);
		return seed[0] * intpower_48 + seed[1] * intpower_32 + seed[2] * intpower_16
	end erand48;

	procedure clamp(x: float64): float64;
	begin
		if x < 0 then
			return 0
		elsif x > 1 then
			return 1
		else
			return x
		end
	end clamp;

	procedure power(Number, Exponent: float64): float64;
	begin
		if (Number = 0) or (Exponent = 0) then
			return 0
		else
			return MathL.exp(Exponent * MathL.ln(Number))
		end
	end power;

	procedure toInt(Value: float64): unsigned8;

	begin
		return gamma_table[entier(clamp(Value) * 255.0)]
	end toInt;

	procedure init_gamma_table;
	const
		c = 1 / 255;
		gamma2_2 = 1.0 / 2.2;
	var
		i : size;
	begin
		for i := 0 to 255 do
			gamma_table[unsigned8(i)] := unsigned8(entier(power(clamp(i * c), gamma2_2) * 255.0))
		end
	end init_gamma_table;

	procedure init_spheres();

	begin

		spheres := [
			new Sphere(1.E5, [1.E5 + 1, 40.8, 81.6, 0], vNull, [0.75, 0.25, 0.25, 0], Refl.DIFF), (* Left *)
			new Sphere(1.E5, [-1.E5 + 99, 40.8, 81.6, 0], vNull, [0.25, 0.25, 0.75, 0], Refl.DIFF), (* Right *)
			new Sphere(1.E5, [50, 40.8, 1.E5, 0], vNull, [0.75, 0.75, 0.75, 0], Refl.DIFF), (* Back *)
			new Sphere(1.E5, [50, 40.8, -1.E5 + 170, 0], vNull, vNull, Refl.DIFF), (* Front *)
			new Sphere(1.E5, [50, 1.E5, 81.6, 0], vNull, [0.75, 0.75, 0.75, 0], Refl.DIFF), (* Bottom *)
			new Sphere(1.E5, [50, -1.E5 + 81.6, 81.6, 0], vNull, [0.75, 0.75, 0.75, 0], Refl.DIFF), (* Top *)
			new Sphere(16.5, [27, 16.5, 47, 0], vNull, [0.999, 0.999, 0.999, 0], Refl.SPEC), (* Mirror *)
			new Sphere(16.5, [73, 16.5, 78, 0], vNull, [0.999, 0.999, 0.999, 0], Refl.REFR), (* Glass *)
			new Sphere(600, [50, 681.6 - 0.27, 81.6, 0], [12, 12, 12, 0], vNull, Refl.DIFF) (* Light *)
		]
	end init_spheres;

	procedure intersect(const r: Ray; var t: float64; var id: size): boolean;
	const
		infinity = 1.E20;
	var
		i: size;
	begin
		t := infinity;
		for i := 0 to len(spheres, 0) - 1 do
			var d := spheres[i].intersect(r) : float64;
			if (d > 0) & (d < t) then
				t := d;
				id := i
			end
		end;
		return t < infinity
	end intersect;

	procedure ray(const o, d: Vec): Ray;
	begin
		result.o := o;
		result.d := d;
		return result
	end ray;

	procedure radiance(const r: Ray; depth: integer; var seed: ERandArray): Vec;
	var
		l_r := r : Ray;
		t := 0 : float64; (* distance to intersection *)
		id := 0 : size; (* id of intersected object *)
		skipRest: boolean;
	begin

		result := vNull;

		var cl := vNull, cf := vIdentity : Vec;

		loop

			if ~intersect(l_r, t, id) then
				result := cl;
				exit
			end;

			skipRest := false;

			var obj := spheres[id] : Sphere;
			var x := l_r.d * t + l_r.o, n := norm(x - obj.p), nl := n, f := obj.c : Vec;
			var dot_n_dir := n +* l_r.d, p := max(f[0], max(f[1], f[2])) : float64;

			cl := cl + cf * obj.e;

			if dot_n_dir >= 0 then
				nl := nl * -1
			end;

			inc(depth);
			if (depth > 5) or ~(p > 0) then
				if erand48(seed) < p then
					f := f * (1 / p)
				else
					result := cl;
					exit
				end
			end;

			cf := cf * f;

			if obj.refl = Refl.DIFF then
				var r1 := MathL.pi * 2 * erand48(seed), r2 := erand48(seed), r2s := MathL.sqrt(r2), m1 : float64;
				var u, v, w := nl : Vec;
				if abs(w[0]) > 0.1 then
					m1 := 1 / MathL.sqrt(w[2] * w[2] + w[0] * w[0]);
					u := [w[2] * m1, 0, -w[0] * m1, 0];
					v := [w[1] * u[2], w[2] * u[0] - w[0] * u[2], -w[1] * u[0], 0]
				else
					m1 := 1 / MathL.sqrt(w[2] * w[2] + w[1] * w[1]);
					u := [0, -w[2] * m1, w[1] * m1, 0];
					v := [w[1] * u[2] - w[2] * u[1], -w[0] * u[2], w[0] * u[1], 0]
				end;
				var ss := MathL.sin(r1), cc := MathL.cos(r1) : float64;
				l_r := ray(x, u * cc * r2s + v * ss * r2s + w * MathL.sqrt(1 - r2));
				skipRest := true
			elsif obj.refl = Refl.SPEC then
				l_r := ray(x, l_r.d - (n + n) * dot_n_dir);
				skipRest := true
			end;

			if ~skipRest then
				var newRay := ray(x, l_r.d - (n + n) * dot_n_dir) : Ray;

				var into := n +* nl > 0, tdirr : boolean;

				var nc := 1, nt := 1.5, nnt, ddn := l_r.d +* nl : float64;

				if into then
					nnt := nc / nt
				else
					nnt := nt / nc
				end;

				var cos2t := 1 - nnt * nnt * (1 - ddn * ddn) : float64;
				if cos2t < 0 then
					l_r := newRay;
					skipRest := true
				end;

				if ~skipRest then
					tdirr := false;
					var a := nt - nc, b := nt + nc, r0 := a * a / (b * b), c, Re, tp : float64;
					var tdir, foo : Vec;
					if into then
						c := 1 + ddn
					else
						foo := n * (ddn * nnt + MathL.sqrt(cos2t));
						if ~into then
							foo := foo * -1
						end;
						tdir := l_r.d * nnt - foo;
						c := 1 - tdir +* n;
						tdirr := true
					end;
					Re := r0 + (1 - r0) * c * c * c * c * c;
					p := 0.25 + 0.5 * Re;
					if erand48(seed) < p then
						cf := cf * (Re / p);
						l_r := newRay
					else
						tp := (1 - Re) / (1 - p);
						if ~tdirr then
							foo := n * (ddn * nnt + MathL.sqrt(cos2t));
							if ~into then
								foo := foo * -1
							end;
							tdir := l_r.d * nnt - foo
						end;
						cf := cf * tp;
						l_r := ray(x, tdir)
					end
				end
			end
		end;
		return result
	end radiance;

	operator "+" (const a, b : Vec) : Vec;
	var
		v : Vec;
	begin
		v[0] := a[0] + b[0];
		v[1] := a[1] + b[1];
		v[2] := a[2] + b[2];
		(*v[3] := a[3] + b[3];*)
		return v
	end "+";

	operator "+*" (const a, b : Vec) : float64;
	begin
		return a[0] * b[0] + a[1] * b[1] + a[2] * b[2] (*+ a[3] * b[3]*)
	end "+*";

	operator "-" (const a, b : Vec) : Vec;
	var
		v : Vec;
	begin
		v[0] := a[0] - b[0];
		v[1] := a[1] - b[1];
		v[2] := a[2] - b[2];
		(*v[3] := a[3] - b[3];*)
		return v
	end "-";

	operator "*" (const a, b : Vec) : Vec;
	var
		v : Vec;
	begin
		v[0] := a[0] * b[0];
		v[1] := a[1] * b[1];
		v[2] := a[2] * b[2];
		(*v[3] := a[3] * b[3];*)
		return v
	end "*";

	operator "*" (const a : Vec; f : float64) : Vec;
	var
		v : Vec;
	begin
		v[0] := a[0] * f;
		v[1] := a[1] * f;
		v[2] := a[2] * f;
		(*v[3] := a[3] * f;*)
		return v
	end "*";

	operator "/" (const a : Vec; f : float64) : Vec;
	var
		v : Vec;
	begin
		v[0] := a[0] / f;
		v[1] := a[1] / f;
		v[2] := a[2] / f;
		(*v[3] := a[3] / f;*)
		return v
	end "/";

	procedure norm(const v: Vec): Vec;
	var
		fLen2: float64;
	begin
		fLen2 := v +* v;
		if fLen2 > 0 then
			return v / MathL.sqrt(fLen2)
		end;
		return vNull
	end norm;

	procedure cross(const v1, v2: Vec): Vec;
	var
		v: Vec;
	begin
		v[0] := v1[1] * v2[2] - v1[2] * v2[1];
		v[1] := v1[2] * v2[0] - v1[0] * v2[2];
		v[2] := v1[0] * v2[1] - v1[1] * v2[0];
		return v
	end cross;

	(*procedure printVec(const header: array of char; const x : array [*] of float64);
	var
		i: size;
	begin
		var context := Commands.GetContext();
		context.out.String(header);
		context.out.FloatFix(x[0], 0, 5, 0);
		for i := 1 to len(x, 0) - 1 do
			context.out.Char(20X);
			context.out.FloatFix(x[i], 0, 5, 0)
		end;
		context.out.Ln;
		context.out.Update
	end printVec;

	procedure printFloat(const header: array of char; x : float64);
	begin
		var context := Commands.GetContext();
		context.out.String(header);
		context.out.FloatFix(x, 0, 5, 0);
		context.out.Ln;
		context.out.Update
	end printFloat;*)

	procedure go*;
	var
		c: Buf;
	begin
		var context := Commands.GetContext();

		var w := 320, h := 240, x, y, sx, sy, s, i : unsigned32;
		
		(*var c := new Buf(w * h);*)
		new(c, w * h);

		var cam := ray([50, 52, 295.6, 0], norm([0, -0.042612, -1, 0])) : Ray;
		var cx := [float64(w * 0.5135 / h), 0, 0, 0], cy := norm(cross(cx, cam.d)) * 0.5135, cc : Vec;

		var d, r : Vec;
		var r1, r2, dx, dy : float64;
		var pos := 0: signed8;
		var seed : ERandArray;
		
		context.out.String('Rendering... '); context.out.Ln; context.out.Update;

		for y := 0 to h - 1 do (* Loop over image rows *)
		
			var fpos := 100 * y / (h - 1) : float32;
			var npos := signed8(entier(fpos + 0.5)) : signed8;
			if abs(pos - npos) >= 1 then
				pos := npos; context.out.Int(pos, 0);
				context.out.String('% '); context.out.Update
			end;

			seed := [0, 0, unsigned16(h - y), unsigned16(y)];
			for x := 0 to w - 1 do (* Loop cols *)
				i := (h - y - 1) * w + x;
				cc := vNull;
				for sy := 0 to 1 do (* 2x2 subpixel rows *)
					for sx := 0 to 1 do (* 2x2 subpixel cols *)
						r := vNull; (* Supersample one sub-pixel *)
						for s := 0 to samps - 1 do

							r1 := 2 * erand48(seed);
							if r1 < 1 then
								dx := MathL.sqrt(r1) - 1
							else
								dx := 1 - MathL.sqrt(2 - r1)
							end;
							r2 := 2 * erand48(seed);
							if r2 < 1 then
								dy := MathL.sqrt(r2) - 1
							else
								dy := 1 - MathL.sqrt(2 - r2)
							end;

							d := norm(
								cam.d + cx * (((sx + 0.5 + dx) * 0.5 + x) / w - 0.5) +
								cy * (((sy + 0.5 + dy) * 0.5 + y) / h - 0.5));

							r := r + radiance(ray(d * 140 + cam.o, d), 0, seed) * (1.0 / samps)

						end; (* Camera rays are pushed ^^^^^ forward to start in interior *)
						cc := cc + [clamp(r[0]), clamp(r[1]), clamp(r[2]), 0] * 0.25
					end
				end;
				c[i] := cc
			end
		end;
		
		context.out.Ln; context.out.Update;

		var cSamps : array 32 of char;
		Strings.IntToStr(samps, cSamps);
		var fileName : Files.FileName;
		copy(('SmallPT_' + cSamps + '.ppm')^, fileName);
		var writer := Codecs.OpenOutputStream(fileName) : Streams.Writer;
		if writer # nil then
			writer.String("P6"); writer.Char(0DX);
			writer.Int(w, 0); writer.Char(20X); writer.Int(h, 0); writer.Char(0DX);
			writer.Int(255, 0); writer.Char(0DX);
			for i := 0 to w * h - 1 do
				writer.Char(chr(toInt(c[i][0])));
				writer.Char(chr(toInt(c[i][1])));
				writer.Char(chr(toInt(c[i][2])))
			end;
			writer.Update
		end;
		context.out.String((fileName + ' done')^); context.out.Ln

	end go;

begin
	init_gamma_table();
	init_spheres()
end SmallPT.

SmallPT.go ~
FSTools.CloseFiles SmallPT_64.ppm ~
System.Free SmallPT ~



