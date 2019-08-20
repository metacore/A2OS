MODULE W3dAbstractWorld;	(** AUTHOR "TF"; PURPOSE "Abstract 3d world (case study)"; *)

IMPORT
	Vectors := W3dVectors, Raster;

TYPE
	Vertex* = OBJECT
		(** SetPos - set the position of the vertex to p *)
		PROCEDURE SetPos*(p : Vectors.TVector3d);
		END SetPos;

		(** SetUV - set the relative texture position of this vertex (texture is defined in the triangle) *)
		PROCEDURE SetUV*(u, v : LONGREAL);
		END SetUV;
	END Vertex;

	Texture* = OBJECT

	END Texture;

	Object* = OBJECT
		(** SetIndex - index that will be reported by World.GetOwnerIndex(x, y) if the object is visible in the view at the pixel(x, y) *)
		PROCEDURE SetIndex*(idx : LONGINT);
		END SetIndex;

		(** convert an image to the internal texture format of the Object *)
		PROCEDURE AddTexture*(img : Raster.Image) : Texture;
		END AddTexture;

		(** convert a vector to the internal vertex format of the object *)
		PROCEDURE AddVertex*(p : Vectors.TVector3d) : Vertex;
		END AddVertex;

		PROCEDURE AddTriangle*(a, b, c : Vertex; color : LONGINT; tex : Texture; mask0, culled: BOOLEAN);
		END AddTriangle;

		PROCEDURE Clear*;
		END Clear;
	END Object;

	World* = OBJECT
		PROCEDURE CreateObject*() : Object;
		END CreateObject;

		PROCEDURE AddObject*(x : Object);
		END AddObject;

		(** replace one object by another (atomic) *)
		PROCEDURE ReplaceObject*(x, y: Object);
		END ReplaceObject;

		(** Declare if an object is animated. Some renderers can optimize the situation of a static world with
			a few animated objects *)
		PROCEDURE SetAnimated*(obj : Object; animated: BOOLEAN);
		END SetAnimated;

		PROCEDURE Clear*;
		END Clear;

		PROCEDURE SetCamera*(p, d, u : Vectors.TVector3d);
		END SetCamera;

		PROCEDURE Render*(img : Raster.Image; movingOnly : BOOLEAN);
		END Render;

		(** currently not for animated objects :-( *)
		PROCEDURE GetOwnerIndex*(x, y : SIZE): LONGINT;
		END GetOwnerIndex;
	END World;

END W3dAbstractWorld.
