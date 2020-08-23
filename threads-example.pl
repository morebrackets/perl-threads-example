use strict;
use threads(
	'exit' => 'threads_only', # Prevent whole script from dying if a thread dies
	# 'stack_size' => 32*4096 # Increase per-thread memory-limit
);
use Net::DNS;
my $res = Net::DNS::Resolver->new;
$res->udp_timeout(3);
$res->tcp_timeout(3);

$|++; # flush output

my $numThreads = 200; # 1x-5x number of cores on *nix. Less on windows.
my $numLookupsPerThread = 20;
my $hostlength = 3;
my @letters = split(//,'qwertyuiopasdfghjklzxcvbnm');
my $lLength = $#letters;

my $beginMain = time;
my $totalLookups = $numThreads*$numLookupsPerThread;

print "*** Main begin: $numThreads threads X $numLookupsPerThread lookups = $totalLookups total lookups\n";

# Create $numThreads threads
for my $n (1..$numThreads) {

	my $t = threads->create(sub { findip($n) });

	if (!$t) { 
		print "\nSystem says ".int(threads->list(threads::running))." is too many threads. Retrying...\n\n";
		sleep 3;
		redo;
	}
}

# Wait for threads to complete
while (int(threads->list(threads::running))) {
	sleep 1;
}

my $elapsed = time - $beginMain;
print "*** Main complete\n$totalLookups in $elapsed sec (".int($totalLookups/$elapsed)." per sec)\n";


# Threaded function
sub findip {
	my $id = shift;
	local $SIG{KILL} = sub { threads->exit; }; #### IMPORTANT
	print "* t$id: begin\n";

	for my $n (1..$numLookupsPerThread){
		my $dom = &randStr($hostlength) . '.com';
		my $ip = 'na';

		# lookup
		my $begin = time;

	    my $reply = $res->search($dom, "A");
 
		if ($reply) {
			$ip = '';
		    foreach my $rr ($reply->answer) {
		        $ip .= $rr->address, ", " if $rr->can("address");
		    }
		} else {
		    $ip = $res->errorstring;
		}


	    print "t$id\: $dom = $ip (".(time - $begin)." sec)\n";
	}

	print "t$id: complete\n";

	# Detach (signal to controller that thread work has been completed)
	threads->detach();
}

# Random string generator
sub randStr {
	my $length = shift;
	my $out = '';
	for(1..$length){
		$out .= $letters[int(rand($lLength))];
	}
	return $out;
}
