reallyfastestmirror - Yum repository mirror speed estimation tool
=================================================================

This tool downloads mirrorlist files for specified repositories,
ranks each host for speed and writes out mirrorlist files where
fastest mirrors appear on top.

New mirrorlist files with speed rankings may now be used with
yum, by putting their path into yum.repos.d conf files, like

    mirrorlist=file:///path/to/mirrorlist.txt

Using
-----

Create files in ./conf/repos and ./conf/arches to specify which
repositories to process and for which architectures.

Then run the script reallyfastestmirror.sh in the directory that
contains the ./conf directory.

