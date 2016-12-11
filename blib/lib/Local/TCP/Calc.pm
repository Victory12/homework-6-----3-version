package Local::TCP::Calc;
use strict;
use JSON::XS;
use DDP;
sub TYPE_START_WORK {1}
sub TYPE_CHECK_WORK {2}
sub TYPE_CONN_ERR   {3}
sub TYPE_CONN_OK    {4}

sub STATUS_NEW   {1}
sub STATUS_WORK  {2}
sub STATUS_DONE  {3}
sub STATUS_ERROR {4}

sub pack_header {
	my $pkg = shift;
	my $type = shift;
	my $size = shift;
	my $packed_header = pack("CL", $type, $size);
	return $packed_header;
}
sub unpack_header {
	my $pkg = shift;
	my $packed_header = shift;
	my $header;
	( $header->{type}, $header->{size} ) = unpack ("CL", $packed_header);
	return $header;	
}
sub pack_message {
	my $pkg = shift;
	my $json_data = shift;
	return JSON::XS->new->utf8->encode($json_data) if ref $json_data eq "ARRAY";
	return $json_data;
}
sub unpack_message {
	my $pkg = shift;
	my $perl_data = shift;
	if ( $perl_data =~ /\"(\d+)\"/ ) {
		my $qwe = "insiderrrr $1";
		return $1;
	}
	if ( $perl_data =~ /^\d+$/ ) {
	    my $qwe = "inside $perl_data";
		return $perl_data;
	}
	return undef if $perl_data eq "";
	return JSON::XS->new->utf8->decode($perl_data);
}
1;
