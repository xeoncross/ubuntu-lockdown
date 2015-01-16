#!/bin/bash

# Install this on a CRON to run ever hour or so and update your IPTables
# with the latest spam/bot IP ranges. If Spamhaus blocks a CIDR (IP Range)
# you want to allow then create a text file called "ignore_ips" file next
# to this file and put your allowed CIDR addresses in there (one each line).

# Search for $1 in the given array ($2)
# http://stackoverflow.com/a/8574392/99923
containsElement () {
	local e
	for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
	return 1
}

# Take each piped line as an "IP ; COMMENT" entry to feed to IPTables
add_spamhaus_ip_bans() {

	# Make sure each entry isn't in our ignore_ips file
	while read ipcidr x comment; do

		if ! containsElement "$ipcidr" "${IGNOREIPS[@]}" ; then

			if [ $DEBUGMODE ]; then
				echo "iptables -A INPUT -s $ipcidr -j DROP -m comment --comment \"spamhaus $comment\""
			else
				#echo "LIVE IP: $ipcidr, Comment: $comment"
				iptables -A INPUT -s $ipcidr -j DROP -m comment --comment "spamhaus $comment" ;
			fi

		fi
	done
}

# A second argument means we only print out the new IPTables rules
DEBUGMODE=$1

# The current directory of this script
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Default an empty ignore list
IGNOREIPS=()

# @todo read in "ignore" file if exists to allow overrides
if [ -f "$DIR/ignore_ips" ]; then
	IFS=$'\n' read -d '' -r -a IGNOREIPS < "$DIR/ignore_ips"
fi

# Make sure we can download the new list or exit
# If this fails we DO NOT want to wipe the current IP bans
curl http://www.spamhaus.org/drop/drop.txt || exit 1

# Remove old bans first (by filtering out "spamhaus" entries)
iptables-save | grep -v "spamhaus" | iptables-restore

# Base DROP (Don't Route Or Peer)
cat drop.txt | grep -o '^[0-9/\.]\+ ; SBL[0-9]\+' | add_spamhaus_ip_bans

# Now try to fetch the Extend DROP (Don't Route Or Peer)
curl http://www.spamhaus.org/drop/edrop.txt || exit 1

# Add it to IPTables also
cat edrop.txt | grep -o '^[0-9/\.]\+ ; SBL[0-9]\+' | add_spamhaus_ip_bans

echo "Updated IPTables"