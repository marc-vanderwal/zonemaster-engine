package Zonemaster::Engine::TestCase;

use v5.16.0;
use warnings;

=head1 NAME

Zonemaster::Engine::TestCase - Common behavior and scaffolding for Zonemaster test cases

=head1 SYNOPSIS

    package Zonemaster::Engine::TestCase::Example;

    use Zonemaster::Engine::TestCase;

    # Annotate methods implementing actual test cases with the "TestCase"
    # attribute for proper operation, like so:
    sub example01 : TestCase {
        my @results;
        ...;
        return @results;
    }

    # Methods without this attribute are left alone.
    sub _private_method { ... }

=head1 DESCRIPTION

The main purpose of this module is to offer common behavior for Zonemaster
test cases, such that common boilerplate is implemented here instead of being
duplicated in each test case.

Test cases need to generate a C<TEST_CASE_START> message on entry, a
C<TEST_CASE_END> message on exit, and all messages need to be tagged with the
correct module name and test case names by setting
C<$Zonemaster::Engine::Logger::MODULE_NAME> and
C<$Zonemaster::Engine::Logger::TEST_CASE_NAME> appropriately.

For that purpose, this module defines the C<TestCase> method attribute. When
used on a method inside a test module, it is wrapped in a function that does
all the aforementioned processing. Then the method is silently redefined as
that wrapped function.

=head1 METHODS

=cut

sub _find_code_sym {
    my ( $package, $ref ) = @_;

    my $found;
    no strict 'refs';
    foreach my $sym ( values %{"${package}::"} ) {
        use strict;
        return \$sym if *{$sym}{'CODE'} && *{$sym}{'CODE'} == $ref;
    }
}

sub _method_to_testcase_name {
    my ( $package, $method ) = @_;

    my $modname = ( $package =~ s/^Zonemaster::Engine::Test:://r );
    my $prefix = lc $modname;
    my $test_case_name = ( $method =~ s/^\Q$prefix\E/$modname/r );

    return ( $modname, $test_case_name );
}

sub _wrap_testcase {
    my ( $package, $ref, $symbol ) = @_;

    my ( $modname, $test_case_name ) = _method_to_testcase_name( $package, *{$symbol}{NAME} );

    # The following redefines the test case method so that it is wrapped
    # inside a function that generates TEST_CASE_START and TEST_CASE_END
    # messages at entry and exit. That way, we don’t have to think about
    # it anymore.
    no warnings 'redefine';
    *{$symbol} = sub {
        local $Zonemaster::Engine::Logger::TEST_CASE_NAME = $test_case_name;
        return ( Zonemaster::Engine->logger->add( TEST_CASE_START => { testcase => $test_case_name } ),
                 $ref->(@_),
                 Zonemaster::Engine->logger->add( TEST_CASE_END => { testcase => $test_case_name } ) );
    };
}

=head2 import

Automatically called by Perl when C<use>-ing this module.

On C<use>, this module defines a function in the calling package called
C<MODIFY_CODE_ATTRIBUTES>, which is itself automatically called by Perl when
the calling package defines a function with at least one attribute.

=cut

sub import {
    my ( $class ) = @_;

    my $calling_module = caller();

    # We could check here if the calling module name starts with
    # Zonemaster::Engine::Test:: and act appropriately if not. But do we
    # really need that? Besides, how would third-party test modules fit in
    # this picture, should we decide to allow that?

    return unless defined $calling_module;

    my $modname = ( split /::/, $calling_module )[-1];

    no strict 'refs';

    # Export a handler for function attributes so that code such as
    # "sub example01 : TestCase { ... }" works
    *{"${calling_module}::MODIFY_CODE_ATTRIBUTES"} = sub {
        my ( $package, $coderef, @attributes ) = @_;

        my @bad_attributes;

        for my $attribute (@attributes) {
            if ($attribute eq 'TestCase') {
                my $sym = _find_code_sym( $package, $coderef );
                _wrap_testcase( $package, $coderef, $sym );
            }
            else {
                push @bad_attributes, $attribute;
            }
        }

        return @bad_attributes;
    };
}

1;
