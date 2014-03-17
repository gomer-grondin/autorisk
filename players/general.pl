#!/usr/bin/perl
#
#  general code for risk
#

use strict;

use Data::Dumper;
use Risk::General;

my $usage = <<HERE
  USAGE: general.pl <args>
    args: one each of; name, keyid, soapserver, soapport
          zero or one of : mode, mapid 
     example: \$PATH/general.pl name=gomer keyid=542DA246 soapserver=mercury soapport=38087 mode=tournament

HERE
;

$| = 1;
my $args;
for ( @ARGV ) {
  /\S=\S/ or next;
  my ( $k, $v ) = split '=';
  $args->{$k}=$v;
}

$args->{mode}  ||= 'tournament';
{
  my @v = qw( tournament local );
  grep { $args->{mode} eq $_ } @v or die $usage;
}
$args->{mapid} ||= 'map1000';
my @args = qw( name keyid soapserver soapport );
for ( @args ) { exists $args->{$_} or die $usage; }

my $self = new Risk::General( $args );

my $state;
# register
# 
my $registration = eval { $self->register() };
$@ and die 'register : ' . Dumper( $registration ) . $@;
{
  my $m = exists $registration->{hash}{errstr} ? 
                 $registration->{hash}{errstr} : '';
  $m and die "register : $m";
}
$self->{static_map} = $registration->{hash}{map};
$self->{gameid} = $registration->{hash}{gameid};
$self->{gameid} or die Dumper( $registration );

my ( $status, $static_map );
until( $status->{hash}{stage} eq 'setup' ) {
  $status = $self->wait_my_turn();
}
#  setup stage -- deploy troops -- before hostilities
#     each general selects one of the territories assigned to him
#     and adds one troop

while( $status->{hash}{stage} eq 'setup' ) {
  $status = $self->reinforce( $status->{hash} );
}

#  hostilities stage -- 
#    1) deploy assigned reinforcments
#    2) redeem cards and deploy reinforcments
#    3) attack ....
#    4) troop movement
#

until( $status->{hash}{stage} eq 'hostilities' ) {
  $status = $self->wait_my_turn();
}
while( $status->{hash}{stage} eq 'hostilities' ) {
  my $h = $status->{hash};
  my $s;
  my $m = $h->{activity};
  $self->can( $m ) or die "activity $m unknown";
  $s = $self->$m( $h ) or die;
  $status = $s; undef $s;
  $h = $status->{hash};
  if( $h->{activity} eq 'victory' ) { 
    die $args->{name} . " : Victory is mine\n";
  }
  if( $h->{activity} eq 'defeat' ) {
    die $args->{name} . " : Arghh .. the agony of defeat\n";
  }
}

print "END OF GAME .. status = " . Dumper( $status ) . "\n";
print "END OF GAME .. stage  = " . Dumper( $status->{hash} ) . "\n";
