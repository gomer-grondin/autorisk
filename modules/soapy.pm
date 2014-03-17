package soapy;

use JSON;
use Data::Dumper qw(Dumper);
use Exporter;
use Map;
use IPC;
use PGP;
use strict;

# base class of this(Arithmetic) module
our @ISA = qw(Exporter);

# Exporting the add and subtract routine
our @EXPORT = qw( register );
# Exporting the multiply and divide  routine on demand basis.
our @EXPORT_OK = qw();

my $server_keyid = '542DA246';
my $defaultmap = 'map1000';
my $defaultmode = 'tournament';

my $statedir = $ENV{STATEDIR} or die "STATEDIR not defined";
my $gamestatusfile = "$statedir/gamestatus";

our $shares = $IPC::shares;
my ( $status, $staticmap, $carddeck );

sub redemption {  # validate manuever
  shift;
  $|=1;
  my $i = shift;
  my $input = ref $i eq 'HASH' ? $i : decode_json( PGP::pgp( $i ) );
  _lock_gameshare( $input );
  $status->{stage} eq $input->{manuever}{stage} or die;
  $status->{activity} eq $input->{manuever}{activity} or die;

  my $keyid = $input->{keyid};
  my $cardtype = { infantry => 0, calvary => 0, artillery => 0, wild => 0 };
  my $h = $input->{manuever}{redemption};
  my $t = $staticmap->{territories};
  if( $status->{players}{$keyid}{card_count} > 4 ) {
    keys %$h == 3 or die;
  }
  unless( keys %$h ) {  # not redeeming now .. but thanks for asking
    _calculate_reinforce();
    return _wait4turn( $input );  # dont wait .. still my turn
  }
  keys %$h == 3 or die;
  for my $k ( keys %$h ) {
    exists $t->{$k} or die;
    my $c = $t->{$k}{cardtype};
    exists $cardtype->{$c} or die;
    $cardtype->{$c}++;
    delete $status->{players}{$keyid}{cards}{$k};
    $status->{players}{$keyid}{card_count}--;
    push @$carddeck, $k;
  }
  $carddeck = _scramble( $carddeck );
  IPC::share_store( 'carddeck', encode_json( $carddeck ) );
  my $rval = 0;
  my $r = 1; # redeemed flag

  $r and $cardtype->{infantry}  > 2 and $r = 0, $status->{strength} += 4; 
  $r and $cardtype->{calvary}   > 2 and $r = 0, $status->{strength} += 6;
  $r and $cardtype->{artillery} > 2 and $r = 0, $status->{strength} += 8; 
  $r and $status->{strength} += 10;
  $status->{players}{$keyid}{card_count} >= 0 or die;
  if( $status->{players}{$keyid}{card_count} > 4 ) {
    $status->{activity} = 'redemption';
  } else {
    _calculate_reinforce();
  }
  _wait4turn( $input );  # dont wait .. still my turn
}

