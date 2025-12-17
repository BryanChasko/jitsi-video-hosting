#!/usr/bin/env perl
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use Time::HiRes qw(time);

# Generate unique subdomain for Jitsi deployment
# Format: meet.<8-char-hash>.bryanchasko.com

my $base_domain = "bryanchasko.com";
my $timestamp = time();
my $random_data = $timestamp . rand() . $$;
my $hash = substr(sha256_hex($random_data), 0, 8);

my $subdomain = "meet.$hash.$base_domain";

print "$subdomain\n";
