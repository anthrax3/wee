package Wee;
use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(
  to_app
  cathome
  env
  query
  param
  upload
  body
  route
  render
  serve
  slurp
  http_error
  redirect
);

$SIG{INT} = sub { exit 0 };

use Encode ();
use List::Util qw(first);
use File::Temp qw(tempfile);
use File::Basename qw(dirname);
use File::Spec::Functions 'catfile';

our $APP;
init((caller)[1]);

sub init {
    my ($caller) = @_;

    $APP = bless {}, __PACKAGE__;
    $caller ||= (caller(0))[1];
    $APP->{routes}   = [];
    $APP->{home}     = dirname($caller);
    $APP->{includes} = _read_includes($caller);
}

sub cathome { catfile($APP->{home}, @_) }

sub env () { $_ }

sub body () {
    my $body = '';
    while (env->{'psgi.input'}->read(my $buf, 8192) > 0) {
        $body .= $buf;
    }
    $body;
}

sub uri_unescape ($) {
    defined $_[0] ? do { $_[0] =~ s/%(\d\d)/chr(hex($1))/eg; $_[0] } : undef;
}

sub query ($) {
    my %pairs = _parse_urlencoded(env->{QUERY_STRING});
    $pairs{$_[0]};
}

sub param ($) {
    if (env->{CONTENT_TYPE} eq 'application/x-www-form-urlencoded') {
        my $body = body;

        my %pairs = _parse_urlencoded($body);
        return $pairs{$_[0]};
    }

    ();
}

sub upload ($) {
    my ($name) = @_;

    if (env->{CONTENT_TYPE} =~ qr{^multipart/form-data; boundary=(.*?)$}) {
        my $boundary = "--$1";

        my @parts;
        my $part = {};

        my $body  = '';
        my $state = 'first_boundary';
      MORE: while (env->{'psgi.input'}->read(my $buf, 8192) > 0) {
            $body .= $buf;

            if ($state eq 'first_boundary') {
                $body =~ s{^$boundary\r\n}{} || next MORE;
                $state = 'part_headers';
            }
            if ($state eq 'part_headers') {
                $body =~ s{^(.*?)\r\n\r\n}{}ms || next MORE;
                $state = 'part_body';

                my $headers = [split /\r\n/, $1];
                foreach my $header (@$headers) {
                    if ($header =~ m/^Content-Disposition: form-data; name="(.*?)"; filename="(.*?)"$/) {
                        $part->{name}     = $1;
                        $part->{filename} = $2;
                    }
                    elsif ($header =~ m/^Content-Type: (.*)$/) {
                        $part->{type} = $1;
                    }
                }
            }
            if ($state eq 'part_body') {
                my $fh = $part->{fh} ||= do {
                    my ($fh, $path) = tempfile(undef, UNLINK => 1);
                    $part->{path} = $path;
                    $fh;
                };

                if ($body =~ s{^(.*?)\r\n$boundary(--)?}{}ms) {
                    print $fh $1;
                    seek $fh, 0, 0;
                    push @parts, {%$part};

                    last if $2;

                    $state = 'part_headers';
                    %$part = ();
                }
                elsif (length($body) > length($boundary) + 2) {
                    print $fh substr($body, 0, length($body) - length($boundary) - 2, '');
                }
            }
        }

        return first { $_->{name} eq $name } @parts;
    }

    return;
}

sub _parse_urlencoded ($) {
    map { uri_unescape($_) }
      map { my ($k, $v) = split /=/, $_, 2 } grep { length } split /\&/,
      $_[0];
}

sub route {
    my $path = shift;
    my %handlers = @_ == 1 ? (GET => $_[0]) : @_;

    my $route = {path => $path};
    foreach my $method (keys %handlers) {
        my $handler = $handlers{$method};

        my $ref = ref $handler eq 'CODE' ? $handler : sub { $handler };

        $route->{methods}->{$method} = $ref;
    }

    push @{$APP->{routes}}, $route;
}

