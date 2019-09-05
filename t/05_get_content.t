#!perl
use strict;
use warnings;
use HTTP::Tiny;
use HTTP::Tiny::Multipart;
use Test::More;

subtest "Excention tests for _get_boundary()" => sub {
  my $error;
  my $headers = {'field1' => 'test'};
  my $content = [ "Content-Disposition: form-data; name=\"field1\"\x0d\x0a\x0d\x0atest\x0d\x0a" ];

  eval { HTTP::Tiny::Multipart::_get_boundary(); 1; } or $error = $@;
  like ( $error, qr/Must provide Headers as param/, "checking if we get message when no header parameter passed" );

  eval { HTTP::Tiny::Multipart::_get_boundary($headers); 1; } or $error = $@;
  like ( $error, qr/Must provide Content as param!/, "checking if we get message when no content parameter passed" );

  ok ( HTTP::Tiny::Multipart::_get_boundary($headers,$content),  "Checking everything works with expected params" );
};

done_testing();
