use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'render simple text' => sub {
    my $output = Wee::render('simple.wee');

    is $output, "Hi from template\n";
};

subtest 'render with inline vars' => sub {
    my $output = Wee::render('inline_vars.wee', foo => 'bar');

    is $output, "Hi from bar\n";
};

subtest 'render with escaped inline vars' => sub {
    my $output = Wee::render('inline_vars.wee', foo => '1 > 3');

    is $output, "Hi from 1 &gt; 3\n";
};

subtest 'render with not escaped inline vars' => sub {
    my $output = Wee::render('inline_not_escaped_vars.wee', foo => '1 > 3');

    is $output, "1 > 3\n";
};

subtest 'render with vars' => sub {
    my $output = Wee::render('vars.wee', foo => 'bar');

    is $output, "bar\n";
};

subtest 'render complex code' => sub {
    my $output = Wee::render('complex.wee', foo => 'bar');

    like $output, qr{<ul>\s+<li>1</li>\s+<li>2</li>\s+<li>3</li>\s+</ul>\n};
};

subtest 'render template several times' => sub {
    my $output1 = Wee::render('complex.wee', foo => 'bar');
    my $output2 = Wee::render('complex.wee', foo => 'bar');

    is $output1, $output2;
};

subtest 'render inlined template' => sub {
    my $output = Wee::render(\'%= $vars{foo}', foo => 'bar');

    is $output, 'bar';
};

done_testing;

__DATA__

@@ simple.wee
Hi from template

@@ inline_vars.wee
Hi from <%= $vars{foo} %>

@@ inline_not_escaped_vars.wee
<%== $vars{foo} %>

@@ vars.wee
%= $vars{foo}

@@ complex.wee
<ul>
% for my $li (1 .. 3) {
<li><%= $li %></li>
% }
</ul>

