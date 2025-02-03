package Zonemaster::Engine::Test::Delegation;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.20");

use List::MoreUtils qw[uniq];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;

use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::Constants ':all';
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::Test::Syntax;
use Zonemaster::Engine::TestCase;
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;
use Zonemaster::LDNS::Packet;
use Zonemaster::LDNS::RR;

=head1 NAME

Zonemaster::Engine::Test::Delegation - Module implementing tests focused on zone delegation

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Delegation->all( $zone );

=head1 METHODS

=over

=item all()

    my @logentry_array = all( $zone );

Runs the default set of tests for that module, i.e. L<seven tests|/TESTS>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->delegation01( $zone ) if Zonemaster::Engine::Util::should_run_test( q{delegation01} );
    push @results, $class->delegation02( $zone ) if Zonemaster::Engine::Util::should_run_test( q{delegation02} );
    push @results, $class->delegation03( $zone ) if Zonemaster::Engine::Util::should_run_test( q{delegation03} );
    push @results, $class->delegation04( $zone ) if Zonemaster::Engine::Util::should_run_test( q{delegation04} );
    push @results, $class->delegation05( $zone ) if Zonemaster::Engine::Util::should_run_test( q{delegation05} );
    push @results, $class->delegation06( $zone ) if Zonemaster::Engine::Util::should_run_test( q{delegation06} );
    push @results, $class->delegation07( $zone ) if Zonemaster::Engine::Util::should_run_test( q{delegation07} );

    return @results;
}

=over

=item metadata()

    my $hash_ref = metadata();

Returns a reference to a hash, the keys of which are the names of all Test Cases in the module, and the corresponding values are references to
an array containing all the message tags that the Test Case can use in L<log entries|Zonemaster::Engine::Logger::Entry>.

=back

=cut

