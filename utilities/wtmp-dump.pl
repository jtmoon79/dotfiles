#!/usr/bin/env perl
#
# ripped from https://www.hcidata.info/wtmp.htm (https://archive.vn/YIrl8)

use warnings;

@type=(
	"Empty",
	"Run Lvl",
	"Boot",
	"New Time",
	"Old Time",
	"Init",
	"Login",
	"Normal",
	"Term",
	"Account"
);
$recs = "";

while (<>) {
	$recs .= $_
};

foreach (split(/(.{384})/s, $recs)) {
	next if length($_) == 0;
	my ($type, $pid, $line, $inittab, $user, $host, $t1, $t2, $t3, $t4, $t5) = $_ =~/(.{4})(.{4})(.{32})(.{4})(.{32})(.{256})(.{4})(.{4})(.{4})(.{4})(.{4})/s;
	if (defined $line && $line =~ /\w/) {
		$line =~ s/\x00+//g;
		$host =~ s/\x00+//g;
		$user =~ s/\x00+//g;
		printf("%s %-8s %-12s %10s %-45s\n",
			scalar(gmtime(unpack("I4", $t3))),
			$type[unpack("I4", $type)],
			$user,
			$line,
			$host,
		)
	};
};
