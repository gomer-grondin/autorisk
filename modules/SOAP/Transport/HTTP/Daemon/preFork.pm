package SOAP::Transport::HTTP::Daemon::preFork;

use strict;
use vars qw(@ISA);
use SOAP::Transport::HTTP;
use POSIX ":sys_wait_h";
use IPC::ShareLite qw( :lock );
use IPC;

$SIG{CHLD} = \&reap;             # do not create zombies
use Data::Dumper qw(Dumper);

@ISA = qw(SOAP::Transport::HTTP::Daemon);

my $offspring = {};
my $reapcount = 0;
sub handle {
  my $self = shift->new;
  my $preforked = shift;
  my $share = IPC::ShareLite->new(
       -key => 9999, -create => 'yes', -destroy => 'no' ) or die $!;
  while ( 1 ) {
    if( keys $offspring > $preforked ) {
      sleep;
    } else {
      my $pid = fork();
      defined $pid or die "cannot fork : $!";
      $pid and $offspring->{$pid}++;
      if( $pid == 0 ) { #child  
        $share->lock( LOCK_EX );
        my $c = $self->accept;
        $share->lock( LOCK_UN );
#	print Dumper( $c );
        $self->close;  # Close the listening socket (always done in children)
        my $r = $c->get_request;
#	print Dumper( $r );
        $self->request($r);
        $self->SOAP::Transport::HTTP::Server::handle;
        $r = $self->response;
#       print Dumper( $r );
        $c->send_response($r);
        $c->close;
        exit;
      }
    }
  }
  return;
}

sub reap {
  while( ( my $dead = waitpid( -1, WNOHANG ) ) > 0 ) {
    delete $offspring->{$dead};
  }
}

#     $reapcount++;
#     print "reaping $dead  .. $reapcount\n ";
#     print scalar ( keys $offspring ) . " remaining \n";
#     print join( " ", keys $offspring ) . " \n";
1;
