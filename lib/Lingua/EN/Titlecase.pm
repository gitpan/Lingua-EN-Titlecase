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
# allow user to set order of applying look-up rules, lc > uc, e.g.

# NEED TO ALLOW FOR fixing or leaving things like pH, PERL, tied hash dictionary?

# new with 1 arg uses it as string
# with more than 1 tries constructors

# There are quite a few apostrophe edge cases right now and no
# utf8/entity handling

__PACKAGE__->mk_accessors qw( 
                              uc_threshold
                              mixed_threshold
                              allow_mixed
                              );

use List::Util qw(first);
use Carp;
our $VERSION = "0.05";

our %LC = map { $_ => 1 }
    qw( the a an and or but aboard about above across after against
        along amid among around as at before behind below beneath
        beside besides between beyond but by for from in inside into
        like minus near of off on onto opposite outside over past per
        plus regarding since than through to toward towards under
        underneath unlike until up upon versus via with within without
        v vs
        );

my %Attr = (
            original => 1,
            title => 1,
            uc_threshold => 1,
            mixed_threshold => 1,
            );

my $Apostrophe = qr/[[:punct:]]/; #' This is very naive

my $Mixed =qr/(?<=[[:lower:]])[[:upper:]]
                    |
                     (?<=\A)[[:upper:]](?=[[:upper:]]+[[:lower:]])
                    |
                     (?<=\A)[[:upper:]](?=[[:lower:]]+[[:upper:]])
                    |
                     (?<=[[:lower:]]$Apostrophe)[[:upper:]]
                    |
                     \G(?<!\A)[[:upper:]]
             /x;

my $Wordish = qr/
            [[:alpha:]]
            (?: (?<=[[:alpha:]])[[:punct:]](?=[[:alpha:]]) | [[:alpha:]] )*
            [[:alpha:]]*
                       /x;

my $Lexer = sub {
            $_[0] =~ s/\A($Wordish)// and return [ "word", "$1" ];
            $_[0] =~ s/\A(.)//s and return [ undef, "$1" ];
            return ();
        };

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
                unless $Attr{$key};
            $self->$key($args{$key});
        }
    }
    $self->_init();
    $self;
}

sub _init : method {
    my ( $self ) = @_;
    $self->{_titlecase} = '';
    $self->{_real_length} = 0;
    $self->{_mixedcase} = [];
    $self->{_wc} = [];
    $self->{_token_queue} = [];
    $self->{_uppercase} = [];
    $self->allow_mixed(undef);
    $self->mixed_threshold(0.25) unless $self->mixed_threshold;
    $self->uc_threshold(0.90) unless $self->uc_threshold;
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
        $self->{_original} = $newstring;
        $self->_init();
        $self->_parse();
    }
    return $self->titlecase() if defined wantarray;
}

sub original : method {
    my ( $self ) = @_;
    return $self->{_original};
}

sub _parse : method {
    my ( $self ) = @_;
    $self->_init();
    my $string = $self->original();
    $self->{_uppercase} = [ $string =~ /[[:upper:]]/g ];
    # TOKEN ARRAYS
    # 0 - type: word|null
    # 1 - content
    # 2 - mixed array
    # 3 - uc array
    # 4 - first word token in queue
    while ( my $token = $Lexer->($string) )
    {
        my @mixed = $token->[1] =~ /$Mixed/g;
        $token->[2] = @mixed ? \@mixed : undef;
        push @{$self->{_mixedcase}}, @mixed if @mixed;
        push @{$self->{_token_queue}}, $token;
        push @{$self->{_wc}}, $token->[1] if $token->[0];
        $self->{_real_length} += length($token->[1]) if $token->[0];
    }
    my $uc_ratio = $self->uppercase / $self->{_real_length};
    my $mixed_ratio = $self->mixedcase / $self->{_real_length};
    if ( $uc_ratio > $self->uc_threshold ) # too much uppercase to be real
    {
        $_->[1] = lc($_->[1]) for @{ $self->{_token_queue} };
#        carp "Original exceeds uppercase threshold (" .
#            $self->uc_threshold .
#            ") lower casing for pre-processing";
    }
    elsif ( $mixed_ratio > $self->mixed_threshold ) # too mixed to be real
    {
        $_->[1] = lc($_->[1]) for @{ $self->{_token_queue} };
#        carp "Original exceeds mixedcase threshold, lower casing for pre-processing";
    }
    else
    {
        $self->allow_mixed(1);
    }
    1;
}

sub titlecase : method {
    my ( $self ) = @_;
    # it's up to _parse to clear it
    return $self->{_titlecase} if $self->{_titlecase};

    # first word token
    my $fwt = first { $_->[0] } @{$self->{_token_queue} };
    $fwt->[4] = 1;

    for my $t ( @{ $self->{_token_queue} } )
    {
        if ( $t->[0] )
        {
            if ( $t->[2] and $self->allow_mixed )
            {
                $self->{_titlecase} .= $t->[1];
            }
            elsif ( $t->[4] ) # the initial word token
            {
                $self->{_titlecase} .= ucfirst $t->[1];
            }
            elsif ( $LC{lc($t->[1])} ) # lc/uc checks here
            {
                $self->{_titlecase} .= lc $t->[1];
            }
            else
            {
                $self->{_titlecase} .= ucfirst $t->[1];
            }
        }
        else # not a word token
        {
            $self->{_titlecase} .= $t->[1];
        }
    }
    return $self->{_titlecase};
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

0.05

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

One of the hardest parts of properly titlecasing input is knowing if
part of it is already correct and should not be clobbered. E.g.--

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
clobber is 0.25. Example breakpoints.

 0.09 --> Old Macdonald Had a Farm
 0.10 --> Old MacDonald Had a Farm

 0.14 --> An Ipod with Low Ph on Ebay
 0.15 --> An iPod with Low pH on eBay

=item $tc->uc_threshold

Same as mixed but for "all" caps. Default threshold is 0.95.

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

Debug ability. Log object or to carp?

Smart apostrophe, utf8, entities?

Recipes. Including TT2 "plugin" recipe.

Take out Class::Accessor...? For having it all in one place, checking
args, and slight speed gain.

Bigger test suite.


=head1 RECIPES

Mini-scripts to test strings or accomplish custom configuration goals.

=head1 CONFIGURATION AND ENVIRONMENT

Lingua::EN::Titlecase requires no configuration files or environment variables.

=head1 DEPENDENCIES

Perl 5.6 or better to support POSIX regex classes.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

This is beta-ish software. No bugs have been reported.

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
