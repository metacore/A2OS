MODULE srTree;
IMPORT srBase, srGL, srVoxel, srM2Space;

TYPE PT = srBase.PT;

TYPE tree* = OBJECT(srBase.V)
VAR
	context: srGL.Context;
	cell*: srM2Space.cell;
	a,b,c, z: PT;
	angle: REAL;

PROCEDURE & new*;
BEGIN
	NEW(context);
	NEW(cell);
	srBase.setPT(a,0.5, 0.5, 0.3);
	srBase.setPT(b,0.5, 0.5, 0.7);
	srBase.setPT(c,0.5, 0.5, 1);
	srBase.setPT(z, 0, 0, 1);
	angle := 0;
	trunk;
	register;
END new;

PROCEDURE tick*;
(*
BEGIN
	cell.erase;
	branch(angle);
	angle := angle + 0.0134472;*)
END tick;

PROCEDURE trunk;
BEGIN
	branch(1,2,1)
END trunk;

PROCEDURE branch(level, limit, rep: INTEGER);
VAR
	p,q: PT;
	i: INTEGER;
BEGIN
	FOR i := 0 TO rep DO
		srBase.randPT(q);
		cell.linevoxel(p,q, level,green);
		context.push;
		context.translatep(q);
		IF level<limit THEN branch(level+1,limit,rep+2) END
	END;
(*	context.push;
	p := a; q := b;
	context.rotate(r,0,1,0);
	context.transform(p);
	context.transform(q);
	cell.line(p,q,2,green);
	context.translatep(q);
	p := a; q := b;
	context.rotate(r,0,1,0);
	context.transform(p);
	context.transform(q);
	cell.line(p,q,3,blue);
	context.translatep(q);
	p := a; q := b;
	context.rotate(r,0,1,0);
	context.transform(p);
	context.transform(q);
	cell.line(p,q,3,red);
	twig;
	context.pop; *)
END branch;

PROCEDURE twig;
VAR
	p,q: PT;
BEGIN
	context.push;
	context.scale(1/2,1/2,1/2);
	p := a; q := b;
	context.rotate(2/3,0,1,1);
	context.transform(p);
	context.transform(q);
	cell.linevoxel(p,q,4,green);
	context.translatep(b);
	p := a; q := b;
	context.rotate(2/3,0,1,1);
	context.transform(p);
	context.transform(q);
	cell.linevoxel(p,q,4,blue);
	context.translatep(b);
	p := a; q := b;
	context.rotate(2/3,0,1,1);
	context.transform(p);
	context.transform(q);
	cell.linevoxel(p,q,4,blue);
	context.translatep(b);
	p := a; q := b;
	context.rotate(2/3,0,1,1);
	context.transform(p);
	context.transform(q);
	cell.linevoxel(p,q,4,blue);
	context.pop;
END twig;

END tree;

VAR
	green, blue, red: srVoxel.DiffuseVox;
	Tree*:tree;
BEGIN
	NEW(green);
	green.SetColor(0,1,0);
	NEW(blue);
	blue.SetColor(0,0,1);
	NEW(red);
	red.SetColor(1,0,0);
	NEW(Tree);
END srTree.