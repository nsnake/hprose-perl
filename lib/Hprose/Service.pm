package Hprose::Service;

#**********************************************************\
#                                                          |
#                          hprose                          |
#                                                          |
# Official WebSite: http://www.hprose.com/                 |
#                   http://www.hprose.org/                 |
#                                                          |
#**********************************************************/

#**********************************************************\
# *                                                        *
# * Hprose/Service.pm                                      *
# *                                                        *
# * hprose service class for perl                          *
# *                                                        *
# * LastModified:                                          *
# * Author: cgi.net    <loveme1314@gmail.com>              *
# *                                                        *
#**********************************************************/

use strict;
use warnings;
use 5.010;
use Data::Dumper qw/Dumper/;
use Hprose::Writer;
use Hprose::Reader;
use Hprose::Tags;
use Hprose::ResultMode;
use Hprose::Exception;
use Hprose::Filter;
use IO::String;
use Sub::Identify ':all';

sub new {
    my ( $class, %args ) = @_;
    my $self = {
        calls          => {},
        names          => {},
        filters        => {},
        simple         => 0,
        debug          => 0,
        error_types    => 'HPROSE_DEFAULT_ERROR_TYPES',
        onBeforeInvoke => undef,
        onAfterInvoke  => undef,
        onSendError    => undef
    };
    bless $self, ref $class || $class;
    return $self;

}

sub defaultHandle {
    my ( $self, $request, $context ) = @_;
    my $input = IO::String->new( \$context );
    my $tag   = $input->getc();
    if ( $tag eq Hprose::Tags->Call ) {
        $self->_doInvoke( $input, $context );
    }
    elsif ( $tag eq Hprose::Tags->End ) {
        $self->_doFunctionList($context);
    }
    else {
        throw Hprose::Exception("Wrong Request: \r\n");
    }
}

sub addFunction {
    my ( $self, $func, $alias, $options ) = @_;
    if ( ref($func) ne 'CODE' ) {
        throw Hprose::Exception('Argument func must be a function');
    }
    my $name = $alias ? lc($alias) : lc( sub_name($func) );

    $self->{'calls'}->{$name} = Hprose::RemoteCall->new(
        func   => $func,
        mode   => 'ResultMode::Normal',
        simple => 0,
        async  => 0,
    );
}

sub _doInvoke {
    my ( $self, $input, $context ) = @_;
    my $output = IO::String->new();
    my $reader = Hprose::Reader->new($input);
    my $tag;
    do {
        $reader->reset();
        my $name  = $reader->read_string();
        my $alias = lc($name);
        my $call;

        if ( $self->{'calls'}{$alias} ) {
            $call = $self->{'calls'}{$alias};
        }
        elsif ( $self->{'calls'}{'*'} ) {
            $call = $self->{'calls'}{'*'};
        }
        else {
            throw Hprose::Exception(
                "Can't find this function " . $name . "()." );
        }
        my $mode   = $call->mode;
        my $simple = $call->simple;
        if ( !$simple ) {
            $simple = $self->{'simple'};
        }
        my $async = $call->async;
        my $args  = ();
        my $byref = 0;
        $tag = $input->getc();
        if ( $tag eq Hprose::Tags->List ) {
            $reader->reset();
            $args = $reader->read_list_without_tag();
            $tag  = $input->getc();
            if ( $tag eq Hprose::Tags->True ) {
                $byref = 1;
                $tag   = $input->getc();
            }

            #if ( $call->byref ) {
            #my @_args = ();
            #foreach ( @{$args} ) {
            #    push( @_args, $_ );
            #}
            #$args = @_args;
            #}
        }
        if (   ( $tag ne Hprose::Tags->End )
            && ( $tag ne Hprose::Tags->Call ) )
        {
            throw Hprose::Exception( 'Unknown tag: '
                  . $tag . "\r\n"
                  . 'with following data: '
                  . ${ $input->string_ref } );
        }

        if ( $self->{'onBeforeInvoke'} ) {
            $self->{'onBeforeInvoke'}->( $name, $args, $byref, $context );
        }

        my $result = $call->{'func'}($args);
        $result = $self->afterInvoke(
            $name,    $args,   $byref,  $mode, $simple,
            $context, $result, $output, 0
        );
        if ($result) { return $result; }

    } while ( $tag eq Hprose::Tags->Call );
    $output->write( Hprose::Tags->End );
    return $self->outputFilter( ${ $output->string_ref }, $context );
}

sub outputFilter() {
    my ( $self, $data, $context ) = @_;

    #$count = count( $this->filters );
    #for ( $i = 0 ; $i < $count ; $i++ ) {
    #    $data = $this->filters[$i]->outputFilter( $data, $context );
    #}
    return $data;
}

sub afterInvoke {
    my (
        $self,   $name,    $args,   $byref,  $mode,
        $simple, $context, $result, $output, $async
    ) = @_;
    if ( $self->{'onAfterInvoke'} ) {
        $self->{'onAfterInvoke'}->( $name, $args, $byref, $result, $context );
    }
    if ( $mode eq 'ResultMode::RawWithEndTag' ) {
        return $self->outputFilter( $result, $context );
    }
    elsif ( $mode eq 'ResultMode::Raw' ) {
        $output->write($result);
    }
    else {

        my $writer = Hprose::Writer->new( $output, $simple );
        $output->write( Hprose::Tags->Result );
        if ( $mode eq 'ResultMode::Serialized' ) {
            $output->write($result);
        }
        else {
            $writer->reset();
            $writer->serialize($result);
        }
        if ($byref) {
            $output->write( Hprose::Tags->Argument );
            $writer->reset();
            $writer->writeArray($args);
        }
    }

    if ($async) {
        $output->write( Hprose::Tags->End );
        return $self->outputFilter( ${ $output->string_ref }, $context );
    }
    return 0;
}

sub _doFunctionList {
    my ( $self, $context ) = shift;
    my $stream = IO::String->new();
    my $writer = Hprose::Writer->new( $stream, 1 );
    $stream->print( Hprose::Tags->Functions );
    $writer->write_array('Demo');
    $stream->write( Hprose::Tags->End );
    my $data = ${ $stream->string_ref };
    $stream->close();
    return _outputFilter( $data, $context );
}

package Hprose::RemoteCall;

sub new {
    my ( $class, %args ) = @_;
    my $self = {
        func   => $args{'func'},
        mode   => $args{'mode'},
        simple => $args{'simple'},
        async  => $args{'async'}
    };
    if ( ref $self->{'func'} eq 'ARRAY' ) {

        #$tmp = new \ReflectionMethod( $func[0], $func[1] );
    }
    else {
        #$tmp = new \ReflectionFunction($func);
    }

    #$this->params = $tmp->getParameters();
    bless $self, ref $class || $class;
    return $self;
}

sub simple { return 0; }
sub func   { return $_[0]->{'func'} }
sub async  { return 0; }
sub mode   { return 'ResultMode::Normal'; }
1;
