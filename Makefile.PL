use ExtUtils::MakeMaker;

WriteMakefile
(
        NAME            => 'Plugin::Installer',

        VERSION         => '0.01',

        ABSTRACT                => <<'END',
Installer top-end handler for Plugin::Language::*
modules. AUTOLOAD dispatches to the compiler, optionally
installes and dispatches the result.
END

        PREREQ_PM =>
        {
                # these are mostly standard distro fare: whatever's
                # available should be fine.

                strict          => 0,
                Symbol          => 0,
                Carp            => 0,
                Scalar::Util    => 0,
                Test::Simple    => 0,
        },
);

