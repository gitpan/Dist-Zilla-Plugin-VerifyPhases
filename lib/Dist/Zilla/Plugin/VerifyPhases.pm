use strict;
use warnings;
package Dist::Zilla::Plugin::VerifyPhases;
BEGIN {
  $Dist::Zilla::Plugin::VerifyPhases::AUTHORITY = 'cpan:ETHER';
}
# git description: ba66047
$Dist::Zilla::Plugin::VerifyPhases::VERSION = '0.001';
# ABSTRACT: Compare data and files at different phases of the distribution build process
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::AfterBuild';
use Moose::Util 'find_meta';
use Digest::MD5 'md5_hex';
use namespace::autoclean;

my %all_files;

sub gather_files
{
    my $self = shift;

    my $distmeta_attr = find_meta($self->zilla)->find_attribute_by_name('distmeta');
    $self->log('distmeta has already been calculated after file gathering phase!')
        if $distmeta_attr->has_value($self->zilla);
}

sub munge_files
{
    my $self = shift;

    foreach my $file (@{$self->zilla->files})
    {
        # don't force FromCode files to calculate early; it might fire some
        # lazy attributes prematurely
        $all_files{$file->name} = $file->isa('Dist::Zilla::File::FromCode')
            ? 'content ignored'
            : md5_hex($file->encoded_content);
    }
}

sub after_build
{
    my $self = shift;

    foreach my $file (@{$self->zilla->files})
    {
        if (not exists $all_files{$file->name})
        {
            $self->log('file has been added after munging phase: \'' . $file->name . '\'');
            next;
        }

        # we give FromCode files a bye, since there is a good reason why their
        # content at file munging time is incomplete
        $self->log('content has changed after munging phase: \'' . $file->name . '\'')
            if not $file->isa('Dist::Zilla::File::FromCode')
                and $all_files{$file->name} ne md5_hex($file->encoded_content);

        delete $all_files{$file->name};
    }

    foreach my $file (keys %all_files)
    {
        $self->log('File has been removed after munging phase: \'' . $file . '\'');
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

version 0.001

=head1 SYNOPSIS

In your F<dist.ini>, as the last plugin loaded:

    [VerifyPhases]

=head1 DESCRIPTION

This plugin runs in multiple L<Dist::Zilla> phases to check what actions have
taken place so far.  Its intent is to find any plugins that are performing
actions outside the appropriate phase, so they can be fixed.

Running at the end of the C<-FileGatherer> phase, it verifies that the
distribution's metadata has not yet been calculated (as it usually depends on
knowing the full manifest of files in the distribution).

It runs at the C<-FileMunger> and C<-AfterBuild> phases to record the state
of files after they have been munged, and again at the end of the build
process.  Any files that have had their names or content changed are flagged.

Currently, L<FromCode|Dist::Zilla::File::FromCode> files are not checked for
content, as interesting side effects can occur if their content subs are run
before all content is available (for example, other lazy builders can run too
early, resulting in incomplete or missing data).

=for Pod::Coverage gather_files munge_files after_build

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
