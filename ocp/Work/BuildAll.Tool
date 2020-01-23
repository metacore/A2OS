Before compilation add root "Work" and "Work/Resources"
folders to Paths.Search parameter (in listed sequence) in aosg.ini (or better
do a copy named "myaos.ini" and make changes in it)

To enable a dark color scheme in PET add "Branch" folder to Paths.Search parameter
and add this to Configuration.XML:

		<Section name="Applications">
			<Section name="PET">
				<Section name="General">
					<Setting name="BackgroundColor" value="0004080FFH"/>

*** A2 sources improvements and small modifications ("Branch") ***

Compiler.Compile -p=Win32

	Branch/WMTextView.Mod
	Branch/PETTrees.Mod
	Branch/PET.Mod ~

*** Bindings ***

Compiler.Compile -p=Win32

	Bindings/BASS/Windows.BASS.Mod
	Bindings/Windows.Pipe.Mod
	Bindings/Windows.UnRAR.Mod ~

Compiler.Compile -p=Unix32
	Bindings/BASS/Unix.BASS.Mod ~

*** Libraries ***

Compiler.Compile -p=Win32

	Libs/AAGraphics.Mod
	Libs/CanvasTools.Mod

	Libs/MathUtils.Mod
	Libs/Windows.PreciseTimer.Mod
	
	(* deprecated *)
	Libs/Containers.Mod

	Libs/Generics.Mod ~

*** Components ***

Compiler.Compile -p=Win32

	Components/WMChart.Mod
	Components/WMComboBox.Mod
	Components/WMLCD.Mod
	Components/WMLEDLadder.Mod ~

*** Dialogs ***

Compiler.Compile -p=Win32

	Dialogs/WMColorPicker.Mod ~

*** Examples ***

Compiler.Compile -p=Win32

	Examples/RegExp/RegExpNFA.Mod
	Examples/RegExp/RegExpMaps.Mod
	Examples/RegExp/RegExpDFA.Mod
	Examples/RegExp/RegExpSubsetConstruct.Mod
	Examples/RegExp/RegExpParse.Mod

	Examples/WMAAGraphicsExample.Mod ~

*** Tools ***

Compiler.Compile -p=Win32

	Tools/ImportCollector.Mod
	Tools/ImportGraph.Mod
	Tools/PascalScanner.Mod
	Tools/PascalProjectCombine.Mod
	Tools/Windows.WinStarter.Mod ~

*** Demos ***

Compiler.Compile -p=Win32

	Demos/WMAStar.Mod
	Demos/WMAStarSet.Mod

	Demos/VisualContainer/VCTypes.Mod
	Demos/VisualContainer/VCPoly.Mod
	Demos/VisualContainer/VCBase.Mod
	Demos/VisualContainer/VCObjects.Mod
	Demos/VisualContainer/WMVC.Mod	

	Demos/WMFM.Mod
	Demos/WMRaycaster.Mod
	Demos/WMRaycasterMaze.Mod
	Demos/WMColorLines.Mod
	Demos/WMXmas.Mod
	Demos/WMBass3DTest.Mod
	Demos/WMBassDSPTest.Mod
	 ~

Run demos

	WMAStar.Open ~
	WMAStarSet.Open ~
	WMBass3DTest.Open ~
	WMBassDSPTest.Open ~
	WMColorLines.Open ~
	WMRaycaster.Open ~
	WMRaycasterMaze.Open ~
	WMXmas.Open ~


