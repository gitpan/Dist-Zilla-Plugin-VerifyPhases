use strict;
use warnings;
package Dist::Zilla::Plugin::VerifyPhases;
BEGIN {
  $Dist::Zilla::Plugin::VerifyPhases::AUTHORITY = 'cpan:ETHER';
}
# git description: v0.002-1-gd62718d
$Dist::Zilla::Plugin::VerifyPhases::VERSION = '0.003';
# ABSTRACT: Compare data and files at different phases of the distribution build process
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with
    'Dist::Zilla::Role::BeforeBuild',
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::EncodingProvider',
    'Dist::Zilla::Role::FilePruner',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::AfterBuild';
use Moose::Util 'find_meta';
use Digest::MD5 'md5_hex';
use List::MoreUtils qw(none first_index first_value);
use namespace::autoclean;

# filename => { object => $file_object, content => $checksummed_content }
my %all_files;

#sub mvp_multivalue_args { qw(skip) }
has skip => (
    isa => 'ArrayRef[Str]',
    traits => [ 'Array' ],
    handles => { skip => 'elements' },
    init_arg => undef,   # do not allow in configs just yet
    lazy => 1,
    default => sub { [ qw(Makefile.PL Build.PL) ] },
);

sub before_build
{
    my $self = shift;

    # adjust plugin order so that we are always last!
    my $plugins = $self->zilla->plugins;
    my $index = first_index { $_ == $self } @$plugins;

    splice(@$plugins, $index, 1);
    push @$plugins, $self;
}

sub gather_files
{
    my $self = shift;

    my $distmeta_attr = find_meta($self->zilla)->find_attribute_by_name('distmeta');
    $self->log('distmeta has already been calculated after file gathering phase!')
        if $distmeta_attr->has_value($self->zilla);

    my $version_attr = find_meta($self->zilla)->find_attribute_by_name('version');
    $self->log('version has already been calculated after file gathering phase!')
        if $version_attr->has_value($self->zilla);

    # all files should have been added by now. save their filenames/objects
    foreach my $file (@{$self->zilla->files})
    {
        $all_files{$file->name} = {
            object => $file,
            # encoding can change; don't bother capturing it yet
            # content can change; don't bother capturing it yet
        }
    }
}

# since last phase,
# new files added: no
# files removed: no
# files renamed: no
# encoding changed: ok to now; no from now on
# contents: ignore
sub set_file_encodings
{
    my $self = shift;

    # since the encoding attribute is SetOnce, if we force all the builders to
    # fire now, we can guarantee they won't change later
    foreach my $file (@{$self->zilla->files})
    {
        $all_files{$file->name}{encoding} = $file->encoding;
    }
}

# since last phase,
# new files added: no
# files removed: ok to now; no from now on
# files renamed: no
# encoding changed: no
# contents: ignore
sub prune_files
{
    my $self = shift;

    foreach my $file (@{$self->zilla->files})
    {
        if ($all_files{$file->name} and $all_files{$file->name}{object} == $file)
        {
            delete $all_files{$file->name};
            next;
        }

        # file has been renamed - an odd time to do this
        if (my $orig_filename = first_value { $all_files{$_}{object} == $file } keys %all_files)
        {
            $self->log('file has been renamed after file gathering phase: \'' . $file->name
                . "' (originally '$orig_filename', " . $file->added_by . ')');
            delete $all_files{$orig_filename};
            next;
        }

        $self->log('file has been added after file gathering phase: \'' . $file->name
            . '\' (' . $file->added_by . ')');
    }

    # anything left over has been removed, but this is okay by a file pruner

    # capture full file list all over again.
    %all_files = ();
    foreach my $file (@{$self->zilla->files})
    {
        $all_files{$file->name} = {
            object => $file,
            encoding => $file->encoding,
            content => undef,   # content can change; don't bother capturing it yet
        }
    }
}

