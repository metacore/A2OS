
Notes:

1. At first put unpacked content of DarwinA2 build (download fresh build from FTP server maintained by Guenter Feldmann at http://www.informatik.uni-bremen.de/~fld/UnixAos/) into folder "A2 64".

2. Before building installer (for building of installer Packages app used from http://s.sudre.free.fr/Software/Packages/about.html) run this command in terminal for whole folder contents for ensuring proper file modes (without this step obtained installer may not function properly). Here and after assumed that whole this folder content placed at the root of drive "work":

	sudo chmod -R u=rwx,g=rwx,o=rx /Volumes/work/DarwinA2\ Installer

3. For obtaining of .dmg disk image from .pkg file run this command in terminal:

	hdiutil create -volname DarwinA2\ 64\ Installer -srcdir /Volumes/work/DarwinA2\ Installer/Output -ov -format UDZO /Volumes/work/DarwinA2\ Installer/DarwinA2\ 64\ Installer.dmg

4. X11 is no longer included with macOS, but X11 server and client libraries are available from the XQuartz project. Install XQuartz manually before installation of A2 (Use a community-supported version of the X11 windowing system for Mac OS-X 10.6.3 or later. Please visit http://www.xquartz.org for more information).