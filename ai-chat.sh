#!/bin/bash

API_KEY_FILE="$HOME/.config/terminal-tools/api_key"
API_ENDPOINT="https://api.reka.ai/v1/chat"

# Acquire query (args or stdin)
if [ $# -eq 0 ]; then
    # If data is being piped in, read from stdin
    if [ ! -t 0 ]; then
        QUERY="$(cat)"
    else
        echo "Error: No query provided"
        echo "Usage: reka-chat.sh <your question>"
        echo "Examples:"
        echo "  reka-chat.sh What's 32C in F?"
        echo "  reka-chat.sh Convert 15 miles to km"
        echo "  echo 'Summarize TCP vs UDP' | reka-chat.sh"
        exit 1
    fi
else
    QUERY="$*"
fi

if [ ! -f "$API_KEY_FILE" ]; then
    echo "Error: API key file not found at $API_KEY_FILE"
    echo "Please create the file and add your Reka API key"
    exit 1
fi

API_KEY=$(cat "$API_KEY_FILE" | tr -d '[:space:]')

if [ -z "$API_KEY" ]; then
    echo "Error: API key file is empty"
    echo "Please add your Reka API key to $API_KEY_FILE"
    exit 1
fi

# Make API request
RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
     -H "X-Api-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d "{
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": $(echo "$QUERY" | jq -R -s .)
    }
  ],
  \"model\": \"reka-core\",
  \"stream\": false
}")

# Check if curl succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to API"
    exit 1
fi

# Extract and display the response content
echo "$RESPONSE" | jq -r '.responses[0].message.content // .error // "Error: Unexpected response format"'

# Check if jq failed (not installed)
if [ $? -ne 0 ]; then
    echo ""
    echo "Note: Install 'jq' for better formatted output: brew install jq"
    echo ""
    echo "Raw response:"
    echo "$RESPONSE"
fi
