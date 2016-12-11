=head1 DESCRIPTION

Эта функция должна принять на вход ссылку на массив, который представляет из себя обратную польскую нотацию,
а на выходе вернуть вычисленное выражение

=cut

use 5.010;
use strict;
use warnings;
use diagnostics;
BEGIN{
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';

sub evaluate {
	my $qwe = shift;
	my @array =@$qwe;																	#создаем копию нашего массива 
	my $ref=\@array;
	while($#$ref>=1)
	{
		for(my $i = 1;$i <= $#$ref;$i++ )
		{
			if($ref->[$i] =~ /U-|U\+/)													# если в массиве U- или U+ применим его к элементу слева
			{
				$ref->[$i] = unar($ref->[$i-1],$ref->[$i]);
				splice(@$ref,$i-1,1);													# удалим ненужный элемент
				$i--;																	# обрежем копию массива
			}
			elsif($ref->[$i] =~ /([\+\-\*\/\^])/)										# если в массиве бинарный операнд применим его к 2м элементам слева
			{
				$ref->[$i] = binar($ref->[$i-2],$ref->[$i-1],$ref->[$i]);				
				splice(@$ref,$i-2,2); 													# удалим ненужные элементы
				$i-=2;																	# обрежем копию массива
				
			}
			else{}
		}
	}
	my $answer=$ref->[0];
	return $answer;
}
1;
sub binar																				# функция для вычисления бинарных операций
{
	my($x,$y,$sign) = @_;
	given($sign)
		{
			when(/-/){return $x-$y;}
			when(/\+/){return $x+$y;}
			when(/\*/){return $x*$y;}
			when(/\//){return $x/$y;}
			when(/\^/){return $x**$y;}
			default {print "erar";}
		}		
}
sub unar																				# функция для вычисления унарных операций
{
	my($y,$sign) = @_;
	given($sign)
		{
			when(/U-/){return 0-$y;}
			when(/U\+/){return $y;}
			default {print "erar";}
		}		
}

