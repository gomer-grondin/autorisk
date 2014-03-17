#!/usr/bin/perl
#

use strict;
use IPC::ShareLite qw( :lock );

while( <> ) {
  chomp;
  print $_ . "\n";
  IPC::ShareLite->new( -key => $_, -create => 'yes', -destroy => 'yes' ) 
       or die $!;
  1;
}

