package Local::TCP::Calc::Server::Worker;

use Fcntl qw(:flock SEEK_END);
use strict;
use warnings;
use Mouse;
use DDP;
our $children;
use POSIX ":sys_wait_h";
use POSIX;
has cur_task_id => (is => 'ro', isa => 'Int', required => 1);
has forks       => (is => 'rw', isa => 'HashRef', default => sub {return {}});
has calc_ref    => (is => 'ro', isa => 'CodeRef', required => 1);
has max_forks   => (is => 'ro', isa => 'Int', required => 1);
has file => (is => 'ro', isa => 'Int', required => 1);
has status => (is => 'ro', isa => 'Int', required => 1);

sub write_err {
	my $self = shift;
	my $error = shift;
	open (my $fh,">",$self->{file});

	flock($fh, LOCK_EX) or do {close $fh; print "Cannot lock $fh\n";return undef};
	print $fh $error."\n";
	flock($fh, LOCK_UN) or do {close $fh; print "Cannot unlock $fh\n"};

	close $fh;
}

sub write_res {
	my $self = shift;
	my $small_task = shift;

	open (my $fh,">>",$self->{file});

	flock($fh, LOCK_EX) or do {close $fh; print "Cannot lock $fh\n";return undef};
	print $fh $small_task."\n" unless $small_task eq "";
	flock($fh, LOCK_UN) or do {close $fh; print "Cannot unlock $fh\n"};

	close $fh;
}

sub REAPER{
	if ($? != 0) {
		my $exit_status = $? >> 8;
		my $signal_num = $? & 127;
		my $qwe = "chld  $signal_num exit with status $exit_status\n";
		p $qwe; 
		for my $chld (keys %$children) {
			kill 9,$chld;
		}
	}  
}
sub start{
	my $worker = shift; 
	my $queue = shift;	
	my $task = $queue->get($worker->{file});
	my $iterator = 0;

	my $a = ( $#$task+1 )/$worker->{max_forks};
	my $step = ceil ($a);
	while ( $iterator < $worker->{max_forks} and $#$task != -1 ) {
		$iterator++;
		my @small_task = splice (@$task, 0, $step);
		if (my $pid = fork) { 
				
				$children->{$pid}=1;
				$SIG{CHLD} = \&REAPER;
				waitpid($pid, 0);
							
			} 
		else {
		    die "cannot fork: $!" unless defined $pid; 
		    my $func = $worker->{calc_ref};
		    for my $elem (@small_task){
			    my $result = &$func ( $elem );
			    unless ( defined $result ){
			    	$worker->write_err( $result ); 
			    	die $result;
			    }
			   	$worker->write_res( $result );  
			}	
			exit(0);		
		}
	}

			
	

}
no Mouse;
__PACKAGE__->meta->make_immutable();

1;
