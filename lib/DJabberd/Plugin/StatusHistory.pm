package DJabberd::Plugin::StatusHistory;

use strict;
use warnings;
use base 'DJabberd::Plugin';

use DateTime;
use DBI;
use List::Util qw( first );

use DJabberd::Log;
our $logger = DJabberd::Log->get_logger();

use vars qw($VERSION);
$VERSION = '1.0';

use constant VALID_AVAIL => {
    'away' => 1,
    'chat' => 1,
    'dnd'  => 1,
    'xa'   => 1,
};

for my $field (qw( dsn dbuser dbpass dbhost dbport )) {
    my $mutator = sub {
        my ($self, $value) = @_;
        $self->{$field} = $value;
    };

    my $method = "set_config_$field";
    no strict 'refs';
    *$method = $mutator;
}

sub finalize {
    my $self = shift;
    die "No database configured'" unless $self->{dsn};

    my $dsn = $self->{dsn};
    $dsn .= ';host=' . $self->{dbhost} if $self->{dbhost};
    $dsn .= ';port=' . $self->{dbport} if $self->{dbport};

    my $dbh = DBI->connect_cached($dsn, $self->{dbuser}, $self->{dbpass},
        { RaiseError => 1, PrintError => 0, AutoCommit => 1 });
    $self->{dbh} = $dbh;
    return $self;
}

sub blocking { 1 }

# to be called outside of a transaction, in auto-commit mode
sub _jidid_alloc {
    my ($self, $jid) = @_;
    my $dbh  = $self->{dbh};
    my $jids = $jid->as_bare_string;
    my $id   = eval {
        $dbh->selectrow_array("SELECT jidid FROM jidmap WHERE jid=?",
                              undef, $jids);
    };
    $logger->logdie("Failed to select from jidmap: $@") if $@;
    return $id if $id;

    eval { $dbh->do("INSERT INTO jidmap (jid) VALUES (?)", {}, $jids) };
    $logger->logdie("_jidid_alloc failed: $@") if $@;

    $id = $dbh->last_insert_id(undef, undef, "jidmap", "jidid")
        or $logger->logdie("Failed to allocate a number in _jidid_alloc");

    return $id;
}

sub _save_to_history {
    my ($self) = @_;

    return sub {
        my ($vhost, $cb, $conn, $pkt) = @_;
        my $dbh = $self->{dbh};

        my $jid = $conn->bound_jid;
        if (!$jid) {
            $cb->done;
            return;
        }
        my $userid = $self->_jidid_alloc($jid);

        my $status_node = first { ref $_ && $_->element_name eq 'status' } $pkt->children;
        if (!defined $status_node) {
            ## No status. Do nothing.
            $cb->done;
            return;
        }
        my $status = $status_node->innards_as_xml;

        my $avail = '';
        if (my $avail_node = first { ref $_ && $_->element_name eq 'show' } $pkt->children) {
            $avail = $avail_node->innards_as_xml;
            $avail = '' if !VALID_AVAIL()->{$avail};
        }

        eval {
            $dbh->do(q{INSERT INTO history (jidid, status, source, avail, time) VALUES (?, ?, ?, ?, ?)},
                {},
                $userid, $status, 'im', $avail, DateTime->now->iso8601());
        };
        $logger->logdie("Could not save history: $@") if $@;

        $cb->done;
        return;
    };
}

sub register {
    my ($self, $vhost) = @_;

    my $save_to_history = $self->_save_to_history();
    $vhost->register_hook('AlterPresenceAvailable',   $save_to_history);
    $vhost->register_hook('AlterPresenceUnavailable', $save_to_history);

    return;
}

1;

__END__

=head1 NAME

DJabberd::Plugin::StatusHistory - records changes in status for posterity and/or display to interested parties

=head1 SYNOPSIS

  # in your djabberd configuration
  <Plugin DJabberd::Plugin::StatusHistory>
     Dsn dbi:mysql:dbname=statushistory
     Dbuser djabberd
     Dbpass password
     Dbhost localhost
     Dbport 8601
  </Plugin>

=head1 DESCRIPTION

StatusHistory allows your DJabberd server to save a history of its users' IM
status, similar to a certain popular web site.

Note that unlike similar products that may record messages explicitly IMed into
the system, this plugin records messagers' actual statuses and status messages.
This may be more or less useful than recording explicit messages.

=head1 CONFIGURATION

=head2 Setting up your database

Use the included schema definitions to create the tables prior to enabling
StatusHistory in your DJabberd server.

=head2 Configuring DJabberd

Use your DJabberd configuration to set the database settings for StatusHistory.
The available config settings are:

=over

=item * C<Dsn I<dsn>>

The DBI data source name for your database.

=item * C<Dbuser I<username>>

The username for logging into your database. C<Dbuser> is not necessary when
using SQLite.

=item * C<Dbpass I<password>>

The password for logging into your database. C<Dbpass> is not necessary when
using SQLite.

=item * C<Dbhost I<hostname>>

The host server that serves your database. C<Dbhost> is not necessary when
using SQLite.

=item * C<Dbport I<port>>

The port for connecting to your database. C<Dbport> is not necessary when using
SQLite.

=back

=head2 Setting up display

You can read the status history records from your configured database by the
method of your choice. See the included Perl CGI, for example.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module. Please report problems to Mark Paschal
<markpasc@markpasc.org>. Patches are welcome.

=head1 SEE ALSO

L<DJabberd>, Twitter L<http://www.twitter.com/>

=head1 AUTHOR

Mark Paschal <markpasc@markpasc.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2007 Six Apart, Ltd. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

