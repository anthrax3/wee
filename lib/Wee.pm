package Wee;
use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(
  to_app
  cathome
  env
  req
  param
  get
  post
  render
  slurp
  http_error
  redirect
);

use Encode ();
use File::Basename qw(dirname);
use File::Spec::Functions 'catfile';

our $APP;
init((caller)[1]);

sub init {
    my ($caller) = @_;

    $APP = bless {}, __PACKAGE__;
    $caller ||= (caller(0))[1];
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

sub _parse_urlencoded ($) {
    map { uri_unescape($_) }
      map { my ($k, $v) = split /=/, $_, 2 } grep { length } split /\&/,
      $_[0];
}

sub route {
    my ($method, $path, $handler) = @_;

    my $ref = ref $handler eq 'CODE' ? $handler : sub { $handler };

    push @{$APP->{routes}}, {method => $method, path => $path, cb => $ref};
}

sub get  { route 'GET',  @_ }
sub post { route 'POST', @_ }

sub http_error {
    my ($message, $code) = @_;

    $code ||= 500;

    if (my $output = eval { render($code, code => $code, message => $message) })
    {
        $message = $output;
    }

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

            return http_error 'Not found', 404
              unless $m && $m->{method} eq $method;

            local $_ = $env;

            my $res = $m->{cb}->(@captures);
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
        $includes{$name} = $content;
    }
    return \%includes;
}

1;
