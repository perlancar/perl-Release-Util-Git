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
    examples => [
        {args => {detail=>1, regex=>'^release'}},
    ],
};
sub list_git_release_tags {
    my %args = @_;

    # XXX schema
    my $regex = $args{regex} // qr/\A(version|ver|v)?\d/;

    -d ".git" or return [412, "No .git subdirectory found"];

    my @res;
    my $resmeta = {};

    for my $line (`git for-each-ref --format='%(creatordate:raw) %(refname) %(objectname)' refs/tags`) {
        my ($epoch, $offset, $tag, $commit) = $line =~ m!^(\d+) ([+-]\d+) refs/tags/(.+) (.+)$! or next;
        $tag =~ $regex or next;
        push @res, {
            tag => $tag,
            date => $epoch,
            commit => $commit,
        },
    }

    $resmeta->{'table.fields'} = [qw/tag date /] if $args{detail};

    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT: Utility routines related to software releases and git

=cut