sub attack {  # validate manuever
  shift;
  $|=1;
  my $i = shift;
  my $input = ref $i eq 'HASH' ? $i : decode_json( PGP::pgp( $i ) );
  _lock_gameshare( $input );
  $status->{stage} eq $input->{manuever}{stage} or die;
  $status->{activity} eq $input->{manuever}{activity} or die;

  my $af = $input->{manuever}{attack_from};
  my $at = $input->{manuever}{attack_to};
  my $tf = $input->{manuever}{troops_from};
  my $tt = $input->{manuever}{troops_to};
  my $s  = $input->{manuever}{strength};

  $af or $at or $tf or $tt or return _next_turn( $input );
  my $ts = $status->{map}{dynamic}{territories};
  if( $tf and $tt and $s ) {
    $ts->{$tf}{occupier} eq $input->{keyid} or die; 
    $ts->{$tt}{occupier} eq $input->{keyid} or die; 
    $ts->{$tf}{strength} > $s               or die;
    $ts->{$tf}{strength} -= $s;
    $ts->{$tt}{strength} += $s;
    return _next_turn( $input );
  }
  if( $af and $at ) { 
    $ts->{$af}{occupier} eq $input->{keyid} or  die; 
    $ts->{$at}{occupier} eq $input->{keyid} and die; 
    $ts->{$af}{strength} > 1                or  die;
    my $as = $ts->{$af}{strength};
    my $ad = $as > 3 ? 3 : $as - 1;  # number of dice attacking
    my $ds = $ts->{$at}{strength};
    my $dd = $ds > 2 ? 2 : 1;        # number of dice defending
    my( @adv, @adv2, @ddv, @ddv2 );
    for( 1 .. $ad ) { push @adv, int(rand(6))+1; }
    for( 1 .. $dd ) { push @ddv, int(rand(6))+1; }
    @adv2 = reverse sort @adv;
    @ddv2 = reverse sort @ddv;
    if( $adv2[0] > $ddv2[0] ) {  # attacker wins
      $ts->{$at}{strength}--;
    } else {
      $ts->{$af}{strength}--;
    }
    if( $dd == 2 ) {
      if( $adv2[1] > $ddv2[1] ) {  # attacker wins
        $ts->{$at}{strength}--;
      } else {
        $ts->{$af}{strength}--;
      }
    }
    $status->{activity} = 'attack';
    if( $ts->{$at}{strength} eq 0 ) {
      my $ts = $status->{map}{dynamic}{territories};
      $status->{activity} = 'conquest';
      $status->{from_territory} = $af;
      $status->{to_territory} = $at;
    }
  }
  _wait4turn( $input ); # dont wait .. still my turn
}

sub conquest {  # validate manuever
  shift;
  $|=1;
  my $i = shift;
  my $input = ref $i eq 'HASH' ? $i : decode_json( PGP::pgp( $i ) );
  _lock_gameshare( $input );
  $status->{stage} eq $input->{manuever}{stage} or die;
  $status->{activity} eq $input->{manuever}{activity} or die;

  my $ft = $input->{manuever}{from_territory};
  my $tt = $input->{manuever}{to_territory};
  my $s = $status->{map}{dynamic}{territories}{$ft}{strength};
  my $tm = $input->{manuever}{troop_movement};
  $s > $tm or die;
  $status->{card_awarded} = 1;
 
  my $keyid = $input->{keyid}; 
  my $ts = $status->{map}{dynamic}{territories};

  my $conquered_general = $ts->{$tt}{occupier};
  $ts->{$ft}{strength} -= $tm;
  $ts->{$tt}{strength} += $tm;
  $ts->{$tt}{occupier} = $keyid;

  $status->{activity} = 'attack';
  unless( _territory_count( $conquered_general ) ) {
    # general is defeated .. take cards
    for( keys %{$status->{players}{$conquered_general}{cards}} ) {
      $status->{players}{$conquered_general}{card_count}--;
      delete $status->{players}{$conquered_general}{cards}{$_};
      $status->{players}{$keyid}{card_count}++;
      $status->{players}{$keyid}{cards}{$_}++;
    }
    if( $status->{players}{$keyid}{card_count} > 5 ) { 
      $status->{activity} = 'redemption';
    }
  } 
  _wait4turn( $input );  # dont wait .. still my turn
}

sub _log {
  my ( $f ) = @_;
  IPC::share_lock( 'logsequence' );
  my $seq = IPC::share_fetch( 'logsequence' );
  $seq = $seq > 0 ? $seq + 1 : 10000;
  IPC::share_store( 'logsequence', $seq );
  IPC::share_unlock( 'logsequence' );
  $f  = "$statedir/" . $status->{input}{gameid} and mkdir $f;
  $f .= "/png/"                                 and mkdir $f;
  $f .= $seq . ".log";
  _fileout( $f, encode_json( $status ) );
}

sub _lock_gameshare {
  my( $input, $f ) = @_;
  $shares->{gameid}{keyid} = $input->{gameid};
  IPC::share_lock( 'gameid' );
  IPC::share_lock( 'turn' );
  if( $input->{mode} eq 'tournament' ) {
    $status = decode_json( IPC::share_fetch( 'gameid' ) );
    $carddeck = decode_json( IPC::share_fetch( 'carddeck' ) );
  }
  $status->{input} = $input;
  _log();
  $staticmap ||= decode_json( IPC::share_fetch( 'staticmap' ) );
  $status;
}

