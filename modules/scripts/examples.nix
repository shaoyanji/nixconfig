{
  config,
  pkgs,
  ...
}: {
  imports = [
    #    ./duckduck.nix
  ];
  home.packages = with pkgs; [
    (pkgs.writers.writeNuBin "example"
      {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          "${lib.makeBinPath [pkgs.hello]}"
        ];
      }
      ''
        hello
      '')
    (pkgs.writers.writeBashBin "duck" {}
      /*
      bash
      */
      ''
        # Check for required dependencies
        if ! command -v curl &>/dev/null; then
            echo "curl is required but not installed. Aborting."
            exit 1
        fi
        MODEL="claude-3-haiku-20240307"

        # Set up conversation file
        CONVERSATION_DB="$HOME/chatbot_conversation.db"
        if [[ ! -f "$CONVERSATION_DB" ]]; then
            # Create table if it doesn't exist
            ${pkgs.sqlite}/bin/sqlite3 $CONVERSATION_DB <<EOF
        CREATE TABLE conversation_history (
            id INTEGER PRIMARY KEY,
            user_input TEXT,
            chatbot_response TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        EOF
        fi

        vqd=$(curl -s -X GET https://duckduckgo.com/duckchat/v1/status -H 'x-vqd-accept: 1' -D -|awk -F': ' '/^(x-vqd-4):/ {print $2}')
        # Start conversation loop
        echo -e "Hello, I'm your friendly chatbot. How can I help you today?"
        while true; do
            # Prompt for input
            echo -e "You: \c"
            read input

            # Generate response from OpenAI API
            response=$(curl -s -X POST 'https://duckduckgo.com/duckchat/v1/chat' \
                    -H "x-vqd-4: $vqd" \
                    -H 'Content-Type: application/json' \
                    -H 'Accept: text/event-stream' \
                    -d '{
                    "model": "'"$MODEL"'",
                    "messages": [{"role": "user", "content": "'"$input"'"}]
                    }'| \
                    awk -F': ' '/^(data):/ {print $2}'| \
                    #jq -r '.message' \
                    sed -n 's/.*"message":"\([^"]*\)".*/\1/p'|\
        	    tr -d '\n'\
                    )

            # Check for errors
            if [[ -z "$response" ]]; then
                echo -e "Sorry, there was an error generating a response."
            else
                # Print response
                echo -e "Chatbot: $response"
                # echo -e "$response" > /dev/clipboard
                # md2c /dev/clipboard
                # Save conversation to SQLite database
                ${pkgs.sqlite}/bin/sqlite3 $CONVERSATION_DB "INSERT INTO conversation_history (user_input, chatbot_response) VALUES ("'$input'", "'$response'");"
            fi
        done
      '')
    (pkgs.writers.writeLuaBin "duckduck" {}
      /*
      lua
      */
      ''
        -- Handle command-line arguments
        local args = {...}
        -- Handle piped input
        --local piped_input = io.stdin:read("*a")
        --if piped_input and piped_input ~= "" then
        --  print("Received piped input:", piped_input)
        --end
        -- Your main script logic here
        -- Fetch the x-vqd-4 header
        local handle = io.popen("curl -s -X GET https://duckduckgo.com/duckchat/v1/status -H 'x-vqd-accept: 1' -D -")
        local result = handle:read("*a")
        handle:close()
        -- Extract the x-vqd-4 value
        local vqd = result:match("x%-vqd%-4: ([^\r\n]+)")
        if vqd then
            -- Use the extracted vqd in the POST request
            local request = io.popen(string.format([[
                curl -s -X POST 'https://duckduckgo.com/duckchat/v1/chat' \
                -H 'x-vqd-4: %s' \
                -H 'Content-Type: application/json' \
                -H 'Accept: text/event-stream' \
                -d '{
                    "model": "claude-3-haiku-20240307",
                    "messages": [{"role": "user", "content": "%s"}]
                }' \
                --no-buffer
            ]], vqd, args[1]))

            local response = request:read("*a")

            request:close()

        -- Parse the JSON stream and extract messages
            local messages = {}
            for line in response:gmatch("[^\r\n]+") do
                if line:match("^data:") then
                    local message = line:match('"message":"(.-)"')
                    if message then
                        message = message:gsub('\\"', '"') -- Unescape quotes
                        table.insert(messages, message)
                    end
                end
            end

            -- Concatenate and print messages
        --    print("Extracted messages:")
            print(table.concat(messages, ""))
        else

        --    print("Command output:\n" .. response)

        --else
            print("Failed to extract x-vqd-4 header")
        end
      '')
    (pkgs.writers.writeRustBin "hellorust" {}
      /*
      rust
      */
      ''
        fn main() {
            println!("hello world");
        }
      '')
    (pkgs.writers.writeBashBin "hellobash" {}
      /*
      bash
      */
      ''
        echo "hello world"
      '')
    (pkgs.writers.writeNimBin "hellonim" {}
      /*
      nim
      */
      ''
        echo "hello world"
      '')
    (pkgs.writers.writeNuBin "hellonu" {}
      /*
      nu
      */
      ''
        echo "hello world"
      '')
    (pkgs.writers.writeHaskellBin "hellohaskell" {}
      /*
      haskell
      */
      ''
        main = putStrLn "hello world"
      '')
    (pkgs.writers.writeJSBin "hellojavascript" {}
      /*
      javascript
      */
      ''
        console.log("hello world");
      '')
    (pkgs.writers.writeLuaBin "hellolua" {}
      /*
      lua
      */
      ''
        print("hello world")
      '')
    (pkgs.writers.writePython3Bin "hellopython" {}
      /*
      python
      */
      ''
        print("hello world")
      '')
  ];
  home.file = {
  };

  home.sessionVariables = {
  };
}
