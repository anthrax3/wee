use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'defaults' => sub {
    Wee::init();

    Wee::route('/', 'Hi there');

    my $env = {REQUEST_METHOD => 'GET', PATH_INFO => '/'};
    my $res = Wee::to_app->($env);
    is $res->[0], 200;
};

subtest 'path correct, unknown method' => sub {
    Wee::init();

    Wee::route('/', 'Hi there');

    my $env = {REQUEST_METHOD => 'POST', PATH_INFO => '/'};
    my $res = Wee::to_app->($env);
    is $res->[0], 405;
};

subtest 'unknown path' => sub {
    Wee::init();

    my $env = {REQUEST_METHOD => 'GET', PATH_INFO => '/unknown'};
    my $res = Wee::to_app->($env);
    is $res->[0], 404;
};

subtest 'different methods' => sub {
    Wee::init();

    Wee::route('/', GET => 'get', POST => 'post');

    my $env = {REQUEST_METHOD => 'GET', PATH_INFO => '/'};
    my $res = Wee::to_app->($env);
    is $res->[2]->[0], 'get';

    $env = {REQUEST_METHOD => 'POST', PATH_INFO => '/'};
    $res = Wee::to_app->($env);
    is $res->[2]->[0], 'post';
};

done_testing;
