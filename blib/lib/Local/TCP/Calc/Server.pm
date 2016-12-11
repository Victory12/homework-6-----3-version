package Local::TCP::Calc::Server;

use strict;
use IPC::Run3;
use IO::Socket::INET;
use POSIX ":sys_wait_h";
use DDP;
use IO::File;
use Local::TCP::Calc;
use Local::TCP::Calc::Server::Queue;
use Local::TCP::Calc::Server::Worker;


my $max_worker;
my $max_forks_per_task = 0;
our $header_size = 5;
our $receiver_count = 0;

sub REAPER{
	while( my $pid = waitpid(-1, WNOHANG)){
		last if $pid == -1;
		$receiver_count--;
		if( WIFEXITED($?) ){
			my $status = $? >> 8;
			print "$pid exit with status $status $/";
		}
		else {
			print "Process $pid sleep $/";
		}
	}
}
$SIG{CHLD} = \&REAPER;

sub start_server {
	my ($pkg, $port, %opts) = @_;
	$max_worker         = $opts{max_worker} // die "max_worker required"; 
	$max_forks_per_task = $opts{max_forks_per_task} // die "max_forks_per_task required";
	my $max_receiver    = $opts{max_receiver}-1 // die "max_receiver required"; 
	my $max_queue_task  = $opts{max_queue_task} // die "max_queue_task required";
	my $quantity_symbols_w = "error in syswrite";
	my $quantity_symbols_r = "error in sysread";
	my $server = IO::Socket::INET->new(
		LocalAddr => 'localhost',
		LocalPort => $port,
		Type => SOCK_STREAM,
		ReuseAddr => 1,
		Listen => $max_receiver
		) or die "we cant start server $!\n";
	my $queue = Local::TCP::Calc::Server::Queue->new( {f_handle => IO::File->new, queue_filename => "queue_list", max_task => $max_queue_task} ); 
	$queue->init();   
	while(1){
		next unless my $client = $server->accept;
		binmode($client);
		if( $receiver_count > $max_receiver ){
			p $quantity_symbols_w if syswrite($client, Local::TCP::Calc::TYPE_CONN_ERR(), 1) != 1;
			close ($client);
		}
		else{		
			p $quantity_symbols_w if syswrite($client, Local::TCP::Calc::TYPE_CONN_OK(), 1) != 1;			 		
			if ( my $child = fork ){
				$receiver_count++;			
				close ($client);	
			}
			else{	
				die "cannot fork: $!" unless defined $child; 
				close ($server);			
				$client->autoflush(1);
				p $quantity_symbols_r if sysread($client, my $packed_header, $header_size) != $header_size;
				my $header = Local::TCP::Calc->unpack_header( $packed_header );
				p $quantity_symbols_r if sysread($client, my $packed_message, $header->{size}) != $header->{size};
				if ( $header->{type} == Local::TCP::Calc::TYPE_START_WORK() ) {	
					my $message = Local::TCP::Calc->unpack_message( $packed_message );
					my $id = $queue->add ( $message, $max_queue_task, $client );
					my $mes = pack_send(1, $id);
					p $quantity_symbols_w if syswrite($client, $mes, length ($mes)) != length ($mes);					
				}
				if ( $header->{type} == Local::TCP::Calc::TYPE_CHECK_WORK() ) {
					check_queue_workers($max_worker, $queue);	
					my $id = Local::TCP::Calc->unpack_message( $packed_message );
					my $status_file = $queue->get_status($id);
					if ( $status_file == Local::TCP::Calc->STATUS_WORK() or $status_file == Local::TCP::Calc->STATUS_NEW() ) {
						my $mes = pack_send ($status_file, undef);
						p $quantity_symbols_w if syswrite($client, $mes, length ($mes)) != length ($mes);								
					}
					else {
						my $mes = pack_send (3 , $status_file);
						$queue->delete($id);
						p $quantity_symbols_w if syswrite($client, $mes, length ($mes)) != length ($mes);			
						unlink($id) or die "Can't delete $status_file:  $!\n";
					}
					check_queue_workers($max_worker, $queue);
				}
				
				close( $client );			
				exit ;
			}	
		}
	}
}

sub check_queue_workers {
	my $self = shift;
	my $queue = shift;
	my $iterator_worker = 0;
	while ( $iterator_worker < $max_worker ) {
		my $object = $queue->get_object;
		last unless defined $object;	
		$iterator_worker++;
		if (my $pid = fork) {  
			waitpid($pid, 0);
			next;
		} 
		else {
		    die "cannot fork: $!" unless defined $pid;
			my $worker = Local::TCP::Calc::Server::Worker->new( {max_forks => $max_forks_per_task, cur_task_id => $object->{id}, calc_ref => \&calc, file => $object->{file}, status => $object->{status}} );
			$worker->start($queue);
			$queue->to_done($worker->{cur_task_id});
			$iterator_worker--;
			exit;
		}	
	}
}
sub pack_send {
	my $type = shift;
	my $message = shift;	
	my $packed_message = Local::TCP::Calc->pack_message($message);
	my $size = length($packed_message);
	my $packed_header = Local::TCP::Calc->pack_header($type, $size);
	my $mes = $packed_header.$packed_message;
	return $mes;	
}
sub calc{
	my $task = shift;
	my $file = 'lib/Local/TCP/Calc/Server/calculator/bin/calculator';
	$|=1;
	my $out;
	my $stderr;
	run3 ($file, \$task, \$out, \$stderr);
	return $out;
}
1;