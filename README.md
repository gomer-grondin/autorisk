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
  gnupg (install to your .gnupg or use your own)
  
  
The gd.pl file may be a good starting place for understanding the details of the protocol between player and server.  the log files that are input to this script are in the same format as the status messages that the server sends to you when it is your turn.  the 'input' section of this structure shows what the server expects when you make your manuever.  The generated png files from this script should give you a good idea what the log files contain.  NOTE:  I've recently added a 'stats' section to the log files but have not rendered them on the png files.  This section keeps track of dice rolls and results of battles.  Those of you who wish to ignore the law of independent trials may find this useful in your decision tree.  

thanks to Maggie for recommending that I punch up this README, I had been relying on the youtube videos.  Your input is also solicited.
