MODULE SVGLoader;

IMPORT SVG, SVGColors, SVGGradients, SVGFilters, SVGRenderer, XML, XMLObjects, XMLLoader, Strings, Math, WMGraphics;

(* Constants that determine what to do if an attribute was omitted *)
CONST 	OnOmittedParseDefault=0;
		OnOmittedDontChange=1;
		OnOmittedError=2;

TYPE
	SVGLoader=OBJECT
		VAR
			ppi: FLOAT64;	(* pixels per inch of the documents *)
			state: SVG.State; (* the current state *)
			mainDocument: SVG.Document; (* the main target *)

			renderer: SVGRenderer.Renderer; (* the object doing the rendering *)
			fePrev: SVGFilters.FilterElement; (* the previous filter element *)

			sizeForced: BOOLEAN; (* should the output be forced to size widthForced * heightForced? *)
			widthForced, heightForced: SIGNED32;

		PROCEDURE &New*;
		BEGIN
			sizeForced := FALSE;
		END New;

		(* Force the output to be of size width * height *)
		PROCEDURE ForceSize(width, height: SIGNED32);
		BEGIN
			sizeForced := TRUE;
			widthForced := width;
			heightForced := height;
		END ForceSize;

		(* Load the root svg element e *)
		PROCEDURE LoadRoot(e: XML.Element);
		BEGIN
			ppi := 90; (* Default assumption *)
			NEW(state);
			SVG.InitDefaultStyle(state.style);

			NEW(renderer);

			LoadElement(e)
		END LoadRoot;

		(* Get the produced document *)
		PROCEDURE GetDocument():SVG.Document;
		BEGIN
			RETURN mainDocument;
		END GetDocument;

		(* Get the width of the viewport *)
		PROCEDURE GetActualWidth(): SVG.Length;
		BEGIN
			RETURN state.viewport.width;
		END GetActualWidth;

		(* Get the height of the viewport *)
		PROCEDURE GetActualHeight(): SVG.Length;
		BEGIN
			RETURN state.viewport.height;
		END GetActualHeight;

		(* Get the diagonal size of the viewport *)
		PROCEDURE GetActualDiagonal(): SVG.Length;
		BEGIN
			RETURN Math.sqrt(SHORT( GetActualWidth()*GetActualWidth()+GetActualHeight()*GetActualHeight() )) / Math.sqrt(2.0);
		END GetActualDiagonal;

		(* Get the name of an xml element *)
		PROCEDURE GetName(e: XML.Element):XML.String;
		VAR name: XML.String;
		BEGIN
			name := e.GetName();
			Strings.LowerCase(name^);
			IF Strings.StartsWith2("svg:",name^) THEN name := Strings.Substring2(4,name^) END;
			RETURN name;
		END GetName;

		(* Load the svg element e *)
		PROCEDURE LoadElement(e: XML.Element);
		VAR name: XML.String;
		BEGIN
			name := GetName(e);
			IF name^ = "svg" THEN LoadSVG(e)
			ELSIF name^ = "g" THEN LoadGroup(e)
			ELSIF name^ = "desc" THEN (* Ignore *)	SVG.Log("<desc />")

			ELSIF name^ = "defs" THEN LoadDefs(e)

			ELSIF name^ = "image" THEN LoadImage(e)

			ELSIF name^ = "rect" THEN LoadRect(e)
			ELSIF name^ = "circle" THEN LoadCircle(e)
			ELSIF name^ = "ellipse" THEN LoadEllipse(e)
			ELSIF name^ = "line" THEN LoadLine(e)
			ELSIF name^ = "polyline" THEN LoadPoly(e, FALSE)
			ELSIF name^ = "polygon" THEN LoadPoly(e, TRUE)
			ELSIF name^ = "path" THEN LoadPath(e)

			ELSE SVG.Log("Unknown element: "); SVG.Log(name^)
			END
		END LoadElement;

		(* Get the subelements of element e *)
		PROCEDURE LoadSubElements(e: XML.Element);
		VAR contents: XMLObjects.Enumerator; content: ANY;
		BEGIN
			contents := e.GetContents();
			WHILE contents.HasMoreElements() DO
				content := contents.GetNext();
				IF content IS XML.Element THEN LoadElement(content(XML.Element))
				ELSE (* Ignore comments *)
				END
			END
		END LoadSubElements;

		(* Load the <svg> element e *)
		PROCEDURE LoadSVG(e: XML.Element);
		BEGIN
			SVG.Log("<svg>");
			state.Push();

			LoadAttrLength(e, "x", state.viewport.x, 640.0, OnOmittedParseDefault, "0");
			LoadAttrLength(e, "y", state.viewport.y, 480.0, OnOmittedParseDefault, "0");
			LoadAttrLength(e, "width", state.viewport.width, 640.0, OnOmittedParseDefault, "100%");
			LoadAttrLength(e, "height", state.viewport.height, 480.0, OnOmittedParseDefault, "100%");

			IF mainDocument = NIL THEN
				NEW(state.userToWorldSpace);
				state.userToWorldSpace.SetIdentity();

				IF sizeForced THEN
					state.userToWorldSpace := state.userToWorldSpace.Scale(widthForced / state.viewport.width,	heightForced / state.viewport.height);
					state.viewport.width := widthForced;
					state.viewport.height := heightForced;
				END;

				LoadViewBoxAttributes(e,state.userToWorldSpace, state.viewport.width, state.viewport.height);

				state.target := SVG.NewDocument(state.viewport.width,state.viewport.height);
				renderer.FillWhite(state);
				mainDocument := state.target;
				state.transparencyUsed := FALSE;

				LoadSubElements(e);
			ELSE
				state.userToWorldSpace:= state.userToWorldSpace.Translate(state.viewport.x, state.viewport.y);
				LoadViewBoxAttributes(e,state.userToWorldSpace, state.viewport.width, state.viewport.height);
				LoadSubElements(e);
			END;

			state.Pop();
			SVG.Log("</svg>")
		END LoadSVG;

		(* Load the <g> element e *)
		PROCEDURE LoadGroup(e: XML.Element);
		BEGIN
			SVG.Log("<g>");
			state.Push();

			LoadPaintAttributes(e);
			LoadAttrTransform(e, "transform", state.userToWorldSpace);
			LoadFilterAttributeBegin(e);
			LoadSubElements(e);
			LoadFilterAttributeEnd();

			state.Pop();
			SVG.Log("</g>")
		END LoadGroup;

		(* Load the <defs> element e *)
		PROCEDURE LoadDefs(e: XML.Element);
		VAR contents: XMLObjects.Enumerator; content: ANY;
			defEl: XML.Element;
			id, name: XML.String;
		BEGIN
			SVG.Log("<defs>");
			contents := e.GetContents();
			WHILE contents.HasMoreElements() DO
				content := contents.GetNext();
				IF content IS XML.Element THEN

					defEl := content(XML.Element);
					id := defEl.GetAttributeValue("id");
					IF id # NIL THEN
						name := GetName(defEl);
						IF name^ = "lineargradient" THEN LoadLinearGradient(defEl, id)
						ELSIF name^ = "radialgradient" THEN LoadRadialGradient(defEl, id)
						ELSIF name^ = "filter" THEN LoadFilter(defEl, id)
						END
					END
				ELSE (* Ignore comments *)
				END
			END;
			SVG.Log("</defs>")
		END LoadDefs;

		(* Load the <linearGradient> element e *)
		PROCEDURE LoadLinearGradient(e: XML.Element; id: XML.String);
		VAR gradient: SVGGradients.LinearGradient;
			onOmitted: SIGNED8;
		BEGIN
			SVG.Log("<linearGradient>");

			NEW(gradient);
			IF LoadGradientParentAttribute(e, gradient) THEN onOmitted := OnOmittedDontChange
			ELSE onOmitted := OnOmittedParseDefault END;
			LoadAttrParsed(e, "gradientUnits", gradient.gradientUnits, onOmitted, "objectBoundingBox", SVG.ParseUnits);
			LoadAttrParsed(e, "spreadMethod", gradient.spreadMethod, onOmitted, "pad", SVGGradients.ParseSpreadMethod);
			LoadAttrTransform(e, "gradientTransform", gradient.transform);

			LoadAttrLength(e, "x1", gradient.p1.x, GetActualWidth(), onOmitted, "0%");
			LoadAttrLength(e, "y1", gradient.p1.y, GetActualHeight(), onOmitted, "0%");
			LoadAttrLength(e, "x2", gradient.p2.x, GetActualWidth(), onOmitted, "100%");
			LoadAttrLength(e, "y2", gradient.p2.y, GetActualHeight(), onOmitted, "0%");

			LoadGradientStops(e,gradient);
			renderer.gradients.AddGradient(gradient,id);
			SVG.Log("</ linearGradient>");
		END LoadLinearGradient;

		(* Load the <radialGradient> element e *)
		PROCEDURE LoadRadialGradient(e: XML.Element; id: XML.String);
		VAR gradient: SVGGradients.RadialGradient;
			onOmitted: SIGNED8;
		BEGIN
			SVG.Log("<radialGradient>");

			NEW(gradient);
			IF LoadGradientParentAttribute(e, gradient) THEN onOmitted := OnOmittedDontChange
			ELSE onOmitted := OnOmittedParseDefault END;
			LoadAttrParsed(e, "gradientUnits", gradient.gradientUnits, onOmitted, "objectBoundingBox", SVG.ParseUnits);
			LoadAttrParsed(e, "spreadMethod", gradient.spreadMethod, onOmitted, "pad", SVGGradients.ParseSpreadMethod);
			LoadAttrTransform(e, "gradientTransform", gradient.transform);

			LoadAttrLength(e, "cx", gradient.center.x, GetActualWidth(), onOmitted, "50%");
			LoadAttrLength(e, "cy", gradient.center.y, GetActualHeight(), onOmitted, "50%");
			LoadAttrLength(e, "r", gradient.radius, GetActualDiagonal(), onOmitted, "50%");
			IF onOmitted=OnOmittedParseDefault THEN
				gradient.focal.x := gradient.center.x;
				gradient.focal.y := gradient.center.y;
			END;
			LoadAttrLength(e, "fx", gradient.focal.x, GetActualWidth(), OnOmittedDontChange, "0");
			LoadAttrLength(e, "fy", gradient.focal.y, GetActualHeight(), OnOmittedDontChange, "0");

			LoadGradientStops(e,gradient);
			renderer.gradients.AddGradient(gradient,id);
			SVG.Log("</radialGradient>");
		END LoadRadialGradient;

		(* Load the parent attribute of some gradient element e *)
		PROCEDURE LoadGradientParentAttribute(e: XML.Element; gradient:SVGGradients.Gradient):BOOLEAN;
		VAR parent: SVGGradients.Gradient;
			linearGradient, linearParent: SVGGradients.LinearGradient;
			radialGradient, radialParent: SVGGradients.RadialGradient;
			href: XML.String;
		BEGIN
			href := e.GetAttributeValue("xlink:href");
			IF href # NIL THEN
				IF SVG.ParseURI(href,href) THEN
					parent := renderer.gradients.GetGradient(href);
				END
			END;
			IF parent#NIL THEN
				IF (parent IS SVGGradients.LinearGradient) & (gradient IS SVGGradients.LinearGradient) THEN
					linearParent := parent(SVGGradients.LinearGradient);
					linearGradient := gradient(SVGGradients.LinearGradient);
					linearGradient.CopyLinear(linearParent);
				ELSIF (parent IS SVGGradients.RadialGradient) & (gradient IS SVGGradients.RadialGradient) THEN
					radialParent := parent(SVGGradients.RadialGradient);
					radialGradient := gradient(SVGGradients.RadialGradient);
					radialGradient.CopyRadial(radialParent);
				ELSE
					gradient.Copy(parent);
				END;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END LoadGradientParentAttribute;

		(* Load the <stop> elements of a gradient *)
		PROCEDURE LoadGradientStops(e: XML.Element; gradient: SVGGradients.Gradient);
		VAR contents: XMLObjects.Enumerator; content: ANY;
			foundStops: BOOLEAN;
			name: XML.String;
		BEGIN
			foundStops := FALSE;
			contents := e.GetContents();
			WHILE contents.HasMoreElements() DO
				content := contents.GetNext();
				IF content IS XML.Element THEN
					WITH content:XML.Element DO
						name := GetName(content);
						IF name^ = "stop" THEN
							IF ~foundStops THEN
								(* Don't inherit the parents stop elements if this element defines stop elements *)
								foundStops := TRUE;
								gradient.ClearStops();
							END;
							LoadGradientStop(content(XML.Element), gradient)
						ELSE
							SVG.Warning("stop element expected, found element: ");
							SVG.Warning(name^);
						END
					END
				ELSE (* Ignore comments *)
				END
			END
		END LoadGradientStops;

		(* Load one <stop> element of a gradient *)
		PROCEDURE LoadGradientStop(e: XML.Element; gradient: SVGGradients.Gradient);
		VAR offset: SVG.Length;
			color: SVG.Color;
			colorStr: XML.String;
		BEGIN
			SVG.Log("<stop />");

			LoadAttrNumber(e, "offset", offset, SVG.AllowPercentages, 1.0, OnOmittedError, "stop element omitted offset attribute");

			colorStr := LoadAttribute(e,"stop-color");
			IF colorStr = NIL THEN
				color := SVGColors.Black;
			END;
			IF ~SVGColors.Parse(colorStr, color) THEN
				color := SVGColors.Black;
				SVG.Warning("stop element specifies invalid stop-color element");
				SVG.Warning(colorStr^)
			END;

			LoadOpacity(e, "stop-opacity", color,  OnOmittedParseDefault, "1");

			gradient.AddStop(offset, color);
		END LoadGradientStop;

		(* Load the <filter> element e *)
		PROCEDURE LoadFilter(e: XML.Element; id: XML.String);
		VAR filter: SVGFilters.Filter;
		BEGIN
			SVG.Log("<filter>");

			NEW(filter);

			LoadAttrLength(e, "x", filter.window.x, GetActualWidth(), OnOmittedParseDefault, "-10%");
			LoadAttrLength(e, "y", filter.window.y, GetActualHeight(), OnOmittedParseDefault, "-10%");
			LoadAttrLength(e, "width", filter.window.width, GetActualWidth(), OnOmittedParseDefault, "120%");
			LoadAttrLength(e, "height", filter.window.height, GetActualHeight(), OnOmittedParseDefault, "120%");

			LoadFilterElements(e,filter);
			renderer.filters.AddFilter(filter,id);
			SVG.Log("</ filter>");
		END LoadFilter;

		(* Load the <fe*> subelements of a filter *)
		PROCEDURE LoadFilterElements(e: XML.Element; filter: SVGFilters.Filter);
		VAR contents: XMLObjects.Enumerator; content: ANY;
			name: XML.String;
		BEGIN
			fePrev := NIL;

			contents := e.GetContents();
			WHILE contents.HasMoreElements() DO
				content := contents.GetNext();
				IF content IS XML.Element THEN
					WITH content:XML.Element DO
						name := GetName(content);
						IF name^ = "feblend" THEN LoadFEBlend(content(XML.Element), filter)
						ELSIF name^ = "feoffset" THEN LoadFEOffset(content(XML.Element), filter)
						ELSIF name^ = "fecolormatrix" THEN LoadFEColorMatrix(content(XML.Element), filter)
						ELSIF name^ = "fegaussianblur" THEN LoadFEGaussianBlur(content(XML.Element), filter)
						ELSIF name^ = "femerge" THEN LoadFEMerge(content(XML.Element), filter)
						ELSIF name^ = "feflood" THEN LoadFEFlood(content(XML.Element), filter)
						ELSIF name^ = "feimage" THEN LoadFEImage(content(XML.Element), filter)
						ELSIF name^ = "fetile" THEN LoadFETile(content(XML.Element), filter)
						ELSE
							SVG.Warning("fe* element expected, found element: ");
							SVG.Warning(name^);
						END
					END
				ELSE (* Ignore comments *)
				END
			END
		END LoadFilterElements;

		(* Load some common attributes of <fe*> elements *)
		PROCEDURE LoadFECommonAttributes(e: XML.Element; fe: SVGFilters.FilterElement; filter: SVGFilters.Filter; loadIn: BOOLEAN);
		VAR
			result: SVG.String;
		BEGIN
			filter.rootElement := fe;

			result := LoadAttribute(e, "result");
			IF result#NIL THEN
				filter.AddFilterElement(fe, result);
			END;

			IF loadIn THEN
				LoadFilterInAttribute(e, filter, "in", fe.in)
			END;

			fe.x := filter.window.x;
			fe.y := filter.window.y;
			fe.width := filter.window.width;
			fe.height := filter.window.height;

			LoadAttrLength(e, "x", fe.x, GetActualWidth(), OnOmittedDontChange, "");
			LoadAttrLength(e, "y", fe.y, GetActualHeight(), OnOmittedDontChange, "");
			LoadAttrLength(e, "width", fe.width, GetActualWidth(), OnOmittedDontChange, "");
			LoadAttrLength(e, "height", fe.height, GetActualHeight(), OnOmittedDontChange, "");

			fePrev := fe
		END LoadFECommonAttributes;

		(* Load the <feBlend> element e *)
		PROCEDURE LoadFEBlend(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feBlend;
		BEGIN
			SVG.Log("<feBlend />");
			NEW(fe);

			LoadFilterInAttribute(e, filter, "in2", fe.in2);

			LoadAttrParsed(e,"mode",fe.mode,OnOmittedParseDefault,"normal",SVGFilters.ParseBlendMode);

			LoadFECommonAttributes(e,fe,filter,TRUE)
		END LoadFEBlend;

		(* Load the <feOffset> element e *)
		PROCEDURE LoadFEOffset(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feOffset;
		BEGIN
			SVG.Log("<feOffset />");
			NEW(fe);

			LoadAttrLength(e, "dx", fe.dx, filter.window.width, OnOmittedParseDefault, "0");
			LoadAttrLength(e, "dy", fe.dy, filter.window.height, OnOmittedParseDefault, "0");

			LoadFECommonAttributes(e,fe,filter,TRUE)
		END LoadFEOffset;

		(* Load the <feColorMatrix> element e *)
		PROCEDURE LoadFEColorMatrix(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feColorMatrix;
			values: SVG.String;
		BEGIN
			SVG.Log("<feColorMatrix />");
			NEW(fe);

			LoadAttrParsed(e, "type", fe.type, OnOmittedError, "feColorMatrix omitted type attribute", SVGFilters.ParseColorMatrixType);
			values := LoadAttribute(e, "values");
			IF ~SVGFilters.ParseColorMatrixValues(values, fe.type, fe.matrix) THEN
				SVG.Error("feColorMatrix has invalid values attribute:");
				SVG.Error(values^)
			END;

			LoadFECommonAttributes(e,fe,filter,TRUE)
		END LoadFEColorMatrix;

		(* Load the <feGaussianBlur> element e *)
		PROCEDURE LoadFEGaussianBlur(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feGaussianBlur;
			value: SVG.String;
		BEGIN
			SVG.Log("<feGaussianBlur />");
			NEW(fe);

			value := LoadAttribute(e,"stdDeviation");
			IF value = NIL THEN
				fe.stdDeviationX := 0;
				fe.stdDeviationY := 0;
			ELSE
				SVG.ParseLengthOptional2(value, ppi, filter.window.width, fe.stdDeviationX, fe.stdDeviationY)
			END;

			LoadFECommonAttributes(e,fe,filter,TRUE)
		END LoadFEGaussianBlur;

		(* Load the <feMerge> element e *)
		PROCEDURE LoadFEMerge(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feMerge;
		BEGIN
			SVG.Log("<feMerge>");
			NEW(fe);

			LoadFEMergeNodes(e,fe,filter);

			LoadFECommonAttributes(e,fe,filter,FALSE);
			SVG.Log("</feMerge>")
		END LoadFEMerge;

		(* Load all <feMergeNodes> elements of <feMerge> element e*)
		PROCEDURE LoadFEMergeNodes(e: XML.Element; fe: SVGFilters.feMerge; filter: SVGFilters.Filter);
		VAR contents: XMLObjects.Enumerator; content: ANY;
			name: XML.String;
			in: SVGFilters.In;
			first: BOOLEAN;
		BEGIN
			fePrev := NIL;
			first := TRUE;
			contents := e.GetContents();
			WHILE contents.HasMoreElements() DO
				content := contents.GetNext();
				IF content IS XML.Element THEN
					WITH content:XML.Element DO
						name := GetName(content);
						IF name^ = "femergenode" THEN
							SVG.Log("<feMergeNode />");
							LoadFilterInAttribute(content, filter, "in", in);
							IF first THEN
								fe.in := in;
								first := FALSE
							ELSE
								fe.AddNode(in);
							END
						ELSE
							SVG.Warning("feMergeNode element expected, found element: ");
							SVG.Warning(name^);
						END
					END
				ELSE (* Ignore comments *)
				END
			END;
			IF first THEN
				SVG.Warning("empty feMerge element. feMergeNode elements expected.");
			END
		END LoadFEMergeNodes;

		(* Load the <feFlood> element e*)
		PROCEDURE LoadFEFlood(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feFlood;
			color: SVG.Color;
			value: SVG.String;
		BEGIN
			SVG.Log("<feFlood />");
			NEW(fe);

			value := LoadAttribute(e, "flood-color");
			IF value=NIL THEN value :=Strings.NewString("black") END;
			IF ~SVGColors.Parse(value, color) THEN
				SVG.Error("expected color, found:");
				SVG.Log(value^);
			END;
			LoadOpacity(e,"flood-opacity",color, OnOmittedParseDefault, "1");
			SVGColors.ColorToPixel(color,fe.pix);

			LoadFECommonAttributes(e,fe,filter,FALSE)
		END LoadFEFlood;

		(* Load the <feImage> element e*)
		PROCEDURE LoadFEImage(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feImage;
			href: SVG.String;
		BEGIN
			SVG.Log("<feImage />");
			NEW(fe);

			href := e.GetAttributeValue("xlink:href");
			IF href = NIL THEN
				SVG.Error("feImage element omitted xlink:href attribute");
				RETURN
			END;

			fe.image :=WMGraphics.LoadImage(href^, TRUE);
			IF fe.image = NIL THEN
				SVG.Error("feImage element specifies invalid xlink:href attribute");
				RETURN
			END;

			LoadFECommonAttributes(e,fe,filter,FALSE)
		END LoadFEImage;

		(* Load the <feTile> element e*)
		PROCEDURE LoadFETile(e: XML.Element; filter: SVGFilters.Filter);
		VAR
			fe: SVGFilters.feTile;
		BEGIN
			SVG.Log("<feTile />");
			NEW(fe);
			LoadFECommonAttributes(e,fe,filter,TRUE)
		END LoadFETile;

		(* Load the in attribute of <fe*> element e*)
		PROCEDURE LoadFilterInAttribute(e: XML.Element; filter: SVGFilters.Filter; name: ARRAY OF CHAR; VAR in: SVGFilters.In);
		VAR
			value: XML.String;
			feIn: SVGFilters.FilterElement;
		BEGIN
			value := LoadAttribute(e, name);
			NEW(in);
			IF value=NIL THEN
				in.type := SVGFilters.InFilterElement;
				in.fe := fePrev;
				IF fePrev=NIL THEN
					SVG.Error("filter element defaults to previous element, but no previous element available")
				END
			ELSE
				SVGFilters.ParseIn(value, in.type);
				IF in.type=SVGFilters.InFilterElement THEN
					feIn := filter.GetFilterElement(value);
					IF feIn#NIL THEN
						in.fe := feIn
					ELSE
						SVG.Error("Couldn't find filter element with result= ");
						SVG.Error(value^);
					END
				END
			END
		END LoadFilterInAttribute;

		(* Load the filter attribute of some element e*)
		PROCEDURE LoadFilterAttribute(e: XML.Element):SVGFilters.Filter;
		VAR filterAttr, name: XML.String;
			filter: SVGFilters.Filter;
		BEGIN
			filterAttr := e.GetAttributeValue("filter");
			IF filterAttr # NIL THEN
				IF SVG.ParseURI(filterAttr, name) THEN
					filter := renderer.filters.GetFilter(name);

					state.transparencyUsed := TRUE;
				END;
				IF filter # NIL THEN
					RETURN filter;
				ELSE
					 SVG.Error("Couldn't find filter with specified id");
					 SVG.Error(name^);
					RETURN NIL
				END
			ELSE
				RETURN NIL
			END
		END LoadFilterAttribute;

		(* Load the filter attribute of some element e and prepare for rendering using this filter *)
		PROCEDURE LoadFilterAttributeBegin(e: XML.Element);
		VAR filter: SVGFilters.Filter;
		BEGIN
			filter := LoadFilterAttribute(e);
			renderer.BeginFilter(filter, state);
		END LoadFilterAttributeBegin;

		(* Cleanup rendering using some filter *)
		PROCEDURE LoadFilterAttributeEnd;
		BEGIN
			renderer.EndFilter(state)
		END LoadFilterAttributeEnd;

		(* Load the <image> element e *)
		PROCEDURE LoadImage(e: XML.Element);
		VAR x, y, width, height: SVG.Length;
			image: SVG.Document;
			href: SVG.String;
		BEGIN
			SVG.Log("<image />");

			state.Push();
			LoadAttrTransform(e, "transform", state.userToWorldSpace);

			LoadAttrLength(e, "x", x, GetActualWidth(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "y", y, GetActualHeight(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "width", width, GetActualWidth(), OnOmittedError, "image element omitted width attribute");
			LoadAttrLength(e, "height", height, GetActualHeight(), OnOmittedError, "image element omitted height attribute");
			href := e.GetAttributeValue("xlink:href");
			IF href = NIL THEN
				SVG.Error("image element omitted xlink:href attribute");
				RETURN
			END;

			image :=WMGraphics.LoadImage(href^, TRUE);
			IF image = NIL THEN
				SVG.Error("image element specifies invalid xlink:href attribute");
				RETURN
			END;

			LoadFilterAttributeBegin(e);
			renderer.RenderImage(x, y, width, height, image, state);
			LoadFilterAttributeEnd();

			state.Pop();
		END LoadImage;

		(* Load the <rect> element e *)
		PROCEDURE LoadRect(e: XML.Element);
		VAR x, y, width, height, rx, ry: SVG.Length;
			rxe, rye: XML.Attribute;
		BEGIN
			SVG.Log("<rect />");

			state.Push();
			LoadPaintAttributes(e);
			LoadAttrTransform(e, "transform", state.userToWorldSpace);

			LoadAttrLength(e, "x", x, GetActualWidth(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "y", y, GetActualHeight(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "width", width, GetActualWidth(), OnOmittedError, "rect element omitted width attribute");
			LoadAttrLength(e, "height", height, GetActualHeight(), OnOmittedError, "rect element omitted width attribute");

			rxe := e.GetAttribute("rx");
			rye := e.GetAttribute("ry");
			IF (rxe=NIL) & (rxe=NIL) THEN
				LoadFilterAttributeBegin(e);
				renderer.RenderRect(x, y, width, height, state);
				LoadFilterAttributeEnd();
			ELSE
				IF rxe=NIL THEN
					LoadAttrLength(e, "ry", ry, GetActualDiagonal(), OnOmittedParseDefault, "0");
					rx := ry;
				ELSIF rye=NIL THEN
					LoadAttrLength(e, "rx", rx, GetActualDiagonal(), OnOmittedParseDefault, "0");
					ry := rx;
				ELSE
					LoadAttrLength(e, "rx", rx, GetActualWidth(), OnOmittedParseDefault, "0");
					LoadAttrLength(e, "ry", ry, GetActualHeight(), OnOmittedParseDefault, "0");
				END;
				LoadFilterAttributeBegin(e);
				renderer.RenderRoundedRect(x, y, width, height, rx, ry, state);
				LoadFilterAttributeEnd();
			END;

			state.Pop();
		END LoadRect;

		(* Load the <circle> element e *)
		PROCEDURE LoadCircle(e: XML.Element);
		VAR cx, cy, r: SVG.Length;
		BEGIN
			SVG.Log("<circle />");

			state.Push();
			LoadPaintAttributes(e);
			LoadAttrTransform(e, "transform", state.userToWorldSpace);

			LoadAttrLength(e, "cx", cx, GetActualWidth(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "cy", cy, GetActualHeight(), OnOmittedParseDefault,  "0");
			LoadAttrLength(e, "r", r, GetActualDiagonal(), OnOmittedError, "circle element omitted r attribute");

			LoadFilterAttributeBegin(e);
			renderer.RenderCircle(cx, cy, r, state);
			LoadFilterAttributeEnd();

			state.Pop();
		END LoadCircle;

		(* Load the <ellipse> element e *)
		PROCEDURE LoadEllipse(e: XML.Element);
		VAR cx, cy, rx, ry: SVG.Length;
		BEGIN
			SVG.Log("<ellipse />");

			state.Push();
			LoadPaintAttributes(e);
			LoadAttrTransform(e, "transform", state.userToWorldSpace);

			LoadAttrLength(e, "cx", cx, GetActualWidth(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "cy", cy, GetActualHeight(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "rx", rx, GetActualWidth(), OnOmittedError, "ellipse element omitted rx attribute");
			LoadAttrLength(e, "ry", ry, GetActualHeight(), OnOmittedError, "ellipse element omitted ry attribute");

			LoadFilterAttributeBegin(e);
			renderer.RenderEllipse(cx, cy, rx, ry, state);
			LoadFilterAttributeEnd();

			state.Pop();
		END LoadEllipse;

		(* Load the <line> element e *)
		PROCEDURE LoadLine(e: XML.Element);
		VAR x1, y1, x2, y2: SVG.Length;
		BEGIN
			SVG.Log("<line />");

			state.Push();
			LoadPaintAttributes(e);
			LoadAttrTransform(e, "transform", state.userToWorldSpace);

			LoadAttrLength(e, "x1", x1, GetActualWidth(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "y1", y1, GetActualHeight(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "x2", x2, GetActualWidth(), OnOmittedParseDefault, "0");
			LoadAttrLength(e, "y2", y2, GetActualHeight(), OnOmittedParseDefault, "0");

			LoadFilterAttributeBegin(e);
			renderer.RenderLine(x1, y1, x2, y2, state);
			LoadFilterAttributeEnd();

			state.Pop();
		END LoadLine;

		(* Load the <polyline> or <polygon> element e *)
		PROCEDURE LoadPoly(e: XML.Element; closed: BOOLEAN);
		VAR points: SVG.String;
		BEGIN
			IF closed THEN SVG.Log("<polygon />")
			ELSE SVG.Log("<polyline />") END;

			state.Push();
			LoadPaintAttributes(e);
			LoadAttrTransform(e, "transform", state.userToWorldSpace);

			points := e.GetAttributeValue("points");
			IF points=NIL THEN
				IF closed THEN SVG.Error("polygon element omitted points attribute")
				ELSE SVG.Error("polyline element omitted points attribute") END;
				RETURN
			ELSE
				LoadFilterAttributeBegin(e);
				renderer.RenderPoly(points, closed, state);
				LoadFilterAttributeEnd();
			END;

			state.Pop();
		END LoadPoly;

		(* Load the <path> element e *)
		PROCEDURE LoadPath(e: XML.Element);
		VAR d: SVG.String;
		BEGIN
			SVG.Log("<path />");

			state.Push();
			LoadPaintAttributes(e);
			LoadAttrTransform(e, "transform", state.userToWorldSpace);

			d := e.GetAttributeValue("d");
			IF d=NIL THEN
				SVG.Error("path element omitted d attribute");
			ELSE
				LoadFilterAttributeBegin(e);
				renderer.RenderPath(d, state);
				LoadFilterAttributeEnd();
			END;

			state.Pop();
		END LoadPath;

		(* Load the paint attributes of element e *)
		PROCEDURE LoadPaintAttributes(e: XML.Element);
		VAR
			value: XML.String;
		BEGIN
			value := LoadAttribute(e, "fill");
			IF value#NIL THEN SVG.ParsePaint(value,state.style.fill) END;
			value := LoadAttribute(e, "stroke");
			IF value#NIL THEN SVG.ParsePaint(value, state.style.stroke) END;
			value := LoadAttribute(e, "stroke-width");
			IF value#NIL THEN SVG.ParseLength(value, ppi, GetActualDiagonal(), state.style.strokeWidth) END;

			LoadOpacity(e, "fill-opacity", state.style.fill.color,  OnOmittedParseDefault, "1");
			LoadOpacity(e, "stroke-opacity", state.style.stroke.color,  OnOmittedParseDefault, "1");

		END LoadPaintAttributes;

		(* Load the viewBox and preserceAspectRatio attributes of element e *)
		PROCEDURE LoadViewBoxAttributes(e: XML.Element; VAR transform: SVG.Transform; width0, height0: SVG.Length);
		VAR viewBox, preserveAR: XML.String;
			minx, miny, width, height, ratioX, ratioY: SVG.Length;
			xAlign, yAlign: SIGNED32;
			meet: BOOLEAN;
		BEGIN
			viewBox := e.GetAttributeValue("viewBox");
			IF viewBox # NIL THEN
				SVG.ParseViewBox(viewBox, minx, miny, width, height);
				ratioX := width0/width;
				ratioY := height0/height;

				preserveAR := e.GetAttributeValue("preserveAspectRatio");
				IF (preserveAR = NIL) OR (Strings.StartsWith2("none",preserveAR^)) THEN
					xAlign := -1;
					yAlign := -1;
				ELSE
					SVG.ParsePreserveAspect(preserveAR, xAlign, yAlign, meet);
					IF meet = (width0/height0 < width/height) THEN
						ratioY := ratioX
					ELSE ratioX := ratioY END
				END;
				transform := transform.TransformBy(ratioX, 0.0, 0.0, ratioY,
					(1+xAlign)*width0/2-(minx+(1+xAlign)*width/2)*ratioX,
					(1+yAlign)*height0/2 -(miny+(1+yAlign)*height/2)*ratioY)
			END
		END LoadViewBoxAttributes;

		(* Load some numeric attribute of element e *)
		PROCEDURE LoadAttrNumber(e: XML.Element; name: ARRAY OF CHAR; VAR number: SVG.Number;
			percentageAllowed: BOOLEAN; percent100: SVG.Number; onOmitted: SIGNED8; default: ARRAY OF CHAR);
		VAR value: XML.String;
		BEGIN
			value := LoadAttribute(e,name);
			IF value = NIL THEN
				CASE onOmitted OF
				OnOmittedParseDefault:
					value := Strings.NewString(default);
					SVG.ParseNumber(value, number, percentageAllowed, percent100)
				| OnOmittedDontChange:
				| OnOmittedError:
					SVG.Error(default);
				END
			ELSE
				SVG.ParseNumber(value, number, percentageAllowed, percent100)
			END
		END LoadAttrNumber;

		(* Load some attribute of element e of type length *)
		PROCEDURE LoadAttrLength(e: XML.Element; name: ARRAY OF CHAR; VAR length: SVG.Length;
			percent100: SVG.Number; onOmitted: SIGNED8; default: ARRAY OF CHAR);
		VAR value: XML.String;
		BEGIN
			value := LoadAttribute(e,name);
			IF value = NIL THEN
				CASE onOmitted OF
				OnOmittedParseDefault:
					value := Strings.NewString(default);
					SVG.ParseLength(value, ppi, percent100, length)
				| OnOmittedDontChange:
				| OnOmittedError:
					SVG.Error(default);
				END
			ELSE
				SVG.ParseLength(value, ppi, percent100, length)
			END
		END LoadAttrLength;

		(* Load the transform attribute of element e *)
		PROCEDURE LoadAttrTransform(e: XML.Element; name: ARRAY OF CHAR; VAR transform: SVG.Transform);
		VAR value: XML.String;
		BEGIN
			value := LoadAttribute(e,name);
			IF value # NIL THEN
				SVG.ParseTransformList(value, transform)
			END
		END LoadAttrTransform;

		(* Load some attribute of element e using a custom parse procedure*)
		PROCEDURE LoadAttrParsed(e: XML.Element; name: ARRAY OF CHAR; VAR parsed: SIGNED8;
			onOmitted: SIGNED8; default: ARRAY OF CHAR;
			parser: PROCEDURE(value: XML.String; VAR parsed: SIGNED8));
		VAR value: XML.String;
		BEGIN
			value := LoadAttribute(e,name);
			IF value = NIL THEN
				CASE onOmitted OF
				OnOmittedParseDefault:
					value := Strings.NewString(default);
					parser(value,parsed)
				| OnOmittedDontChange:
				| OnOmittedError:
					SVG.Error(default);
				END
			ELSE
				parser(value,parsed)
			END
		END LoadAttrParsed;

		(* Load some attribute of element e *)
		PROCEDURE LoadAttribute(e: XML.Element; name: ARRAY OF CHAR): XML.String;
		VAR value: XML.String;
		BEGIN
			value := e.GetAttributeValue(name);
			IF value=NIL THEN
				value := e.GetAttributeValue("style");
				IF value=NIL THEN RETURN NIL END;
				value := SVG.ParseStyle(value,name);
			END;
			RETURN value
		END LoadAttribute;

		(* Load some opacity attribute of element e *)
		PROCEDURE LoadOpacity(e: XML.Element; name: ARRAY OF CHAR; VAR color: SVG.Color; onOmitted: SIGNED8; default: ARRAY OF CHAR);
		VAR opacity: SVG.Length;
			r,g,b,a: SIGNED16;
		BEGIN
			LoadAttrNumber(e,name, opacity,SVG.DisallowPercentages, 0.0,  onOmitted, default);
			IF opacity#1 THEN
				SVGColors.Split(color, r,g,b,a);
				a:=SHORT(ENTIER(255*opacity));
				SVGColors.Unsplit(color, r,g,b,a);

				state.transparencyUsed := TRUE;
			END;
		END LoadOpacity;

	END SVGLoader;

(* Load some svg file *)
PROCEDURE LoadSVG*(svgName: ARRAY OF CHAR): SVG.Document;
VAR
	xml: XML.Document;
	root: XML.Element;
BEGIN
	xml := XMLLoader.LoadXML(svgName);
	IF xml = NIL THEN RETURN NIL END;

	root := xml.GetRoot();
	IF root = NIL THEN RETURN NIL END;

	RETURN LoadSVGEmbedded(root)
END LoadSVG;

(* Load some svg elements in parsed xml form *)
PROCEDURE LoadSVGEmbedded*(root: XML.Element): SVG.Document;
VAR loader: SVGLoader;
BEGIN
	NEW(loader);
	loader.LoadRoot(root);
	RETURN loader.GetDocument()
END LoadSVGEmbedded;

(* Load some svg file and force the resulting size to be width * height *)
PROCEDURE LoadSizedSVG*(svgName: ARRAY OF CHAR; width, height: SIGNED32): SVG.Document;
VAR
	xml: XML.Document;
	root: XML.Element;
	loader: SVGLoader;
BEGIN
	xml := XMLLoader.LoadXML(svgName);
	IF xml = NIL THEN RETURN NIL END;

	root := xml.GetRoot();
	IF root = NIL THEN RETURN NIL END;

	NEW(loader);
	loader.ForceSize(width, height);
	loader.LoadRoot(root);
	RETURN loader.GetDocument()
END LoadSizedSVG;

END SVGLoader.