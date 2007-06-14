#!/usr/bin/perl

use strict;
use Test::More tests => 13;
use lib 't/lib';
BEGIN { require 'djabberd-test.pl' }

use File::Temp qw();

use_ok('DJabberd::Plugin::StatusHistory');


sub setup_db {
    my ($dsn) = @_;

    my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1 });

    open my $schema, '<', 'schema/sqlite.sql' or die "Could not open schema file: $!\n";
    my $sql = eval { local $/; <$schema> };
    for my $stmt (split /;/, $sql) {
        next if $stmt !~ m{ \S }xms;
        my $sth = $dbh->prepare($stmt);
        $sth->execute();
    }
    close $schema;

    $dbh->disconnect;
}

sub make_server {
    my ($dsn) = @_;
    my $server = Test::DJabberd::Server->new( id => 1 );
    $server->start([
        DJabberd::Delivery::Local->new(),
        DJabberd::Delivery::S2S->new(),
        DJabberd::RosterStorage::InMemoryOnly->new(),
        DJabberd::Authen::AllowedUsers->new( allowedusers => 'test', policy => 'accept' ),
        DJabberd::Authen::StaticPassword->new( password => 'test' ),

        DJabberd::Plugin::StatusHistory->new( dsn => $dsn ),
    ]);
}


my $tempfile = File::Temp->new;
my $dsn = 'dbi:SQLite:' . $tempfile->filename;

setup_db($dsn);
my $server = make_server($dsn);

my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1 });

{
    my $res = $dbh->selectall_arrayref(q{select count(jidid) from history});
    is($res->[0]->[0], 0, 'there is no prehistory');
};

my $client = Test::DJabberd::Client->new( server => $server, name => 'test' );
$client->login('test');

{
    my $res = $dbh->selectall_arrayref(q{select count(jidid) from history});
    is($res->[0]->[0], 0, 'there is no history from just connecting');
};

{
    $client->send_xml(q{
        <presence type="available" id="1701">
            <status>initial status</status>
        </presence>
    });

    # ugh, need to let the server process the presence request
    sleep 1;

    my $res = $dbh->selectall_arrayref(q{select jid, status, avail, source from history, jidmap where jidmap.jidid = history.jidid});
    is(scalar @$res, 1, 'sending presence made one history record');
    my ($hr) = @$res;
    like($hr->[0], qr{ \A test \@ }xms, 'saved status was for correct user');
    is($hr->[1], 'initial status', 'historical status was correctly saved');
    is($hr->[2], '', 'no availability from plain presence');
    is($hr->[3], 'im', 'correct default source ("im")');
};

{
    $client->send_xml(q{
        <presence type="available" id="1702">
            <show>away</show>
            <status>further status</status>
        </presence>
    });

    # ugh, need to let the server process the presence request
    sleep 1;

    my $res = $dbh->selectall_arrayref(q{select jid, status, avail, source from history, jidmap where jidmap.jidid = history.jidid order by time desc});
    is(scalar @$res, 2, 'sending another presence made another history record');
    my ($hr, undef) = @$res;
    like($hr->[0], qr{ \A test \@ }xms, 'saved status was for correct user');
    is($hr->[1], 'further status', 'different historical status was correctly saved');
    is($hr->[2], 'away', 'availability set when presence has a <show/>');
    is($hr->[3], 'im', 'correct default source ("im")');
};

1;

