#!/usr/bin/env bats

sudo apt-get install -y curl >/dev/null

@test "admin login" {
	curl -X POST -c test.cookies -b test.cookies --data-urlencode "email=test@example.com" --data-urlencode "password=passw0rd" http://localhost:8080/login
	curl -X GET -c test.cookies -b test.cookies http://localhost:8080/ | grep "Logged in as"
}
