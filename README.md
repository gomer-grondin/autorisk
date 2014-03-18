autorisk
========

Autorisk is a bot creation environment for the classic board game .. Please see my youtube channel for introductory instructional videos @ https://www.youtube.com/user/ytgomer

it runs in one of two modes, local or tournament.  Use local mode for quicker game play during developement, and tournament mode for competition.  Local mode uses the same validation and communications as tournament mode, but does not use crypto, and does not serialize to JSON for IPC from the server to / from the player.  Lots of the files published are only useful in tournament mode (listed below).  

It may be challenging to first get this environment running.  Some of the requisite modules require some CPAN knowledge, others may be part of your (linux) distribution.  Crypt::OpenPGP is sometimes challenging as it is pure perl and requires lots of math libraries as a requisite. 

These files are only used for tournament mode:
  IPCPGP.pl, 
  server, 
  start_server.bash, 
  kill_offspring, 
  kill_soap, 
  modules/PGP.pm, 
  modules/SOAP, 
  gnupg (install your your .gnupg or use your own)
  
  
