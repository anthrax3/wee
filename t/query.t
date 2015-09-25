use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'parses query params' => sub {
    local $_;

    $_ = {QUERY_STRING => ''};
    ok !defined Wee::query('foo');

    $_ = {QUERY_STRING => 'foo'};
    ok !defined Wee::query('foo');

    $_ = {QUERY_STRING => 'foo='};
    is Wee::query('foo'), '';

    $_ = {QUERY_STRING => 'foo=bar'};
    is Wee::query('foo'), 'bar';

    $_ = {QUERY_STRING => 'foo=bar&&bar=baz'};
    is Wee::query('foo'), 'bar';
    is Wee::query('bar'), 'baz';

    $_ = {QUERY_STRING => '=foo'};
    is Wee::query(''), 'foo';

    $_ = {QUERY_STRING => '='};
    is Wee::query(''), '';

    $_ = {QUERY_STRING => '%20hello%20=%20there%20'};
    is Wee::query(' hello '), ' there ';
};

done_testing;