sub reinforce {  # validate manuever
  shift;
  $|=1;
  my $i = shift;
  my $input = ref $i eq 'HASH' ? $i : decode_json( PGP::pgp( $i ) );
  _lock_gameshare( $input );
  $status->{stage} eq $input->{manuever}{stage} or die;
  $status->{activity} eq $input->{manuever}{activity} or die;
  my $h = $input->{manuever}{territories};
  my $ts = $status->{map}{dynamic}{territories};
  for my $t ( keys %$h ) {
    $ts->{$t}{occupier} eq $input->{keyid} or die;
    my $s = $h->{$t}{strength};
    $s <= $status->{strength} or die;
    $status->{strength} -= $s;
    $ts->{$t}{strength} += $s;
  }
  $status->{strength} > 0 and die;
  $status->{server} = $server_keyid; 
  $status->{player} = $input->{keyid};
  if( $status->{setup_count} == 1 ) {  # switch to hostilities stage
    $status->{stage} = 'hostilities';
    $status->{setup_count} = -1; # turn off setup processing
    $status->{activity} = 'reinforce'; 
    return _next_turn( $input );
  }
  $status->{stage} eq 'setup' and return _next_turn( $input );
  $status->{activity} = 'attack';
  _wait4turn( $input ); # dont wait .. still my turn (hostile stage)
}

sub _calculate_redemption { # is it possible to redeem cards?
  my ( $rval ) = @_;
  my $keyid = @{$status->{turnorder}}[$status->{turnindex}];
  return 0 if( $status->{players}{$keyid}{card_count} < 3 );
  my( $infantry, $calvary, $artillery, $wild ) = ( 0, 0, 0, 0 );
  my $h = $status->{players}{$keyid}{cards};
  my $ts = $staticmap->{territories};
  for my $k ( keys %$h ) {
    $ts->{$k}{cardtype} eq 'wild'      and $wild++;
    $ts->{$k}{cardtype} eq 'infantry'  and $infantry++;
    $ts->{$k}{cardtype} eq 'calvary'   and $calvary++;
    $ts->{$k}{cardtype} eq 'artillery' and $artillery++;
  }
  $wild                                 and $rval = 1;
  $infantry > 2                         and $rval = 1;
  $calvary  > 2                         and $rval = 1;
  $artillery > 2                        and $rval = 1;
  $infantry and $artillery and $calvary and $rval = 1;
  $rval or return 0;
  $status->{activity} = 'redemption'; # offer card redemption
  $rval;
}

sub _calculate_reinforce {
  my ( $rval ) = @_;
  if( $status->{already_calculated_reinforce} ) {
    $status->{activity} = 'reinforce'; 
    return; 
  }
  my $keyid = @{$status->{turnorder}}[$status->{turnindex}];
  my $tcount = _territory_count( $keyid );
  my $dm = $status->{map}{dynamic}{territories};
  my $ts = $staticmap->{territories};
  $rval = int( $tcount / 3 );
  $rval > 2 or $rval = 3;
  for my $c ( keys $staticmap->{continents} ) {
    my $c2 = 1; # assume that this player controls this continent
    for my $t ( keys $ts ) {
      $ts->{$t}{continent} eq $c or next;
      unless( $dm->{$t}{occupier} eq $keyid ) {
        $c2 = 0;
        last;
      }
    }
    $c2 and $rval += $staticmap->{continents}{$c};
  }
  $status->{activity} = 'reinforce'; 
  $status->{already_calculated_reinforce} = 1;
  $status->{strength} += $rval;
}

sub _territory_count {  # how many territories occupied by player
  my ( $keyid ) = @_;
  my $ts = $status->{map}{dynamic}{territories};
  exists $status->{total_territories} or 
         $status->{total_territories} = keys %$ts;
  my $c = 0;
  for( keys %$ts ) {
    $ts->{$_}{occupier} eq $keyid and $c++;
  }
  $c;
}

sub _bump_turnindex {  # make sure player is still in the game
  my ( $input, $c, $keyid ) = @_;
  until( $c ) {
    $status->{turnindex}++;
    $status->{turnindex} > 5    and $status->{turnindex} = 0; 
    $keyid = @{$status->{turnorder}}[$status->{turnindex}];
    $c = _territory_count( $keyid ) or _player_defeated( $keyid );
  }
  $keyid;
}

