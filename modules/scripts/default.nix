{ config, pkgs, ... }:

{
  imports = [
        #    ./duckduck.nix
  ];
  home.packages = with pkgs;[
    (pkgs.writers.writeLuaBin "duckduck" {} /*lua*/ ''
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
    (pkgs.writers.writeRustBin "hellorust" {} /*rust*/ ''
        fn main() {
            println!("hello world");
        }
    '')
    (pkgs.writers.writeBashBin "hellobash" {} /*bash*/ ''
        echo "hello world"
    '')
    (pkgs.writers.writeNimBin "hellonim" {} /*nim*/ ''
        echo "hello world"
    '')
    (pkgs.writers.writeNuBin "hellonu" {} /*nu*/ ''
        echo "hello world"
    '')
    (pkgs.writers.writeHaskellBin "hellohaskell" {} /*haskell*/ ''
        main = putStrLn "hello world"
    '')
    (pkgs.writers.writeJSBin "hellojavascript" {} /*javascript*/ ''
        console.log("hello world");
    '')
    (pkgs.writers.writeLuaBin "hellolua" {} /*lua*/ ''
        print("hello world")
    '')
    (pkgs.writers.writePython3Bin "hellopython" {} /*python*/ ''
        print("hello world")
    '')
  ];
  home.file = {
  };
  
  home.sessionVariables = {
  };

}
