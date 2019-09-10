MODULE SVGMatrix;

IMPORT Math;

CONST
	Eps = 1.0E-5;

TYPE
	Number*=FLOAT64;

	Point*=RECORD
		x*, y* : Number;
	END;

	Matrix*=OBJECT
		VAR a*, b*, c*, d*, e*, f*: Number;

		(*
		[a c e]
		[b d f]
		[0 0 1]
		*)

		PROCEDURE SetIdentity*;
		BEGIN
			a := 1.0; c := 0.0; e := 0.0;
			b := 0.0; d := 1.0; f := 0.0;
		END SetIdentity;

		PROCEDURE Set*(newa, newb, newc, newd, newe, newf: Number);
		BEGIN
			a := newa; c := newc; e := newe;
			b := newb; d := newd; f := newf;
		END Set;


		PROCEDURE TransformBy*(othera, otherb, otherc, otherd, othere, otherf: Number):Matrix;
		VAR other: Matrix;
		BEGIN
			NEW(other);
			other.Set(othera, otherb, otherc, otherd, othere, otherf);
			RETURN Multiply(other)
		END TransformBy;

		PROCEDURE Translate*(x, y: Number):Matrix;
		VAR other: Matrix;
		BEGIN
			NEW(other);
			other.Set(1.0, 0.0, 0.0, 1.0, x, y);
			RETURN Multiply(other)
		END Translate;

		PROCEDURE Scale*(x, y: Number):Matrix;
		VAR other: Matrix;
		BEGIN
			NEW(other);
			other.Set(x, 0.0, 0.0, y, 0.0, 0.0);
			RETURN Multiply(other)
		END Scale;

		PROCEDURE Rotate*(angle, x, y: Number):Matrix;
		VAR other: Matrix;
			s, c: Number;
		BEGIN
			s := Math.sin(SHORT(angle)/180.0*Math.pi);
			c := Math.cos(SHORT(angle)/180.0*Math.pi);
			NEW(other);
			other.Set(c, s, -s, c, -c*x+s*y+x, -s*x-c*y+y);
			RETURN Multiply(other)
		END Rotate;

		PROCEDURE SkewX*(angle: Number):Matrix;
		VAR other: Matrix;
			s, c: Number;
		BEGIN
			s := Math.sin(SHORT(angle)/180.0*Math.pi);
			c := Math.cos(SHORT(angle)/180.0*Math.pi);
			NEW(other);
			other.Set(1.0, 0.0, s / c, 1.0, 0.0, 0.0);
			RETURN Multiply(other)
		END SkewX;

		PROCEDURE SkewY*(angle: Number):Matrix;
		VAR other: Matrix;
			s, c: Number;
		BEGIN
			s := Math.sin(SHORT(angle)/180.0*Math.pi);
			c := Math.cos(SHORT(angle)/180.0*Math.pi);
			NEW(other);
			other.Set(1.0, s / c, 0.0, 1.0, 0.0, 0.0);
			RETURN Multiply(other)
		END SkewY;

		PROCEDURE Multiply*(other: Matrix):Matrix;
		VAR result: Matrix;
		BEGIN
			NEW(result);
			result.a := a * other.a + c * other.b;
			result.b := b * other.a + d * other.b;
			result.c := a * other.c + c * other.d;
			result.d := b * other.c + d * other.d;
			result.e := a * other.e + c * other.f + e;
			result.f := b * other.e + d * other.f + f;
			RETURN result
		END Multiply;

		PROCEDURE Invert*():Matrix;
		VAR result: Matrix;
			det, inv: Number;
		BEGIN
			NEW(result);

			det := a * d - b * c;
			IF ABS(det) >= Eps THEN	(* matrix can be inverted; use Cramer's rule *)
				inv := 1/det;
				result.a := +inv * d;
				result.b := -inv * b;
				result.c := -inv * c;
				result.d := +inv * a;
				result.e := +inv * (c * f - d * e);
				result.f := +inv * (b * e - a * f)
			ELSE
				result.Set(0, 0, 0, 0, 0, 0)
			END;
			RETURN result
		END Invert;

		PROCEDURE Transform*(VAR p: Point):Point;
		VAR result: Point;
		BEGIN
			result.x := p.x * a + p.y * c + e;
			result.y := p.x * b + p.y * d + f;
			RETURN result
		END Transform;

		PROCEDURE TransformLength*(VAR p: Number):Number;
		VAR x, y: Number;
		BEGIN
			x := p * a; y := p * b;
			RETURN Math.sqrt(SHORT(x * x + y * y))
		END TransformLength;

	END Matrix;

END SVGMatrix.
