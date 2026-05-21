#!/bin/bash

# Determine source and target language from script name
SCRIPT_NAME=$(basename "$0")
if [[ "$SCRIPT_NAME" == *"fr-en"* ]]; then
    SL="fr"
    TL="en"
elif [[ "$SCRIPT_NAME" == *"en-fr"* ]]; then
    SL="en"
    TL="fr"
else
    echo "Error: Script name must contain 'fr-en' or 'en-fr'"
    echo "Usage: translate-fr-en.sh <text> or translate-en-fr.sh <text>"
    exit 1
fi

# Acquire query (args or stdin)
if [ $# -eq 0 ]; then
    if [ ! -t 0 ]; then
        QUERY="$(cat)"
    else
        echo "Error: No text provided"
        echo "Usage: $0 <text to translate>"
        echo "Examples:"
        echo "  $0 arbre"
        echo "  echo 'hello world' | $0"
        exit 1
    fi
else
    QUERY="$*"
fi

# URL-encode the query
ENCODED_QUERY=$(echo "$QUERY" | jq -s -R -r @uri)

# Google Translate API endpoint (unofficial, no auth required)
API_URL="https://translate.googleapis.com/translate_a/single?client=gtx&sl=$SL&tl=$TL&dt=t&q=$ENCODED_QUERY"

# Make request
RESPONSE=$(curl -s "$API_URL")

# Check if curl succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to Google Translate API"
    exit 1
fi

# Parse and display the translation
TRANSLATION=$(echo "$RESPONSE" | jq -r '.[0][0][0]')

if [ -z "$TRANSLATION" ] || [ "$TRANSLATION" = "null" ]; then
    echo "Error: No translation found"
    echo "Raw response: $RESPONSE"
    exit 1
fi

echo "$TRANSLATION"
