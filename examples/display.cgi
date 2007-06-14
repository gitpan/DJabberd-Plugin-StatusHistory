#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use CGI;

use constant DSN => "dbi:SQLite:$ENV{HOME}/djabberd/statushistory.sqlite";


my $dbh = DBI->connect(DSN);
my $cgi = CGI->new;

my $jid = $cgi->path_info;
$jid =~ s{ \A / }{}xms;

my $sth = $dbh->prepare(q{select time, status, avail, source }
    . q{from history, jidmap where history.jidid = jidmap.jidid }
    . q{and jidmap.jid = ? order by time desc limit 10});

my ($time, $status, $avail, $source);
my $rv = $sth->execute($jid);
$sth->bind_columns(\$time, \$status, \$avail, \$source);


print "Content-type: text/html\n\n";

print "<h1>$jid</h1>\n";

print "<table>\n";
print "<tr><th>when</th><th>status</th><th>availability</th><th>source</th></tr>\n";

while ($sth->fetchrow_arrayref) {
    print "<tr><td>$time</td><td>$status</td><td>$avail</td><td>$source</td></tr>\n";
}

print "</table>\n";


