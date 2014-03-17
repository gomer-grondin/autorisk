package PGP;

use strict;
use IPC;
use JSON;

$|=1;
sub pgp {
  my $in = shift;
  my $data = $in;
  ref $in eq 'HASH' and $data = encode_json( $in );
  IPC::share_lock( 'pgp_player_lock' );
  IPC::share_lock( 'pgp_in' );
  IPC::share_lock( 'pgp_out' );
  IPC::share_store( 'pgp_in', 'init' );
  IPC::share_store( 'pgp_out', $data );
  IPC::share_unlock( 'pgp_out' );
  my $fetched;
  while( 1 ) {
    IPC::share_lock( 'pgp_in' );
    $fetched = IPC::share_fetch( 'pgp_in' );
    if( $fetched eq 'init' ) {
      IPC::share_unlock( 'pgp_in' );
      select( undef, undef, undef, .01 );
      next;
    }
    IPC::share_unlock( 'pgp_in' );
    last;
  }
  IPC::share_unlock( 'pgp_player_lock' );
  $fetched;
}

1;
