#!/usr/bin/perl
#
#  gd.pl
#
#  visualize log files from autorisk
#
#  need to merge the log file (dynamic data) with map (static data)
#

use GD;
use Map;
use JSON;

my $map = Map->new( { mapid => 'map1000' } );
my $ts = $map->{territories};

my ( $black, $white, $player_color, @player_color );
sub _colors {
  my( $im ) = @_;
    # allocate some colors
  $black = $im->colorAllocate(0,0,0);       
  $white = $im->colorAllocate(255,255,255);
  $player_color = {
    red => $im->colorAllocate(255,120,120),
    blue => $im->colorAllocate(150,150,255),
    green => $im->colorAllocate(120,255,120),
    aqua => $im->colorAllocate(0,255,255),
    purple => $im->colorAllocate(255,120,255),
    gray => $im->colorAllocate(148,148,148),
  };
}

my $color = {};

while( <> ) {
  chomp;
  my $im = new GD::Image(1024,768);
  _colors( $im );
  my @player_color = keys %$player_color;
  my $h = decode_json( $_ );
  unless( keys %$color ) {
    for ( sort keys %{$h->{players}} ) {
      $color->{$_} = pop @player_color;
    }
  }
  $im->rectangle( 0, 0, 1024, 768, $black );
  $im->fill( 1, 1, $white );
  my $gameid = $h->{input}{gameid};
  my $activity = $h->{input}{manuever}{activity};
  my $stage = $h->{input}{manuever}{stage};
  my $o = $h->{input}{keyid};
  my $name = $h->{players}{$o}{name};
  my $manuever = "$stage : $activity : $name";
  if( $activity eq 'conquest' ) {
    my $from = $h->{input}{manuever}{from_territory};
    my $to = $h->{input}{manuever}{to_territory};
    my $s = $h->{input}{manuever}{troop_movement};
    $manuever .= " move $s troops from $from to $to";
  }
  if( $activity eq 'redemption' ) {
    for ( keys %{$h->{input}{manuever}{redemption}} ) {
      my $ct = '(' . substr( $ts->{$_}{cardtype}, 0, 1 ) . ')';
      $manuever .= " : $_ $ct";
    }
  }
  if( $activity eq 'reinforce' ) {
    for ( keys %{$h->{input}{manuever}{territories}} ) {
      my $s = $h->{input}{manuever}{territories}{$_}{strength};
      $manuever .= " : $_ $s";
    }
  }
  if( $activity eq 'attack' ) {
    my $from = $h->{input}{manuever}{attack_from};
    my $to = $h->{input}{manuever}{attack_to};
    if( $from ) {
      $manuever .= " attacks $to from $from";
    } else {
      $from = $h->{input}{manuever}{troops_from};
      $to = $h->{input}{manuever}{troops_to};
      my $s = $h->{input}{manuever}{strength};
      if( $from ) {
        $manuever .= " : troop movement : $s troops from $from to $to";
      }
      $manuever .= " : end turn";
    }
  }
  $im->rectangle( 40, 30, 900, 65, $black );
  $im->fill( 45, 35, $player_color->{$color->{$o}} );
  $im->string( gdMediumBoldFont, 50, 40, $manuever, $black );
  my $stats = {};
  for my $t ( keys %$ts ) {
    my $o = $h->{map}{dynamic}{territories}{$t}{occupier};
    my $s = $h->{map}{dynamic}{territories}{$t}{strength};
    my $name = $h->{players}{$o}{name};
    my $ct = '  (' . substr( $ts->{$t}{cardtype}, 0, 1 ) . ')';
    $stats->{$o}{territory_count}++;
    exists $ts->{$t}{rectangle} or next;
    my( $a, $b, $c, $d, $x, $y ) = @{$ts->{$t}{rectangle}};
    $im->rectangle( $a, $b, $c, $d, $black );
    $x = $a + 4;
    $y = $b + 4;
    $im->fill( $x, $y, $player_color->{$color->{$o}} );
    my $t_ct = $t . '_' . $ct;
    for( split '_', $t_ct ) {
      $im->string( gdSmallFont, $x, $y, $_, $black );
      $y += 10;
    }
    $x = $c - 40; 
    $y = $d - 20;
    $im->string( gdSmallFont, $x, $y, $s, $black );
  }
  $im->string( gdLargeFont, 50, 10, 'AUTORISK', $black );
  my $x = 120;
  for my $o ( keys %$color ) {
    my $t = $stats->{$o}{territory_count};
    my $c = $h->{players}{$o}{card_count};
    my $name = $h->{players}{$o}{name};
    $im->rectangle( $x, 560, $x + 120, 740, $black );
    $im->fill( $x + 1, 561, $player_color->{$color->{$o}} );
    $im->string( gdLargeFont, $x + 20, 565, $name, $black );
    $t and $im->string( gdLargeFont, $x + 20, 580, $t . ' terr', $black );
    $y = 600;
    for ( sort keys %{$h->{players}{$o}{cards}} ) {
      s/United_States/US/;
      s/Australia/AUS/;
      s/Northwest/N/;
      s/Northern/N/;
      s/North/N/;
      s/Western/W/;
      s/Eastern/E/;
      s/Southern/S/;
      s/South/S/;
      s/Central/C/;
      $im->string( gdSmallFont, $x + 20, $y, $_, $black );
      $y += 16;
    }
    $x += 120;
  }
  # make sure we are writing to a binary stream
  binmode STDOUT;

  # Convert the image to PNG and print it on standard output
  print $im->png;
}
