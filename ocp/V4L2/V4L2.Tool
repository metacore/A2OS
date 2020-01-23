# ========================================
# V4L2 (Video For Linux 2) interface for UnixAos
#
# 13-04-2013
#
# Official V4L2 API spec is available at:  
#                   http://linuxtv.org/downloads/v4l-dvb-apis/
# ========================================

# Compile modules:

Compiler.Compile 
	V4L2/Unix.V4L2.Mod 
	V4L2/Unix.libv4l2.Mod 
	V4L2/Unix.VideoExample.Mod
	~
	
# run demo example:

	VideoExample.Start ~   			#start capturing on /dev/video0
	VideoExample.OpenPreview ~	 	# open preview window
	VideoExample.OpenControlWin ~ 	# open camera control gui
	VideoExample.ResetAllControls ~  
	VideoExample.Stop ~  			# stop capturing
	
# free modules:

	System.Free VideoExample libv4l2 V4L2 ~ 
	



	