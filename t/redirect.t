use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'build correct redirect response' => sub {
    my $res = Wee::redirect('/foo');
    is_deeply $res, [302, [Location => '/foo'], ['']];
};

subtest 'build correct redirect response with custom code' => sub {
    my $res = Wee::redirect('/foo', 301);
    is_deeply $res, [301, [Location => '/foo'], ['']];
};

done_testing;
