########################################################################
# Plugin::Installer
#
# fodder for use base.
#
# Implements AUTOLOAD, DESTROY. 
########################################################################

########################################################################
# housekeeping
########################################################################

package Plugin::Installer;

use strict;

use Carp;
use Symbol;
use Scalar::Util qw( &reftype );

########################################################################
# package variables
########################################################################

our $VERSION = '0.10';

# default is to install and dispatch (iff possible) 
# the compiler results; not storing special metadata
# for any methods.

my $meta = {};

my $default_meta = 
{

    install     => 1,
    dispatch    => 1,
    storemeta   => 0,

    alt_package => '',

};

########################################################################
# methods
########################################################################

########################################################################
# AUTOLOAD block does the deed.
# trick here is to dispatch the plugin method calls into the
# compiler. result can be a referent or false; referents are
# installed as $AUTOLOAD, false is silently ignored; coderefs
# are dispatched via GOTO.
#
# the object has an "install_meta" key temporarily inserted
# into it for passing back install and dispatch data or 
# storing the updated install_meta value back as a default
# for the class.

our $AUTOLOAD = '';

AUTOLOAD
{
    use Symbol;
    use Scalar::Util;

    my $obj  = $_[0];

    my ( $class, $name ) = $AUTOLOAD =~ m{^ (.+) :: (\w+) $ }x;

    # Note: metadata is cached for the CLASS not 
    # the individual objects. if someone wants 
    # object-level metadata they can deal with 
    # it in their compiler.
    #
    # languages can udpate the metadata to 
    # tickle the switches for the class (with 
    # install set) or a single method (with 
    # install false).

    my %method_meta
    = %{ $meta->{ $class } ||= $default_meta };

    local $obj->{ install_meta } = \%method_meta;

    # note that this will install any referent 
    # it is handed back: code or data. this is a 
    # quick way to hand back data (via install + 
    # nodispatch).
    #
    # reftype can't handle unblessed ref's, so the
    # fix is to eval it and use ref as a fallback. 

    if( defined ( my $result = eval{ $obj->compile($name) } ) )
    {
        if( $method_meta{store_meta} )
        {
            $meta->{ $class } = \%method_meta;
        }

        # no way to install or dispatch a non-referent...

        if( my $type = eval { reftype $result } || ref $result )
        {
            if( $method_meta{ install } )
            {
                # check if they have a better idea where to 
                # install the thing than the caller.

                # the caller gets SOMEthing installed in any
                # case: even if it's a scalar.

                my $package
                = $method_meta{ alt_package } || $class;

                my $ref = qualify_to_ref $name, $package;

                # note: undef of coderefs avoids warnings.

                undef &{$ref} if $type eq 'CODE';

                *$ref = $result;
            }

            if( $type eq 'CODE' && $method_meta{ dispatch } )
            {
                goto &$result
            }
        }
        elsif( $result )
        {
            # false-but-defined is good enough to avoid
            # installation, anything true is proabably
            # a bogus call.

            warn "Oddity: true non-referent result from '$name':\n$result\n";
        }
    }
    elsif( $@ )
    {
        croak "Compile aborted for '$class' handling '$name'";
    }

}

########################################################################
# stub destroy, saves hitting the AUTOLOAD
# for every destructor. classes that need 
# their own DESTROY can override this easily
# enough...
# 
# the object doesn't have to bookkeep any of
# the class-based metadata so there isn't any
# metadata maintinence here.

DESTROY
{

    ()
}

# keep require happy

1

__END__

=head1 NAME

Plugin::Installer

Call the plugin's compiler, install it via quality_to_ref, then
dispatch it using goto.

=head1 SYNOPSIS 

    package Myplugin;

    use base qw( Plugin::Installer Plugin::Language::Foobar );

    ...

    my $plugin = Myplugin->construct;

    # frobnicate is passed first to Plugin::Installer 
    # via AUTOLOAD, then to P::L::Foobar's compile
    # method. if what comes back from the compiler is
    # a referent it is intalled in the P::L::F namespace
    # and if it is a code referent it is dispatched.

    $plugin->frobnicate;

=head1 DESCRIPTION

