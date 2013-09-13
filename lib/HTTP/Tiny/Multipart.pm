package HTTP::Tiny::Multipart;

# ABSTRACT: Add post_multipart to HTTP::Tiny

use strict;
use warnings;

use HTTP::Tiny;
use File::Basename;
use Carp;
use MIME::Base64;

our $VERSION = 0.01;

sub _get_boundary {
    my ($headers, $content) = @_;
 
    # Generate and check boundary
    my $boundary;
    my $size = 1;

    while (1) {
        $boundary = encode_base64 join('', map chr(rand 256), 1 .. $size++ * 3);
        $boundary =~ s/\W/X/g;
        last unless grep{ $_ =~ m{$boundary} }@{$content};
    }
 
    # Add boundary to Content-Type header
    ($headers->{'content-type'} || '') =~ m!^(.*multipart/[^;]+)(.*)$!;

    my $before = $1 || 'multipart/form-data';
    my $after  = $2 || '';

    $headers->{'content-type'} = "$before; boundary=$boundary$after";
 
    return "--$boundary\x0d\x0a";
}

sub _build_content {
    my ($data) = @_;

    my $boundary = _get_boundary();
    my @params = ref $data eq 'HASH' ? %$data : @$data;
    @params % 2 == 0
        or Carp::croak("form data reference must have an even number of terms\n");
 
    my @terms;
    while( @params ) {
        my ($key, $value) = splice(@params, 0, 2);
        if ( ref $value eq 'ARRAY' ) {
            unshift @params, map { $key => $_ } @$value;
        }
        else {
            my $filename = '';
            my $content  = $value;

            if ( ref $value and ref $value eq 'HASH' ) {
                if ( $value->{content} ) {
                    $content = $value->{content};
                }

                if ( $value->{filename} ) {
                    $filename = $value->{filename};
                }
                else {
                    $filename = $key;
                }

                $filename = '; filename="' . basename( $filename ) . '"';
            }

            push @terms, sprintf "Content-Disposition: form-data; name=\"%s\"%s\x0d\x0a\x0d\x0a%s\x0d\x0a",
                $key, 
                $filename,
                $content;
        }
    }

    return \@terms;
}

no warnings 'redefine';

*HTTP::Tiny::post_multipart = sub {
    my ($self, $url, $data, $args) = @_;

    (@_ == 3 || @_ == 4 && ref $args eq 'HASH')
        or Carp::croak(q/Usage: $http->post_multipart(URL, DATAREF, [HASHREF])/ . "\n");

    (ref $data eq 'HASH' || ref $data eq 'ARRAY')
        or Carp::croak("form data must be a hash or array reference\n");
 
    my $headers = {};
    while ( my ($key, $value) = each %{$args->{headers} || {}} ) {
        $headers->{lc $key} = $value;
    }

    delete $args->{headers};

    my $content_parts = _build_content($data);
    my $boundary      = _get_boundary($headers, $content_parts);

    my $last_boundary = $boundary;
    substr $last_boundary, -3, 0, "--";
 
    return $self->request('POST', $url, {
            %$args,
            content => $boundary . join( $boundary, @{$content_parts}) . $last_boundary,
            headers => {
                %$headers,
            },
        }
    );
};

1;
