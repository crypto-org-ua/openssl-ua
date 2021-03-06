#! /usr/bin/perl

use strict;
use warnings;

use File::Compare qw/compare_text/;
use File::Copy;
use lib 'testlib';
use OpenSSL::Test qw/:DEFAULT top_file/;

my %conversionforms = (
    # Default conversion forms.  Other series may be added with
    # specific test types as key.
    "*"		=> [ "d", "p" ],
    );
sub tconversion {
    my $testtype = shift;
    my $t = shift;
    my @conversionforms = 
	defined($conversionforms{$testtype}) ?
	@{$conversionforms{$testtype}} :
	@{$conversionforms{"*"}};
    my @openssl_args = @_;
    if (!@openssl_args) { @openssl_args = ($testtype); }

    my $n = scalar @conversionforms;
    my $totaltests =
	1			# for initializing
	+ $n			# initial conversions from p to all forms (A)
	+ $n*$n			# conversion from result of A to all forms (B)
	+ 1			# comparing original test file to p form of A
	+ $n*($n-1);		# comparing first conversion to each fom in A with B
    $totaltests-- if ($testtype eq "p7d"); # no comparison of original test file
    plan tests => $totaltests;

    my @cmd = ("openssl", @openssl_args);

    my $init;
    if (scalar @openssl_args > 0 && $openssl_args[0] eq "pkey") {
	$init = ok(run(app([@cmd, "-in", $t, "-out", "$testtype-fff.p"])),
		   'initializing');
    } else {
	$init = ok(copy($t, "$testtype-fff.p"), 'initializing');
    }
    if (!$init) {
	diag("Trying to copy $t to $testtype-fff.p : $!");
    }

  SKIP: {
      skip "Not initialized, skipping...", 22 unless $init;

      foreach my $to (@conversionforms) {
	  ok(run(app([@cmd,
		      "-in", "$testtype-fff.p",
		      "-inform", "p",
		      "-outform", $to],
		     stdout => "$testtype-f.$to")), "p -> $to");
      }

      foreach my $to (@conversionforms) {
	  foreach my $from (@conversionforms) {
	      ok(run(app([@cmd,
			  "-in", "$testtype-f.$from",
			  "-inform", $from,
			  "-outform", $to],
			 stdout => "$testtype-ff.$from$to")), "$from -> $to");
	  }
      }

      if ($testtype ne "p7d") {
	  is(compare_text("$testtype-fff.p", "$testtype-f.p"), 0,
	     'comparing orig to p');
      }

      foreach my $to (@conversionforms) {
	  next if $to eq "d";
	  foreach my $from (@conversionforms) {
	      is(compare_text("$testtype-f.$to", "$testtype-ff.$from$to"), 0,
		 "comparing $to to $from$to");
	  }
      }
    }
    unlink glob "$testtype-f.*";
    unlink glob "$testtype-ff.*";
    unlink glob "$testtype-fff.*";
}

1;
