use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Path::Tiny;

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ MakeMaker => ],
                    [ VerifyPhases => ], # { skip => [ 'Makefile.PL' ] }
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    $tzil->build;

    cmp_deeply(
        [
            grep {
                /\[VerifyPhases\]/
                && ( Dist::Zilla->VERSION < 5.022
                    ? ! /^\[VerifyPhases\] file has been added after file gathering phase: 'Makefile.PL'/
                    : 1 )
            }
                @{ $tzil->log_messages }
        ],
        [],
        'no warnings from the plugin despite Makefile.PL being modified late',
    );

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

done_testing;

