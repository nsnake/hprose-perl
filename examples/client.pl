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
