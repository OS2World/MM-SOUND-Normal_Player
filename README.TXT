Normal Player

This is a OS/2 Multimedia player. It will play sound and video files in 
any format MMOS/2 supports.

I wrote this for several reasons:

1. The OS/2 Multimedia Infrastructure Project

New media formats have been appearing over the years, however IBM has had
little interest in adding support for these format into OS/2.  Other
developers have created their own stand alone players for these formats.
Each player support different sets of media formats tied to their own
interface.  The idea of the OS/2 Multimedia Infrastructure Project is to
use MMOS/2 expandability to add support for new formats using open OS/2
standards.  This will mean any media format supported by MMOS/2 and played
using any interface that supports MMOS/2.  I also hope to not only add new
formats to MMOS/2, but add new features to MMOS/2.  This will require new
players to support these new features.  Also, people have had issues with
stability of the standard MMOS/2 players.  With a new player this can be
resolved.  The home page for this the project:
http://www.reamined.on.ca/doconnor/mmos2/

2. Support Interface Standards

These days many media players being developed have a phobia about 
supporting user interface standards of their operating system. This is as 
true for Windows and MacOS as it has been for OS/2. I'm designing Normal 
Player around standard OS/2 controls, which will allow it to work and look
exactly like OS/2 users expect. At the same time they will still be 
highly customizable thanks to OS/2's capabilities. This website discusses 
what's wrong with ignoring user interface standards: 
http://www.iarchitect.com/qtime.htm

3. I hate C

A lot of my programming with OS/2 has been porting UNIX programs written
in C. While this allows me to add large and useful applications to the
OS/2 library with relatively little effort, it constantly reminds me why I
prefer Pascal over C. C is annoyingly case sensitive.  C has header files.
C has makefiles.  They've created layers and layers of other things to try
and make it cross platform and easier to compile without succeeding in
either and required the programmer to learn several additional languages
to work with the program.  Normal Player has been developed from scratch
using Virtual Pascal.  Virtual Pascal is a free compiler based on
Borland's version Pascal.  The Virtual Pascal homepage is
http://www.vpascal.com/


This program is very much a work in progress and at it's present state,
not very useful.  This follows the open source idea of "Release Early,
Release Often".

You can open files entering a command line paramter, enter the name in the
entry-field and press Open, using the File|Open to get a file dialog, or 
drag and drop the file.

If you have the Netscape Plug-in Pack installed you can stream media files
directly from the Internet.  Entering a url to a media file and pressing
Open will work, even Internet mp3 radio station will work, if you have a
mp3 support for MMOS/2.  If you don't want it to cache what you download
prepend the url with "ipipe:".  See my brother's page for more
information:  http://www.math.berkeley.edu/~roconnor/MMIOMP3/stream.html

Darwin O'Connor
doconnor@reamined.on.ca
