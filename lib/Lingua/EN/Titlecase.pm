package Lingua::EN::Titlecase;

use strict;
use warnings;
require 5.006; # for POSIX classes
use base "Class::Accessor::Fast";
use overload '""' => sub { $_[0]->original ? $_[0]->titlecase : ref $_[0] },
    fallback => 1;

# DEVELOPER NOTES
# story card it out including a TT2 plugin
# HOW will entities and utf8 be handled?
# should be raw; OO and functional both?
# lc, default is prepositions, articles, conjunctions, can point to a
# file or to a hash ref (like a tied file, should have recipe)
# canonical /different word/, like OSS or eBay?
# Hyphen-Behavior
# confidence
# titlecase, tc
# rules

# NEED TO ALLOW FOR fixing or leaving things like pH, PERL, tied hash dictionary?

# new with 1 arg uses it as string
# with more than 1 tries constructors

# There are quite a few apostrophe edge cases right now and no
# utf8/entity handling

__PACKAGE__->mk_accessors qw( lc all_cap_threshold
                              uc_threshold
                              mixed_threshold
                              original
                              words
                              mixed_case_threshold dictionary );

use Carp;
our $VERSION = "0.02";

our %LC = map { $_ => 1 }
    qw( the a an and or but aboard about above across after against
        along amid among around as at before behind below beneath
        beside besides between beyond but by for from in inside into
        like minus near of off on onto opposite outside over past per
        plus regarding since than through to toward towards under
        underneath unlike until up upon versus via with within without
        v vs
        );

my $Apostrophe = qr/'/; #' This is very naive

my %Parse =
    (
     mixedcase => qr/(?<=[[:lower:]])[[:upper:]]
                    |
                     (?<=\s)[[:upper:]](?=[[:upper:]]+[[:lower:]])
                    |
                     (?<=\s)[[:upper:]](?=[[:lower:]]+[[:upper:]])
                    |
                     (?<=[[:lower:]]$Apostrophe)[[:upper:]]
                    |
                     \G(?<!\A)[[:upper:]]
                    /x,
     uppercase => qr/[[:upper:]]/,
     lowercase => qr/[[:lower:]]/,
     whitespace => qr/\s+/,
     wc => qr/[[:alpha:]]+$Apostrophe[[:alpha:]]+|[[:alpha:]]+/,
     );

# not used yet
our %Cases =
    (
     proper => undef,
     default_uc => undef,
     default_lc => undef, # see the %LC
    );

sub new : method {
    my $self = +shift->SUPER::new();

    if ( @_ == 1 )
    {
        $self->original($_[0]);
    }
    else
    {
        my %args = @_; # might be empty
        for my $key ( keys %args )
        {
            croak "Construction parameter \"$key\" not allowed"
                unless $Parse{$key};
            $self->$key($args{$key});
        }
    }
    $self->mixed_threshold(.3) unless $self->mixed_threshold;
    $self->uc_threshold(.9) unless $self->uc_threshold;
    $self;
}

sub mixedcase : method {
    my ( $self ) = @_;
    $self->_parse unless $self->{_mixedcase};
    wantarray ? @{$self->{_mixedcase}} : scalar @{$self->{_mixedcase}};
}

sub uppercase : method {
    my ( $self ) = @_;
    $self->_parse unless $self->{_uppercase};
    wantarray ? @{$self->{_uppercase}} : scalar @{$self->{_uppercase}};
}

sub lowercase : method {
    my ( $self ) = @_;
    $self->_parse unless $self->{_lowercase};
    wantarray ? @{$self->{_lowercase}} : scalar @{$self->{_lowercase}};
}

sub whitespace : method {
    my ( $self ) = @_;
    $self->_parse unless $self->{_whitespace};
    wantarray ? @{$self->{_whitespace}} : scalar @{$self->{_whitespace}};
}

sub wc : method {
    my ( $self ) = @_;
    $self->_parse unless $self->{_wc};
    wantarray ? @{$self->{_wc}} : scalar @{$self->{_wc}};
}

sub title : method {
    my ( $self, $newstring ) = @_;

    if ( $newstring )
    {
        $self->original($newstring);
        $self->_parse();
    }
    return $self->titlecase() if defined wantarray;
}


sub titlecase : method {
    my ( $self ) = @_;
    return $self->{_titlecase} if $self->{_titlecase};

    my $title = $self->original
        or croak "No original string set for titlecasing"; # wc better?

    my $length = length($title) - $self->whitespace;
    my $uc_ratio = $self->uppercase / $length;
    my $mixed_ratio = $self->mixedcase / $length;
    if ( $uc_ratio > $self->uc_threshold # too much uppercase to be real
         or
         $mixed_ratio > $self->mixed_threshold )
    {
        $title = lc $title;
    }
    $title =~ s/(\b(?<!\w[[:punct:]])\w+)/$LC{lc($1)} ? lc($1) : ucfirst($1)/eg;
    $title =~ s/(\A\w)/\U$1/g;
    $self->{_titlecase} = $title;
    $title;
}

sub _parse : method {
    my ( $self ) = @_;
    $self->{_titlecase} = '';
    {
        local $_ = $self->original;
        for my $name ( keys %Parse )
        {
            $self->{"_$name"} = [];
            @{$self->{"_$name"}} = /$Parse{$name}/g;
        }
    }
    1;
}

