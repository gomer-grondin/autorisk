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
  for my $k ( %$h ) {
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
      return _soapy( $input, 'redemption', @args );
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
  return _soapy( $input, 'redemption', @args );
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
  _soapy( $input, 'reinforce', @args );
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

sub _continent_borders {
  my( $self, $status, $rval ) = @_;
  my $c = $self->_occupied_continents( $status );
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  for my $co ( @$c ) {
    for my $t ( keys %$ts ) {
      $ts->{$t}{continent} eq $co or next;
      $self->_is_insulated_territory( $status, $t ) and next; 
      push @$rval, $t;
    }
  }
  $rval or [];
}

sub _find_reinforce_territory {
  my( $self, $status, $rt, $bt ) = @_;
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  my $s = $status->{strength};
  my $cb = $self->_continent_borders( $status );
  while( $s ) {
    for my $t ( @$cb ) {
      if( $s ) { $rt->{$t}++; $s--; }
    }
    $rt or last;
  }
  $rt and return $rt;
  my $ratio = {};
  for my $t ( keys %$ts ) {
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
  my ( $me, $thee, $ratio, $border_count );
  for my $t ( keys %$ts ) {
    $dm->{$t}{occupier} eq $self->{keyid} and next;
    $thee = $dm->{$t}{strength}; $me = 0;
    for my $b ( @{$ts->{$t}{borders}} ) {
      $dm->{$b}{occupier} eq $self->{keyid} or next;
      if( $dm->{$b}{strength} > 3 ) {
        $me += $dm->{$b}{strength} - 2;
        $border_count->{$t}++;
      }
    }
    $me and $ratio->{$t} = $me / $thee;
  }
  my( $bc );
  for ( keys %$border_count ) {
    $border_count->{$_} > $bc or next;
    $bc = $border_count->{$_};
  }
  while( $bc ) {
    my $r = 0;
    for ( keys %$ratio ) {
      $border_count->{$_} == $bc or next;
      $ratio->{$_} > $r or next;
      $r = $ratio->{$_};
      $r > 1 and $tt = $_;
    }
    $tt and last;
    $bc--;
  }
  $tt;
}

sub _find_attack_territory { 
  my( $self, $status, $tt, $at, $strongest, $weakest ) = @_;
  $tt or return undef; 
  my $max = 0;
  my $min = 9999999;
  my $dm = $status->{map}{dynamic}{territories};
  my $ts = $self->{static_map}{territories};
  for my $b ( @{$ts->{$tt}{borders}} ) {
    $dm->{$b}{occupier} eq $self->{keyid} or next;
    my $s = $dm->{$b}{strength};
    $s > 3 or next;
    $s > $max and $max = $s and $strongest = $b;
    $s < $min and $min = $s and $weakest = $b;
  }
  $at = $strongest;
  $dm->{$tt}{strength} > 3 and $self->{BIGFOOT} and $at = $weakest;
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
  $tt and return $tt;
  # move towards closest adversary 
  $max = 99999;
  for my $adversary ( keys %$ts ) {
    $dm->{$adversary}{occupier} eq $self->{keyid} and next;
    my $p = $self->_shortest_path( $ft, $adversary );
    if( ref $p eq 'ARRAY' ) {
      @$p < $max and $max = @$p and $tt = $p->[1] and $adv = $adversary; 
    }
  }
  $tt or return undef;
# find weakest territory bordering both from territory and adversary
  $max = 99999;
  for my $b0 ( @{$ts->{$ft}{borders}} ) { 
    $dm->{$b0}{occupier} eq $self->{keyid} or next;
    for my $b1 ( @{$ts->{$b0}{borders}} ) { 
      $b1 eq $adv or next;
      my $s = $dm->{$b1}{strength};
      $s < $max and $max = $s and $tt = $b0;
    }
  }
  $tt;
}

{
  my $cache;
  sub _shortest_path {
    my( $self, $t0, $t1 ) = @_;
    if( ref $cache->{$t0}{$t1} eq 'ARRAY' ) {
      $cache->{$t1}{$t0} ||= [ reverse @{$cache->{$t0}{$t1}} ];
      return $cache->{$t0}{$t1};
    }
    my $ts = $self->{static_map}{territories};
    for my $b0 ( @{$ts->{$t0}{borders}} ) { 
      $cache->{$t0}{$b0} ||= [ $t0, $b0 ];
      $cache->{$b0}{$t0} ||= [ $b0, $t0 ];
    }
    for my $b0 ( @{$ts->{$t0}{borders}} ) { 
      for my $b1 ( @{$ts->{$b0}{borders}} ) { 
        $cache->{$b0}{$b1} ||= [ $b0, $b1 ];
        $cache->{$b1}{$b0} ||= [ $b1, $b0 ];
        $cache->{$t0}{$b1} ||= [ $t0, $b0, $b1 ];
        $cache->{$b1}{$t0} ||= [ $b1, $b0, $t0 ];
      }
    }
    for my $b0 ( @{$ts->{$t0}{borders}} ) { 
      for my $b1 ( @{$ts->{$b0}{borders}} ) { 
        for my $b2 ( @{$ts->{$b1}{borders}} ) { 
          $cache->{$b1}{$b2} ||= [ $b1, $b2 ];
          $cache->{$b2}{$b1} ||= [ $b2, $b1 ];
          $cache->{$b0}{$b2} ||= [ $b0, $b1, $b2 ];
          $cache->{$b2}{$b0} ||= [ $b2, $b1, $b0 ];
          $cache->{$t0}{$b2} ||= [ $t0, $b0, $b1, $b2 ];
          $cache->{$b2}{$t0} ||= [ $b2, $b1, $b0, $t0 ];
        }
      }
    }
    for my $b0 ( @{$ts->{$t0}{borders}} ) { 
      for my $b1 ( @{$ts->{$b0}{borders}} ) { 
        for my $b2 ( @{$ts->{$b1}{borders}} ) { 
          for my $b3 ( @{$ts->{$b2}{borders}} ) { 
            $cache->{$b2}{$b3} ||= [ $b2, $b3 ];
            $cache->{$b3}{$b2} ||= [ $b3, $b2 ];
            $cache->{$b1}{$b3} ||= [ $b1, $b2, $b3 ];
            $cache->{$b3}{$b1} ||= [ $b3, $b2, $b1 ];
            $cache->{$b0}{$b3} ||= [ $b0, $b1, $b2, $b3 ];
            $cache->{$b3}{$b0} ||= [ $b3, $b2, $b1, $b0 ];
            $cache->{$t0}{$b3} ||= [ $t0, $b0, $b1, $b2, $b3 ];
            $cache->{$b3}{$t0} ||= [ $b3, $b2, $b1, $b0, $t0 ];
          }
        }
      }
    }
    if( ref $cache->{$t0}{$t1} eq 'ARRAY' ) {
      return $cache->{$t0}{$t1};
    }
    undef;
  }
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

sub _is_empire {  # is given territory part of occupied continent?
  my( $self, $status, $t ) = @_;
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  my $c = $ts->{$t}{continent};
  my $o = $dm->{$t}{occupier};
  for my $t2 ( keys %$ts ) {
    $ts->{$t2}{continent} eq $c or next;
    $dm->{$t2}{occupier} eq $o or return 0;
  }
  return 1;
}

sub _troop_ratio {  
  my( $self, $status, $mt, $others ) = @_;
  my $ts = $self->{static_map}{territories};
  my $dm = $status->{map}{dynamic}{territories};
  for my $t ( keys %$ts ) {
    if( $dm->{$t}{occupier} eq $self->{keyid} ) {
      $mt += $dm->{$t}{strength};
    } else {
      $others += $dm->{$t}{strength};
    }
  }
  $others ? $mt / $others : 0;
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
  $self->{BIGFOOT} = 0;
  if( $self->_troop_ratio( $status ) > 1 )  {  # TODO abstract to param
    $self->{BIGFOOT} = 1;
    my $tt = $self->_find_weak_adversary( $status );
    my $ft = $self->_find_attack_territory( $status, $tt );
    if( $ft and $tt and $dm->{$ft}{strength} > 3 ) {
      $input->{manuever}{attack_from} = $ft;
      $input->{manuever}{attack_to}   = $tt;
      return _soapy( $input, 'attack', @args );
    }
  }
  my $cb = $self->_continent_borders( $status );
  for my $t ( @$cb ) {
    # are bordering territories part of empire (occupied continent)?
    # if so, attack if strong enough
    # otherwise, leave alone
    my ( $bcount );
    for my $b ( @{$ts->{$t}{borders}} ) {
      $dm->{$b}{occupier} eq $self->{keyid} and next; 
      $bcount++;  
    }
    $bcount > 1 and next; # avoid complex borders
    for my $b ( @{$ts->{$t}{borders}} ) {
      $dm->{$b}{occupier} eq $self->{keyid} and next; 
      $self->_is_empire( $status, $b ) or next;
      my $s = $dm->{$t}{strength};
      if( $s > $dm->{$b}{strength} and $s > 10 ) {
        $input->{manuever}{attack_from} = $t;
        $input->{manuever}{attack_to}   = $b;
        return _soapy( $input, 'attack', @args );
      }
    }
  }
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
  _soapy( $input, 'attack', @args );
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
  my $to = $status->{map}{dynamic}{territories}{$tt}{occupier};
  $status->{map}{dynamic}{territories}{$tt}{occupier} = $self->{keyid};
  $self->_is_insulated_territory( $status, $ft ) and $tm = $s - 1;
  $self->{BIGFOOT} and $tm = $s - 1;
  $self->_is_insulated_territory( $status, $tt ) and $tm = $s > 3 ? 3 : $s - 1;
  $status->{map}{dynamic}{territories}{$tt}{occupier} = $to; # change back
  $input->{manuever}{from_territory} = $ft;
  $input->{manuever}{to_territory} = $tt;
  $input->{manuever}{troop_movement} = $tm;
  _soapy( $input, 'conquest', @args );
}

sub register {
  my( $self, $input ) = @_;
  my @args = qw( name keyid mode mapid soapserver soapport );
  for( @args ) { $input->{$_} = $self->{$_}; }
  my $rval = eval { _soapy( $input, 'register', @args ) };
  $@ and die $@;
  $rval;
}

sub wait_my_turn {
  my( $self, $input ) = @_;
  my @args = qw( name keyid mode mapid soapserver soapport gameid );
  for( @args ) { $input->{$_} = $self->{$_}; }
  my $rval = eval { _soapy( $input, 'wait4turn', @args ) };
  $@ and die $@;
  $rval;
}

sub _soapy {
  my( $input, $method, @args ) = @_;

  if( $input->{mode} eq 'local' ) {
    my $hash = soapy->$method( encode_json( $input ) );
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
