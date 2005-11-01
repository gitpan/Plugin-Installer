#!/opt/bin/perl

########################################################################
# Test::Simple is sufficient for this.
########################################################################

########################################################################
# housekeeping
########################################################################

use Test::Simple qw( tests 9 );

use strict;

########################################################################
# new object with simplistic compiler
########################################################################

my $object = Testify->construct;

# install the various items.

$object->$_ for keys %Testify::testz;

my $codereturn = $object->code;

my $bogus_return = 
eval
{
    eval { $object->bogus };

    $@ =~ m{^Compile aborted for 'Testify' handling 'bogus'};
};

ok(   0  == $Testify::this[ 0], '$this[0] == 0'  );
ok(   9  == $Testify::this[-1], '$this[9] == 0'  );

ok( 'ab' eq $Testify::that{aa}, '$that{aa} eq ab');
ok( 'az' eq $Testify::that{ay}, '$that{ay} eq az');

ok( $object->{package} eq 'foobar', '$object package value is foobar' );

ok( $codereturn eq 'Hello, world!', 'Code ran' );
ok( 1 == $object->{code_count},     'Code ran only once' );

{
    # avoid nastygram due to $Frobnicate::Foo being used only once.

    no warnings;

    ok( $Frobnicate::foo eq 'bar',      'foo installed into Frobnicate' );
}

ok( $bogus_return,                  'Bogus call fails' );

########################################################################
# Testify is a class suitable for plugin installation:
# its objects are hashes
# the 'compile' method can extract a referent for each name or
# return false-but-defined to signal that the method's contents
# do not need further processing by Plugin::Install.
########################################################################

package Testify;

use strict;

use base qw( Plugin::Installer );

our %testz = ();

BEGIN
{
    %testz = 
    (
        # return data that gets installed as @this, %that

        this => [  0..9 ],

        that => { 'aa' .. 'az' },

        # return false, this leaves the object's package
        # set to 'foobar' without any dispatch from the
        # installer.

        zero =>
        sub
        {
            $_[0]->{package} = 'foobar';
            
            0
        },

        # return a coderef, which doesn't get dispatched
        # immediately. this should leave $obj->{code_count}
        # at one after the method is called explicitly.

        code =>
        sub
        {
            $_[0]->{install_meta}{dispatch} = 0;

            $_[0]->{ code_count } = 0;

            sub
            {
                $_[0]->{ code_count } += 1;

                'Hello, world!'
            }
        },

        # push the value into an alternate package 
        # ('Frobnicate') instead of this one.

        foo => 
        sub
        {
            $_[0]->{install_meta}{alt_package} = 'Frobnicate';

            \'bar'
        },

    )
};

sub construct
{
    my $obj = \%testz;

    bless $obj, ref $_[0] || $_[0];
}


sub compile
{
    # exception is logged and passed on by 
    # the autoloader.

    my $item = $testz{ $_[1] } or die "No test for: '$_[1]'";

    # otherwise, run the code, return the values.
    
    ref $item eq 'CODE' ? $item->( $_[0] ) : $item
}

# this isn't a module

0

__END__
