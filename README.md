# Hprose for Perl

### 安装
Linux
```
perl Makefile.PL
make
make install
```

Window 带编译环境
```
perl Makefile.PL
dmake
dmake install
```


### Usage
本版本只实现了客户端的功能，还没有服务端的部分。所以不要直接
```
use Hprose;
```
而是
```
use Hprose::Client;
```
具体使用可以参照Hprose::Client中的文档