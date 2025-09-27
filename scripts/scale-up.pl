#!/usr/bin/env perl
use strict;
use warnings;

# Basic scale-up script - needs enhancement
print "Scaling up Jitsi platform...\n";

# TODO: Add AWS CLI integration
# TODO: Add error handling
# TODO: Add logging

system("aws ecs update-service --cluster jitsi-video-platform-cluster --service jitsi-video-platform-service --desired-count 1 --profile jitsi-dev");

print "Scale-up command executed\n";