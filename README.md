# shellf
Shellf is a set of little utility programs (shell scripts) for helping on some day-to-day desktop tasks.


License
-------
These programs are free software; you can redistribute them and/or modify them under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.


Dependencies
------------
These utilities tries at most be POSIX compliant, using POSIX shell compliant syntax, and using well known GNU versions of the basics unix world programs.


Development stages
------------------
 0. requirement -> someone realized that something is needed;
 1. conception  -> just exploring the idea, writing some papers;
 2. draft       -> designing some things, writing some code;
 3. prototype   -> the code works at some level, but can't be used for real;
 4. alpha       -> almost finished, but some little tests and ajustments are needed;
 5. beta        -> prepared for user tests;
 6. delta       -> finished and fully usable, still making improvements;
 7. mature      -> it has been in good use, for a good time, but no improvements anymore;
 8. legacy      -> most of its user base decreased, little maintanence;
 9. abandoned   -> no known user base, no maintanence;
10. unavailable -> the program cannot be found anymore;



Nomad GNU POSIX Desktop Backup Utility
======================================
Nomad creates simple backup files using mainly the GNU tar archiving utility.


Dependencies
------------
Nomad is a POSIX compliant Desktop Backup Utility (a shell script actually) that relies only on the GNU coreutils, i.e. GNU version of the POSIX basic tools (a POSIX compliant shell, env, test, echo, getent, basename, mkdir, cp, mv, rm, rmdir, ls, touch, cat, tail, chmod, hostname, date, wc, bc, cut, grep, sed, tar). There's a bunch of dependencies, but if you're using a relative modern Unix like operating system, they usually are already installed. Anyway, the program will do a little check before it gets its hands on the work.


Operation
---------
The intent of the program, is to save configurations on one system at a certain time, and restore this configuration on any other system, at any other time. Due to Unix's nature, this usually means backing up some config files and/or running some commands. Nomad can do both these things in a way that keeps different configurations under different names, meaning that they can be executed in an isolated fashion, i.e., you don't need to restore the whole system configuration, you can restore just a piece of it.
The program operates just like if it was the user. The two major operations are packing (creating a tarball file with all what is needed for restoring) and unpacking (restore configurations that are inside some file).




Passafe password safe utility
=============================
Passafe keeps an encrypted password database file.


Dependecies
-----------
Passafe depends mainly on gpg for operating de encryption and decryption of the password database




Recycle utility
===============
Recycle is used to keep those files or directories that you want to wipe out of the filesystem, but you're not sure if you really can remove them. It will send then to a recycle bin, where you can restore them later or finally vanish them from the disk.


Dependecies
-----------
Recycle depends mainly on the tar archiving utility.
