use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Lingua::EN::Titlecase',
    AUTHOR              => 'Ashley Pond V <ashley@cpan.org>',
    VERSION_FROM        => 'lib/Lingua/EN/Titlecase.pm',
    ABSTRACT_FROM       => 'lib/Lingua/EN/Titlecase.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        "Test::More" => 0,
        "Carp"       => 0,
        "List::Util" => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Lingua-EN-Titlecase-*' },
);
