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
# * hprose http client library for perl5.                  *
# *                                                        *
# * LastModified: 2016/2/24                                *
# * Author: CGI.NET <loveme1314@gmail.com>                 *
# *                                                        *
#***********************************************************

use strict;
use warnings;
use AnyEvent::HTTP;
use Hprose::Writer;
use Hprose::Reader;
use Hprose::Tags;
use Hprose::ResultMode;
use Hprose::Exception;
use Hprose::Filter;
use IO::String;
use Data::Dumper;
our $VERSION = '0.12.0';

sub new {
    my ( $class, $url ) = @_;
    $class = ( ref $class ) || $class || __PACKAGE__;
    my $self = {};
    bless $self, $class;
    if ( !$url ) {
        throw Hprose::Exception('Url is needed.');
    }
    $self->{'url'}       = $url;
    $self->{'proxy'}     = undef;
    $self->{'keepalive'} = 1;
    return $self;
}

sub invoke {
    my $self = shift;
    my $cb   = pop;
    my ( $function, $arguments, $byRef, $resultMode, $simple ) = @_;
    $self->{'simple'} = $simple ? 1 : 0;
    my $head = {
        'User-Agent'   => 'Perl Hprose ' . $VERSION,
        'Content-type' => 'application/hprose'
    };
    my $body;

    $byRef      = $byRef      ? $byRef      : 0;
    $resultMode = $resultMode ? $resultMode : Hprose::ResultMode->Normal;
    if ( ref $arguments ne 'ARRAY' ) {
        $arguments = [$arguments];
    }
    if ( ref $cb ne 'CODE' ) {
        throw Hprose::Exception('Callback function is needed.');
    }

    my $io = IO::String->new( \$body );
    $io->print( Hprose::Tags->Call );
    my $hproseWriter = Hprose::Writer->new( $io, $self->{'simple'} );
    $hproseWriter->write_string($function);

    if ( scalar @$arguments > 0 || $byRef ) {
        $hproseWriter->reset();
        $hproseWriter->write_array($arguments);
        if ($byRef) {
            $hproseWriter->write_boolean(1);
        }
    }

    $io->print( Hprose::Tags->End );

    #$self->{'cv'} = AE::cv;
    http_request
      POST      => $self->{'url'},
      headers   => $head,
      timeout   => 5,
      body      => $body,
      keepalive => $self->{'keepalive'},
      socks     => $self->{'proxy'},
      sub {
        my ( $body, $hdr ) = @_;

        #$self->{'cv'}->send;

        if ( $hdr->{Status} != 200 ) {
            throw Hprose::Exception($body);
        }

        if ( $resultMode == Hprose::ResultMode->RawWithEndTag ) {
            $cb->($body);
            return;

        }
        if ( $resultMode == Hprose::ResultMode->Raw ) {
            $cb->( substr( $body, 0, -1 ) );
            return;
        }

        my $io           = IO::String->new( \$body );
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
                if ( $resultMode == Hprose::ResultMode->Serialized ) {
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
                for ( $i = 0, $i < scalar( \$arguments ), $i++ ) {
                    $arguments->[$i] = $args->[$i];
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
        $cb->($result);
      };

    #$self->{'cv'}->recv;
}

sub setTimeout {
    my ( $self, $timeout ) = @_;
    $AnyEvent::HTTP::TIMEOUT = $timeout;
}

sub getTimeout {
    my $self = shift;
    return $AnyEvent::HTTP::TIMEOUT;
}

sub setKeepAlive {
    my ( $self, $keepalive ) = @_;
    $self->{'keepAlive'} = $keepalive;
}

sub getKeepAlive {
    my $self = shift;
    return $self->{'keepAlive'};
}

#socks4://10.0.0.1:1080
#socks5://root:123@10.0.0.2:1080
#socks4a://85.224.100.1:9010
sub setProxy {
    my $self = shift;
    $self->{'proxy'} = shift;
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

=head1 NAME

 Hprose::Client - 异步Hprose perl客户端

=head1 SYNOPSIS

    use AnyEvent;
    use Hprose::Client;
    my $cv = AE::cv;
    my $client = Hprose::Client->new(Hprose Service Url);
       $client->hello('Hprose',
                               sub{print shift; $cv->send;}
                                                      );

        $cv->recv;

=head1 DESCRIPTION
       new(str url)
       setTimeout(int seconds)
       setKeepAlive(int Bool)
       setProxy(str ip)
       setFilter(int Bool)
       getFilter(int Bool)
       setSimpleMode(int Bool)
       getSimpleMode(int Bool)

=head2 方法
       new(Hprose Service Url)
       创建一个客户端对象,Hprose Service Url为你的服务端地址。

       setTimeout(int seconds)
       设置超时时长,默认为5秒

       setKeepAlive(int Bool)
       是否启用长连接,默认不启用

       setProxy(socks5://your socket ip)
       设置代理

       invoke(function,arguments,int by ref,int result mode,int simple,callback)
       invoke方法,具体参数和PHP的一样,唯一的区别就是callback方法是必须指定的，后继操作将在这里完成

       function(function,arguments,callback)
       同其它语言的一样,直接通过远程方法名进行远程调用


=head2 已知的问题
       对异常检测还不够完善
       还有一些方法没有完成

=head1 AUTHOR

CGI.NET <loveme1314@gmail.com>

=head1 SEE ALSO

L<AnyEvent::Http>

=cut
