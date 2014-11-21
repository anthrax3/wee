wee
===

The smallest PSGI framework.

```perl
use Wee;

get '/' => 'hi there';

get '/index.html' => render 'index.html';

get '/raw' => [200, [], ['Raw response']];

get '/500' => sub { die 'here' };

get '/file' => slurp __FILE__;

get '/redirect' => redirect '/';

get '/form'  => render 'form.html';
post '/form' => sub {
    'Submitted. Good bye';
};

to_app;

__DATA__

@@ index.html
<html>
    <body>
        <h1>Привет!</h1>
    </body>
</html>

@@ form.html
<form method="POST">
<input name="name" />
<input type="submit" />
</form>

@@ 500
Error <%= $vars{message} %>.

@@ 404
OOOOOPS!
```
