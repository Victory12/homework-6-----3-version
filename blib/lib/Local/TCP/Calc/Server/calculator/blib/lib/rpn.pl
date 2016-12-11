=head1 DESCRIPTION

Эта функция должна принять на вход арифметическое выражение,
а на выходе дать ссылку на массив, содержащий обратную польскую нотацию
Один элемент массива - это число или арифметическая операция
В случае ошибки функция должна вызывать die с сообщением об ошибке

=cut

use 5.010;
use strict;
use warnings;
use diagnostics;
use DDP;
BEGIN{
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';
use FindBin;
require "$FindBin::Bin/../lib/tokenize.pl";

sub rpn {
	my $expr = shift;
	my $source = tokenize($expr);
	my @symbol,my @stack;
	for my $elem (@{$source}){	
		my $sign;
		my $i;		
		given($elem){
			when(/\(/)	{push( @symbol,$elem);}
			when(/\)/)	{						
							do{							
								$sign=pop(@symbol);
								push(@stack,$sign);	
							}until($sign=~/\(/);	
							pop(@stack);
						}
			when(/\d/)	{
							push( @stack,$elem);
							for(@stack){
								chomp($_);						
							}
						}
			when(/(?:(U\+)|(U\-)|(\*)|(\/)|(\^)|(\%)|(\()|(\))|(\-)|(\+))/){									
							$sign=pop(@symbol);
							if  (defined $sign){
								my $pElem =priority($elem);											
								my $psign =priority($sign);
								if($pElem <= $psign)
								{	
									if(($pElem == $psign)&&($pElem ==4))
									{
										push(@symbol,$sign);					
										push(@symbol,$elem);
									}						
									else
									{								
										{
											do{
												push(@stack,$sign);
												$sign=pop(@symbol);
												if  (!defined $sign)
													{last;}												
												$psign = priority($sign);
											}while ($pElem <= $psign);
										}
										push(@symbol,$sign);					
										push(@symbol,$elem);
									}
								}
								else{
									push(@symbol,$sign);
									push(@symbol,$elem);
								}								
							}
							else{
								push(@symbol,$elem);
							}
						}			
			default{print ".";}		
		}
	}
	for my $stackelem (@stack){
		chomp($stackelem);
	}
	my $k=pop(@symbol);
	while (defined  $k){		
		push(@stack,$k);
		$k=pop(@symbol);
	}	
	return \@stack;
}
1;
sub priority{
	my($x) = @_;
	return $x =~ /^\+/ || $x =~ /^\-/ ? 1 : $x =~ /\*/ || $x =~ /\// || $x =~ /\%/ ? 2:$x =~ /U\+/ || $x =~ /U\-/ || $x =~ /\^/? 4:-1;		
}

	
