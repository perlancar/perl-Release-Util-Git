package Release::Util::Git;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Regexp::Pattern 'Git::release_tag';

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
        release_tag_regex => {
            summary => 'Regex to match a release tag',
            schema => 're*',
            default => qr/\A$RE{release_tag}/,
        },
        author_name_regex => {
            summary => 'Only consider release commits where author name matches this regex',
            schema => 're*',
        },
        author_email_regex => {
            summary => 'Only consider release commits where author email matches this regex',
            schema => 're*',
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
            args => {detail=>1, release_tag_regex=>'^release'},
            'x.doc.show_result' => 0,
            test => 0,
        },
    ],
};
sub list_git_release_tags {
    require File::Which;

    my %args = @_;

    # XXX schema
    my $release_tag_regex  = $args{release_tag_regex} // $args{regex} // $RE{release_tag};
    my $author_name_regex  = $args{author_name_regex};
    my $author_email_regex = $args{author_email_regex};

    -d ".git" or return [412, "No .git subdirectory found"];
    File::Which::which("git") or return [412, "git is not found in PATH"];

    my @res;
    my $resmeta = {};

    for my $line (`git for-each-ref --format='%(creatordate:raw)%09%(authorname)%09%(authoremail)%09%(refname)%09%(objectname)' refs/tags`) {
        my ($epoch, $offset, $author_name, $author_email, $tag, $commit) = $line =~ m!^(\d+) ([+-]\d+)\t(.+?)\t(.+?)\trefs/tags/(.+)\t(.+)$! or next;
        $tag =~ $release_tag_regex or next;
        my $rec = {
            tag => $tag,
            date => $epoch,
            tz_offset => $offset,
            author_name => $author_name,
            author_email => $author_email,
            commit => $commit,
        };
        if (defined $author_name_regex && $rec->{author_name} !~ $author_name_regex) {
            log_debug "Not including release tag $tag because author name ($rec->{author_name}) does not match regex $author_name_regex";
            next;
        }
        if (defined $author_email_regex && $rec->{author_email} !~ $author_email_regex) {
            log_debug "Not including release tag $tag because author email ($rec->{author_email}) does not match regex $author_email_regex";
            next;
        }
        push @res, $rec;
    }

    if ($args{detail}) {
        $resmeta->{'table.fields'} = [qw/tag date tz_offset author_name author_email commit/];
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
    my $res = list_git_release_tags(%args, detail=>1);
    return $res unless $res->[0] == 200;

    my %tags; # key = year, value = tags
    for my $e (@{ $res->[2] }) {
        # XXX use tz_offset? use gmtime?
        my $year = (localtime $e->{date})[5] + 1900;
        push @{ $tags{$year} }, $e->{tag};
    }

    my $resmeta = {};

    my @res;
    if ($args{detail}) {
        @res = map { +{year=>$_, tags=>$tags{$_}} }
            reverse sort keys %tags;
        $resmeta->{'table.fields'} = [qw/year tags/];
    } else {
        @res = reverse sort keys %tags;
    }

    [200, "OK", \@res, $resmeta];
}

1;
# ABSTRACT: Utility routines related to software releases and git

=cut
