package Hprose::Http::Client;

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
# *  Hprose::Http::Client;                                 *
# *                                                        *
# *  hprose http nonblock client                           *
# *                                                        *
# * LastModified: 2016/2/24                                *
# * Author: CGI.NET <loveme1314@gmail.com>                 *
# *                                                        *
#***********************************************************

use strict;
use warnings;
use AnyEvent::HTTP;
use base 'Hprose::Client';
use Data::Dumper;
our $VERSION = '0.9.0';

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

    $self->_doOutput( \$body, $function, $arguments, $byRef );

    http_request
      POST      => $self->{'url'},
      headers   => $head,
      timeout   => 5,
      body      => $body,
      keepalive => $self->{'keepalive'},
      socks     => $self->{'proxy'},
      sub {
        my ( $body, $hdr ) = @_;

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

        $cb->( $self->_doInput( \$body, $resultMode, $arguments ) );
      };

}

sub setTimeout {
    my ( $self, $timeout ) = @_;
    $AnyEvent::HTTP::TIMEOUT = $timeout;
}

sub getTimeout {
    my $self = shift;
    return $AnyEvent::HTTP::TIMEOUT;
}

#socks4://10.0.0.1:1080
#socks5://root:123@10.0.0.2:1080
#socks4a://85.224.100.1:9010
sub setProxy {
    my $self = shift;
    $self->{'proxy'} = shift;
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
