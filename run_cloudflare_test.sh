#!/bin/bash
# This script runs the main Ruby entrypoint with the provided config file for test_cloudflare.

echo "Running Cloudflare test..."

# capture output
output=$(bundle exec ruby src/main.rb cloudflare_test/cloudflare_test_config.yml)
# echo "$output"


# Check for 'Error: 400' or 'Error: 401' in output
if echo "$output" | grep -q 'Error: 400'; then
	echo "Detected Error: 400 in output. Problem with headers on our side."
	exit 400
elif echo "$output" | grep -q 'Error: 401'; then
	echo "Detected Error: 401 in output. We need to wait for Cloudflare to register our bot."
	exit 401
elif echo "$output" | grep -q 'Error: 200'; then
	echo "Detected Error: 200 in output. Cloudflare is passing our bot."
	exit 200
else
	exit 0
fi
