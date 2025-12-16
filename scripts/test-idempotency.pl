#!/usr/bin/env perl
use strict;
use warnings;

print "\033[34m[INFO]\033[0m Testing Power-Down Script Idempotency\n";
print "=" x 60 . "\n";

print "\033[34m[TEST 1]\033[0m First power-down execution...\n";
my $result1 = system("./power-down.pl");
my $exit1 = $? >> 8;

print "\n\033[34m[TEST 2]\033[0m Second power-down execution (should be idempotent)...\n";
my $result2 = system("./power-down.pl");
my $exit2 = $? >> 8;

print "\n\033[34m[VERIFICATION]\033[0m Running verification script...\n";
my $verify_result = system("./verify-power-down.pl");
my $verify_exit = $? >> 8;

print "\n" . "=" x 60 . "\n";
print "\033[34m[IDEMPOTENCY TEST RESULTS]\033[0m\n";

if ($exit1 == 0) {
    print "  \033[32m✓\033[0m First execution: SUCCESS\n";
} else {
    print "  \033[31m✗\033[0m First execution: FAILED (exit code: $exit1)\n";
}

if ($exit2 == 0) {
    print "  \033[32m✓\033[0m Second execution: SUCCESS\n";
} else {
    print "  \033[31m✗\033[0m Second execution: FAILED (exit code: $exit2)\n";
}

if ($verify_exit == 0) {
    print "  \033[32m✓\033[0m Verification: PASSED\n";
} else {
    print "  \033[31m✗\033[0m Verification: FAILED (exit code: $verify_exit)\n";
}

print "\n\033[34m[IDEMPOTENCY ANALYSIS]\033[0m\n";
if ($exit1 == 0 && $exit2 == 0 && $verify_exit == 0) {
    print "  \033[32m✓\033[0m IDEMPOTENCY TEST PASSED\n";
    print "  \033[34m[INFO]\033[0m Script can be safely run multiple times\n";
    print "  \033[34m[INFO]\033[0m No errors when resources already deleted\n";
    exit 0;
} else {
    print "  \033[31m✗\033[0m IDEMPOTENCY TEST FAILED\n";
    print "  \033[31m[ERROR]\033[0m Script may not handle repeated execution properly\n";
    exit 1;
}
