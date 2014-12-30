# File: AntiAway.pm
# Author: pragma_
#
# Purpose: Kicks people that visibly auto-away with ACTIONs or nick-changes

package PBot::AntiAway;

use warnings;
use strict;

use Carp ();

sub new {
  Carp::croak("Options to " . __FILE__ . " should be key/value pairs, not hash reference") if ref $_[1] eq 'HASH';
  my ($class, %conf) = @_;
  my $self = bless {}, $class;
  $self->initialize(%conf);
  return $self;
}

sub initialize {
  my ($self, %conf) = @_;

  $self->{pbot}    = delete $conf{pbot} // Carp::croak("Missing pbot reference to " . __FILE__);

  $self->{pbot}->{registry}->add_default('text', 'antiaway', 'bad_nicks',   $conf{bad_nicks}   // '[[:punct:]](afk|away|sleep|z+|work|gone)[[:punct:]]*$');
  $self->{pbot}->{registry}->add_default('text', 'antiaway', 'bad_actions', $conf{bad_actions} // '^/me is away');
  $self->{pbot}->{registry}->add_default('text', 'antiaway', 'kick_msg',    'http://sackheads.org/~bnaylor/spew/away_msgs.html');

  $self->{pbot}->{event_dispatcher}->register_handler('irc.nick',    sub { $self->on_nickchange(@_) });
  $self->{pbot}->{event_dispatcher}->register_handler('irc.caction', sub { $self->on_action(@_) });
}

sub on_nickchange {
  my ($self, $event_type, $event) = @_;
  my ($nick, $user, $host, $newnick) = ($event->{event}->nick, $event->{event}->user, $event->{event}->host, $event->{event}->args);

  my $bad_nicks = $self->{pbot}->{registry}->get_value('antiaway', 'bad_nicks');
  if($newnick =~ m/$bad_nicks/i) {
    $self->{pbot}->{logger}->log("$newnick matches bad away nick regex, kicking...\n");
    my $kick_msg = $self->{pbot}->{registry}->get_value('antiaway', 'kick_msg');
    my $channels = $self->{pbot}->{nicklist}->get_channels($newnick);
    foreach my $chan (@$channels) {
      $self->{pbot}->{chanops}->add_op_command($chan, "kick $chan $newnick $kick_msg");
      $self->{pbot}->{chanops}->gain_ops($chan);
    }
  }

  return 0;
}

sub on_action {
  my ($self, $event_type, $event) = @_;
  my ($nick, $user, $host, $msg, $channel) = ($event->{event}->nick, $event->{event}->user, $event->{event}->host, $event->{event}->{args}[0], $event->{event}->{to}[0]);

  return 0 if $channel !~ /^#/;

  my $bad_actions = $self->{pbot}->{registry}->get_value('antiaway', 'bad_actions');
  if($msg =~ m/$bad_actions/i) {
    $self->{pbot}->{logger}->log("$nick $msg matches bad away actions regex, kicking...\n");
    my $kick_msg = $self->{pbot}->{registry}->get_value('antiaway', 'kick_msg');
    $self->{pbot}->{chanops}->add_op_command($channel, "kick $channel $nick $kick_msg");
    $self->{pbot}->{chanops}->gain_ops($channel);
  }

  return 0;
}

1;