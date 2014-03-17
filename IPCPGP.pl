#!/usr/bin/perl
#
#   IPCPGP.pl  .. handle the PGP work
#
#
#   assume one of four types of input on the input share
#     1) server sends signed (PGP) input from a player
#          .. verify and return the json
#     2) server sends json string (state) 
#          .. encrypt and return the PGP message
#          .. server then sends this PGP message to the player (SOAP response)
#     3) player sends json string (manuever)
#          .. this is the manuever intended for the server 
#          .. sign it and return the PGP message
#          .. player then sends this PGP message to server (SOAP invocation)
#     4) player sends encrypted message
#          .. this is the state message from the server
#          .. decrypt it and return the hash
#

use strict;
use IPC::ShareLite qw( :lock );
use JSON;
use Data::Dumper qw( Dumper );
use Crypt::OpenPGP;
use MIME::Base64;

my $pgp = Crypt::OpenPGP->new( SecRing => '/home/gomer/.gnupg/secring.gpg',
                               PubRing => '/home/gomer/.gnupg/pubring.gpg',
                             );
my $passphrase = 'gomer';

my $share_in = IPC::ShareLite->new(
        -key     => 4205,
        -create  => 'yes',
        -destroy => 'no'
    ) or die $!;

my $share_out = IPC::ShareLite->new(
        -key     => 4202,
        -create  => 'yes',
        -destroy => 'no'
    ) or die $!;

my $sleepval = shift || .1;
my ( $in, $json, $encrypt );
$share_in->lock( LOCK_EX );
$share_in->store( '' );
$share_out->lock( LOCK_EX );
$share_out->store( '' );
$share_out->unlock;
$|=1;

while( 1 ) {
  $share_in->lock( LOCK_EX );
  $in = $share_in->fetch;
  unless( $in ) {
    $share_in->unlock;
    select( undef, undef, undef, $sleepval );
    next;
  }
  $share_in->store( '' );
  $share_out->lock( LOCK_EX );
# print "IPCPGP input : " . substr( $in, 0, 20 ) . "\n";
  if( $in =~ /PGP SIGNED MESSAGE/ ) { # (case 1)
    my $v = verify( $in );  
    if( exists $v->{json}  ) {  
      $json = $v->{json};
      $share_out->store( $json );
      $share_out->unlock;
      next;
    }
    die " problem verifying $in : " . Dumper( $v ) . "\n";
  }
  if( $in =~ /PGP MESSAGE/ ) { # (case 4)
    my $v = decrypt( $in );  # see if it is a PGP encrypted message (case 4)
    if( exists $v->{json} ) {  
      $json = $v->{json};
      $share_out->store( $json );
      $share_out->unlock;
      next;
    }
    die " problem decrypting $in : " . Dumper( $v ) . "\n";
  }
  my $h = decode_json( $in ); 
  if( ref $h eq 'HASH' ) {
    if( exists $h->{server} ) { # see if it is json from server (case 2)
      my $data = $h->{mode} eq 'tournament' ? sign( $h, $h->{server} ) : $in;
      $data or die "bad Signature \n";
      $share_out->store( $data );
      $share_out->unlock;
      next;
    }
    if( exists $h->{keyid} ) { # see if it is json from player (case 3)
      my $data = $h->{mode} eq 'tournament' ? sign( $h, $h->{keyid} ) : $in;
      $data or die "bad Signature \n";
      $share_out->store( $data );
      $share_out->unlock;
      next;
    }
  }
  die "ERROR : in = " . Dumper( $in ) . "\n";
}

sub encrypt {
  my( $data ) = @_;
  ref $data eq 'HASH' and return _encrypt_hash( @_ );
  _encrypt_json( @_ );
}

sub _encrypt_hash {
  my $hash = shift;
  my $json = encode_json( $hash );
  _encrypt_json( $json, @_ );
}

sub _encrypt_json {
  my( $json, $signer, @rest ) = @_;
  $pgp->encrypt(
                 Armour         => 1,
                 SignKeyID      => $signer,
                 SignPassphrase => $passphrase,
                 Data           => $json,
                 Recipients     => \@rest,
               );
}

sub sign {
  my( $data, $signer ) = @_;
  ref $data eq 'HASH' and return _sign_hash( @_ );
  _sign_json( @_ );
}

sub _sign_hash {
  my( $hash, $signer ) = @_;
  my $json = encode_json( $hash );
  _sign_json( $json, $signer );
}

sub _sign_json {
  my( $json, $signer ) = @_;
  $pgp->sign(
              Clearsign  => 1,
              KeyID      => $signer,
              Passphrase => $passphrase,
              Data       => $json,
            );
}

sub decrypt {
  my ( $data, $rval ) = @_;
  my ( $decrypt, $sig, @rest ) = $pgp->decrypt(
                                    Passphrase => $passphrase,
                                    Data       => $data,
                              );
  $rval->{errstr} = $pgp->errstr;
  $decrypt or return $rval;
  $sig     or return $rval;
  my $json = $decrypt;
  my $hash = decode_json( $json );
  { hash => $hash, json => $json };
}

sub verify {
  my ( $sig, $rval ) = @_;
  $rval->{input} = $sig;
  if( $pgp->verify( Signature  => $sig ) ) {
    $sig =~ /.*?Hash:\s+\S+\s+(.*?)\s+-----BEGIN PGP SIGNATURE-----/sm;
    $rval->{json} = $1;
    $rval->{hash} = decode_json( $rval->{json} );
  }
  $rval->{errstr} = $pgp->errstr;
  $rval;
}

1;
