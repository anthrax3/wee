use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'dispatch to simple text' => sub {
    Wee::init();

    Wee::route('/', 'Hi there');

    my $res = Wee::to_app->();
    is $res->[0], 200;
    is_deeply $res->[2], ['Hi there'];
};

subtest 'dispatch to array reference' => sub {
    Wee::init();

    Wee::route('/', [500, [], ['Error']]);

    my $res = Wee::to_app->();
    is $res->[0], 500;
    is_deeply $res->[2], ['Error'];
};

subtest 'dispatch to code reference' => sub {
    Wee::init();

    Wee::route('/', sub { 'Hi there' });

    my $res = Wee::to_app->();
    is $res->[0], 200;
    is_deeply $res->[2], ['Hi there'];
};

subtest 'return 404 when no route found' => sub {
    Wee::init();

    my $res = Wee::to_app->();
    is $res->[0], 404;
    is_deeply $res->[2], ['Not found'];
};

subtest 'catch error' => sub {
    Wee::init();

    Wee::route('/', sub { die 'error' });

    my $res = Wee::to_app->();
    is $res->[0], 500;
    is_deeply $res->[2], ['System error'];
};

subtest 'dispatch to template' => sub {
    Wee::init();

    Wee::route('/', sub { Wee::render('template.wee') });

    my $res = Wee::to_app->();
    is $res->[0], 200;
    is_deeply $res->[2], ['Hi from template'];
};

subtest 'throw when template not found' => sub {
    Wee::init();

    Wee::route('/', sub { Wee::render('unknown.wee') });

    my $res = Wee::to_app->();
    is $res->[0], 500;
    is_deeply $res->[2], ['System error'];
};

done_testing;

__DATA__

@@ template.wee
Hi from template
