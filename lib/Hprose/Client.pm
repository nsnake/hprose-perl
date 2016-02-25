package Hprose::Client;

#************************************************************
#|                                                          |
#|                          hprose                          |
#|                                                          |
#| Official WebSite: http://www.hprose.com/                 |
#|                   http://www.hprose.net/                 |
#|                   http://www.hprose.org/                 |
#|                                                          |
#************************************************************

#***********************************************************
# *                                                        *
# *  Hprose::Client;                                       *
# *                                                        *
# *  Hprose Serialize and Deserialize                      *
# *                                                        *
# * LastModified: 2016/2/24                                *
# * Author: CGI.NET <loveme1314@gmail.com>                 *
# *                                                        *
#***********************************************************

use strict;
use warnings;
use Hprose::Writer;
use Hprose::Reader;
use Hprose::Tags;
use Hprose::ResultMode;
use Hprose::Exception;
use Hprose::Filter;
use IO::String;
our $VERSION = '0.2.0';

#\$body, $function, $arguments, $byRef
sub _doOutput {
    my $self = $_[0];
    my $io   = IO::String->new( $_[1] );
    $io->print( Hprose::Tags->Call );
    my $hproseWriter = Hprose::Writer->new( $io, $self->{'simple'} );
    $hproseWriter->write_string( $_[2] );
    if ( scalar @{ $_[3] } > 0 || $_[4] ) {
        $hproseWriter->reset();
        $hproseWriter->write_array( $_[3] );
        if ( $_[4] ) {
            $hproseWriter->write_boolean(1);
        }
    }
    $io->print( Hprose::Tags->End );
}

#\$body,$resultMode,$arguments
sub _doInput {
    my $self         = $_[0];
    my $io           = IO::String->new( $_[1] );
    my $hproseReader = Hprose::Reader->new($io);
    my ( $result, $error );
    while (
        (
            my $tag = $hproseReader->check_tags(
                    Hprose::Tags->Result
                  . Hprose::Tags->Argument
                  . Hprose::Tags->Error
                  . Hprose::Tags->End
            )
        ) ne Hprose::Tags->End
      )
    {

        if ( $tag eq Hprose::Tags->Result ) {
            if ( $_[2] == Hprose::ResultMode->Serialized ) {
                $result = $hproseReader->readRaw()->toString();
            }
            else {
                $hproseReader->reset();
                $result = $hproseReader->unserialize();
            }
        }
        elsif ( $tag eq Hprose::Tags->Argument ) {
            $hproseReader->reset();
            my $args = $hproseReader->read_array();
            my $i;
            for ( $i = 0, $i < scalar( \$_[3] ), $i++ ) {
                $_[3]->[$i] = $args->[$i];
            }

        }
        elsif ( $tag eq Hprose::Tags->Error ) {
            $hproseReader->reset();
            $error = Hprose::Exception( $hproseReader->read_string() );
        }

    }
    if ($error) {
        throw $error;
    }
    return $result;
}

sub setFilter {
    shift->{'filter'} = shift || 0;
}

sub getFilter {
    return shift->{'filter'};
}

sub setSimpleMode {
    shift->{'simple'} = shift || 1;
}

sub getSimpleMode {
    return shift->{'simple'};
}

sub setKeepAlive {
    my ( $self, $keepalive ) = @_;
    $self->{'keepAlive'} = $keepalive;
}

sub getKeepAlive {
    my $self = shift;
    return $self->{'keepAlive'};
}

sub AUTOLOAD {
    my $self = shift;
    my $cb   = pop;
    my $name = our $AUTOLOAD;
    return if $name =~ /::DESTROY$/;
    $name =~ /.*::(\w*)/;
    $name = $1;
    $self->invoke( $name, \@_, $cb );
}

1;
