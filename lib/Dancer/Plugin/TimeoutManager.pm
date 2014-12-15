package Dancer::Plugin::TimeoutManager;

use 5.012002;
use strict;
use warnings;
# VERSION

use Dancer ':syntax';
use Dancer::Exception ':all';
use Dancer::Plugin;
use Data::Dumper;
use Carp 'croak';
use List::MoreUtils qw( none);

register 'timeout' => \&timeout;

register_exception ('NoTimeout',
        message_pattern => "timeout must be defined and > 0 and is %s",
        );
register_exception ('InvalidMethod',
        message_pattern => "method must be one in get, put, post, delete and %s is used as a method",
        );

my @authorized_methods = ('get', 'post', 'put', 'delete');

sub timeout {
    my ($timeout,$method,$pattern, @rest) = @_;
    my $code;
    for my $e (@rest) { $code = $e if (ref($e) eq 'CODE') }
    
    #if no timeout an exception is done
    raise NoTimeout  => $timeout if (!defined $timeout);
    #if method is not valid an exception is done
    if ( none { $_ eq lc($method) } @authorized_methods ){
        raise InvalidMethod => $method;
    }
    
    my $timeout_route = sub {
   
        my $response;
        # if timeout equal 0 the timeout manager is not used
        if ($timeout == 0){
            $response = $code->();
        }
        else{
            eval {
                local $SIG{ALRM} = sub { croak ("Route Timeout Detected"); };
                alarm($timeout);
                $response = $code->();
                alarm(0);
            };
            alarm(0);
        }
        # Timeout detected
        if ($@ && $@ =~ /Route Timeout Detected/){
            my $response_with_timeout = Dancer::Response->new(
                    status => 408,
                    content => "Request Timeout : more than $timeout seconds"
                    );
            return $response_with_timeout;
        }
        # Preserve exceptions caught during route call
        croak $@ if $@;

        # else everything is allright
        return $response;
    };


    my @compiled_rest;
    for my $e (@rest) {
        if (ref($e) eq 'CODE') {
            push @compiled_rest, $timeout_route;
        }
        else {
            push @compiled_rest, $e;
        }
    }

    # declare the route in Dancer's registry
    any [$method] => $pattern, @compiled_rest;
}

register_plugin;


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dancer::Plugin::TimeoutManager - Dancer plugin to set a timeout to a Dancer request

=head1 SYNOPSIS
  package MyDancerApp;

  use strict;
  use warnings;

  use Dancer::Plugin::TimeoutManager;
  
  timeout 1, 'get' => '/method' => sub{
    my $code;
  };
 

=head1 DESCRIPTION

The goal of this plugin is to manage a timeout to Dancer. 
If the timeout is set to 0, the behavior is the same than without timeout
If a timeout is set, when this one is outdated a response with status 408 is sent


=head1 AUTHOR

Frederic Lechauve, E<lt>frederic_lechauve at yahoo.frE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Frederic Lechauve

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
