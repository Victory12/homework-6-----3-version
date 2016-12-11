package Local::TCP::Calc::Client;

use strict;
use IO::Socket;
use Local::TCP::Calc;
our $header_size = 5;
use DDP;

sub set_connect {
	my $pkg = shift;
	my $ip = shift;
	my $port = shift;
	my $message;
	my $quantity_symbols_r = "error in sysread in client\n";
	my $socket;
	$socket = IO::Socket::INET->new(
		PeerAddr => $ip,
		PeerPort => $port,
		Proto => "tcp",
		Type => SOCK_STREAM
	) or die "you cant Socket inet $!\n";
	binmode($socket);
	p $quantity_symbols_r if sysread($socket, $message, 1) != 1;
	if ($message == 3) {
		die  "overloaded server\n";
	}
	return $socket;
}
sub do_request {
	my $pkg = shift;
	my $socket = shift;
	my $type = shift;
	my $message = shift;
	my $quantity_symbols_r = "error in sysread in client\n";
	my $quantity_symbols_w = "error in syswrite in client\n";
	binmode($socket);
	my $packed_message = Local::TCP::Calc->pack_message( $message );
	my $size =length($packed_message);
	my $packed_header = Local::TCP::Calc->pack_header($type, $size);
	my $mes = $packed_header.$packed_message;
	p $quantity_symbols_w if syswrite($socket, $mes, length($mes)) != length($mes);
	p $quantity_symbols_r if sysread($socket, $packed_header, $header_size) != $header_size;
	my $header = Local::TCP::Calc->unpack_header( $packed_header );
 	p $quantity_symbols_r if sysread($socket,  my $packed_message, $header->{size}) != $header->{size};
	my $message = Local::TCP::Calc->unpack_message( $packed_message );
	close( $socket );
	if ($type == 1){
		return $message;
	}
	else{
		my @array;
		push @array, $header->{type};
		push @array, @$message if defined $message;
		return @array;
	}	
}
1;

