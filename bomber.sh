#!/usr/bin/expect -f

# For expect debugging, uncomment the following:
# exp_internal 1

# Set Expect Timeout to 5 minutes
set timeout 300

set ACCOUNT_ALIAS "$::env(ACCOUNT_ALIAS)"
set NOT_A_DRILL "$::env(NOT_A_DRILL)"

if { $NOT_A_DRILL == "true" } {
  puts "Commencing bombing run of account: $ACCOUNT_ALIAS."
  spawn /usr/local/bin/aws-nuke -c /home/aws-nuke/nuke-config.yml --no-dry-run
} else {
  puts "Commencing bombing *dry-run* of account: $ACCOUNT_ALIAS."
  spawn /usr/local/bin/aws-nuke -c /home/aws-nuke/nuke-config.yml
}

expect "Do you want to continue? Enter account alias to continue."
expect "> "

send "$ACCOUNT_ALIAS\r"

expect {
    "Do you want to continue? Enter account alias to continue." {
      expect ">"
      send "$ACCOUNT_ALIAS\r"
      expect eof
    }
    "Provide --no-dry-run to actually destroy resources." {
      puts "Dry Run Complete!"
      exit 0;
    }
}
