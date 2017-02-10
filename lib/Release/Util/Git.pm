package Release::Util::Git;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{list_git_release_tags} = {
    v => 1.1,
    summary => 'List git release tags',
    description => <<'_',

It's common to tag a release with something like:

    v1.2.3

This routine returns a list of them.

_
    args => {
        regex => {
            summary => 'Regex to match a release tag',
            schema => 're*',
            default => qr/\A(version|ver|v)?\d/,
        },
        detail => {
            schema => ['bool*', is=>1],
            cmdline_aliases => {l=>{}},
        },
    },
    deps => {
        prog => 'git',
    },
    examples => [
        {
            args => {detail=>1, regex=>'^release'},
            'x.doc.show_result' => 0,
            test => 0,
        },
    ],
};
sub list_git_release_tags {
    require File::Which;

    my %args = @_;

    # XXX schema
    my $regex = $args{regex} // qr/\A(version|ver|v)?\d/;

    -d ".git" or return [412, "No .git subdirectory found"];
    File::Which::which("git") or return [412, "git is not found in PATH"];

    my @res;
    my $resmeta = {};

    for my $line (`git for-each-ref --format='%(creatordate:raw) %(refname) %(objectname)' refs/tags`) {
        my ($epoch, $offset, $tag, $commit) = $line =~ m!^(\d+) ([+-]\d+) refs/tags/(.+) (.+)$! or next;
        $tag =~ $regex or next;
        push @res, {
            tag => $tag,
            date => $epoch,
            tz_offset => $offset,
            commit => $commit,
        },
    }

    if ($args{detail}) {
        $resmeta->{'table.fields'} = [qw/tag date tz_offset commit/];
    } else {
        @res = map { $_->{tag} } @res;
    }

    [200, "OK", \@res, $resmeta];
}

$SPEC{list_git_release_years} = {
    v => 1.1,
    summary => 'List git release years',
    description => <<'_',

This routine uses list_git_release_tags() to collect the release tags and their
dates, then group them by year.

_
    args => $SPEC{list_git_release_tags}{args},
    deps => $SPEC{list_git_release_tags}{deps},
    examples => [
        {
            args => {detail=>1, regex=>'^release'},
            'x.doc.show_result' => 0,
            test => 0,
        },
    ],
};
sub list_git_release_years {
    my %args = @_;
    my $res = list_git_release_years(%args);
    return $res unless $res->[0] == 200;

    my %tags; # key = year
    my $resmeta = {};

    my @res;
    if ($args{detail}) {
        @res = map { +{year=>$_, tags=>$tags{$_}} } reverse sort keys %tags;
        $resmeta->{'table.fields'} = [qw/year tags/];
    } else {
        @res = reverse sort keys %tags;
    }

    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT: Utility routines related to software releases and git

=cut
