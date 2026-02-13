#!/bin/bash
# This script runs the main Ruby entrypoint with the provided config file for test_cloudflare.

echo "Running Cloudflare test..."

# Check if CLOUDFLARE_PRIVATE_KEY environment variable is set
if [ -z "$CLOUDFLARE_PRIVATE_KEY" ]; then
  echo "ERROR: CLOUDFLARE_PRIVATE_KEY environment variable is not set."
  echo "Usage: CLOUDFLARE_PRIVATE_KEY=\$(cat private-key.pem) ./run_cloudflare_test.sh"
  exit 1
fi

# Inject private key into config file
cat > cloudflare_test/cloudflare_test_config.yml << EOF
mode: "fetch"
page_url: https://crawltest.com/cdn-cgi/web-bot-auth
headless: false
cloudflare_private_key: |
$(echo "$CLOUDFLARE_PRIVATE_KEY" | sed 's/^/  /')
key_directory_url: "https://artsdata.ca/.well-known/http-message-signatures-directory"
EOF


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
