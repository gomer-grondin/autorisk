package Risk::General;
#
#  general code for risk
#

use strict;

use Data::Dumper qw( Dumper );
use base 'Risk';
use SOAP::Lite;
use JSON;
use PGP;
use soapy;

my $soap;

sub mapid {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

sub mode {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

sub soapport {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

sub soapserver {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

sub keyid {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

sub name {  # name of general
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

sub _redemption_triple {
  my( $self, $h, $ts, $type, $rval ) = @_;
  for my $k ( keys %$h ) {
    $ts->{$k}{cardtype} eq $type or next;
    push @$rval, $k;
    @$rval == 3 and last;
  }
  $rval;
}

sub redemption {  # candidate for sub classing
  my( $self, $status, $input ) = @_;
  my $errstring = "redemption";
# $self->log( "       $self->{keyid} $errstring " );
  my @args = qw( name keyid mode mapid soapserver soapport gameid );
  for( @args ) { $input->{$_} = $self->{$_}; }
  
  $input->{manuever} = {};
  $input->{manuever}{stage} = $status->{stage};
  $input->{manuever}{activity} = $status->{activity};
  $input->{manuever}{redemption} = {};
  my $keyid = $self->{keyid};
  my $ts = $self->{static_map}{territories};
  if( $status->{players}{$keyid}{card_count} > 4 ) {
    my( $infantry, $calvary, $artillery, $wild ) = ( 0, 0, 0, 0 );
    my $h = $status->{players}{$keyid}{cards};
    for my $k ( keys %$h ) {
      $ts->{$k}{cardtype} eq 'wild'      and $wild++;
      $ts->{$k}{cardtype} eq 'infantry'  and $infantry++;
      $ts->{$k}{cardtype} eq 'calvary'   and $calvary++;
      $ts->{$k}{cardtype} eq 'artillery' and $artillery++;
    }
    my $r;
    if( $infantry and $calvary and $artillery ) {
      $r = [ qw( infantry artillery calvary ) ];
    } elsif( $wild and $infantry and $calvary ) {
      $r = [ qw( wild infantry calvary ) ];
    } elsif( $wild and $infantry and $artillery ) {
      $r = [ qw( wild infantry artillery ) ];
    } elsif( $wild and $calvary and $artillery ) {
      $r = [ qw( wild calvary artillery ) ];
    } 
    if( $r ) {
      for my $t ( @$r ) {
        for my $k ( keys %$h ) {
          $ts->{$k}{cardtype} eq $t or next;
          $input->{manuever}{redemption}{$k}++; 
          last;
        }
      }
      return $self->_soapy( $input, 'redemption', @args );
    }
    my $rval;
    if( $artillery > 2 ) {
      $rval = $self->_redemption_triple( $h, $ts, 'artillery' );
    } elsif( $calvary > 2 ) {
      $rval = $self->_redemption_triple( $h, $ts, 'calvary' );
    } elsif( $infantry > 2 ) {
      $rval = $self->_redemption_triple( $h, $ts, 'infantry' );
    }
    for( @$rval ) { $input->{manuever}{redemption}{$_}++; } 
  }
  return $self->_soapy( $input, 'redemption', @args );
}

sub reinforce {  # candidate for sub classing
  my( $self, $status, $input ) = @_;
  my $errstring = "reinforce";
# $self->log( "       $self->{keyid} $errstring " );
  my @args = qw( name keyid mode mapid soapserver soapport gameid );
  for( @args ) { $input->{$_} = $self->{$_}; }

  $input->{manuever} = {};
  $input->{manuever}{stage} = $status->{stage};
  $input->{manuever}{activity} = $status->{activity};
  my $t = $self->_find_reinforce_territory( $status );
  for ( keys %$t ) {
    $input->{manuever}{territories}{$_}{strength} = $t->{$_};
  }
  $self->_soapy( $input, 'reinforce', @args );
}

sub _occupied_continents {
  my( $self, $status, $rval ) = @_;
  my $tc = $self->{static_map}{continents};
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  for my $c ( keys %$tc ) {
    my $mine = 1;
    for my $t ( keys %$ts ) {
      $ts->{$t}{continent} eq $c or next;
      unless( $dm->{$t}{occupier} eq $self->{keyid} ) {
        $mine = 0;
        last;
      }
    }
    $mine and push @$rval, $c;
  }
  $rval or [];  
}

sub _find_reinforce_territory {
  my( $self, $status, $rt, $bt ) = @_;
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  my $s = $status->{strength};
  my $ratio = {};
  for my $t ( keys %$dm ) {
    $dm->{$t}{occupier} eq $self->{keyid} or next;
    $self->_is_insulated_territory( $status, $t ) and next; 
    $rt = { $t => $status->{strength} };
    my $b = @{$ts->{$t}{borders}};
    my $b2 = 0;
    for $bt ( @{$ts->{$t}{borders}} ) {
      $dm->{$bt}{occupier} eq $self->{keyid} or next;
      $b2++;  # how many border territories do I occupy?
    }
    $ratio->{$t} = $b2 / $b;
    my $r = -1;
    for( keys %$ratio ) {
      $ratio->{$_} > $r or next;
      $r = $ratio->{$_} and $rt = { $_ => $status->{strength} };
    }
  }
  $rt;
}

sub _is_insulated_territory { # any border adversaries?
  my( $self, $status, $t ) = @_;
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  for my $b ( @{$ts->{$t}{borders}} ) {
    $dm->{$b}{occupier} eq $self->{keyid} or return 0;
  }
  return $dm->{$t}{strength};
}

sub _find_weak_adversary {
  my( $self, $status, $tt ) = @_;
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  my ( $me, $thee, $ratio );
  for my $t ( keys %$ts ) {
    $dm->{$t}{occupier} eq $self->{keyid} and next;
    $thee = $dm->{$t}{strength}; $me = 0;
    for my $b ( @{$ts->{$t}{borders}} ) {
      $dm->{$b}{occupier} eq $self->{keyid} or next;
      if( $dm->{$b}{strength} > 3 ) {
        $me += $dm->{$b}{strength} - 2;
      }
    }
    $me and $me / $thee > $ratio and $ratio = $me / $thee and $tt = $t;
  }
  $tt;
}

sub _find_attack_territory { 
  my( $self, $status, $tt, $at ) = @_;
  $tt or return undef; 
  my $max = 0;
  my $dm = $status->{map}{dynamic}{territories};
  my $ts = $self->{static_map}{territories};
  for my $b ( @{$ts->{$tt}{borders}} ) {
    $dm->{$b}{occupier} eq $self->{keyid} or next;
    my $s = $dm->{$b}{strength};
    $s > 3 or next;
    $s > $max and $max = $s and $at = $b;
  }
  $at;
}

sub _find_insulated_territory { # want to move troops from here
  my( $self, $status, $ft ) = @_;
  my $dm = $status->{map}{dynamic}{territories};
  my $s = 1;
  for my $t ( keys %$dm ) {
    $dm->{$t}{occupier} eq $self->{keyid} or next;
    $self->_is_insulated_territory( $status, $t ) or next; 
    my $is = $dm->{$t}{strength};
    $is > $s and $s = $is and $ft = $t;
  }
  $ft;
}

sub _find_challenged_territory { 
  my( $self, $status, $ft, $adv, $tt, $max ) = @_;
  $ft or return undef;
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  # reinforce weakest neighbor
  $max = 99999;
  for my $b0 ( @{$ts->{$ft}{borders}} ) { 
    $dm->{$b0}{occupier} eq $self->{keyid} or next;
    $self->_is_insulated_territory( $status, $b0 ) and next;
    my $s = $dm->{$b0}{strength};
    $s < $max and $max = $s and $tt = $b0;
  }
  $tt;
}

sub _troop_movement {
  my( $self, $status, $input ) = @_;

  my $ft = $self->_find_insulated_territory( $status );
  my $tt = $self->_find_challenged_territory( $status, $ft );
  $ft and $tt or return '';
  my $ts = $status->{map}{dynamic}{territories};
  $ts->{$ft}{strength} > 1 or return '';
  $input->{manuever}{troops_from} = $ft;
  $input->{manuever}{troops_to}   = $tt;
  $input->{manuever}{strength}    = $ts->{$ft}{strength} - 1;
  $ft;
}

sub attack {  # candidate for sub classing
  my( $self, $status, $input ) = @_;
  my $errstring = "attack";
# $self->log( "       $self->{keyid} $errstring " );
  my @args = qw( name keyid mode mapid soapserver soapport gameid );
  for( @args ) { $input->{$_} = $self->{$_}; }

  $self->{manuever} = {};
  $input->{manuever}{stage} = $status->{stage};
  $input->{manuever}{activity} = $status->{activity};
  @args = qw( strength attack_from attack_to troops_from troops_to );
  for( @args ) { $input->{manuever}{$_} = undef; }

  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  if( $status->{card_awarded} ) {  # done attacking
    $self->_troop_movement( $status, $input );
  } else {  # do attack
    my $tt = $self->_find_weak_adversary( $status );
    my $ft = $self->_find_attack_territory( $status, $tt );
    if( $ft and $tt and $dm->{$ft}{strength} > 3 ) {
      $input->{manuever}{attack_from} = $ft;
      $input->{manuever}{attack_to}   = $tt;
    } else {
      $self->_troop_movement( $status, $input );
    }
  }
  $self->_soapy( $input, 'attack', @args );
}

sub conquest {  # candidate for sub classing 
  my( $self, $status, $input ) = @_;
  my @args = qw( name keyid mode mapid soapserver soapport gameid );
  for( @args ) { $input->{$_} = $self->{$_}; }
  my $errstring = "conquest";
# $self->log( "       $self->{keyid} $errstring " );

  $input->{manuever} = {};
  $input->{manuever}{stage} = $status->{stage};
  $input->{manuever}{activity} = $status->{activity};
  
  my $ft = $status->{from_territory};
  my $tt = $status->{to_territory};
  my $s  = $status->{map}{dynamic}{territories}{$ft}{strength};
  my $tm = $s > 6 ? int( $s / 2 ) + 1 : $s - 1;
  $input->{manuever}{from_territory} = $ft;
  $input->{manuever}{to_territory} = $tt;
  $input->{manuever}{troop_movement} = $tm;
  $self->_soapy( $input, 'conquest', @args );
}

sub register {
  my( $self, $input ) = @_;
  my @args = qw( name keyid mode mapid soapserver soapport );
  for( @args ) { $input->{$_} = $self->{$_}; }
  my $rval = eval { $self->_soapy( $input, 'register', @args ) };
  $@ and die $@;
  $rval;
}

sub wait_my_turn {
  my( $self, $input ) = @_;
  my @args = qw( name keyid mode mapid soapserver soapport gameid );
  for( @args ) { $input->{$_} = $self->{$_}; }
  my $rval = eval { $self->_soapy( $input, 'wait4turn', @args ) };
  $@ and die $@;
  $rval;
}

sub _soapy {
  my( $self, $input, $method, @args ) = @_;

  if( $input->{mode} eq 'local' ) {
    my $hash = soapy->$method( $input );
    return { hash => $hash };
  }

  print Dumper( $input ) . "\n";
  my $signed = PGP::pgp( $input, $input->{keyid} ); 
  $signed or die "bad Signature \n";

  unless( $soap ) { 
    my $SERVER = $input->{soapserver};
    my $PORT = $input->{soapport};

    $soap = SOAP::Lite
            -> uri("http://$SERVER:$PORT/soapy")
            -> proxy("http://$SERVER:$PORT/soapy" , timeout => 600 );

    $soap->autotype(0);
    $soap->default_ns('urn:soapy');
  }
  my $result = $soap->call($method, 
                SOAP::Data->name('name')->value( $signed ));
  
  if($result->fault) {
    my $m = join ', ',
      $result->faultcode,
      $result->faultstring,
      $result->faultdetail;
    die $m;
  }
  my $rval = $result->result();
  my $json = PGP::pgp( $rval );
  my $hash = decode_json( $json );
  { json => $json, hash => $hash };
}

1;