sub metadata {
    my ( $class ) = @_;

    return {
        delegation01 => [
            qw(
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL
              NOT_ENOUGH_NS_DEL
              NOT_ENOUGH_NS_CHILD
              ENOUGH_IPV4_NS_CHILD
              ENOUGH_IPV4_NS_DEL
              ENOUGH_IPV6_NS_CHILD
              ENOUGH_IPV6_NS_DEL
              NOT_ENOUGH_IPV4_NS_CHILD
              NOT_ENOUGH_IPV4_NS_DEL
              NOT_ENOUGH_IPV6_NS_CHILD
              NOT_ENOUGH_IPV6_NS_DEL
              NO_IPV4_NS_CHILD
              NO_IPV4_NS_DEL
              NO_IPV6_NS_CHILD
              NO_IPV6_NS_DEL
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        delegation02 => [
            qw(
              CHILD_DISTINCT_NS_IP
              CHILD_NS_SAME_IP
              DEL_DISTINCT_NS_IP
              DEL_NS_SAME_IP
              SAME_IP_ADDRESS
              DISTINCT_IP_ADDRESS
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        delegation03 => [
            qw(
              REFERRAL_SIZE_TOO_LARGE
              REFERRAL_SIZE_OK
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        delegation04 => [
            qw(
              IS_NOT_AUTHORITATIVE
              IPV4_DISABLED
              IPV6_DISABLED
              ARE_AUTHORITATIVE
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        delegation05 => [
            qw(
              NO_NS_CNAME
              NO_RESPONSE
              NS_IS_CNAME
              UNEXPECTED_RCODE
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        delegation06 => [
            qw(
              SOA_NOT_EXISTS
              SOA_EXISTS
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        delegation07 => [
            qw(
              EXTRA_NAME_PARENT
              EXTRA_NAME_CHILD
              TOTAL_NAME_MISMATCH
              NAMES_MATCH
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    DELEGATION01 => sub {
        __x    # DELEGATION:DELEGATION01
          "Minimum number of name servers";
    },
    DELEGATION02 => sub {
        __x    # DELEGATION:DELEGATION02
          "Name servers must have distinct IP addresses";
    },
    DELEGATION03 => sub {
        __x    # DELEGATION:DELEGATION03
          "No truncation of referrals";
    },
    DELEGATION04 => sub {
        __x    # DELEGATION:DELEGATION04
          "Name server is authoritative";
    },
    DELEGATION05 => sub {
        __x    # DELEGATION:DELEGATION05
          "Name server must not point at CNAME alias";
    },
    DELEGATION06 => sub {
        __x    # DELEGATION:DELEGATION06
          "Existence of SOA";
    },
    DELEGATION07 => sub {
        __x    # DELEGATION:DELEGATION07
          "Parent glue name records present in child";
    },
    ARE_AUTHORITATIVE => sub {
        __x    # DELEGATION:ARE_AUTHORITATIVE
          "All these nameservers are confirmed to be authoritative : {nsname_list}.", @_;
    },
    CHILD_DISTINCT_NS_IP => sub {
        __x    # DELEGATION:CHILD_DISTINCT_NS_IP
          "All the IP addresses used by the nameservers in child are unique.", @_;
    },
    CHILD_NS_SAME_IP => sub {
        __x    # DELEGATION:CHILD_NS_SAME_IP
          "IP {ns_ip} in child refers to multiple nameservers ({nsname_list}).", @_;
    },
    DEL_DISTINCT_NS_IP => sub {
        __x    # DELEGATION:DEL_DISTINCT_NS_IP
          "All the IP addresses used by the nameservers in parent are unique.", @_;
    },
    DEL_NS_SAME_IP => sub {
        __x    # DELEGATION:DEL_NS_SAME_IP
          "IP {ns_ip} in parent refers to multiple nameservers ({nsname_list}).", @_;
    },
    DISTINCT_IP_ADDRESS => sub {
        __x    # DELEGATION:DISTINCT_IP_ADDRESS
          "All the IP addresses used by the nameservers are unique.", @_;
    },
    ENOUGH_IPV4_NS_CHILD => sub {
        __x    # DELEGATION:ENOUGH_IPV4_NS_CHILD
          "Child lists enough ({count}) nameservers that resolve to IPv4 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    ENOUGH_IPV4_NS_DEL => sub {
        __x    # DELEGATION:ENOUGH_IPV4_NS_DEL
          "Delegation lists enough ({count}) nameservers that resolve to IPv4 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    ENOUGH_IPV6_NS_CHILD => sub {
        __x    # DELEGATION:ENOUGH_IPV6_NS_CHILD
          "Child lists enough ({count}) nameservers that resolve to IPv6 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    ENOUGH_IPV6_NS_DEL => sub {
        __x    # DELEGATION:ENOUGH_IPV6_NS_DEL
          "Delegation lists enough ({count}) nameservers that resolve to IPv6 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    ENOUGH_NS_CHILD => sub {
        __x    # DELEGATION:ENOUGH_NS_CHILD
          "Child lists enough ({count}) nameservers. Lower limit set to {minimum}. Name servers: {nsname_list}", @_;
    },
    ENOUGH_NS_DEL => sub {
        __x    # DELEGATION:ENOUGH_NS_DEL
          "Delegation lists enough ({count}) nameservers. Lower limit set to {minimum}. Name servers: {nsname_list}", @_;
    },
    EXTRA_NAME_CHILD => sub {
        __x    # DELEGATION:EXTRA_NAME_CHILD
          "Child has nameserver(s) not listed at parent ({extra}).", @_;
    },
    EXTRA_NAME_PARENT => sub {
        __x    # DELEGATION:EXTRA_NAME_PARENT
          "Parent has nameserver(s) not listed at the child ({extra}).", @_;
    },
    IPV4_DISABLED => sub {
        __x    # DELEGATION:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # DELEGATION:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IS_NOT_AUTHORITATIVE => sub {
        __x    # DELEGATION:IS_NOT_AUTHORITATIVE
          "Nameserver {ns} response is not authoritative on {proto} port 53.", @_;
    },
    NAMES_MATCH => sub {
        __x    # DELEGATION:NAMES_MATCH
          "All of the nameserver names are listed both at parent and child.", @_;
    },
    NO_RESPONSE => sub {
        __x    # DELEGATION:NO_RESPONSE
          'Nameserver {ns} did not respond to a query for name {query_name} and type {rrtype}.', @_;
    },
    NOT_ENOUGH_IPV4_NS_CHILD => sub {
        __x    # DELEGATION:NOT_ENOUGH_IPV4_NS_CHILD
          "Child does not list enough ({count}) nameservers that resolve to IPv4 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    NOT_ENOUGH_IPV4_NS_DEL => sub {
        __x    # DELEGATION:NOT_ENOUGH_IPV4_NS_DEL
          "Delegation does not list enough ({count}) nameservers that resolve to IPv4 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    NOT_ENOUGH_IPV6_NS_CHILD => sub {
        __x    # DELEGATION:NOT_ENOUGH_IPV6_NS_CHILD
          "Child does not list enough ({count}) nameservers that resolve to IPv6 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    NOT_ENOUGH_IPV6_NS_DEL => sub {
        __x    # DELEGATION:NOT_ENOUGH_IPV6_NS_DEL
          "Delegation does not list enough ({count}) nameservers that resolve to IPv6 "
          . "addresses. Lower limit set to {minimum}. Name servers: {ns_list}",
          @_;
    },
    NOT_ENOUGH_NS_CHILD => sub {
        __x    # DELEGATION:NOT_ENOUGH_NS_CHILD
          "Child does not list enough ({count}) nameservers. Lower limit set to {minimum}. Name servers: {nsname_list}", @_;
    },
    NOT_ENOUGH_NS_DEL => sub {
        __x    # DELEGATION:NOT_ENOUGH_NS_DEL
          "Delegation does not list enough ({count}) nameservers. Lower limit set to {minimum}. Name servers: {nsname_list}", @_;
    },
    NO_IPV4_NS_CHILD => sub {
        __x    # DELEGATION:NO_IPV4_NS_CHILD
          "Child lists no nameserver that resolves to an IPv4 address. "
          . "If any were present, the minimum allowed would be {minimum}.",
          @_;
    },
    NO_IPV4_NS_DEL => sub {
        __x    # DELEGATION:NO_IPV4_NS_DEL
          "Delegation lists no nameserver that resolves to an IPv4 address. "
          . "If any were present, the minimum allowed would be {minimum}.",
          @_;
    },
    NO_IPV6_NS_CHILD => sub {
        __x    # DELEGATION:NO_IPV6_NS_CHILD
          "Child lists no nameserver that resolves to an IPv6 address. "
          . "If any were present, the minimum allowed would be {minimum}.",
          @_;
    },
    NO_IPV6_NS_DEL => sub {
        __x    # DELEGATION:NO_IPV6_NS_DEL
          "Delegation lists no nameserver that resolves to an IPv6 address. "
          . "If any were present, the minimum allowed would be {minimum}.",
          @_;
    },
    NS_IS_CNAME => sub {
        __x    # DELEGATION:NS_IS_CNAME
          "Nameserver {nsname} RR points to CNAME.", @_;
    },
    NO_NS_CNAME => sub {
        __x    # DELEGATION:NO_NS_CNAME
          "No nameserver points to CNAME alias.", @_;
    },
    REFERRAL_SIZE_TOO_LARGE => sub {
        __x    # DELEGATION:REFERRAL_SIZE_TOO_LARGE
          "The smallest possible legal referral packet is larger than 512 octets (it is {size}).", @_;
    },
    REFERRAL_SIZE_OK => sub {
        __x    # DELEGATION:REFERRAL_SIZE_OK
          "The smallest possible legal referral packet is smaller than 513 octets (it is {size}).", @_;
    },
    SAME_IP_ADDRESS => sub {
        __x    # DELEGATION:SAME_IP_ADDRESS
          "IP {ns_ip} refers to multiple nameservers ({nsname_list}).", @_;
    },
    SOA_EXISTS => sub {
        __x    # DELEGATION:SOA_EXISTS
          "All the nameservers have SOA record.", @_;
    },
    SOA_NOT_EXISTS => sub {
        __x    # DELEGATION:SOA_NOT_EXISTS
          "Empty NOERROR response to SOA query was received from {ns}.", @_;
    },
    TEST_CASE_END => sub {
        __x    # DELEGATION:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # DELEGATION:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
    TOTAL_NAME_MISMATCH => sub {
        __x    # DELEGATION:TOTAL_NAME_MISMATCH
          "None of the nameservers listed at the parent are listed at the child.", @_;
    },
    UNEXPECTED_RCODE => sub {
        __x    # DELEGATION:UNEXPECTED_RCODE
          'Nameserver {ns} answered query for name {query_name} and type {rrtype} with RCODE {rcode}.', @_;
    },

);

=over

=item tag_descriptions()

    my $hash_ref = tag_descriptions();

Used by the L<built-in translation system|Zonemaster::Engine::Translator>.

Returns a reference to a hash, the keys of which are the message tags and the corresponding values are strings (message IDs).

=back

=cut

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

=over

=item version()

    my $version_string = version();

Returns a string containing the version of the current module.

=back

=cut

sub version {
    return "$Zonemaster::Engine::Test::Delegation::VERSION";
}

=head1 INTERNAL METHODS

=over

=item _ip_disabled_message()

    my $bool = _ip_disabled_message( $logentry_array_ref, $ns, @query_type_array );

Checks if the IP version of a given name server is allowed to be queried. If not, it adds a logging message and returns true. Else, it returns false.

Takes a reference to an array of L<Zonemaster::Engine::Logger::Entry> objects, a L<Zonemaster::Engine::Nameserver> object and an array of strings (query type).

Returns a boolean.

=back

=cut

sub _ip_disabled_message {
    my ( $results_array, $ns, @rrtypes ) = @_;

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
        push @$results_array, map {
          _emit_log(
            IPV6_DISABLED => {
                ns     => $ns->string,
                rrtype => $_
            }
          )
        } @rrtypes;
        return 1;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
        push @$results_array, map {
          _emit_log(
            IPV4_DISABLED => {
                ns     => $ns->string,
                rrtype => $_,
            }
          )
        } @rrtypes;
        return 1;
    }
    return 0;
}

=over

=item _max_length_name_for()

    my $name_string = _max_length_name_for( $name );

Makes up a name of maximum length in the given domain name. Used as an helper function for Test Case L<Delegation03|/delegation03()>.

Takes a L<Zonemaster::Engine::DNSName> object.

Returns a string.

=back

=cut

sub _max_length_name_for {
    my ( $top ) = @_;
    my @chars = q{A} .. q{Z};

    my $name = name( $top )->fqdn;
    $name = q{} if $name eq q{.};    # Special case for root zone

    while ( length( $name ) < $FQDN_MAX_LENGTH - 1 ) {
        my $len = $FQDN_MAX_LENGTH - length( $name ) - 1;
        $len = $LABEL_MAX_LENGTH if $len > $LABEL_MAX_LENGTH;
        $name = join( q{}, map { $chars[ rand @chars ] } 1 .. $len ) . q{.} . $name;
    }

    return $name;
}

=over

=item _find_dup_ns()

    my @logentry_array = _find_dup_ns( %hash );

Checks if given name servers have distinct IP addresses. Used as an helper function for Test Case L<Delegation02|/delegation02()>.

Takes a hash - the keys of which are C<duplicate_tag>, C<distinct_tag> and C<ns_list>, and their corresponding values are a string,
a string and a reference to an array of L<Zonemaster::Engine::Nameserver> objects, respectively.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub _find_dup_ns {
    my %args          = @_;
    my $duplicate_tag = $args{duplicate_tag};
    my $distinct_tag  = $args{distinct_tag};
    my @nss           = @{ $args{ns_list} };

    my %nsnames_and_ip;
    my %ips;
    foreach my $local_ns ( @nss ) {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        push @{ $ips{ $local_ns->address->short } }, $local_ns->name->string;

        $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;

    }

    my @results;
    foreach my $local_ip ( sort keys %ips ) {
        if ( scalar @{ $ips{$local_ip} } > 1 ) {
            push @results,
              _emit_log(
                $duplicate_tag => {
                    nsname_list => join( q{;}, @{ $ips{$local_ip} } ),
                    ns_ip       => $local_ip,
                }
              );
        }
    }

    if ( @nss && !@results ) {
        push @results, _emit_log( $distinct_tag => {} );
    }

    return @results;
}

=head1 TESTS

=over

=item delegation01()

    my @logentry_array = delegation01( $zone );

Runs the L<Delegation01 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Delegation-TP/delegation01.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub delegation01 : TestCase {
    my ( $class, $zone ) = @_;

    my @results;

    # Determine delegation NS names
    my @del_nsnames = map { $_->string } @{ Zonemaster::Engine::TestMethods->method2( $zone ) };
    my $del_nsnames_args = {
        count       => scalar( @del_nsnames ),
        minimum     => $MINIMUM_NUMBER_OF_NAMESERVERS,
        nsname_list => join( q{;}, sort @del_nsnames ),
    };

    # Check delegation NS names
    if ( scalar( @del_nsnames ) >= $MINIMUM_NUMBER_OF_NAMESERVERS ) {
        push @results, _emit_log( ENOUGH_NS_DEL => $del_nsnames_args );
    }
    else {
        push @results, _emit_log( NOT_ENOUGH_NS_DEL => $del_nsnames_args );
    }

    # Determine child NS names
    my @child_nsnames = map { $_->string } @{ Zonemaster::Engine::TestMethods->method3( $zone ) };
    my $child_nsnames_args = {
        count       => scalar( @child_nsnames ),
        minimum     => $MINIMUM_NUMBER_OF_NAMESERVERS,
        nsname_list => join( q{;}, sort @child_nsnames ),
    };

    # Check child NS names
    if ( scalar( @child_nsnames ) >= $MINIMUM_NUMBER_OF_NAMESERVERS ) {
        push @results, _emit_log( ENOUGH_NS_CHILD => $child_nsnames_args );
    }
    else {
        push @results, _emit_log( NOT_ENOUGH_NS_CHILD => $child_nsnames_args );
    }

    # Determine child NS names with addresses
    my @child_ns = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my @child_ns_ipv4 = map { $_ } grep { $_->address->version == 4 } @child_ns;
    my @child_ns_ipv6 = map { $_ } grep { $_->address->version == 6 } @child_ns;

    my $child_ns_ipv4_args = {
        count       => scalar( uniq map { $_->name->string } @child_ns_ipv4 ),
        minimum     => $MINIMUM_NUMBER_OF_NAMESERVERS,
        ns_list => join( q{;}, sort map { $_->string } @child_ns_ipv4 ),
    };
    my $child_ns_ipv6_args = {
        count       => scalar( uniq map { $_->name->string } @child_ns_ipv6 ),
        minimum     => $MINIMUM_NUMBER_OF_NAMESERVERS,
        ns_list => join( q{;}, sort map { $_->string } @child_ns_ipv6 ),
    };

    if ( scalar( uniq map { $_->name->string } @child_ns_ipv4 ) >= $MINIMUM_NUMBER_OF_NAMESERVERS ) {
        push @results, _emit_log( ENOUGH_IPV4_NS_CHILD => $child_ns_ipv4_args );
    }
    elsif ( scalar( uniq map { $_->name->string } @child_ns_ipv4 ) > 0 ) {
        push @results, _emit_log( NOT_ENOUGH_IPV4_NS_CHILD => $child_ns_ipv4_args );
    }
    else {
        push @results, _emit_log( NO_IPV4_NS_CHILD => $child_ns_ipv4_args );
    }

    if ( scalar( uniq map { $_->name->string } @child_ns_ipv6 ) >= $MINIMUM_NUMBER_OF_NAMESERVERS ) {
        push @results, _emit_log( ENOUGH_IPV6_NS_CHILD => $child_ns_ipv6_args );
    }
    elsif ( scalar( uniq map { $_->name->string } @child_ns_ipv6 ) > 0 ) {
        push @results, _emit_log( NOT_ENOUGH_IPV6_NS_CHILD => $child_ns_ipv6_args );
    }
    else {
        push @results, _emit_log( NO_IPV6_NS_CHILD => $child_ns_ipv6_args );
    }

    # Determine delegation NS names with addresses
    my @del_ns = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @del_ns_ipv4 = map { $_ } grep { $_->address->version == 4 } @del_ns;
    my @del_ns_ipv6 = map { $_ } grep { $_->address->version == 6 } @del_ns;

    my $del_ns_ipv4_args = {
        count       => scalar( uniq map { $_->name->string } @del_ns_ipv4 ),
        minimum     => $MINIMUM_NUMBER_OF_NAMESERVERS,
        ns_list => join( q{;}, sort map { $_->string } @del_ns_ipv4 ),
    };
    my $del_ns_ipv6_args = {
        count       => scalar( uniq map { $_->name->string } @del_ns_ipv6 ),
        minimum     => $MINIMUM_NUMBER_OF_NAMESERVERS,
        ns_list => join( q{;}, sort map { $_->string } @del_ns_ipv6 ),
    };

    if ( scalar( uniq map { $_->name->string } @del_ns_ipv4 ) >= $MINIMUM_NUMBER_OF_NAMESERVERS ) {
        push @results, _emit_log( ENOUGH_IPV4_NS_DEL => $del_ns_ipv4_args );
    }
    elsif ( scalar( uniq map { $_->name->string } @del_ns_ipv4 ) > 0 ) {
        push @results, _emit_log( NOT_ENOUGH_IPV4_NS_DEL => $del_ns_ipv4_args );
    }
    else {
        push @results, _emit_log( NO_IPV4_NS_DEL => $del_ns_ipv4_args );
    }

    if ( scalar( uniq map { $_->name->string } @del_ns_ipv6 ) >= $MINIMUM_NUMBER_OF_NAMESERVERS ) {
        push @results, _emit_log( ENOUGH_IPV6_NS_DEL => $del_ns_ipv6_args );
    }
    elsif ( scalar( uniq map { $_->name->string } @del_ns_ipv6 ) > 0 ) {
        push @results, _emit_log( NOT_ENOUGH_IPV6_NS_DEL => $del_ns_ipv6_args );
    }
    else {
        push @results, _emit_log( NO_IPV6_NS_DEL => $del_ns_ipv6_args );
    }

    return @results;
} ## end sub delegation01

=over

=item delegation02()

    my @logentry_array = delegation02( $zone );

Runs the L<Delegation02 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Delegation-TP/delegation02.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub delegation02 : TestCase {
    my ( $class, $zone ) = @_;

    my @results;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };

    push @results,
      _find_dup_ns(
        duplicate_tag => 'DEL_NS_SAME_IP',
        distinct_tag  => 'DEL_DISTINCT_NS_IP',
        ns_list       => [@nss_del],
      );

    push @results,
      _find_dup_ns(
        duplicate_tag => 'CHILD_NS_SAME_IP',
        distinct_tag  => 'CHILD_DISTINCT_NS_IP',
        ns_list       => [@nss_child],
      );

    push @results,
      _find_dup_ns(
        duplicate_tag => 'SAME_IP_ADDRESS',
        distinct_tag  => 'DISTINCT_IP_ADDRESS',
        ns_list       => [ @nss_del, @nss_child ],
      );

    return @results;
} ## end sub delegation02

=over

=item delegation03()

    my @logentry_array = delegation03( $zone );

Runs the L<Delegation03 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Delegation-TP/delegation03.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub delegation03 : TestCase {
    my ( $class, $zone ) = @_;

    my @results;

    my $long_name = _max_length_name_for( $zone->name );
    my @nsnames   = map { $_->string } @{ Zonemaster::Engine::TestMethods->method2( $zone ) };
    my @nss       = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_v4    = grep { $_->address->version == $IP_VERSION_4 } @nss;
    my @nss_v6    = grep { $_->address->version == $IP_VERSION_6 } @nss;
    my $parent    = $zone->parent();

    my $p = Zonemaster::LDNS::Packet->new( $long_name, q{NS}, q{IN} );
    for my $nsname ( @nsnames ) {
        my $rr = Zonemaster::LDNS::RR->new( sprintf( q{%s IN NS %s}, $zone->name, $nsname ) );
        $p->unique_push( q{authority}, $rr );
    }

    # If @nss_v4 is non-empty and all of its elements are in bailiwick of parent
    if ( @nss_v4 and not grep { not $parent->name->is_in_bailiwick( $_->name ) } @nss_v4 ) {
        my $ns = $nss_v4[0];
        my $rr = Zonemaster::LDNS::RR->new( sprintf( q{%s IN A %s}, $ns->name, $ns->address->short ) );
        $p->unique_push( q{additional}, $rr );
    }

    # If @nss_v6 is non-empty and all of its elements are in bailiwick of parent
    if ( @nss_v6 and not grep { not $parent->name->is_in_bailiwick( $_->name ) } @nss_v6 ) {
        my $ns = $nss_v6[0];
        my $rr = Zonemaster::LDNS::RR->new( sprintf( q{%s IN AAAA %s}, $ns->name, $ns->address->short ) );
        $p->unique_push( q{additional}, $rr );
    }

    my $size = length( $p->data );
    if ( $size > $UDP_PAYLOAD_LIMIT ) {
        push @results,
          _emit_log(
            REFERRAL_SIZE_TOO_LARGE => {
                size => $size,
            }
          );
    }
    else {
        push @results,
          _emit_log(
            REFERRAL_SIZE_OK => {
                size => $size,
            }
          );
    }

    return @results;
} ## end sub delegation03

=over

=item delegation04()

    my @logentry_array = delegation04( $zone );

Runs the L<Delegation04 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Delegation-TP/delegation04.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub delegation04 : TestCase {
    my ( $class, $zone ) = @_;

    my @results;
    my %nsnames;
    my @authoritatives;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        if ( _ip_disabled_message( \@results, $local_ns, $query_type ) ) {
            next;
        }

        next if $nsnames{ $local_ns->name->string };

        foreach my $usevc ( 0, 1 ) {
            my $p = $local_ns->query( $zone->name, $query_type, { usevc => $usevc } );
            if ( $p ) {
                if ( not $p->aa ) {
                    push @results,
                      _emit_log(
                        IS_NOT_AUTHORITATIVE => {
                            ns    => $local_ns->string,
                            proto => $usevc ? q{TCP} : q{UDP},
                        }
                      );
                }
                else {
                    push @authoritatives, $local_ns->name->string;
                }
            }
        }

        $nsnames{ $local_ns->name }++;
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if (
        (
               scalar @{ Zonemaster::Engine::TestMethods->method4( $zone ) }
            or scalar @{ Zonemaster::Engine::TestMethods->method5( $zone ) }
        )
        and not grep { $_->tag ne q{TEST_CASE_START} } @results
        and scalar @authoritatives
      )
    {
        push @results,
          _emit_log(
            ARE_AUTHORITATIVE => {
                nsname_list => join( q{;}, uniq sort @authoritatives ),
            }
          );
    }

    return @results;
} ## end sub delegation04

=over

=item delegation05()

    my @logentry_array = delegation05( $zone );

Runs the L<Delegation05 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Delegation-TP/delegation05.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub delegation05 : TestCase {
    my ( $class, $zone ) = @_;

    my @results;

    my @nsnames = @{ Zonemaster::Engine::TestMethods->method2and3( $zone ) };

    foreach my $local_nsname ( @nsnames )  {

        if ( $zone->name->is_in_bailiwick( $local_nsname ) ) {
            my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
            my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
            my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

            for my $key ( sort keys %nss ) {
                my $ns = $nss{$key};
                my $ns_args = {
                    ns         => $ns->string,
                    query_name => $local_nsname,
                    rrtype     => q{A},
                };

                if ( _ip_disabled_message( \@results, $ns, q{A} ) ) {
                    next;
                }

                my $p = $ns->query( $local_nsname, q{A}, { recurse => 0 } );
                if ( not $p ) {
                    push @results, _emit_log( NO_RESPONSE => $ns_args );
                    next;
                }
                elsif ($p->rcode ne q{NOERROR} ) {
                    $ns_args->{rcode} = $p->rcode;
                    push @results, _emit_log( UNEXPECTED_RCODE => $ns_args );
                    next;
                }
                elsif ( scalar $p->get_records( q{CNAME}, q{answer} ) > 0 ) {
                    push @results, _emit_log( NS_IS_CNAME => { nsname => $local_nsname } );
                    next;
                }
                elsif ($p->is_redirect) {
                    my $p = $ns->query( $local_nsname, q{A}, { recurse => 1 } );
                    if ( defined $p and scalar $p->get_records( q{CNAME}, q{answer} ) > 0 ) {
                        push @results, _emit_log( NS_IS_CNAME => { nsname => $local_nsname } );
                    }
                }
            }
        }
        else {
            my $p = Zonemaster::Engine::Recursor->recurse( $local_nsname, q{A} );
            if ( defined $p and scalar $p->get_records( q{CNAME}, q{answer} ) > 0 ) {
                push @results, _emit_log( NS_IS_CNAME => { nsname => $local_nsname } );
            }
        }
    }

    if ( not grep { $_->tag eq q{NS_IS_CNAME} } @results ) {
        push @results, _emit_log( NO_NS_CNAME => {} );
    }

    return @results;
} ## end sub delegation05

=over

=item delegation06()

    my @logentry_array = delegation06( $zone );

Runs the L<Delegation06 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Delegation-TP/delegation06.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub delegation06 : TestCase {
    my ( $class, $zone ) = @_;

    my @results;
    my %nsnames;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        if ( _ip_disabled_message( \@results, $local_ns, $query_type ) ) {
            next;
        }

        next if $nsnames{ $local_ns->name->string };

        my $p = $local_ns->query( $zone->name, $query_type );
        if ( $p and $p->rcode eq q{NOERROR} ) {
            if ( not $p->get_records( $query_type, q{answer} ) ) {
                push @results, _emit_log( SOA_NOT_EXISTS => { ns => $local_ns->string } );
            }
        }

        $nsnames{ $local_ns->name->string }++;
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if (
        (
               scalar @{ Zonemaster::Engine::TestMethods->method4( $zone ) }
            or scalar @{ Zonemaster::Engine::TestMethods->method5( $zone ) }
        )
        and not grep { $_->tag ne q{TEST_CASE_START} } @results
      )
    {
        push @results, _emit_log( SOA_EXISTS => {} );
    }

    return @results;
} ## end sub delegation06

=over

=item delegation07()

    my @logentry_array = delegation07( $zone );

Runs the L<Delegation07 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Delegation-TP/delegation07.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub delegation07 : TestCase {
    my ( $class, $zone ) = @_;

    my @results;

    my %names;
    foreach my $name ( @{ Zonemaster::Engine::TestMethods->method2( $zone ) } ) {
        $names{$name} += 1;
    }
    foreach my $name ( @{ Zonemaster::Engine::TestMethods->method3( $zone ) } ) {
        $names{$name} -= 1;
    }

    my @same_name         = sort grep { $names{$_} == 0 } keys %names;
    my @extra_name_parent = sort grep { $names{$_} > 0 } keys %names;
    my @extra_name_child  = sort grep { $names{$_} < 0 } keys %names;

    if ( @extra_name_parent ) {
        push @results,
          _emit_log(
            EXTRA_NAME_PARENT => {
                extra => join( q{;}, sort @extra_name_parent ),
            }
          );
    }

    if ( @extra_name_child ) {
        push @results,
          _emit_log(
            EXTRA_NAME_CHILD => {
                extra => join( q{;}, sort @extra_name_child ),
            }
          );
    }

    if ( @extra_name_parent == 0 and @extra_name_child == 0 ) {
        push @results,
          _emit_log(
            NAMES_MATCH => {
                names => join( q{;}, sort @same_name ),
            }
          );
    }

    if ( scalar( @same_name ) == 0 ) {
        push @results,
          _emit_log(
            TOTAL_NAME_MISMATCH => {
                glue  => join( q{;}, sort @extra_name_parent ),
                child => join( q{;}, sort @extra_name_child ),
            }
          );
    }

    return @results;
} ## end sub delegation07

1;
