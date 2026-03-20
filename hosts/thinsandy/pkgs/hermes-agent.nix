{
  lib,
  python312,
  fetchFromGitHub,
  fetchPypi,
  makeWrapper,
  nodejs_22,
  ripgrep,
  ffmpeg,
  git,
  src ? null,
  version ? "main",
}: let
  python = python312.override {
    packageOverrides = _final: prev: {
      sanic = prev.sanic.overridePythonAttrs (_: {
        doCheck = false;
      });

      apscheduler = prev.apscheduler.overridePythonAttrs (_: {
        doCheck = false;
      });

      python-telegram-bot = prev.python-telegram-bot.overridePythonAttrs (_: {
        doCheck = false;
      });
    };
  };

  pythonPackages = python.pkgs;

  fal-client = pythonPackages.buildPythonPackage rec {
    pname = "fal-client";
    version = "0.13.1";
    pyproject = true;

    src = fetchPypi {
      pname = "fal_client";
      inherit version;
      hash = "sha256-nhwH0KYbRSqP+0jBmd5fJUPXVG8SMPYxI3BEMSfF6Tc=";
    };

    build-system = with pythonPackages; [
      setuptools
      setuptools-scm
    ];

    dependencies = with pythonPackages; [
      httpx
      httpx-sse
      msgpack
      websockets
    ];

    doCheck = false;
    pythonImportsCheck = ["fal_client"];
  };

  honcho-ai = pythonPackages.buildPythonPackage rec {
    pname = "honcho-ai";
    version = "2.0.1";
    pyproject = true;

    src = fetchPypi {
      pname = "honcho_ai";
      inherit version;
      hash = "sha256-b97r+UVOYrxSPVeIjlA1nme6r9sh9oYh+cFOCNwAYjo=";
    };

    build-system = with pythonPackages; [
      setuptools
      wheel
    ];

    dependencies = with pythonPackages; [
      httpx
      pydantic
      typing-extensions
    ];

    doCheck = false;
    pythonImportsCheck = ["honcho"];
  };

  agent-client-protocol = pythonPackages.buildPythonPackage rec {
    pname = "agent-client-protocol";
    version = "0.8.1";
    pyproject = true;

    src = fetchPypi {
      pname = "agent_client_protocol";
      inherit version;
      hash = "sha256-G78VZjv1H2SUJZf2OOMqYoTF2pGAVdlnLTUQ6WUUPb0=";
    };

    build-system = [pythonPackages.pdm-backend];

    dependencies = with pythonPackages; [
      pydantic
    ];

    doCheck = false;
    pythonImportsCheck = ["acp"];
  };

  parallel_web = pythonPackages.buildPythonPackage rec {
    pname = "parallel-web";
    version = "0.4.2";
    format = "wheel";

    src = fetchPypi {
      pname = "parallel_web";
      inherit version format;
      dist = "py3";
      python = "py3";
      abi = "none";
      platform = "any";
      hash = "sha256-qjpKmuzAiXLFzpMDJx1JF5Azc9/03Sd9mj4w+c/1M0Y=";
    };

    propagatedBuildInputs = with pythonPackages; [
      anyio
      distro
      httpx
      pydantic
      sniffio
      typing-extensions
    ];

    doCheck = false;
    pythonImportsCheck = ["parallel"];
  };

  hermesSrc =
    if src != null
    then src
    else
      fetchFromGitHub {
        owner = "NousResearch";
        repo = "hermes-agent";
        rev = "6ebb816e5611aaf1f3f7187ba8b10e985e899c75";
        hash = "sha256-JGjusff/jGjvCCdUtl9IErBTGmpIq6BVA5Gj8mwqVYg=";
        fetchSubmodules = true;
      };
in
  pythonPackages.buildPythonApplication {
    pname = "hermes-agent";
    inherit version;
    src = hermesSrc;
    pyproject = true;

    build-system = [pythonPackages.setuptools];

    dependencies = with pythonPackages; [
      openai
      anthropic
      python-dotenv
      fire
      httpx
      rich
      tenacity
      pyyaml
      requests
      jinja2
      pydantic
      prompt-toolkit

      firecrawl-py
      fal-client
      parallel_web

      edge-tts
      faster-whisper

      litellm
      typer
      platformdirs

      pyjwt

      python-telegram-bot
      discordpy
      aiohttp

      croniter

      simple-term-menu

      elevenlabs

      sounddevice
      numpy

      ptyprocess

      honcho-ai

      mcp
      agent-client-protocol
    ];

    nativeBuildInputs = [makeWrapper];
    doCheck = false;

    # postPatch = ''
    #   if [ -f minisweagent_path.py ] && ! grep -q minisweagent_path pyproject.toml; then
    #     sed -i 's/py-modules = \[/py-modules = ["minisweagent_path", /' pyproject.toml
    #   fi

    #   if [ -d mini-swe-agent/src/minisweagent ]; then
    #     cp -r mini-swe-agent/src/minisweagent .
    #   fi
    # '';

    # postFixup = ''
    #   for bin in $out/bin/hermes $out/bin/hermes-agent $out/bin/hermes-acp; do
    #     if [ -f "$bin" ]; then
    #       wrapProgram "$bin" \
    #         --prefix PATH : ${
    #           lib.makeBinPath [ nodejs_22 ripgrep ffmpeg git ]
    #         }
    #     fi
    #   done
    # '';

    passthru = {
      upstreamSrc = hermesSrc;
    };

    meta = with lib; {
      description = "The self-improving AI agent by Nous Research";
      homepage = "https://github.com/NousResearch/hermes-agent";
      license = licenses.mit;
      mainProgram = "hermes";
      platforms = platforms.linux ++ platforms.darwin;
    };
  }
