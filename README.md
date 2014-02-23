# NAME

Dist::Zilla::Plugin::VerifyPhases - Compare data and files at different phases of the distribution build process

# VERSION

version 0.001

# SYNOPSIS

In your `dist.ini`, as the last plugin loaded:

    [VerifyPhases]

# DESCRIPTION

This plugin runs in multiple [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) phases to check what actions have
taken place so far.  Its intent is to find any plugins that are performing
actions outside the appropriate phase, so they can be fixed.

Running at the end of the `-FileGatherer` phase, it verifies that the
distribution's metadata has not yet been calculated (as it usually depends on
knowing the full manifest of files in the distribution).

It runs at the `-FileMunger` and `-AfterBuild` phases to record the state
of files after they have been munged, and again at the end of the build
process.  Any files that have had their names or content changed are flagged.

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
