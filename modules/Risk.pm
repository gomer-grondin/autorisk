package Risk;

use strict;

use Data::Dumper;
use Time::HiRes qw(gettimeofday);

sub new {
  my ($class,$options,$self);
  ($class,$options) = @_;
  $self = bless({ }, ref($class) || $class);
  $self->initialize($options);
  return($self);
}

sub initialize {
  my ($self,$options);
  ($self,$options) = @_;
  $self->{_class} = ref($self);
  if (ref($options) eq 'HASH') {
    foreach my $key (keys %$options) {
      $self->$key($key, $options->{$key}) if $self->can($key);
    }
  }
}

sub browser {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
  $self->{$key}->conn_cache(LWP::ConnCache->new());
}

sub memkey {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $options =~ /^\d+$/ or die 'memkey must be an integer';
  $self->{$key} = $options;
}

sub url {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
}

sub server_id {
  my ($self, $key, $options);
  ($self, $key, $options) = @_;
  $self->{$key} = $options;
  $self->{keyid} = $options;
}

sub log {
  my ( $self, $msg, $s, $usec ) = @_;
  ($s, $usec) = gettimeofday();
  print "$s $usec $self->{keyid} $msg\n";
}

1;

