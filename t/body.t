use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'slurps body' => sub {
    local $_;

    my $hello = 'there';
    open my $fh, '<', \$hello;

    $_ = {'psgi.input' => $fh};
    is Wee::body, 'there';
};

done_testing;
