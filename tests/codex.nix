{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (import ../lib)
    mkCodexConfigArgFiles
    mkCodexConfigArgs
    mkConfig
    ;
  # Create a test configuration for codex with inline TOML
  testConfig = mkConfig pkgs {
    flavor = "codex";
    format = "toml-inline";
    fileName = ".mcp.toml";

    programs = {
      filesystem = {
        enable = true;
        args = [ "/test/path" ];
        env = {
          TEST_VAR = "test_value";
        };
      };
    };
  };
  testArgConfig = {
    settings = {
      mcp_oauth_callback_port = 5555;
      servers = {
        custom = {
          command = "echo";
          args = [ "custom" ];
        };
        other = {
          command = "echo";
          args = [ "other" ];
          env = {
            TEST_VAR = "test_value";
          };
        };
      };
    };
  };
  codexConfigArgFiles = mkCodexConfigArgFiles pkgs testArgConfig;
  codexConfigArgsText = pkgs.writeText "codex-config-args.txt" (
    lib.concatStringsSep "\n" (mkCodexConfigArgs pkgs testArgConfig)
  );
in
{
  test-codex =
    pkgs.runCommand "test-codex"
      {
        nativeBuildInputs = with pkgs; [
          codex
        ];
      }
      ''
        export CODEX_HOME=$(mktemp -d)
        codex -c "$(cat ${testConfig})" mcp list | grep -e filesystem > $out
      '';

  test-codex-config-args = pkgs.runCommand "test-codex-config-args" { } ''
    grep -F 'mcp_servers."custom" = {args = ["custom"], command = "echo"}' ${
      codexConfigArgFiles."mcp-server-custom"
    }
    grep -F 'mcp_servers."other" = {args = ["other"], command = "echo", env = {TEST_VAR = "test_value"}}' ${
      codexConfigArgFiles."mcp-server-other"
    }
    grep -F 'mcp_oauth_callback_port = 5555' ${codexConfigArgFiles.extra}

    grep -F -- "-c '\$(cat ${codexConfigArgFiles."mcp-server-custom"})'" ${codexConfigArgsText}
    grep -F -- "-c '\$(cat ${codexConfigArgFiles."mcp-server-other"})'" ${codexConfigArgsText}
    grep -F -- "-c '\$(cat ${codexConfigArgFiles.extra})'" ${codexConfigArgsText}

    touch $out
  '';
}