# since last phase,
# new files added: no
# files removed: no
# files renamed: allowed
# encoding changed: no
# record contents: ok to now; no from now on
sub munge_files
{
    my $self = shift;

    # cross off all files by their original filenames, to see what's left.
    foreach my $file (@{$self->zilla->files})
    {
        if ($all_files{$file->name} and $all_files{$file->name}{object} == $file)
        {
            delete $all_files{$file->name};
            next;
        }

        # file has been renamed - but this is okay by a file munger
        if (my $orig_filename = first_value { $all_files{$_}{object} == $file } keys %all_files)
        {
            delete $all_files{$orig_filename};
            next;
        }

        # this is a new file we haven't seen before.
        $self->log('file has been added after file gathering phase: \'' . $file->name
            . '\' (' . $file->added_by . ')');
    }

    # now report on any files added earlier that were removed.
    foreach my $filename (keys %all_files)
    {
        $self->log('file has been removed after file pruning phase: \'' . $filename
            . '\' (' . $all_files{$filename}{object}->added_by . ')');
    }


    # capture full file list all over again, recording contents now.
    %all_files = ();
    foreach my $file (@{$self->zilla->files})
    {
        # don't force FromCode files to calculate early; it might fire some
        # lazy attributes prematurely
        $all_files{$file->name} = {
            object => $file,
            encoding => $file->encoding,
            content => ( $file->isa('Dist::Zilla::File::FromCode')
                ? 'content ignored'
                : md5_hex($file->encoded_content) ),
        }
    }
}

# since last phase,
# new files added: no
# files removed: no
# files renamed: no
# change contents: no
sub after_build
{
    my $self = shift;

    foreach my $file (@{$self->zilla->files})
    {
        if (not $all_files{$file->name} or $all_files{$file->name}{object} != $file)
        {
            if (my $orig_filename = first_value { $all_files{$_}{object} == $file } keys %all_files)
            {
                $self->log('file has been renamed after munging phase: \'' . $file->name
                    . "' (originally '$orig_filename', " . $file->added_by . ')');
                delete $all_files{$orig_filename};
            }
            else
            {
                $self->log('file has been added after file gathering phase: \'' . $file->name
                    . '\' (' . $file->added_by . ')');
            }
            next;
        }

        # we give FromCode files a bye, since there is a good reason why their
        # content at file munging time is incomplete
        $self->log('content has changed after munging phase: \'' . $file->name
            # this looks suspicious; we ought to have separate added_by,
            # changed_by attributes
                . '\' (' . $file->added_by . ')')
            if not $file->isa('Dist::Zilla::File::FromCode')
                and none { $file->name eq $_ } $self->skip
                and $all_files{$file->name}{content} ne md5_hex($file->encoded_content);

        delete $all_files{$file->name};
    }

    foreach my $filename (keys %all_files)
    {
        $self->log('file has been removed after file pruning phase: \'' . $filename
            . '\' (' . $all_files{$filename}{object}->added_by . ')');
    }
}

1;

__END__

=pod

=encoding UTF-8

=for :stopwords Karen Etheridge FromCode irc

=head1 NAME

Dist::Zilla::Plugin::VerifyPhases - Compare data and files at different phases of the distribution build process

=head1 VERSION

version 0.003

=head1 SYNOPSIS

In your F<dist.ini>:

    [VerifyPhases]

=head1 DESCRIPTION

This plugin runs in multiple L<Dist::Zilla> phases to check what actions have
taken place so far.  Its intent is to find any plugins that are performing
actions outside the appropriate phase, so they can be fixed.

Running at the end of the C<-FileGatherer> phase, it verifies that the
distribution's metadata has not yet been calculated (as it usually depends on
knowing the full manifest of files in the distribution), and that the
distribution's version has not been calculated (as it can depend on parsing
file content, before we know their encodings).

Running at the end of the C<-EncodingProvider> phase, it forces all encodings
to be built (by calling their lazy builders), to use their C<SetOnce> property
to ensure that no subsequent phase attempts to alter a file encoding.

Running at the end of the C<-FilePruner> phase, it verifies that no additional
files have been added to the distribution, nor renamed, since the
C<-FileGatherer> phase.

Running at the end of the C<-FileMunger> phase, it verifies that no additional
files have been added to nor removed from the distribution, nor renamed, since
the C<-FilePruner> phase.

Running at the end of the C<-AfterBuild> phase, the full state of all files
are checked: files may not be added, removed, renamed nor had their content
change.

Currently, L<FromCode|Dist::Zilla::File::FromCode> files are not checked for
content, as interesting side effects can occur if their content subs are run
before all content is available (for example, other lazy builders can run too
early, resulting in incomplete or missing data).

=for Pod::Coverage before_build gather_files set_file_encodings prune_files munge_files after_build

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER>
(or L<bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org|mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

=over 4

=item *

L<Dist::Zilla::Plugin::ReportPhase>

=item *

L<Dist::Zilla::App::Command::dumpphases>

=back

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
