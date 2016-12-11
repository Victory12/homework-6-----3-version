package Local::TCP::Calc::Server::Queue;

use strict;
use warnings;
use Fcntl ':flock';
use Mouse;
use Local::TCP::Calc;
use DDP;
use Math::Random::Secure qw(irand);

has f_handle       => (is => 'rw', isa => 'FileHandle');
has queue_filename => (is => 'ro', isa => 'Str', default => '/tmp/local_queue.log');
has max_task       => (is => 'rw', isa => 'Int', default => 0);

my @array_id;

sub init {
	my $self = shift;
	open($self->{f_handle}, ">", "$self->{queue_filename}");
	close $self->{f_handle};
}
sub open_queue {
	my $self = shift;
	my $queue_struct;	
	if ( open( $self->{f_handle}, "+<", "$self->{queue_filename}" ) ) {
	 	flock($self->{f_handle}, LOCK_EX) or die print "cant flock";
		while (defined ( my $line = $self->{f_handle}->getline() ))
		{
			chomp($line);
			my @array;
			my $hash;		
			@array = split(":", $line);
			for my $elem (@array){
				my ($k,$v) = split("=>",$elem);
				$hash->{$k} = $v;
			}
			push @$queue_struct, $hash;	
		}
		return $queue_struct;
	}
	else{
		print "cant open $self->{queue_filename}\n";
		return undef;
	}
}
sub close_queue {
	my $self = shift;
	my $queue_struct = shift;
	seek( $self->{f_handle}, 0, 0 );
	my $qwe = truncate($self->{queue_filename}, 0);
	flock($self->{f_handle}, LOCK_EX) or die print "cant flock";
	for my $elem (@$queue_struct){
		while ( my ($k,$v) = each %$elem) {
	  		$self->{f_handle}->print ("$k=>$v:");	
		}
		$self->{f_handle}->print ("\n");
	}
	flock($self->{f_handle}, LOCK_UN) or do {close $self->{f_handle}; print "Cannot unlock file\n"};
	close $self->{f_handle};
}
sub to_done {
	my $self = shift;
	my $id = shift;
	my $queue_struct = $self->open_queue;
	for my $elem (@$queue_struct){
		if( $elem->{id} == $id ){
			$elem->{status} = Local::TCP::Calc::STATUS_DONE();
			seek( $self->{f_handle}, 0, 0 );
			my $qwe = truncate($self->{queue_filename}, 0);
			$self->close_queue ( $queue_struct );	
			return;
		}
	}
	$self->close_queue ( $queue_struct );	
}
sub get_object{
	my $queue = shift;
	my $queue_struct = $queue->open_queue();
	for my $elem (@$queue_struct){
		next unless defined $elem->{status};
		if( $elem->{status} == Local::TCP::Calc::STATUS_NEW ){
			$elem->{status} = Local::TCP::Calc::STATUS_WORK;
			$queue->close_queue ( $queue_struct );
			return $elem;
		}
	}
	$queue->close_queue ( $queue_struct );
	return undef;
}
sub get_status {
	my $queue = shift;
	my $id = shift;
	my $task;
	my $queue_struct = $queue->open_queue;
	$queue->close_queue ( $queue_struct );
	for my $elem (@$queue_struct){
		if( $elem->{id} == $id ){
			if ( $elem->{status} == Local::TCP::Calc::STATUS_DONE() or $elem->{status} == Local::TCP::Calc::STATUS_ERROR() ) {
				my $task = $queue->get($elem->{file});
				return $task;
			}
			else{
				return $elem->{status};
			}			
		}
	}
	return "no such id ";
}
sub delete {
	my $self = shift;
	my $id = shift;
	my $iterator = 0;
	my $queue_struct = $self->open_queue;
	for my $elem (@$queue_struct){
		if( $elem->{id} == $id ){
			splice (@$queue_struct, $iterator, 1);
		}
		$iterator++;
	}
	$self->close_queue ( $queue_struct );
	$self->delete_id($id);
}

sub get {
	my $self = shift;
	my $file = shift;
	my @tasks;
	my @kek;
	open (my $fh,"<", $file);
	while (<$fh>)
	{
		chomp $_;
		push @tasks, $_;
	}
	my $qwe = truncate($file, 0); 
	close $fh;
	return \@tasks;
}
sub add {
	
	my $queue = shift;
	my $message = shift;  
	my $max_queue_task = shift;
	my $client= shift;
	my $queue_struct;
	$queue_struct = $queue->open_queue;
	if ( $#$queue_struct+1 < $max_queue_task ){	
		my $id = $queue->get_id;
		open (my $fh, ">", $id);
		for my $elem (@$message){  
			print $fh $elem."\n";
		}
		close $fh;
		my $hash = {id => $id, status => Local::TCP::Calc::STATUS_NEW, file => $id};
		unless ( defined $queue_struct->[0]->{id} ){
			$queue_struct->[0] = $hash;
		}
		else{
			push  @$queue_struct, $hash if defined $hash->{id};
		}
		$queue->close_queue($queue_struct);	
		return $id;
	}
	else{
		$queue->close_queue($queue_struct);
		return 0;
	}
}
sub delete_id{
	my $self = shift;
	my $id = shift;
	@array_id = grep { $_ != $id } @array_id;
}
sub get_id{
	my $queue = shift;
	my $flag = 1;
	my $id;
	do{
		$id = irand(1000);
		for my $elem ( @array_id ){
			if ($elem == $id ){
				$flag = 0;
			}
		}
	}while ($flag != 1);
	push @array_id, $id;
	return $id;
}
no Mouse;
__PACKAGE__->meta->make_immutable();

1;