1;

__END__

Behaviors?
Leave alone non-dictionary words? Like code bits: [\w]?

1. Process comment titles from a blog?
2. Normalize titles in a news feed.
3. XHTML broken-up text -- Go _____ Your<i>self</i>
4. Big list of cases
5. Add a callback to specifically address something, pre or post

1-
    my $title = CGI::param("title");

4-
test cases


=pod

=head1 NAME

Lingua::EN::Titlecase - Titlecasing of English words by traditional editorial rules.

=head1 VERSION

0.02

=head1 CAVEAT

Alpha software. I'm very interested in feedback! All interfaces,
method names, and internal code subject to change or being roundfiled
in the BackPan.

Apologies for the current placeholders in this doc.

=head1 SYNOPSIS

 use Lingua::EN::Titlecase;
 my $tc = Lingua::EN::Titlecase->new("CAN YOU FIX A TITLE?");
 print $tc->title(), $/;

 $tc->title("and again but differently");
 print $tc->title(), $/;

 $tc->title("cookbook don't work, do she?");
 print "$tc\n";

=head1 DESCRIPTION

Titlecasing in standard English usage is the initial capitalization of
regular words minus inner articles, prepositions, and conjunctions.

This is one of those problems that is somewhat easy to solve for the
general case but impossible to solve for all cases. Hence the lack of
module till now.

# allow for style/usage plugins...?

Simple techniques like--

 $data =~ s/(\w+)/\u\L$1/g;

Fail on words like "can't" and don't always take into account
editorial rules or cases like--

=over 4

=item compound words -- Perl-like

=item abbreviations -- USA

=item mixedcase and proper names -- eBay: nEw KEyBOArD

=item all caps -- SHOUT ME DOWN

=back

Lingua::EN::Titlecase attempts to cater to the general cases and
provide hooks to address the special.

=head1 INTERFACE

=over 4

=item Lingua::EN::Titlecase->new()

=item $tc->new

The string to be titlecased can be set three ways. Single argument to
new. The "original" hash element to C<new>. With the C<title>
method.

 $tc->new("this is what should be titlecased");

 $tc->new(original => "no, this is");

 $tc->title("i beg to differ");

The last is to be able to reuse the Titlecase object.

Lingua::EN::Titlecase objects stringify to their processed titlecase,
if they have a string, the ref of the object otherwise.

=item $tc->original

Returns the original string.

=item $tc->title

Set the original string, returns the titlecased version. Both can be
done at once.

 print $tc->title("did you get that thing i sent?")

=item $tc->titlecase

Returns the titlecased string. Croaks if there is no original set via
the constructor or the method C<title>.

=back

=head2 STRATEGIES

One of the hardest parts of properly titlecasing input is just not
knowing if part of it is already correct and should not be clobbered.
E.g.--

 Old MacDonald had a farm

Is partly right and the proper name MacDonald should be left alone.
Lowercasing the whole string and then title casing would yield--

  Old Macdonald Had a Farm

So, to determine when to flatten a title to lowercase before
processing, we check the ratio of mixedcase and the ratio of caps.

=over 4

=item $tc->mixed_threshold

Set/get. The ratio of mixedcase to letters which triggers lowercasing
the whole string before trying to titlecase. The built-in threshold to
clobber is .30.

 # example

=item $tc->uc_threshold

Same as mixed but for "all" caps. Default threshold is .90.

 # example

=item $tc->mixed_case

Scalar context returns count of mixedcase letters found. All caps and
initial caps are not counted. List context returns the letters. E.g.--

 my $tc = Lingua::EN::Titlecase->new();
 $tc->title("tHaT pROBABly Will nevEr BE CorrectlY hanDled");
 printf "%d, %s\n",
     scalar($tc->mixedcase),
     join(" ", $tc->mixedcase);

Yields--

 11, H T R O B A B E C Y D

This is useful for determining if a string is overly mixed. Substrings
like "pH" crop up now and then but they should never compose a high
percentage of a properly cased title.

=item $tc->wc

"Word" count. Scalar context returns count of "words." List returns
them.

=item $tc->lowercase

Count/list of lowercase letters found.

=item $tc->mixedcase

Count/list of mixedcase letters found.

=item $tc->uppercase

Count/list of uppercase letters found.

=item $tc->whitespace

Count/list of whitespace -- \s+ -- found.

=back

=head1 DIAGNOSTICS

=over 2

=item No diagnostics for you!

[Non-existent Description of error here]

=back

=head1 TODO

Dictionary hook to allow BIG lists of proper names and lc to be
applied.

Handle hypens; user hooks.

Smart apostrophe, utf8, entities?

Recipes. Including TT2 "plugin" recipe.

Take out Class::Accessor...? For having it all in one place, checking
args, and slight speed gain.

Bigger test suite.


=head1 RECIPES

Mini-scripts to test strings or accomplish custom configuration goals.

=head1 CONFIGURATION AND ENVIRONMENT

...321
  
Lingua::EN::Titlecase requires no configuration files or environment variables.

=head1 DEPENDENCIES

Perl 5.6 or better to support POSIX regex classes.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

This is alpha-software. No bugs have been reported.

Please report any bugs or feature requests to
C<bug-lingua-en-titlecase@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Ashley Pond V  C<< <ashley@cpan.org> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Ashley Pond V C<< <ashley@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
