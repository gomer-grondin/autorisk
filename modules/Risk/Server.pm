package Risk::Server;

use strict;

use base 'Risk';
use Data::Dumper;
use LWP 5.64;
use Storable qw( freeze thaw );
use IPC::ShareLite qw( :lock );
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);

sub mapfile {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

# validate map
#
sub validate_map {
  my ($self, $mapfile ) = @_;
  # create signed version
  $self->{mapsha1} = eval {$self->_uxml2sxml($mapfile, 
                           './map', $self->{server_id}); 
                          };
  $@ and $self->_server_death( '',  "validate map -- $@" );
  eval {$self->_xmlin("./map/$self->{mapsha1}", 'map'); };
  $@ and $self->_server_death( '',  "validate map -- $@" );
  my $map = $self->{map};
  my $count = scalar ( keys %{$map->{territories}} );
  $count == 42 or $self->_server_death( '',  "$count territories???" );
  for my $territory ( keys %{$map->{territories}} ) {
    my $continent = $map->{territories}{$territory}{continent};
    my $msg = "check $territory for bad continent $continent";
    exists $map->{continents}{$continent} or $self->_server_death( '',  $msg );
    for my $border ( @{$map->{territories}{$territory}{borders}} ) {
      grep /^$territory$/, @{$map->{territories}{$border}{borders}} and next;
      $msg = "problem with border between $territory/$border ";
      $self->_server_death( '', $msg );
    }
  }
  $self->{map_share}->store( freeze( $map ) ) or die;
  # map validated, upload to cgi server
  eval { $self->_upload("map/$self->{mapsha1}",
                        'map',
                        $self->{server_id}, 1 );
       };
  $@ and $self->_server_death( '',  "validate map -- $@" );
  $map;
}

sub poll_registration {
  my ($self, $generals, $state, $tot) = @_;
  my @rval; 
  $tot ||= 6;
  my( $name, $keyid, $rval );
  while( @$generals < $tot ) {
    sleep 1;
    eval { $self->poll_manuever( $state ); };
    $@ and $self->_server_death( $state,  "poll registration : $@" );
    $name = $self->{manuever}{name};
    $keyid = $self->{manuever}{keyid};
    exists $state->{generals}{$keyid}{name} and next; 
    $state->{manuever}{$keyid}{sha1} = $rval;
    $state->{generals}{$keyid}{name} = $name;
    push @$generals, $name;
    print join( "\t", sort @$generals ) . "\n";
  }
}

sub poll_manuever {
  my ($self, $state) = @_;
  my $errstring = "poll_manuever -- ";
  $self->log("    $errstring ");
  my $init = $state->{manuever_hash};
  while( $init eq $state->{manuever_hash} ) {
    $self->{manuever_share_hash}->lock( LOCK_EX );
    $init = $self->{manuever_share_hash}->fetch;
    $self->{manuever_share_hash}->unlock;
  }
  $self->{manuever} = thaw( $self->{manuever_share}->fetch );
  $state->{manuever_hash} = $init;
  $self->log("    $errstring $state->{manuever_hash} ");
}

sub hostilities_reinforcement {
  my ($self, $state, $general, $redemption, $conquest) = @_;
  $state->{turn}{activity} = 'reinforcement';
  my $errstring = " hostilities_reinforcement  ";
  $self->log("    $errstring ");
  $self->{state_share}->lock( LOCK_EX );
  $conquest or $state->{turn_ended} = 0;
  # how many territories?
  my $t = scalar @{$state->{generals}{$general}{territories}};
  my $r = int($t / 3);
  my $name = $state->{generals}{$general}{name};
  my $ch = {};
  for ( sort keys %{$self->{map}{territories}} ) {
    my $s = $state->{territory}{$_}{strength};
    my $c = $self->{map}{territories}{$_}{continent};
    my $o = $state->{territory}{$_}{occupier};
    my $n = $state->{generals}{$o}{name};
    push @{$ch->{$c}}, [$_, $s, $o, $n];
  }
  for my $c ( sort keys %$ch ) {
    $self->log("        $c ");
    for my $t ( @{$ch->{$c}} ) {
      $self->log("           $t->[3] \t $t->[1] \t $t->[0] ");
    }
  }
  $self->log("    $name has $t territories: ");
  for my $c ( sort keys %$ch ) {
    $self->log("        $c ");
    for my $t ( @{$ch->{$c}} ) {
      if( $t->[2] eq $general ) {
        $self->log("           $t->[3] \t $t->[1] \t $t->[0] ");
      }
    }
  }
  $r > 2 or $r = 3;
  my $msg  = "  $name is awarded $r troops for $t territories";
  $self->log($msg);
  $conquest or $redemption += $r;
  # occupy any continents?
  my $map = $self->{map};
  for my $continent ( keys %{$map->{continents}} ) {
    my $flag = 1;
    for my $t ( keys %{$map->{territories}} ) {
      $map->{territories}{$t}{continent} eq $continent or next;
      unless( $state->{territory}{$t}{occupier} eq $general ) {
        $flag = 0;
        last;
      }
    }
    if( $flag ) {
      $r = $map->{continents}{$continent};
      $conquest or $redemption += $r;
      my $n = $state->{generals}{$general}{name};
      $self->log("  $n is awarded $r troops for $continent ");
    }
  }
  $self->log("      $name is awarded $redemption troops total ");
  $state->{turn}{strength} = $redemption;
  $self->update_state($state, $general); 
  eval { $self->validate_reinforcement($state); };
  $@ and $self->_server_death( $state,  "reinforcement -- $@" );
}

sub validate_reinforcement {
  my( $self, $state ) = @_;
  my $errstring = "validate_reinforcement  ";
  $self->log("    $errstring ");
  $errstring .= "Non compliance by general $state->{turn}{general}";
  my $s = 0;
  for ( keys %{$self->{manuever}{territory}} ) {
    $state->{territory}{$_}{occupier} eq $state->{turn}{general} or
            $self->_server_death( $state,  "$errstring -- territory" );
    my $s2 = $self->{manuever}{territory}{$_};
    $s += $s2;
    $state->{territory}{$_}{strength} += $s2;
    my $s3 = $state->{territory}{$_}{strength};
    $self->log("    reinforced $_ - $s3");
  }
  $s == $state->{turn}{strength} or 
         $self->_server_death( $state,  "$errstring -- strength " );
}

my $turn = 100000;
sub log_state {
  my ($self, $state, $general) = @_;
  my $errstring = "log state --";
  $self->log("    $errstring ");
  my $name = $state->{generals}{$general}{name};
  my $m = './state/map'; 
  unless( -f $m ) { 
    mkdir './state';  #ignore error
    Storable::store $self->{map}, $m;
  }
  Storable::store $state, './state/state_' . $turn++ . '_' . $name;
}

sub update_state { 
  my ($self, $state, $general) = @_;
  my $errstring = "update state --";
  $self->log("    $errstring ");
  $state->{stage} eq 'hostilities' and $self->log_state( $state, $general );
  $state->{turn}{general} = $general;
  my $s = freeze($state);
  $self->{state_share}->store( $s ) or die;
  $s = sha1_hex( $s );
  $self->log("   state_hash =  $s ");
  $self->{state_share}->unlock;
  $state->{turn}{activity} eq 'victory'      and return;
  $state->{stage}          eq 'registration' and return;
  $self->poll_manuever( $state );
}

sub encrypt_cards {
  my ($self, $state, $general) = @_;
  my $errstring = "encrypt cards --";
  $self->log("    $errstring ");
  my $key = $self->{server_id};
  my $hash = $self->{generals}{$general};
  my $fn = eval {$self->_hash2uxml( $hash, './state', $general ); };
  $@ and $self->_server_death( $state,  "$errstring : $@" );
  unlink "${fn}.asc";
  my $c = "gpg -u $self->{server_id} -r $general -ea $fn";
  system( $c ) and $self->_server_death( $state,  "$errstring - $c : $!" );
  $state->{generals}{$general}{cards} = '';
  open my $F, "${fn}.asc" or 
        $self->_server_death( $state,  "$errstring - open $fn asc" );
  while( <$F> ) { $state->{generals}{$general}{cards} .= $_; }
  close $F or $self->_server_death( $state,  "$errstring - close $fn asc" );
}

sub card_report {
  my ($self, $state, $general) = @_;
  my $errstring = "card_report --";
  $self->log("    $errstring ");
  my $c = $state->{generals}{$general}{cardcount}; 
  my $name = $state->{generals}{$general}{name};
  my $msg = "        $name has $c cards: ";
  $self->log($msg);
  for ( @{$self->{generals}{$general}{card}} ) {
    $self->log("         $_ - $self->{map}{territories}{$_}{cardtype} ");
  }
}

sub card_recycle {
  my ($self, $state, $general) = @_;
  my $errstring = "card_recycle --";
  $self->log("    $errstring ");
  my @w = @{$self->{generals}{$general}{card}};
  my @m = keys %{$self->{manuever}{territory}};
  my @wild = grep { /^wild$/ } @w;
  my @wildm = grep { /^wild$/ } @m;
  @{$self->{generals}{$general}{card}} = ();
  for my $allcard ( @w ) {
    unless( grep { $_ eq $allcard } @m ) {
      push @{$self->{generals}{$general}{card}}, $allcard;
    }
  }
  if( @wild == 2 and @wildm == 1 ) {
     push @{$self->{generals}{$general}{card}}, 'wild';
  }
  $state->{generals}{$general}{cardcount} -= 3;
  push @{$self->{cards}}, @m;
  for my $mancard ( @m ) {
    if( $state->{territory}{$mancard}{occupier} eq $general ) {
      $state->{territory}{$mancard}{strength} += 2;  
    }
  }
  unless( @{$self->{generals}{$general}{card}} == @w - 3 ) { 
    $self->_server_death( $state, "card problems -- card count mismatch" );
  }
}

sub card_redeem_recycle {
  my ($self, $state, $general) = @_;
  my $errstring = "card_redeem_recycle --";
  $self->log("    $errstring ");
  eval { $self->_redemption_value($state, $general); };
  $@ and $self->_server_death( $state,  "$errstring : $@"); 
  eval { $self->card_recycle($state, $general); };
  $@ and $self->_server_death( $state,  "$errstring : $@" );
}

sub card_request {
  my ($self, $state, $general) = @_;
  my $errstring = "card_request --";
  $self->log("    $errstring ");
  $state->{turn} = {};
  $state->{turn}{activity} = 'redemption';
  eval { $self->encrypt_cards($state, $general); };
  $@ and $self->_server_death( $state,  "$errstring : $@" );
  $self->update_state($state, $general);
}

sub card_redemption {
  my ($self, $state, $general, $conquest) = @_;
  my $errstring = "card_redemption --";
  $self->log("    $errstring ");
  $self->{state_share}->lock( LOCK_EX );
  $self->card_report( $state, $general );
  $self->{redemption} = 0;
  my $post_report = 0;
  while( $state->{generals}{$general}{cardcount} > 4 ) {
    eval { $self->card_request($state, $general); };
    $@ and $self->_server_death( $state,  "$errstring : $@" );
    eval { $self->card_redeem_recycle($state, $general); };
    $@ and $self->_server_death( $state,  "$errstring : $@" );
    $post_report = 1;
  }
  if( $state->{generals}{$general}{cardcount} > 2 and !$conquest) {
    eval { $self->card_request($state, $general); };
    $@ and $self->_server_death( $state,  "$errstring : $@" );
    if( keys %{$self->{manuever}{territory}}  ) {
      eval { $self->card_redeem_recycle($state, $general); };
      $@ and $self->_server_death( $state,  "$errstring : $@" );
      $post_report = 1;
    }
  }
  $post_report and $self->card_report( $state, $general );
  $self->{redemption};
}

sub _redemption_value {
  my ( $self, $state, $general ) = @_;
  my $errstring = "redemption_value --";
  $self->log("    $errstring ");
  my @type; 
  for ( keys %{$self->{manuever}{territory}} ) {
    if( /^wild$/ ) { push @type, 'wild'; next; }
    grep /^$_$/, @{$self->{generals}{$general}{card}} or
          $self->_server_death( $state,  "$errstring -- territory");
    push @type, $self->{map}{territories}{$_}{cardtype};
  }
  my $redemption = 0;
  my $infantry =  grep { $_ eq 'infantry'  } @type;
  my $calvary =   grep { $_ eq 'calvary'   } @type;
  my $artillery = grep { $_ eq 'artillery' } @type;
  my $wild =      grep { $_ eq 'wild'      } @type;
  $infantry  == 3 and $redemption = 4;
  $calvary   == 3 and $redemption = 6;
  $artillery == 3 and $redemption = 8;
  $infantry == 1 and $calvary == 1 and $artillery == 1 and $redemption = 10;
  $wild > 1 and $redemption = 10;
  $wild == 1 and $infantry  > 1 and $redemption = 4;
  $wild == 1 and $calvary   > 1 and $redemption = 6;
  $wild == 1 and $artillery > 1 and $redemption = 8;
  $wild == 1 and $artillery == 1 and $infantry == 1 and $redemption = 10;
  $wild == 1 and $artillery == 1 and $calvary == 1 and $redemption = 10;
  $wild == 1 and $infantry == 1 and $calvary == 1 and $redemption = 10;
  $self->log("         $redemption troops awarded for cards");
  my $msg = "$errstring -- invalid cards redeemed";
  $redemption or $self->_server_death( '', $msg );
  $self->{redemption} += $redemption;
}

sub validate_conquest {
  my ($self, $state, $general) = @_;
  my $func = "validate_conquest --";
  $self->log("    $func ");
  my $errstring .= "$func -- Non compliance by general $general";
  my $at = $state->{turn}{from_territory};
  my $as = $state->{territory}{$at}{strength};
  my $dt = $state->{turn}{to_territory};
  my $tm = $self->{manuever}{troop_movement};

  my $msg; 
  $msg = "$errstring -- troop movement not numeric";
  $tm =~ /^\d+$/ or $self->_server_death( $state, $msg );
  $msg = "$errstring -- no troop movement";
  $tm > 0   or $self->_server_death( $state, $msg );
  $msg = "$errstring -- must leave one troop";
  $tm < $as or $self->_server_death( $state, $msg );
  $msg = "$errstring -- at least 3 troops";
  $as > 3 and ($tm > 2 or $self->_server_death( $state, $msg ) );

  $state->{territory}{$dt}{strength} = $tm;
  $state->{territory}{$at}{strength} -= $tm;

  $self->log("    $func -- $tm troops moved from $at to $dt");
}

sub validate_attack {
  my ($self, $state, $general) = @_;
  my $errstring = "validate_attack --";
  $self->log("    $errstring ");
  my $name = $state->{generals}{$general}{name};
  $errstring .= "Non compliance by general $name ";

  my $msg;
  my $at = $self->{manuever}{attack_territory};
  $msg = "$errstring -- attack territory";
  $state->{territory}{$at}{occupier} eq $general or
	    $self->_server_death( $state, $msg );
    
  $msg = "$errstring -- attack territory strength";
  $state->{territory}{$at}{strength} > 1 or 
                 $self->_server_death( $state, $msg );
    
  my $dt = $self->{manuever}{defend_territory};
  my $dg = $state->{territory}{$dt}{occupier}; #defending general
  $msg = "$errstring -- defend territory";
  $dg eq $general and $self->_server_death( $state, $msg );
  
  $msg = "$errstring -- not bordering territories";
  grep /^$dt$/, @{$self->{map}{territories}{$at}{borders}} or
                                    $self->_server_death( $state, $msg );
  
  my $as = $state->{territory}{$at}{strength};
  my $ds = $state->{territory}{$dt}{strength};
  $msg = "general $name attacking $dt ($ds) from $at ($as)";
  $self->log( $msg );
  eval {$self->resolve_attack( $state, $general );};
  $@ and $self->_server_death( $state,  "$errstring : $@" ); 
}

sub resolve_attack {
  my ($self, $state, $general) = @_;
  my $errstring = "resolve_attack --";
  $self->log("    $errstring ");
  my $name = $state->{generals}{$general}{name};
  $errstring .= "Non compliance by general $name";
  my $at = $self->{manuever}{attack_territory};
  my $dt = $self->{manuever}{defend_territory};
  my $dg = $state->{territory}{$dt}{occupier}; #defending general
  my $ad = 3;  # dice counts
  my $dd = 2;  # dice counts
  $state->{territory}{$at}{strength} == 3 and $ad = 2; 
  $state->{territory}{$at}{strength} == 2 and $ad = 1; 
  $state->{territory}{$dt}{strength} == 1 and $dd = 1; 
  my @adv; # dice values
  my @ddv; # dice values
  for( 1 .. $ad ) { push @adv, int(rand(6))+1; }
  for( 1 .. $dd ) { push @ddv, int(rand(6))+1; }
  for( @adv ) {
    $self->{stats}{roll}{$_}++;
    $self->{stats}{general}{$general}{roll}{$_}++;
  }
  for( @ddv ) {
    $self->{stats}{roll}{$_}++;
    $self->{stats}{general}{$dg}{roll}{$_}++;
  }
  my @adv2 = reverse sort @adv;
  my @ddv2 = reverse sort @ddv;
  my $atype = "$ad" . 'v' . "$dd";
  $self->log( "     general $name " . join( " ", @adv2 ) );
  $name = $state->{generals}{$dg}{name};
  $self->log( "          general $name " . join( " ", @ddv2 ) );
  my ($l,$v);
  if( $adv2[0] > $ddv2[0] ) {  # attacker wins
    $v++;
    $state->{territory}{$dt}{strength}--;
  } elsif( $adv2[0] <= $ddv2[0] ) {  # attacker loses
    $l++;
    $state->{territory}{$at}{strength}--;
  }
  if( $adv2[1] and $ddv2[1] ) {  
    if( $adv2[1] > $ddv2[1] ) {  # attacker wins
      $v++;
      $state->{territory}{$dt}{strength}--;
    } elsif( $adv2[1] <= $ddv2[1] ) {  # attacker loses
      $l++;
      $state->{territory}{$at}{strength}--;
    }
  }
  if( $v == 2  and $dd == 2 ) {
    $self->{stats}{general}{$general}{battle}{attack}{$atype}{victory}++;
    $self->{stats}{general}{$dg}{battle}{defense}{$atype}{defeat}++;
  } elsif( $l == 2  and $dd == 2 ) {
    $self->{stats}{general}{$general}{battle}{attack}{$atype}{defeat}++;
    $self->{stats}{general}{$dg}{battle}{defense}{$atype}{victory}++;
  } elsif( $v == 1 and $dd == 1 ) {
    $self->{stats}{general}{$general}{battle}{attack}{$atype}{victory}++;
    $self->{stats}{general}{$dg}{battle}{defense}{$atype}{defeat}++;
  } elsif( $v == 1 and $dd == 2 ) {
    $self->{stats}{general}{$general}{battle}{attack}{$atype}{draw}++;
    $self->{stats}{general}{$dg}{battle}{defense}{$atype}{draw}++;
  } elsif( $v == 0 and $dd == 1 ) {
    $self->{stats}{general}{$general}{battle}{attack}{$atype}{defeat}++;
    $self->{stats}{general}{$dg}{battle}{defense}{$atype}{victory}++;
  }

  unless( $state->{territory}{$dt}{strength} ) {
    eval {$self->conquest( $state, $general, $dg );};
    $@ and $self->_server_death( $state,  "$errstring : $@" ); 
  }
}

sub conquest {
  my ($self, $state, $general, $defending_general ) = @_;
  my $errstring = "conquest -- ";
  $self->log("    $errstring ");
  my $at = $self->{manuever}{attack_territory};
  my $dt = $self->{manuever}{defend_territory};
  $state->{turn} = {};
  $state->{turn}{activity} = 'conquest';
  $state->{turn}{from_territory} = $at;
  $state->{turn}{to_territory} = $dt;
  $state->{territory}{$dt}{occupier} = $general;
  push @{$state->{generals}{$general}{territories}}, $dt;
  @{$state->{generals}{$defending_general}{territories}} = grep { $_ ne $dt } 
  @{$state->{generals}{$defending_general}{territories}};
  if( scalar @{$state->{generals}{$general}{territories}} == 42 ) {
    $state->{turn}{activity} = 'victory';
    $self->update_state($state, $general);
    $self->_end_turn($state);
    return;
  }
  $self->update_state($state, $general);
  eval { $self->validate_conquest($state, $general); };
  $@ and $self->_server_death( $state,  "$errstring : $@" ); 
  $state->{conquest}++;

  unless( @{$state->{generals}{$defending_general}{territories}} ) {
    $state->{generals}{$general}{cardcount} += 
         @{$self->{generals}{$defending_general}{card}}; 
    while( @{$self->{generals}{$defending_general}{card}} ) {
      push @{$self->{generals}{$general}{card}}, 
       pop @{$self->{generals}{$defending_general}{card}}; #take cards
    }
    $state->{generals}{$defending_general}{cardcount} = 0; 
    my $msg = "    $defending_general is defeated, $general assumes loot ";
    $self->log($msg);
    if( $state->{generals}{$general}{cardcount} > 5 ) {
      my $redemption = eval { $self->card_redemption($state, $general, 1); };
      $@ and die "conquest redemption -- $@";
      eval { $self->hostilities_reinforcement($state, $general, $redemption, 1); };
      $@ and die "conquest reinforcement -- $@";
    }
  }
}

sub attack {
  my ($self, $state, $general) = @_;
  my $errstring = "attack --";
  $self->log("    $errstring ");
  $state->{conquest} = 0;
  $state->{troop_movement} = 0;
  
  until( $state->{turn_ended} > 0 ) {
    $state->{turn} = {};
    $state->{turn}{activity} = 'attack';
    $self->{state_share}->lock( LOCK_EX );
    $self->update_state($state, $general);
    
    if( $self->{manuever}{activity} eq 'end turn' )  {
      $self->_end_turn($state);
      return;
    }
   
    if( $self->{manuever}{activity} eq 'troop movement' ) {
      eval { $self->validate_troop_movement( $state, $general ); }; 
      $@ and $self->_server_death( $state,  "$errstring : $@" ); 
      $self->_end_turn($state);
      return;
    }
    
    eval { $self->validate_attack($state, $general); };
    $@ and $self->_server_death( $state,  "$errstring : $@" ); 
  }
}

sub _end_turn {
  my ($self, $state) = @_;
  my $errstring = "_end_turn";
  $state->{turn_ended} = 1;
  $self->log("    $errstring ");
  for my $g ( @{$self->{turn_order}} ) {
    my $name = $state->{generals}{$g}{name};
    my $c = scalar @{$state->{generals}{$g}{territories}};
    my $s;
    for ( @{$state->{generals}{$g}{territories}} ) { 
      $s += $state->{territory}{$_}{strength}; 
    }
    $self->log("    $name has $c territories, $s troops");
  }
  return;
  # to statistics report
  $self->log("    dice rolls : ");
  my $msg = '     ';
  for( sort keys %{$self->{stats}{roll}} ) {
    $msg .= "    $_ : $self->{stats}{roll}{$_}";
  } 
  $self->log($msg);
  for my $g ( keys %{$self->{stats}{general}} ) {
    my $name = $state->{generals}{$g}{name};
    $self->log("    general $name : ");
    my $h = $self->{stats}{general}{$g};
    $self->log("       dice rolls : ");
    my $msg = '         ';
    for( sort keys %{$h->{roll}} ) {
      $msg .= "    $_ : $h->{roll}{$_}";
    } 
    $self->log($msg);
    for my $m ( sort keys %{$h->{battle}} ) {
      for my $at ( sort keys %{$h->{battle}{$m}} ) {
        $self->log("      $m type $at : ");
        my $tot = 0;
        for my $r ( sort keys %{$h->{battle}{$m}{$at}} ) {
          $tot += $h->{battle}{$m}{$at}{$r};
        } 
        for my $r ( sort keys %{$h->{battle}{$m}{$at}} ) {
          my $c = $h->{battle}{$m}{$at}{$r};
          $self->log("         $r : $c : " . int( $c / $tot * 100 ) . "%" );
        } 
      } 
    }
  }
}

sub validate_troop_movement {
  my ($self, $state, $general) = @_;
  my $errstring = "validate troop movement -- ";
  $self->log("    $errstring ");
  $errstring .= "Non compliance by general $general";
  my $at = $self->{manuever}{from_territory};
  my $dt = $self->{manuever}{to_territory};
  my $tm = $self->{manuever}{troop_movement};
  my $as = $state->{territory}{$at}{strength};
 
  my $msg = "$errstring -- already had troop movement ";
  $state->{troop_movement} and $self->_server_death( $state, $msg );
  $state->{troop_movement}++;

  $msg = "$errstring -- troop movement not numeric";
  $tm =~ /^\d+$/ or $self->_server_death( $state, $msg );

  $state->{territory}{$at}{occupier} eq $general or
	    $self->_server_death( $state,  "$errstring -- from territory" );
    
  $state->{territory}{$dt}{occupier} eq $general or 
            $self->_server_death( $state,  "$errstring -- to territory" );
  
  grep /^$dt$/, @{$self->{map}{territories}{$at}{borders}} or
    $self->_server_death( $state,  "$errstring -- not bordering territories" );
  
  $state->{territory}{$dt}{strength} += $tm;
  $state->{territory}{$at}{strength} -= $tm;
  
  $state->{territory}{$at}{strength} > 0 or 
    $self->_server_death( $state,  "$errstring -- from territory strength" );
  

  $self->log( "      troop movement $general $tm from $at to $dt " );

}

sub card_processing {
  my ($self, $state, $general) = @_;
  my $errstring = "card processing --";
  $self->log("    $errstring ");
  $self->{state_share}->lock( LOCK_EX );
  exists $state->{conquest} or $self->_server_death( $state,  "$errstring " );
  $state->{conquest} or return;
  
  $state->{generals}{$general}{cardcount}++;

  my $ct = int( rand( @{$self->{cards}} ) );
  my $c = $self->{cards}[$ct];
  my $type = $self->{map}{territories}{$c}{cardtype};
  push @{$self->{generals}{$general}{card}}, $c;
  my $name = $state->{generals}{$general}{name};

  $self->log("          $name awarded $c - $type ");

  @{$self->{cards}} = ( @{$self->{cards}}[0 .. $ct - 1], 
                        @{$self->{cards}}[$ct + 1 .. @{$self->{cards}} - 1] );

}
1;
