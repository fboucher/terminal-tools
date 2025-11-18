#!/bin/bash


API_KEY_FILE="$HOME/.config/reka/api_key"
API_ENDPOINT="https://api.reka.ai/v1/transcription_or_translation"


AUDIO_URL=""
TARGET_LANGUAGE="english"
IS_TRANSLATE="false"
RETURN_AUDIO="false"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            AUDIO_URL="$2"
            shift 2
            ;;
        -l|--language)
            TARGET_LANGUAGE="$2"
            shift 2
            ;;
        -t|--translate)
            IS_TRANSLATE="$2"
            shift 2
            ;;
        -a|--audio)
            RETURN_AUDIO="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Usage: reka-translate.sh -f|--file <AUDIO_URL> [-l|--language <LANGUAGE>] [-t|--translate <true|false>] [-a|--audio <true|false>]"
            exit 1
            ;;
    esac
done

# Check if audio URL is provided
if [ -z "$AUDIO_URL" ]; then
    echo "Error: No audio file provided"
    echo "Usage: reka-translate.sh -f|--file <AUDIO_FILE_OR_URL> [-l|--language <LANGUAGE>] [-t|--translate <true|false>] [-a|--audio <true|false>]"
    echo ""
    echo "Options:"
    echo "  -f, --file        Local audio file path, URL, or data URI (required)"
    echo "  -l, --language    Target language (default: english)"
    echo "                    Supported: french, spanish, japanese, chinese, korean, italian, portuguese, german"
    echo "  -t, --translate   true for translation, false for transcription (default: false)"
    echo "  -a, --audio       true to return translated audio (default: false, only with -t true)"
    echo ""
    echo "Examples:"
    echo "  reka-translate.sh -f \"audio.mp3\""
    echo "  reka-translate.sh -f \"~/audio.wav\" --translate true --language french"
    echo "  reka-translate.sh --file \"https://example.com/audio.mp3\" --translate true --language french"
    echo "  reka-translate.sh -f \"audio.mp3\" -t true -l spanish -a true"
    exit 1
fi

