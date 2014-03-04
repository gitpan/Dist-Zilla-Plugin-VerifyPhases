# NAME

Dist::Zilla::Plugin::VerifyPhases - Compare data and files at different phases of the distribution build process

# VERSION

version 0.002

# SYNOPSIS

In your `dist.ini`:

    [VerifyPhases]

# DESCRIPTION

This plugin runs in multiple [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) phases to check what actions have
taken place so far.  Its intent is to find any plugins that are performing
actions outside the appropriate phase, so they can be fixed.

Running at the end of the `-FileGatherer` phase, it verifies that the
distribution's metadata has not yet been calculated (as it usually depends on
knowing the full manifest of files in the distribution).

Running at the end of the `-EncodingProvider` phase, it forces all encodings
to be built (by calling their lazy builders), to use their `SetOnce` property
to ensure that no subsequent phase attempts to alter a file encoding.

Running at the end of the `-FilePruner` phase, it verifies that no additional
files have been added to the distribution, nor renamed, since the
`-FileGatherer` phase.

Running at the end of the `-FileMunger` phase, it verifies that no additional
files have been added to nor removed from the distribution, nor renamed, since
the `-FilePruner` phase.

Running at the end of the `-AfterBuild` phase, the full state of all files
are checked: files may not be added, removed, renamed nor had their content
change.

Currently, [FromCode](https://metacpan.org/pod/Dist::Zilla::File::FromCode) files are not checked for
content, as interesting side effects can occur if their content subs are run
before all content is available (for example, other lazy builders can run too
early, resulting in incomplete or missing data).

# SUPPORT

Bugs may be submitted through [the RT bug tracker](https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-PluginBundle-Author-ETHER)
(or [bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org](mailto:bug-Dist-Zilla-PluginBundle-Author-ETHER@rt.cpan.org)).
I am also usually active on irc, as 'ether' at `irc.perl.org`.

# SEE ALSO

- [Dist::Zilla::Plugin::ReportPhase](https://metacpan.org/pod/Dist::Zilla::Plugin::ReportPhase)
- [Dist::Zilla::App::Command::dumpphases](https://metacpan.org/pod/Dist::Zilla::App::Command::dumpphases)

# AUTHOR

Karen Etheridge <ether@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
