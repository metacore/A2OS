MODULE  srVolShader;
IMPORT srBase;

TYPE SREAL=srBase.SREAL;
TYPE Color=srBase.COLOR;

TYPE Shader* = OBJECT

PROCEDURE Shade*(VAR x,y,z,r,g,b,a: SREAL);
END Shade;

END Shader;

TYPE checkerboard3d*= OBJECT(Shader)
VAR
	isquish*, jsquish*, ksquish*: SIGNED16;
	black, white: Color;

PROCEDURE squish*(i,j,k: SIGNED16);
BEGIN
	isquish:=i; jsquish:=j; ksquish:=k;
END squish;

PROCEDURE set*(b,w: Color);
BEGIN
	black:=b; white:=w;
END set;

PROCEDURE Shade*(VAR x,y,z,r,g,b,a: SREAL);
VAR
	i,j,k:SIGNED16;
BEGIN
	i:=SHORT(ENTIER(x*isquish));
	j:=SHORT(ENTIER(y*jsquish));
	k:=SHORT(ENTIER(z*ksquish));
	IF ODD(i+j+k) THEN
		r:=black.red; g:=black.green; b:=black.blue; a:=0
	ELSE
		r:=white.red; g:=white.green; b:=black.blue; a:=0
	END
END Shade;

END checkerboard3d;


END srVolShader.

