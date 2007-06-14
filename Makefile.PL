use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'DJabberd::Plugin::StatusHistory',
    AUTHOR        => 'Mark Paschal <markpasc@markpasc.org>',
    VERSION_FROM  => 'lib/DJabberd/Plugin/StatusHistory.pm',
    ABSTRACT_FROM => 'lib/DJabberd/Plugin/StatusHistory.pm',
    PREREQ_PM     => {
        DateTime => 0,
        DJabberd => 0,
    },
);

