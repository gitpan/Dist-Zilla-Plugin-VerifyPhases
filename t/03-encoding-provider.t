use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::DZil;
use Path::Tiny;

my @added_line;
{
    package Dist::Zilla::Plugin::Naughty;
    use Moose;
    with
        'Dist::Zilla::Role::FileGatherer',
        'Dist::Zilla::Role::FileMunger';
    use List::MoreUtils 'first_value';
    use Dist::Zilla::File::InMemory;

    sub gather_files
    {
        my $self = shift;
        push @added_line, __LINE__; $self->add_file( Dist::Zilla::File::InMemory->new(
            name => 'file_0',
            content => 'oh hai!',
        ));
    }
    sub munge_files
    {
        my $self = shift;

        # not okay to change encodings at munge time
        my $file0 = first_value { $_->name eq 'file_0' } @{$self->zilla->files};
        $file0->encoding('Latin1');
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

    like(
        exception { $tzil->build },
        qr/cannot change value of .*encoding/,
        'cannot set encoding attribute after EncodingProvider phase',
    );
}

done_testing;
