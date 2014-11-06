use strict;
use warnings;
package Dist::Zilla::Plugin::VerifyPhases;
# git description: v0.005-1-g1911da9
$Dist::Zilla::Plugin::VerifyPhases::VERSION = '0.006';
# ABSTRACT: Compare data and files at different phases of the distribution build process
# KEYWORDS: plugin distribution configuration phase verification validation
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
use List::Util 1.33 qw(none first any);
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

my %zilla_constructor_args;

sub BUILD
{
    my $self = shift;
    my $zilla = $self->zilla;

    # no phases have been run yet, so we can effectively capture the initial
    # state of the zilla object (and determine its construction args)
    %zilla_constructor_args = map {
        my $attr = find_meta($zilla)->find_attribute_by_name($_);
        $attr->has_value($zilla) ? ( $_ => $attr->get_value($zilla) ) : ()
    } qw(name version abstract main_module authors distmeta _license_class _copyright_holder _copyright_year);
}

# nothing to put in dump_config yet...
# around dump_config => sub { ... };

sub before_build
{
    my $self = shift;

    # adjust plugin order so that we are always last!
    my $plugins = $self->zilla->plugins;
    @$plugins = ((grep { $_ != $self } @$plugins), $self);
}

sub gather_files
{
    my $self = shift;

    my $zilla = $self->zilla;
    foreach my $attr_name (qw(name version abstract main_module authors distmeta))
    {
        next if exists $zilla_constructor_args{$attr_name};
        $self->log($attr_name . ' has already been calculated by end of file gathering phase')
            if find_meta($zilla)->find_attribute_by_name($attr_name)->has_value($zilla);
    }

    # license is created from some private attrs, which may have been provided
    # at construction time
    $self->log('license has already been calculated by end of file gathering phase')
        if any {
            not exists $zilla_constructor_args{$_}
                and find_meta($zilla)->find_attribute_by_name($_)->has_value($zilla)
        } qw(_license_class _copyright_holder _copyright_year);

    # all files should have been added by now. save their filenames/objects
    foreach my $file (@{$zilla->files})
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
        if (my $orig_filename = first { $all_files{$_}{object} == $file } keys %all_files)
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
        if (my $orig_filename = first { $all_files{$_}{object} == $file } keys %all_files)
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

    # verify that nothing has tried to read the prerequisite data yet
    # (only possible when the attribute is lazily built)
    my $prereq_attr = find_meta($self->zilla)->find_attribute_by_name('prereqs');
    $self->log('prereqs have already been read from after munging phase!')
         if Dist::Zilla->VERSION >= 5.024 and $prereq_attr->has_value($self->zilla);
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
            if (my $orig_filename = first { $all_files{$_}{object} == $file } keys %all_files)
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

=head1 NAME

Dist::Zilla::Plugin::VerifyPhases - Compare data and files at different phases of the distribution build process

=head1 VERSION

version 0.006

=head1 SYNOPSIS

In your F<dist.ini>:

    [VerifyPhases]

=head1 DESCRIPTION

This plugin runs in multiple L<Dist::Zilla> phases to check what actions have
taken place so far.  Its intent is to find any plugins that are performing
actions outside the appropriate phase, so they can be fixed.

Running at the end of the C<-FileGatherer> phase, it verifies that the
following distribution properties have not yet been populated/calculated, as
they usually depend on having the full complement of files added to the
distribution, with known encodings:

=over 4

=item *

name

=item *

version

=item *

abstract

=item *

main_module

=item *

license

=item *

authors

=item *

metadata

=back

Running at the end of the C<-EncodingProvider> phase, it forces all encodings
to be built (by calling their lazy builders), to use their C<SetOnce> property
to ensure that no subsequent phase attempts to alter a file encoding.

Running at the end of the C<-FilePruner> phase, it verifies that no additional
files have been added to the distribution, nor renamed, since the
C<-FileGatherer> phase.

Running at the end of the C<-FileMunger> phase, it verifies that no additional
files have been added to nor removed from the distribution, nor renamed, since
the C<-FilePruner> phase. Additionally, it verifies that the prerequisite list
has not yet been read from, when possible.

Running at the end of the C<-AfterBuild> phase, the full state of all files
are checked: files may not be added, removed, renamed nor had their content
change.

=for stopwords FromCode

Currently, L<FromCode|Dist::Zilla::File::FromCode> files are not checked for
content, as interesting side effects can occur if their content subs are run
before all content is available (for example, other lazy builders can run too
early, resulting in incomplete or missing data).

=for Pod::Coverage BUILD before_build gather_files set_file_encodings prune_files munge_files after_build

=head1 SUPPORT

=for stopwords irc

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
