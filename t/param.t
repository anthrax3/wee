use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'parses form params' => sub {
    local $_;

    open my $fh, '<', \'foo=bar';
    $_ = {CONTENT_TYPE => 'application/x-www-form-urlencoded', 'psgi.input' => $fh};

    is Wee::param('foo'), 'bar';
};

done_testing;
