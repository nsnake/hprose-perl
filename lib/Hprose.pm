package Hprose;

use 5.010000;
our $VERSION = '0.01';

sub AUTOLOAD {

    my $self  = shift;
    my $type  = ref($self);
    my $field = $AUTOLOAD;
    $field =~ s/.*://;
    if ( $field eq 'HproseHttpClient' ) {
        require Hprose::Client;
    }
}

1;
__END__

=head1 NAME

Hprose - is a High Performance Remote Object Service Engine.


=head1 SYNOPSIS

    use strict;
    use warnings;
    use Hprose;

    my $hprose = Hprose->new;

=head1 DESCRIPTION

It is a modern, lightweight, cross-language, cross-platform, object-oriented, high performance, remote dynamic communication middleware. It is not only easy to use, but powerful. You just need a little time to learn, then you can use it to easily construct cross language cross platform distributed application system.