sub _player_defeated {
  my( $keyid ) = @_;
  unless( exists $status->{defeated}{$keyid} ) {
    $status->{defeated}{$keyid}++;
    my $name = $status->{players}{$keyid}{name};
    print "$$ $name is defeated \n";
    $status->{activity} = 'defeat';
    IPC::share_store( 'gameid', encode_json( $status ) );
    IPC::share_unlock( 'gameid' );
    IPC::share_store( 'turn', $keyid );
    IPC::share_unlock( 'turn' );
    sleep 2;
    IPC::share_lock( 'turn' );
    IPC::share_lock( 'gameid' );
  }
}

sub _next_turn {
  my ( $input ) = @_;
  if( $status->{card_awarded} ) {
    my $k = $input->{keyid};
    my $c = shift @$carddeck;
    IPC::share_store( 'carddeck', encode_json( $carddeck ) );
    $status->{players}{$k}{card_count}++;
    $status->{players}{$k}{cards}{$c}++;
    my $ts = $status->{map}{dynamic}{territories};
    $ts->{$c}{occupier} eq $k and $ts->{$c}{strength} += 2;
  }
  my $keyid = _bump_turnindex( $input );
  $status->{strength} = 0;
  $status->{card_awarded} = 0;
  $status->{already_calculated_reinforce} = 0;
  if( $status->{stage} eq 'setup' ) {
    $status->{strength} = 1;
    $status->{setup_count}--;
  }
  IPC::share_store( 'turn', $keyid );
  if( $status->{stage} eq 'hostilities' ) { # redemption possible?
    _calculate_redemption() or _calculate_reinforce();
  }
  _wait4turn( $input, 1 ); # wait, not my turn anymore 
}

sub _wait4turn {
  my( $input, $wait, $h, $k ) = @_; # wait only if end of turn
  if( $wait ) {
    $status and IPC::share_store( 'gameid', encode_json( $status ) );
    $status and IPC::share_unlock( 'gameid' );
    until( $input->{keyid} eq $k ) {
      IPC::share_unlock( 'turn' );
      select( undef, undef, undef, .1 );
      IPC::share_lock( 'turn' );
      $k = IPC::share_fetch( 'turn' );
    }
    print "$$ _wait4turn : turn obj key =  $k\n";
    until( $k eq @{$h->{turnorder}}[$h->{turnindex}] ) { 
      IPC::share_lock( 'gameid' );
      my $json = IPC::share_fetch( 'gameid' ) or next;
      $h = decode_json( $json ) or die;
      $status = $h;
      $json = IPC::share_fetch( 'carddeck' ) or next;
      $carddeck = decode_json( $json ) or die;
      $h->{activity} eq 'defeat' and exists $h->{defeated}{$k} and last;
      select( undef, undef, undef, .01 );
      IPC::share_unlock( 'gameid' );
    }
  }
  if( $input->{mode} eq 'tournament' ) {
    $status and IPC::share_store( 'gameid', encode_json( $status ) );
    for my $k ( @{$status->{turnorder}} ) { # only show this players cards
      $k eq $input->{keyid} and next;
      delete $status->{players}{$k}{cards}; 
    }
  }
  $status->{server} = $server_keyid; 
  $status->{player} = $input->{keyid};
  my $c = _territory_count( $input->{keyid} );
  if( $c eq $status->{total_territories} ) {
    for( @{$status->{turnorder}} ) { 
      _territory_count( $_ ) or _player_defeated( $_ );
    } 
    $status->{activity} = 'victory';
    $status->{stage} = 'endgame';
    _log();
    IPC::share_store( 'logsequence', 0 );
    IPC::share_store( 'staticmap', '' );
  }
  _report( undef, $input->{mode} );
}

sub wait4turn {
  shift;
  $|=1;
  my $i = shift;
  my $input = ref $i eq 'HASH' ? $i : decode_json( PGP::pgp( $i ) );
  print "$$ wait4turn .. input = " . Dumper($input) . "\n";
  $shares->{gameid}{keyid} = $input->{gameid};
  _wait4turn( $input, 1 ); # wait
}

