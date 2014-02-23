use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::Deep;
use Test::DZil;

{
    package Dist::Zilla::Plugin::Naughty;
    use Moose;
    with
        'Dist::Zilla::Role::FileGatherer',
        'Dist::Zilla::Role::PrereqSource',
        'Dist::Zilla::Role::FileInjector';

    sub gather_files
    {
        my $self = shift;
        my $distmeta = $self->zilla->distmeta;  # make the attribute fire
    }
    sub register_prereqs
    {
        my $self = shift;
        require Dist::Zilla::File::InMemory;
        $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'rogue_file',
            content => 'naughty naughty!',
        ));
    }
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                'source/dist.ini' => simple_ini(
                    [ Naughty => ],
                    [ VerifyPhases => ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    $tzil->build;

    cmp_deeply(
        $tzil->log_messages,
        supersetof(
            '[VerifyPhases] distmeta has already been calculated after file gathering phase!',
            '[VerifyPhases] file has been added after munging phase: \'rogue_file\'',
        ),
        'warnings are logged about our naughty plugin',
    )
    or diag explain $tzil->log_messages;
}

done_testing;