# Convert local file to data URI if needed
if [[ ! "$AUDIO_URL" =~ ^https?:// ]] && [[ ! "$AUDIO_URL" =~ ^data: ]]; then
    # Expand tilde to home directory
    AUDIO_FILE="${AUDIO_URL/#\~/$HOME}"
    
    # Check if file exists
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "Error: Audio file not found: $AUDIO_FILE"
        exit 1
    fi
    
    # Check if file is not WAV and needs conversion
    FILE_EXT="${AUDIO_FILE##*.}"
    if [[ "$FILE_EXT" != "wav" ]]; then
        echo "File is not WAV format, checking for ffmpeg..." >&2
        
        if ! command -v ffmpeg &> /dev/null; then
            echo "Error: ffmpeg is required to convert $FILE_EXT files to WAV"
            echo "Please install ffmpeg: brew install ffmpeg"
            exit 1
        fi
        
        # Create WAV file in same directory as original
        AUDIO_DIR=$(dirname "$AUDIO_FILE")
        AUDIO_BASE=$(basename "$AUDIO_FILE" ".$FILE_EXT")
        CONVERTED_WAV="${AUDIO_DIR}/${AUDIO_BASE}_tmp.wav"
        
        echo "Converting $FILE_EXT to WAV..." >&2
        ffmpeg -i "$AUDIO_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 -write_bext 0 -fflags +bitexact -map_metadata -1 "$CONVERTED_WAV" -y 2>&1 | grep -E "(Duration:|Stream|error|Error)" >&2
        
        if [ $? -ne 0 ] || [ ! -f "$CONVERTED_WAV" ]; then
            echo "Error: Failed to convert audio file to WAV"
            exit 1
        fi
        
        # Use the converted file
        AUDIO_FILE="$CONVERTED_WAV"
        FILE_EXT="wav"
        echo "Conversion complete: $CONVERTED_WAV" >&2
    fi
    
    # Detect MIME type based on file extension
    case "$FILE_EXT" in
        mp3)
            MIME_TYPE="audio/mpeg"
            ;;
        wav)
            MIME_TYPE="audio/wav"
            ;;
        ogg)
            MIME_TYPE="audio/ogg"
            ;;
        flac)
            MIME_TYPE="audio/flac"
            ;;
        m4a)
            MIME_TYPE="audio/mp4"
            ;;
        *)
            MIME_TYPE="application/octet-stream"
            ;;
    esac
    
    echo "Converting local file to base64..." >&2
    FILE_SIZE=$(wc -c < "$AUDIO_FILE" | tr -d ' ')
    echo "File size: $FILE_SIZE bytes" >&2
    BASE64_DATA=$(base64 -i "$AUDIO_FILE")
    BASE64_LEN=${#BASE64_DATA}
    echo "Base64 length: $BASE64_LEN characters" >&2
    AUDIO_URL="data:${MIME_TYPE};base64,${BASE64_DATA}"
    AUDIO_URL_LEN=${#AUDIO_URL}
    echo "Data URI length: $AUDIO_URL_LEN characters" >&2
fi

# Validate target language
VALID_LANGUAGES=("english" "french" "spanish" "japanese" "chinese" "korean" "italian" "portuguese" "german")
if [[ ! " ${VALID_LANGUAGES[@]} " =~ " ${TARGET_LANGUAGE} " ]]; then
    echo "Error: Invalid target language: $TARGET_LANGUAGE"
    echo "Supported languages: ${VALID_LANGUAGES[*]}"
    exit 1
fi

# Check if API key file exists
if [ ! -f "$API_KEY_FILE" ]; then
    echo "Error: API key file not found at $API_KEY_FILE"
    echo "Please create the file and add your Reka API key"
    echo ""
    echo "You can do this by running:"
    echo "  mkdir -p ~/.config/reka"
    echo "  echo 'your-api-key-here' > ~/.config/reka/api_key"
    echo "  chmod 600 ~/.config/reka/api_key"
    exit 1
fi

# Check file permissions (warn if too open)
if [ "$(uname)" = "Darwin" ] || [ "$(uname)" = "Linux" ]; then
    FILE_PERMS=$(stat -f "%Lp" "$API_KEY_FILE" 2>/dev/null || stat -c "%a" "$API_KEY_FILE" 2>/dev/null)
    if [ "$FILE_PERMS" != "600" ] && [ "$FILE_PERMS" != "400" ]; then
        echo "Warning: API key file has insecure permissions ($FILE_PERMS)"
        echo "Consider running: chmod 600 $API_KEY_FILE"
        echo ""
    fi
fi

# Read API key
API_KEY=$(cat "$API_KEY_FILE" | tr -d '[:space:]')

# Validate API key is not empty
if [ -z "$API_KEY" ]; then
    echo "Error: API key file is empty"
    echo "Please add your Reka API key to $API_KEY_FILE"
    exit 1
fi

# Create JSON payload using a temporary file
TEMP_JSON=$(mktemp)
trap "rm -f $TEMP_JSON" EXIT

cat > "$TEMP_JSON" <<EOF
{
  "audio_url": $(echo "$AUDIO_URL" | jq -R -s .),
  "sampling_rate": 16000,
  "temperature": 0,
  "max_tokens": 1024,
  "target_language": "$TARGET_LANGUAGE",
  "is_translate": $IS_TRANSLATE,
  "return_translation_audio": $RETURN_AUDIO
}
EOF

PAYLOAD_SIZE=$(wc -c < "$TEMP_JSON" | tr -d ' ')
echo "Request payload size: $PAYLOAD_SIZE bytes" >&2

# Verify the audio_url in the JSON is complete
AUDIO_URL_IN_JSON=$(jq -r '.audio_url' "$TEMP_JSON")
AUDIO_URL_IN_JSON_LEN=${#AUDIO_URL_IN_JSON}
echo "Audio URL in JSON length: $AUDIO_URL_IN_JSON_LEN characters" >&2

echo "Sending request to API..." >&2

# Make API request
RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
     -H "X-Api-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d @"$TEMP_JSON")

# Check if curl succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to API"
    exit 1
fi

# Extract and display the response content
if command -v jq &> /dev/null; then
    # Debug: show raw response if it's short enough
    RESPONSE_LEN=${#RESPONSE}
    echo "Response length: $RESPONSE_LEN characters" >&2
    
    if [ $RESPONSE_LEN -lt 1000 ]; then
        echo "Raw response:" >&2
        echo "$RESPONSE" | jq . >&2
    fi
    
    # Check if response has error
    ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
    if [ -n "$ERROR" ]; then
        echo "Error: $ERROR"
        exit 1
    fi
    
    # Display transcription/translation text (check both possible fields)
    TEXT=$(echo "$RESPONSE" | jq -r '.transcript // .results[0].text // .text // empty')
    if [ -n "$TEXT" ] && [ "$TEXT" != " " ]; then
        echo "$TEXT"
    else
        echo "Warning: No text found in response" >&2
    fi
    
    # If audio was requested, display audio URL or data
    if [ "$RETURN_AUDIO" = "true" ]; then
        AUDIO=$(echo "$RESPONSE" | jq -r '.results[0].audio_url // .audio_url // .audio_data // empty')
        if [ -n "$AUDIO" ]; then
            echo ""
            echo "Audio: $AUDIO"
        fi
    fi
    
    # If nothing was extracted, show raw response
    if [ -z "$TEXT" ]; then
        echo "Response:"
        echo "$RESPONSE" | jq .
    fi
else
    # jq not installed, show raw response
    echo "$RESPONSE"
    echo ""
    echo "Note: Install 'jq' for better formatted output: brew install jq"
fi