sub http_error {
    my ($message, $code) = @_;

    $code ||= 500;

    return [$code, [], [$message]];
}

sub redirect {
    my ($url, $code) = @_;

    $code ||= 302;

    return [$code, [Location => $url], ['']];
}

sub html_escape { local $_ = $_[0]; s/>/&gt;/; s/</&lt;/; $_; }

sub render {
    my ($name, %vars) = @_;

    my $template = ref $name eq 'SCALAR' ? $$name : $APP->{includes}->{$name}
      or die "Template not found";
    $template = $template->{content} if ref $template eq 'HASH';

    my $ref = ref $template eq 'CODE' ? $template : compile_template($template);
    $APP->{includes}->{$name} = $ref unless ref $name;
    return $ref->({html_escape => \&html_escape, %vars});
}

sub compile_template {
    my ($template) = @_;

    my $code = 'sub {';
    $code .= 'my %vars = %{$_[0]};';
    $code .= 'my $html_escape = $vars{html_escape};';
    $code .= 'my $_T = q{};';

    pos $template = 0;
    while (pos $template < length $template) {
        if (
            $template =~ m/\G (?:<%(?<mode>={1,2})? \s+ (?<content>.*?) %>
                        | ^ %(?<mode>={1,2})? \s+ (?<content>.*?) $)/gcxms
          )
        {
            my $value =
              $+{mode}
              && length($+{mode}) == 2 ? "    \$_T .= do {$+{content}};"
              : $+{mode} ? "    \$_T .= do {\$html_escape->($+{content})};"
              :            $+{content};

            $code .= $value;
        }
        elsif ($template =~ m/\G (.*?) (?=(?:<%|^%))/gcxms) {
            $code .= "\$_T .= q{$1};";
        }
        else {
            $code .= '$_T .= q{' . substr($template, pos($template)) . '};';
            last;
        }
    }

    $code .= '$_T}';

    no strict 'refs';
    my $ref = eval $code or die $@;
    return $ref;
}

sub serve {
    my ($name) = @_;

    my $include = $APP->{includes}->{$name};
    die 'Include not found' unless $include;

    [200, ['Content-Type' => $include->{type}], [$include->{content}]];
}

sub to_app {
    sub {
        my $env = shift;

        my $path_info = $env->{PATH_INFO}      || '/';
        my $method    = $env->{REQUEST_METHOD} || 'GET';

        eval {
            my $m;

            my @captures;
            foreach my $route (@{$APP->{routes}}) {
                if (ref $route->{path} eq 'Regexp') {
                    if (@captures = $path_info =~ m/^$route->{path}$/) {
                        $m = $route;
                        last;
                    }
                }
                elsif ($route->{path} eq $path_info) {
                    $m = $route;
                    last;
                }
            }

            return http_error 'Not found', 404 unless $m;
            return http_error 'Method not allowed', 405
              unless my $cb = $m->{methods}->{$method};

            local $_ = $env;

            my $res = $cb->(@captures);
            return $res if ref $res eq 'ARRAY';

            $res = Encode::encode('UTF-8', $res) if Encode::is_utf8($res);

            [200, ['Content-Type' => 'text/html; charset=utf-8'], [$res]];
        } or do {
            warn "System error: $@";
            http_error 'System error';
        };
    };
}

sub slurp {
    my ($file) = @_;
    open my $fh, '<', $file;
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

sub _read_includes {
    my ($caller) = @_;

    my $content = slurp($caller);

    my (undef, $includes) = split m/^__DATA__$/m, $content, 2;

    my %includes;
    foreach my $include (grep { !/^\s+$/ } split /@@\s+/, $includes // '') {
        my ($name, $content) = map { chomp; $_ } split /^/, $include, 2;

        my $type = 'text/plain';
        if ($name =~ s/^(.*?),\s*(.*)$//) {
            $name = $1;
            $type = $2;
        }
        elsif ($name =~ m/\.html$/) {
            $type = 'text/html';
        }

        $includes{$name} = {content => $content, type => $type};
    }
    return \%includes;
}

1;
