#!/usr/bin/expect -f
# bomber.sh

set ACCOUNT_ALIAS [lindex $argv 0]

spawn /usr/local/bin/aws-nuke -c /home/aws-nuke/nuke-config.yml

expect "Do you want to continue? Enter account alias to continue."
expect "> "

send "$::env(ACCOUNT_ALIAS)\r"

expect {
    "> " { send -- "$::env(ACCOUNT_ALIAS)\r" }
    "Would delete these resources. Provide --no-dry-run to actually destroy resources." { puts "Dry Run Complete!"; exit 0; }
}
