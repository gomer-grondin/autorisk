package IPC;

use strict;

use IPC::ShareLite qw( :lock );

our $shares = {
   register_lock   => { keyid => 4201, obj => '', },
   pgp_in          => { keyid => 4202, obj => '', },
   pgp_player_lock => { keyid => 4203, obj => '', },
   turn            => { keyid => 4204, obj => '', },
   pgp_out         => { keyid => 4205, obj => '', },
   staticmap       => { keyid => 4207, obj => '', },
   logsequence     => { keyid => 4206, obj => '', },
   carddeck        => { keyid => 4208, obj => '', },
   gameid          => { keyid => 0, obj => '', },
};

sub share_lock {
  my( $key ) = @_;
# print "$$ locking $key \n";
  $shares->{$key}{obj} ||= ipcshare( $shares->{$key}{keyid} );
  $shares->{$key}{obj}->lock( LOCK_EX ) or die $!;
}

sub share_unlock {
  my( $key ) = @_;
# print "$$ unlocking $key \n";
  $shares->{$key}{obj} ||= ipcshare( $shares->{$key}{keyid} );
  $shares->{$key}{obj}->unlock or die $!;
}

sub share_store {
  my( $key, $data ) = @_;
# print "$$ storing to $key " . substr($data, 0, 10) . "\n";
  $shares->{$key}{obj} ||= ipcshare( $shares->{$key}{keyid} );
  $shares->{$key}{obj}->store( $data )  or die $!;
}

sub share_fetch {
  my( $key ) = @_;
# print "$$ fetching from $key \n";
  $shares->{$key}{obj} ||= ipcshare( $shares->{$key}{keyid} );
  my $f = $shares->{$key}{obj}->fetch;
# print "$$ fetched from $key " . substr( $f, 0, 10 ) . "\n";
  $f;
}

sub ipcshare {
  my ( $key ) = @_;
# print "$$ creating share $key \n";
  IPC::ShareLite->new( -key => $key, -create => 'yes', -destroy => 'no' ) or
     die "$key : $!";
}

1;
