#!/usr/bin/perl

use strict;
use warnings;

use IO::Socket::INET;
use Digest::MD5;

our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK, %RAD_STATE);

use constant {
	RLM_MODULE_REJECT   => 0, # immediately reject the request
	RLM_MODULE_OK       => 2, # the module is OK, continue
	RLM_MODULE_HANDLED  => 3, # the module handled the request, so stop
	RLM_MODULE_INVALID  => 4, # the module considers the request invalid
	RLM_MODULE_USERLOCK => 5, # reject the request (user is locked out)
	RLM_MODULE_NOTFOUND => 6, # user not found
	RLM_MODULE_NOOP     => 7, # module succeeded without doing anything
	RLM_MODULE_UPDATED  => 8, # OK (pairs modified)
	RLM_MODULE_NUMCODES => 9  # How many return codes there are
};

use constant {
	L_AUTH         => 2,  # Authentication message
	L_INFO         => 3,  # Informational message
	L_ERR          => 4,  # Error message
	L_WARN         => 5,  # Warning
	L_PROXY        => 6,  # Proxy messages
	L_ACCT         => 7,  # Accounting messages
	L_DBG          => 16, # Only displayed when debugging is enabled
	L_DBG_WARN     => 17, # Warning only displayed when debugging is enabled
	L_DBG_ERR      => 18, # Error only displayed when debugging is enabled
	L_DBG_WARN_REQ => 19, # Less severe warning only displayed when debugging is enabled
	L_DBG_ERR_REQ  => 20, # Less severe error only displayed when debugging is enabled
};

my %hosts = ( "10.10.0" => { 'secret' => 'xxx',
                             'nas' => [ '10.10.0.252', '10.10.0.253', '10.10.0.223' ]
                           },
              "10.10.1" => { 'secret' => 'yyy',
                             'nas' => [ '10.10.1.252', '10.10.1.253', '10.10.1.223' ]
                           }
            );
my $port = "3799";

# Function to handle accounting_stop
sub accounting_stop {
	# Send Disconnect-Request to multiple routers

	# https://www.ietf.org/rfc/rfc3576.txt
	# https://www.ietf.org/rfc/rfc2866.txt

	if (!%RAD_REQUEST) {
		&radiusd::radlog(4, "perl accounting_stop error: hash %RAD_REQUEST not exist");
		return RLM_MODULE_NOOP;
	}
	if (!exists($RAD_REQUEST{'Acct-Status-Type'})) {
		&radiusd::radlog(4, "perl accounting_stop error: key Acct-Status-Type not exist in hash %RAD_REQUEST");
		return RLM_MODULE_NOOP;
	}
	if (!exists($RAD_REQUEST{'User-Name'})) {
		&radiusd::radlog(4, "perl accounting_stop error: key User-Name not exist in hash %RAD_REQUEST");
		return RLM_MODULE_NOOP;
	}
	if (!exists($RAD_REQUEST{'NAS-IP-Address'})) {
		&radiusd::radlog(4, "perl accounting_stop error: key NAS-IP-Address not exist in hash %RAD_REQUEST");
		return RLM_MODULE_NOOP;
	}
	if (length($RAD_REQUEST{'User-Name'}) < 1 ) {
		&radiusd::radlog(4, "perl accounting_stop error: key User-Name not valid");
		return RLM_MODULE_NOOP;
	}
	
	if ($RAD_REQUEST{'Acct-Status-Type'} eq 'Stop') {
		my $user = $RAD_REQUEST{'User-Name'};
		my ($ip_prefix) = $RAD_REQUEST{'NAS-IP-Address'} =~ /^(\d+\.\d+\.\d+)/;

		my $type_attribute = 1; # 1 = Radius Attribute "User-Name"
		my $code = 40; # 40 - Radius Code "Disconnect-Request"

		my $identifier = int(rand(255)) + 1;
		my $attributes = pack('C C', $type_attribute, length($user) + 2) . $user;
		my $length = 20 + length($attributes);

		my $header = pack('C C n', $code, $identifier, $length);
		my $oc_fill = "\0" x 16;

		my $ct = Digest::MD5->new;
		$ct->add($header, $oc_fill, $attributes, $hosts{$ip_prefix}{'secret'});
		my $authenticator = $ct->digest();

		my $data = $header . $authenticator . $attributes;

		if (exists($hosts{$ip_prefix})) {
			foreach my $host (@{$hosts{$ip_prefix}{'nas'}}) {
				my $socket = new IO::Socket::INET->new(PeerAddr => $host,
								       PeerPort => $port,
								       Proto    => 'udp',
								       Timeout  => 2) or &radiusd::radlog(4, "perl accounting_stop error: Couldn't connect to $host:$port: $@"); 

				my $rc = $socket->send($data);
				close($socket);
			}
		} else {
			&radiusd::radlog(4, "perl accounting_stop error: NAS-IP-Address Prefix not found in config, prefix: $ip_prefix");
			return RLM_MODULE_NOOP;
		}
	} else {
		&radiusd::radlog(4, "perl accounting_stop error: Acct-Status-Type ist not Stop");
		return RLM_MODULE_NOOP;
	}

	return RLM_MODULE_OK;
}

sub accounting_start {
	return RLM_MODULE_NOOP;
}

sub accounting {
	return RLM_MODULE_NOOP;
}
