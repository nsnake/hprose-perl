# Hprose for Perl

### 依赖
Perl >= 5.10

### 安装
Linux
```
perl Makefile.PL
make
make test
make install
```

Window 带编译环境
```
perl Makefile.PL
dmake
dmake test
dmake install
```

### Usage
本版本只实现了客户端的功能，还没有服务端的部分。
注意，与php版本的客户端不同，perl版本的客户端是基于AnyEvent::Http的无阻塞模式实现,所以在回调方法里面尽量不要使用有阻塞的方法。
```
#!/usr/bin/perl
use warnings;
use strict;
use 5.010;
use lib qw!../lib!;
use AnyEvent;
use Hprose::Http::Client;
use Data::Dumper qw/Dumper/;
my $cv     = AE::cv;
my $client = Hprose::Http::Client->new('http://127.0.0.1/hprosetest');
   $client->hello( sub { say Dumper @_; $cv->send() } );
   $cv->recv;
```

###方法
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


###BUG反馈
CGI.NET <loveme1314@gmail.com>