sub _report {
  my ( $data, $mode, $json ) = @_;
  $shares->{gameid}{obj}   and IPC::share_unlock( 'gameid' );
  $shares->{turn}{obj}     and IPC::share_unlock( 'turn' );
  $data or $data = $status;
  if( $mode eq 'local' ) {
    ref $data eq 'HASH' and return $data;
    return decode_json( $data );
  }
  ref $data eq 'HASH' or  $json = $data;
  ref $data eq 'HASH' and $json = encode_json( $data );
  my $e = $mode eq 'tournament' ? PGP::pgp( $json ) : $json;
  $e or $e = $json;
  my $s = "<successresponse>$e</successresponse>";
  SOAP::Data->type( xml => $s );
}

sub register {  
  my ( $out );
  shift;
  $|=1;
  my $i = shift;
  my $input = ref $i eq 'HASH' ? $i : decode_json( PGP::pgp( $i ) );
  print "$$ register .. input = " . Dumper($input) . "\n";
  IPC::share_lock( 'register_lock' );
  IPC::share_lock( 'turn' );
  IPC::share_store( 'turn', 1 ); # make this true, avoid fetch error
  IPC::share_unlock( 'turn' );
  {
    my $h = _getmap( $input->{mapid} );
    $h->{territories}{wild1}{cardtype} = 'wild';
    $h->{territories}{wild2}{cardtype} = 'wild';
    my $json = encode_json( $h );
    IPC::share_lock( 'staticmap' );
    IPC::share_store( 'staticmap', $json );
    $out->{map} = $h;
    my $cards = _scramble( [ keys $h->{territories} ] );
    IPC::share_lock( 'carddeck' );
    IPC::share_store( 'carddeck', encode_json( $cards ) );
    IPC::share_unlock( 'carddeck' );
    IPC::share_unlock( 'staticmap' );
  }
  
# print "$$ register .. shares = " . Dumper($shares) . "\n";
  $out->{server} = $server_keyid; 
  exists $input->{name} or $out->{errstr} .= '.. no player name defined .. ';
  exists $input->{keyid} and $out->{player} = $input->{keyid};
  exists $input->{keyid} or $out->{errstr} .= '.. no player keyid defined ..';
  exists $input->{mapid} or $input->{mapid} = $defaultmap;
  exists $input->{mode}  or $input->{mode} = $defaultmode;
  $out->{errstr} and return _report( $out, $input->{mode} );
  my $gamestatus = _get_gamestatus( $gamestatusfile );
  my $gameid = _find_game( $gamestatus->{pending}, $input ) ;
  for my $p ( keys %{$gamestatus->{pending}{$gameid}{players}} ) {
      $p eq $input->{keyid} or next;
      my $s = "  already registered in pending game .. " . $gameid;
      $out->{errstr} .= " .. keyid " . $input->{keyid} . "$s .. ";
  }
  if( $out->{errstr} ) {
    print "BAILING due to errstr : " . $out->{errstr} . "\n";
    return _report( $out, $input->{mode} );
  }
  $out->{status} = 'registered';
  $out->{mode}   = $gamestatus->{pending}{$gameid}{mode};
  $out->{gameid} = $gameid;
  my $p = $gamestatus->{pending}{$gameid}{players};
  my $k = $input->{keyid};
  $p->{$k}{name} = $input->{name};
  $p->{$k}{card_count} = 0;
  $p->{$k}{cards} = {};
  $gamestatus->{pending}{$gameid}{numplayers}++;
  my $gamestate; # just for this game, gamestatus is all games
  $shares->{gameid}{keyid} = $gameid;
  IPC::share_lock( 'gameid' );
  IPC::share_store( 'gameid', encode_json( {} ) );
  IPC::share_unlock( 'gameid' );
  if( $gamestatus->{pending}{$gameid}{numplayers} > 5 ) {
    $gamestatus->{active}{$gameid} = $gamestatus->{pending}{$gameid};
    delete $gamestatus->{pending}{$gameid};
    $gamestate = $gamestatus->{active}{$gameid};
    _initialize_game( $gamestate, $gameid );
  }
  my $json = encode_json( $gamestatus );
  _fileout( $gamestatusfile, $json );
  IPC::share_unlock( 'register_lock' );
  _report( $out, $input->{mode} );
}

