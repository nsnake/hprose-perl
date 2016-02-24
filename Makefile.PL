use 5.010000;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Hprose',
    DISTNAME         => 'Hprose',
    VERSION_FROM     => 'lib/Hprose.pm',
    MIN_PERL_VERSION => '5.10.0',
    PREREQ_PM        => {
        'Data::GUID'     => 0,
        'DateTime'       => 0,
        'Error'          => 0,
        'AnyEvent'       => 7.12,
        'AnyEvent::HTTP' => 2.22,
        'IO::String'     => 0,
        'Data::Dumper'   => 0,
        'Math::BigInt'   => 0,
        'Math::BigFloat' => 0,
        'Tie::RefHash'   => 0
    },
    ABSTRACT_FROM => 'lib/Hprose.pm',
    AUTHOR        => 'Ma Bingyao <andot@hprose.com>',
    LICENSE       => 'perl',
);
