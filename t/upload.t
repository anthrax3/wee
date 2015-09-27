use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Wee ();

subtest 'parses uploads' => sub {
    local $_;

    my $data =
        "--------------------------7583b6d42beddaaf\r\n"
      . "Content-Disposition: form-data; name=\"file\"; filename=\"file.bin\"\r\n"
      . "Content-Type: application/octet-stream\r\n" . "\r\n" . "hello" . "\r\n"
      . "--------------------------7583b6d42beddaaf--";

    open my $fh, '<', \$data;
    $_ = {
        CONTENT_TYPE => 'multipart/form-data; '
          . 'boundary=------------------------7583b6d42beddaaf',
        'psgi.input' => $fh
    };

    my $upload = Wee::upload('file');
    is $upload->{name},     'file';
    is $upload->{filename}, 'file.bin';
    is $upload->{type},     'application/octet-stream';

    my $upload_fh = $upload->{fh};
    is <$upload_fh>, 'hello';
};

subtest 'parses uploads byte by byte' => sub {
    local $_;

    my $input =
      TestInput->new("--------------------------7583b6d42beddaaf\r\n"
          . "Content-Disposition: form-data; name=\"file\"; filename=\"file.bin\"\r\n"
          . "Content-Type: application/octet-stream\r\n" . "\r\n" . "hello"
          . "\r\n"
          . "--------------------------7583b6d42beddaaf--");

    $_ = {
        CONTENT_TYPE => 'multipart/form-data; '
          . 'boundary=------------------------7583b6d42beddaaf',
        'psgi.input' => $input
    };

    my $upload = Wee::upload('file');
    is $upload->{name},     'file';
    is $upload->{filename}, 'file.bin';
    is $upload->{type},     'application/octet-stream';

    my $upload_fh = $upload->{fh};
    is <$upload_fh>, 'hello';
};

done_testing;

package TestInput;

sub new {
    my $class = shift;
    my ($buffer) = @_;

    my $self = {};
    $self->{pos}    = 0;
    $self->{buffer} = $buffer;

    bless $self, $class;

    return $self;
}

sub read {
    my $self = shift;

    $_[0] = substr($self->{buffer}, $self->{pos}, 1);
    $self->{pos}++;
    return 0 if $self->{pos} > length $self->{buffer};
    return 1;
}
