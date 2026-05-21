# terminal-tools

Quick AI and translation tools accessible from the terminal.

## Setup

1. **Install dependencies**: Make sure `curl` and `jq` are installed
   ```bash
   # macOS
   brew install jq

   # Linux
   sudo apt install jq
   ```

2. **Add your OpenAI API key**:
   ```bash
   mkdir -p ~/.config/terminal-tools
   echo "sk-your-openai-api-key" > ~/.config/terminal-tools/api_key
   ```

3. **Install aliases**:
   ```bash
   ./add-aliases.sh
   source ~/.zshrc  # or ~/.bashrc
   ```

## Usage

### AI Chat (`?`)

Chat with ChatGPT (gpt-4o-mini) directly from your terminal:

```bash
? "What's 32C in Fahrenheit?"
? "Explain quantum computing in 3 sentences"
echo "Summarize TCP vs UDP" | ?
```

### Translation (`?fr-en`, `?en-fr`)

Translate text between French and English using Google Translate:

```bash
?fr-en "bonjour"        # French to English
?en-fr "hello world"    # English to French
echo "merci" | ?fr-en   # Pipe input
```