sub _getmap {
  my( $id ) = @_;
  my $hash = eval { Map->new( { mapid => $id } ) };
  $@ and die "died calling Map.pm for mapid $id .. $@";
  $hash;
}

sub dumper { 
  shift;
  my $in = shift;
  my $json = PGP::pgp( $in );
  print Dumper( $json );
  my $h = decode_json( $json );
  delete $h->{clientkey};
  $json = encode_json( $h );
  _report( $json );
}

sub _get_gamestatus {
  my ( $f ) = @_;
  unless( -f $f ) {
    my $c = { completed => {}, active => {}, pending => {}, };
    my $json = encode_json( $c );
    _fileout( $f, $json );
  }
  my $json = _filein( $f );
  decode_json( $json );
}

sub _find_game {
  my( $pending, $input, $h, $r ) = @_;
  until( $h ) {
    for $r ( keys %$pending ) {
      $pending->{$r}{mapid} eq $input->{mapid} or next;
      $pending->{$r}{mode}  eq $input->{mode}  or next;
      $h = $r;
      last;
    }
    defined $h and last;
    my $key = time;
    $pending->{$key} = { numplayers => 0, 
                         players => {}, 
                         mapid => $input->{mapid},
                         mode => $input->{mode},
                       };
  }
  $h;
}

{
  sub _fileout {
    my( $f, $json, $append ) = @_;
    my $mode = $append ? '>>' : '>';
    open my $FH, "$mode $f" or die "unable to open $f for output : $!";
    print $FH "$json\n";
    close $FH or die "unable to close $f : $!";
  }

  sub _filein {
    my( $f, $json ) = @_;
    open my $FH, "$f" or die "unable to open $f for input : $!";
    $json = <$FH>;
    close $FH or die "unable to close $f : $!";
    $json;
  }
}

sub _initialize_game {
  my ( $hash, $gameid ) = @_;
  $shares->{gameid}{keyid} = $gameid;
  IPC::share_lock( 'gameid' );
  IPC::share_lock( 'turn' );
  $hash->{turnorder} = _scramble( [ keys $hash->{players} ] );
  $hash->{map}{dynamic} = decode_json( IPC::share_fetch( 'staticmap' ) );
  delete $hash->{map}{dynamic}{territories}{wild1};
  delete $hash->{map}{dynamic}{territories}{wild2};
  _assign_territories( @_ );
  delete $hash->{map}{dynamic}{continents};
  my $ts = $hash->{map}{dynamic}{territories};
  for ( keys %$ts ) { 
    delete $ts->{$_}{borders}; 
    delete $ts->{$_}{continent}; 
    delete $ts->{$_}{cardtype}; 
    delete $ts->{$_}{rectangle}; 
  }
  $hash->{stage} = 'setup';
  $hash->{setup_count} = 78; # 13 * 6 .. one reinforce per general 13 times
  $hash->{activity} = 'reinforce';
  $hash->{strength} = 1;
  $hash->{turnindex} = 0;
  $status = $hash;
  IPC::share_store( 'gameid', encode_json( $hash ) );
  IPC::share_unlock( 'gameid' );
  my $k = @{$hash->{turnorder}}[$hash->{turnindex}];
  IPC::share_store( 'turn', $k );
}

sub _assign_territories { # randomly 7 territories to each player
  my ( $hash, $gameid ) = @_;
  my $t = $hash->{map}{dynamic}{territories};
  my $tmp = _scramble( [ keys $t ] );
  for ( 0 .. 6 ) {  # turn index
    for ( @{$hash->{turnorder}} ) { # player index
      my $r = pop @$tmp;
      $t->{$r}{occupier} = $_;
      $t->{$r}{strength} = 1;
    }
  }
}

sub _scramble {
  my( $tmp, $rval ) = @_;
  while( @$tmp ) {
    my $r = int(rand(@$tmp));
    push @$rval, $tmp->[$r];
    @$tmp = (@{$tmp}[0..$r-1], @{$tmp}[$r+1..@$tmp - 1]);
  }
  $rval;
}

1;
