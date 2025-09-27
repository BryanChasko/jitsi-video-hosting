#!/usr/bin/env perl
use strict;
use warnings;

# Basic scale-down script - needs enhancement
print "Scaling down Jitsi platform...\n";

# TODO: Add AWS CLI integration
# TODO: Add error handling  
# TODO: Add logging

system("aws ecs update-service --cluster jitsi-video-platform-cluster --service jitsi-video-platform-service --desired-count 0 --profile jitsi-dev");

print "Scale-down command executed\n";