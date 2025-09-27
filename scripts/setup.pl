#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use File::Spec;
use Term::ANSIColor qw(colored);

my $SCRIPT_DIR = dirname(File::Spec->rel2abs(__FILE__));

print colored("Setting up Jitsi Platform operational scripts...", 'blue') . "\n";

# Make Perl scripts executable
print "Making Perl scripts executable...\n";
my @perl_scripts = glob("$SCRIPT_DIR/*.pl");
for my $script (@perl_scripts) {
    chmod 0755, $script;
}

# Verify scripts are executable
print "Verifying script permissions...\n";
my @scripts = qw(test-platform.pl scale-up.pl scale-down.pl check-health.pl status.pl);
for my $script (@scripts) {
    my $script_path = "$SCRIPT_DIR/$script";
    if (-x $script_path) {
        print "  ✓ $script\n";
    } else {
        print "  ✗ $script (failed to make executable)\n";
        exit 1;
    }
}

print colored("Setup completed successfully!", 'green') . "\n";
print "\nAvailable scripts:\n";
print "  ./test-platform.pl  - Complete testing workflow\n";
print "  ./scale-up.pl       - Scale service up\n";
print "  ./scale-down.pl     - Scale service down\n";
print "  ./check-health.pl   - Health verification\n";
print "  ./status.pl         - Platform status\n";
print "\nRun './test-platform.pl' to start comprehensive testing.\n";