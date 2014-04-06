use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Deep;
use Test::DZil;
use Path::Tiny;

my @added_line;
{
    package Dist::Zilla::Plugin::Naughty;
    use Moose;
    with
        'Dist::Zilla::Role::FileGatherer',
        'Dist::Zilla::Role::FileMunger',
        'Dist::Zilla::Role::PrereqSource',
        'Dist::Zilla::Role::FileInjector';
    use Dist::Zilla::File::InMemory;
    use List::MoreUtils 'first_value';

    sub gather_files
    {
        my $self = shift;
        my $distmeta = $self->zilla->distmeta;  # make the attribute fire
        my $version = $self->zilla->version;    # make the attribute fire
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_0',
            content => 'oh hai!',
        ));
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_1',
            content => 'oh hai!',
        ));
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'normal_file_2',
            content => 'oh hai!',
        ));
    }
    sub munge_files
    {
        my $self = shift;

        # okay to rename files at munge time
        my $file0 = first_value { $_->name eq 'normal_file_0' } @{$self->zilla->files};
        $file0->name('normal_file_0_moved');

        # not okay to remove files at munge time
        $self->zilla->prune_file(first_value { $_->name eq 'normal_file_2' } @{$self->zilla->files});

        # not okay to add files at munge time
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'rogue_file_3',
            content => 'naughty naughty!',
        ));
    }
    sub register_prereqs
    {
        my $self = shift;

        # not okay to remove files at prereq time
        $self->zilla->prune_file(first_value { $_->name eq 'normal_file_0_moved' } @{$self->zilla->files});

        # not okay to rename files at prereq time
        my $file1 = first_value { $_->name eq 'normal_file_1' } @{$self->zilla->files};
        $file1->name('normal_file_1_moved');

        # not okay to add files at prereq time
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'rogue_file_4',
            content => 'naughty naughty!',
        ));
    }
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does_not_exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ Naughty => ],
                    [ VerifyPhases => ],
                ),
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    $tzil->build;

    cmp_deeply(
        [ grep { /\[VerifyPhases\]/ } @{ $tzil->log_messages } ],
        bag(
            '[VerifyPhases] distmeta has already been calculated after file gathering phase!',
            '[VerifyPhases] version has already been calculated after file gathering phase!',
            "[VerifyPhases] file has been removed after file pruning phase: 'normal_file_0_moved' (content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[0]))",
            "[VerifyPhases] file has been renamed after munging phase: 'normal_file_1_moved' (originally 'normal_file_1', content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[1]))",
            "[VerifyPhases] file has been removed after file pruning phase: 'normal_file_2' (content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[2]))",
            "[VerifyPhases] file has been added after file gathering phase: 'rogue_file_3' (content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[3]))",
            "[VerifyPhases] file has been added after file gathering phase: 'rogue_file_4' (content set by Naughty (Dist::Zilla::Plugin::Naughty line $added_line[4]))",
        ),
        'warnings are logged about our naughty plugin',
    )
    or diag explain $tzil->log_messages;
}

done_testing;