The goal of this module is to provide a simple, 
flexable interface for developing plugin 
languages. Any language that can store its
object data as a hash and implement a "compile"
method that takes the method name as an argument
can use this class.  The Plugin framework gives 
runtime compile, install, and dispatch of 
user-defined code.  The code doesn't have to be 
Perl, just something that the object handling it 
can compile. 

The installer is language-agnostic: in fact it
has no idea what the object does with the name
passed to its compioer. All it does is (by 
default) install a returned reference and dispatch
coderefs. This is intended as a convienence class
that standardizes the top half of any plugin 
language.

Note that any referent returned by the compiler
is installed. Handing back a hashref can deposit
a hash into the caller's namespace. This allows
for plugins to handle command line switches
(via GetoptFoo and a hashref) or manipulate 
queues (by handing back an [udpated] arrayref.

By default coderefs are dispatched via goto, 
which allows the obvious use of compiling the 
plugin to an anonymous sub for later use. This
make the plugins something of a trampoline 
object, with the exception that the "trampolines"
are the class' methods rather than the object
itself.

=head2 AUTOLOAD

Extracts the package and method name from a call,
dispatches $package->compile( $name ), and handles
the result. Results can be installed (if they are
referents of any type) and dispatched (if they are
coderefs).

The point of this is that the pluing language is
free to compile the plugin source to whatever suits
it best, Plugin::Installer will install the result.

In most cases the result will be a coderef, which 
will be installed as $AUTOLOAD, which allows 
plugins to resolve themselves from source to method
at runtime.

=head2 DESTROY

Stub, saves passing back through the AUTOLOAD
unnecessarly. Plugin classes that need housekeeping
should implement a DESTROY of their own.

=head2 Plugin install metadata

During compilation, Plugin::Install::AUTOLOAD
places an {install_meta} entry into the object.
This is done via local hash value, and will not
be visible to the caller after the autoloader 
has processed the call.

This defines switches used for post-compile 
handling:

    my $default_meta = 
    {
        install     => 1,
        dispatch    => 1,
        storemeta   => 0,

        alt_package => '',
    };

 
=over 4

=item install     => 1,

Does a referent returned from $obj->compile get installed
into the namespace or simply dispatched?

This is used to avoid installing plugins whose 
contents will be re-defined during execution
and called multiple times. 

=item dispatch    => 1,

Is a code referent dispatched (whether or not it is 
installed into a package)?

Some methods may be easier to pre-install but not 
dispatch immediately (e.g. if they involve expensive
startup but have per-execution side-effects). Setting
this to false will skip dispatch of coderef's even
if they are installed.

=item alt_package => '',

Package to install the referent into (default if
false is the object's package). This the namespace
passed with the method name to 'qualify_to_ref'.

This can be used by the compiler to install data
or coderef's into a caller's namespace (e.g. via
caller(2)). If this is used with storemeta then 
ALL of the methods for the plugin class will be 
installed into the alternate package space unless
they set their own alt_package when called.

=item storemeta   => 0,

Store the current metdata as the default for this
class? The metadata is stored by class name, allowing
an initial "startup" call (say in the constructor
or import) to configure appropriate defaults for the
entire class.

=back

Note that if install is true for a coderef then 
none of these matter much after the first call
since the installed method will bypass the 
AUTOLOAD.

Corrilary: If a "setup" method is used to set 
metadata values then it probably should not be 
installed so that it can fondle the class' 
metadata and modify it if necewsary on later 
calls.

This also means that plugin languages should
implement some sort of instructions to modify
the metadata.

=head1 SEE ALSO

=over 4

=item ./t/01.t

Example plugin class with simple, working
compiler.

=item Plugin::Language::DML

Little language for bulk data filtering,
including pre- and post-processing DBI calls;
uses Plugin::Install to handle method installation.

=item Symbol

Installing symbols without resoting to no strict 'refs'.

=item Scalar::Util 

Extracting the basetype of a blessed referent.

=item Object::Trampoline

Trampoline object: construction and initilization
are put off until a method is called on the 
compiled object.

=back

=head1 AUTHORS

Steven Lembark  <lembark@wrkhors.com>
Florian Mayr    <florian.mayr@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2005 by the authors; this code can 
be reused and re-released under the same terms 
as Perl-5.8.0 or any later version of the Perl. 

