#!/usr/bin/env bats

sudo apt-get install -y curl >&2

@test "strider code is present" {
	[ -d "/opt/strider" ]
}

@test "strider process is running" {
	pgrep -f "node bin/strider"
}

@test "strider responds to requests" {
	curl http://localhost:3000 | grep Strider
}
