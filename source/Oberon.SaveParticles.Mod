(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
SaveParticles: A sample fader for SaveScreen.
1999.11.03 - Ben Smith-Mannschott
	- particle velocities no longer get out of control.
	- particles now have a time to live, after which a new random particle takes their place
1999.11.05 - Ben Smith-Mannschott
	- now supports configuration: particleCount, particleSize
1999.11.12 - bpsm
	- now requests a frame rate.
2000.03.29 - bpsm
	- supports configuration: speed, frameRate, origin
		- origin = 0 -> random origin
		- origin = 1 -> all particles originte from the center
	- coloring changed.

*)

MODULE SaveParticles IN Oberon;

	IMPORT Modules, Display, In, Out, SaveScreen, Input;

	CONST
		versionString = "SaveParticles: 2000.03.29 - bpsm";

		minParticleCount = 16;
		maxParticleCount = 256;
		defParticleCount = 64;

		minParticleSize = 1;
		maxParticleSize = 32;
		defParticleSize = 4;

		minSpeed = 1;
		maxSpeed = 16;
		defSpeed = 10;

		minFrameRate = 1;
		maxFrameRate = 30;
		defFrameRate = 20;

		randomOrigin = 0;
		centerOrigin = 1;

		minOrigin = randomOrigin;
		maxOrigin = centerOrigin;
		defOrigin = randomOrigin;

	TYPE
		Particle = RECORD
			x, y, vx, vy: SIGNED16;
			tolive: SIGNED16;
			color: SIGNED16;
		END;

	VAR
		particleCount: SIGNED16;
		particleSize: SIGNED16;
		speed: SIGNED16;
		frameRate: SIGNED16;
		origin: SIGNED16;
		particle: ARRAY maxParticleCount OF Particle;


	PROCEDURE CreateParticle(VAR p: Particle; color: SIGNED16);
	BEGIN
		CASE origin OF
		| randomOrigin:
			p.x := SaveScreen.Rand(Display.Width - particleSize);
			p.y := SaveScreen.Rand(Display.Height - particleSize);
			p.vx := SaveScreen.Rand(5) + speed;
			p.vy := SaveScreen.Rand(5) + speed;
			IF p.x > Display.Left + Display.Width DIV 2 THEN p.vx := -p.vx END;
			IF p.y > Display.Bottom + Display.Height DIV 2 THEN p.vy := -p.vy END;
		| centerOrigin:
			p.x := Display.Width DIV 2 + Display.Left + SaveScreen.Rand(16)-8;
			p.y := Display.Height DIV 2 + Display.Bottom+ SaveScreen.Rand(12)-6;
			p.vx := SaveScreen.Rand(2 * speed) - speed;
			p.vy := SaveScreen.Rand(2 * speed) - speed;
		END;
		p.color := color;
		p.tolive := 100 + SaveScreen.Rand(156);
	END CreateParticle;

	PROCEDURE StartParticles;
		VAR
			i: SIGNED16;
	BEGIN
		SaveScreen.SetFrameRate(frameRate);
		Display.ReplConst(Display.FG,
			Display.Left, Display.Bottom, Display.Width, Display.Height,
			Display.replace);
		FOR i := 0 TO particleCount - 1 DO CreateParticle(particle[i], SHORT(Input.Time() MOD 15)) END
	END StartParticles;

	PROCEDURE StepParticles;
		VAR
			ox, oy, i: SIGNED16;
			p: Particle;
			rightLimit, topLimit: SIGNED16;
	BEGIN
		rightLimit := Display.Left + Display.Width - particleSize;
		topLimit := Display.Bottom + Display.Height - particleSize;
		FOR i := 0 TO particleCount - 1 DO
			p := particle[i];
			ox := p.x; oy := p.y;
			INC(p.x, p.vx); INC(p.y, p.vy);
			IF (p.x > rightLimit) OR (p.x < Display.Left) THEN p.x := ox; p.vx := -p.vx; END;
			IF (p.y > topLimit) OR (p.y < Display.Bottom) THEN p.y := oy; p.vy := -p.vy; END;
			DEC(p.tolive);
			IF p.tolive = 0 THEN
				CreateParticle(p, SHORT((Input.Time() DIV 16) MOD 16))
			END;
			IF (oy # p.y) OR (ox # p.x) THEN
				Display.ReplConst(Display.FG, ox, oy, particleSize, particleSize, Display.replace);
				Display.ReplConst(p.color, p.x, p.y, particleSize, particleSize, Display.replace);
			END;
			particle[i] := p;
		END;
	END StepParticles;

	PROCEDURE StopParticles;
	END StopParticles;

	PROCEDURE Install*;	(** {name value} *)
		VAR name: ARRAY 32 OF CHAR; n: SIGNED16;
	BEGIN
		In.Open;
		LOOP
			In.Name(name); IF ~In.Done THEN EXIT END;
			In.Int(n); IF ~In.Done THEN EXIT END;
			IF (name = "particleCount") THEN
				particleCount := SaveScreen.Limit(minParticleCount, n, maxParticleCount)
			ELSIF (name = "particleSize") THEN
				particleSize := SaveScreen.Limit(minParticleSize, n, maxParticleSize)
			ELSIF (name = "speed") THEN
				speed := SaveScreen.Limit(minSpeed, n, maxSpeed)
			ELSIF (name = "frameRate") THEN
				frameRate := SaveScreen.Limit(minFrameRate, n, maxFrameRate)
			ELSIF (name = "origin") THEN
				origin := SaveScreen.Limit(minOrigin, n, maxOrigin)
			END;
		END;
		SaveScreen.InstallFader(StartParticles, StepParticles, StopParticles);
	END Install;

	PROCEDURE Remove;
	BEGIN
		SaveScreen.RemoveFader(StartParticles, StepParticles, StopParticles);
	END Remove;

	PROCEDURE Configuration*;
	BEGIN
		Out.String("SaveParticles: "); Out.Ln;
		Out.String("    particleCount "); Out.Int(particleCount, 0); Out.Ln;
		Out.String("    particleSize "); Out.Int(particleSize, 0); Out.Ln;
		Out.String("    speed "); Out.Int(speed, 0); Out.Ln;
		Out.String("    frameRate"); Out.Int(frameRate, 0); Out.Ln;
	END Configuration;

BEGIN
	origin := defOrigin;
	frameRate := defFrameRate;
	speed := defSpeed;
	particleCount := defParticleCount;
	particleSize := defParticleSize;
	Modules.InstallTermHandler(Remove);
	Out.String(versionString); Out.Ln;
END SaveParticles.