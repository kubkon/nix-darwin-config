{
  pkgs,
  pkgs-stable,
  lib,
  whois,
  ...
}:
let
  # Signing uses whichever YubiKey is plugged in: yubikey-agent only lists the
  # PIV key of the connected device, so no public key lives in this config.
  # Matches the socket of Home Manager's services.yubikey-agent on macOS.
  yubikeyAgentSock = "/tmp/yubikey-agent.sock";

  # git: prints the agent's current key for gpg.ssh.defaultKeyCommand.
  yubikeySigningKey = pkgs.writeShellApplication {
    name = "yubikey-signing-key";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      export SSH_AUTH_SOCK=${yubikeyAgentSock}
      if ! keys=$(ssh-add -L); then
        echo "yubikey-agent has no key; is a YubiKey plugged in?" >&2
        exit 1
      fi
      printf 'key::%s\n' "''${keys%%$'\n'*}"
    '';
  };

  # jj: it requires signing.key, so it gets a placeholder and this ssh-keygen
  # wrapper replaces `-f <key>` on `-Y sign` with the agent's current key.
  # Every other invocation (verify, find-principals, ...) passes through.
  yubikeySshKeygen = pkgs.writeShellApplication {
    name = "yubikey-ssh-keygen";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      export SSH_AUTH_SOCK=${yubikeyAgentSock}
      args=("$@")
      sign=0
      for ((i = 0; i + 1 < ''${#args[@]}; i++)); do
        [ "''${args[i]}" = -Y ] && [ "''${args[i + 1]}" = sign ] && sign=1
      done
      if [ "$sign" -eq 0 ]; then
        exec ssh-keygen "$@"
      fi

      keyfile=$(mktemp)
      trap 'rm -f "$keyfile"' EXIT
      ${lib.getExe yubikeySigningKey} | sed 's/^key:://' >"$keyfile"
      for ((i = 0; i + 1 < ''${#args[@]}; i++)); do
        [ "''${args[i]}" = -f ] && args[i + 1]=$keyfile
      done
      ssh-keygen "''${args[@]}"
    '';
  };
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.kubkon = {
      home.username = "${whois.username}";
      home.stateVersion = "24.11";
      home.sessionPath = [
        "/Users/${whois.username}/.local/bin"
        "/Users/${whois.username}/go/bin"
      ]
      ++ lib.optionals ("${whois.systemName}" == "kyoraku") [
        "${pkgs.darwin.xcode_16_4}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
      ];

      programs.gpg.enable = true;
      services.gpg-agent = {
        enable = true;
        enableFishIntegration = true;
        # Also yubikey-agent's PIN prompt: it reads pinentry-program from
        # gpg-agent.conf, and as a launchd agent it has no terminal to use.
        pinentry.package = pkgs.pinentry_mac;
      };

      # PIV key on the YubiKey for SSH logins and SSH commit signing. The agent
      # asks for the PIN once and keeps it until the YubiKey is unplugged.
      services.yubikey-agent.enable = true;

      programs.direnv.enable = true;
      programs.direnv.nix-direnv.enable = true;

      programs.fish = {
        enable = true;
        plugins = [
          {
            name = "grc";
            src = pkgs.fishPlugins.grc.src;
          }
          {
            name = "fzf-fish";
            src = pkgs.fishPlugins.fzf-fish.src;
          }
          {
            name = "hydro";
            src = pkgs.fishPlugins.hydro.src;
          }
        ];
      };

      programs.ssh = {
        enable = true;
        # GUI apps get SSH_AUTH_SOCK from launchd (Apple's agent), not from the
        # shell, so point ssh itself at yubikey-agent too.
        matchBlocks."*".identityAgent = yubikeyAgentSock;
      };

      programs.git = {
        enable = true;
        ignores = [ ".swp" ];
        settings = {
          user = {
            email = "${whois.email}";
            name = "${whois.name}";

          };
        };
        extraConfig =
          (
            if builtins.hasAttr "gpg" whois.commitSigner then
              {
                gpg.format = "openpgp";
                user.signingKey = whois.commitSigner.gpg.signingKey;
              }
            else
              {
                gpg.format = "ssh";
                gpg.ssh.allowedSignersFile = whois.commitSigner.ssh.allowedSignersFile;
                gpg.ssh.defaultKeyCommand = lib.getExe yubikeySigningKey;
              }
          )
          // {
            commit.gpgsign = true;
          };
      };

      programs.jujutsu = {
        enable = true;
        # cargo-nextest fails to build on macOS, so skip tests until resolved:
        # https://github.com/NixOS/nixpkgs/issues/456113
        package = pkgs.jujutsu.override {
          rustPlatform = pkgs.rustPlatform // {
            buildRustPackage = pkgs.rustPlatform.buildRustPackage.override {
              cargoNextestHook = null;
            };
          };
        };
        settings = {
          user = {
            email = "${whois.email}";
            name = "${whois.name}";
          };
          signing =
            if builtins.hasAttr "gpg" whois.commitSigner then
              {
                backend = "gpg";
                key = whois.commitSigner.gpg.signingKey;
                behavior = "own";
              }
            else
              {
                backend = "ssh";
                key = "yubikey-agent"; # placeholder, see yubikeySshKeygen
                backends.ssh = {
                  allowed-signers = whois.commitSigner.ssh.allowedSignersFile;
                  program = lib.getExe yubikeySshKeygen;
                };
                behavior = "drop";
              };
          git = lib.attrsets.optionalAttrs (builtins.hasAttr "ssh" whois.commitSigner) {
            sign-on-push = true;
          };
          ui = {
            editor = "hx";
          };
        };
      };

      home.file.".config/ghostty/config".text = ''
        font-size = 13
        background = 282828
        foreground = dedede
        keybind = cmd+d=new_split:right
        keybind = cmd+left_bracket=goto_split:left
        keybind = cmd+right_bracket=goto_split:right
        keybind = cmd+shift+left_bracket=previous_tab
        keybind = cmd+shift+right_bracket=next_tab
      '';

      programs.helix = {
        enable = true;
        defaultEditor = true;

        settings = {
          theme = "tokyonight";
          editor = {
            soft-wrap = {
              enable = true;
            };
            cursor-shape = {
              normal = "block";
              insert = "bar";
              select = "underline";
            };
            bufferline = "multiple";
            statusline = {
              left = [
                "mode"
                "spinner"
                "spacer"
                "diagnostics"
                "file-name"
                "separator"
                "spacer"
                "version-control"
              ];
              right = [
                "file-type"
                "file-encoding"
                "file-line-ending"
                "position"
                "position-percentage"
                "total-line-numbers"
              ];
              separator = "⌥";
            };
            lsp = {
              display-inlay-hints = true;
            };
            end-of-line-diagnostics = "disable";
            inline-diagnostics = {
              cursor-line = "hint";
            };
          };

          keys = {
            normal = {
              C = [
                "extend_to_line_end"
                "yank_main_selection_to_clipboard"
                "delete_selection"
                "insert_mode"
              ];
              D = [
                "extend_to_line_end"
                "yank_main_selection_to_clipboard"
                "delete_selection"
              ];
              V = [
                "select_mode"
                "extend_to_line_bounds"
              ];
              "{" = [
                "extend_to_line_bounds"
                "goto_prev_paragraph"
              ];
              "}" = [
                "extend_to_line_bounds"
                "goto_next_paragraph"
              ];
              "*" = [
                "move_char_right"
                "move_prev_word_start"
                "move_next_word_end"
                "search_selection"
                "search_next"
              ];
              esc = [
                "collapse_selection"
                "keep_primary_selection"
              ];
            };

            insert = {
              esc = [
                "collapse_selection"
                "normal_mode"
              ];
            };

            select = {
              esc = [
                "collapse_selection"
                "keep_primary_selection"
                "normal_mode"
              ];
              "{" = [
                "extend_to_line_bounds"
                "goto_prev_paragraph"
              ];
              "}" = [
                "extend_to_line_bounds"
                "goto_next_paragraph"
              ];
            };
          };
        };

        languages = {
          language = [
            {
              name = "nix";
              auto-format = true;
              formatter.command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
            }
            {
              name = "typescript";
              auto-format = true;
              formatter = {
                command = "prettier";
                args = [
                  "--parser"
                  "typescript"
                ];
              };
              language-servers = [
                "typescript-language-server"
              ];
            }
            {
              name = "tsx";
              auto-format = true;
              formatter = {
                command = "prettier";
                args = [
                  "--parser"
                  "typescript"
                ];
              };
              language-servers = [
                "typescript-language-server"
              ];
            }
            {
              name = "solidity";
              auto-format = false;
              formatter = {
                command = "prettier";
                args = [
                  "--parser"
                  "solidity-parse"
                  "--plugin"
                  "prettier-plugin-solidity"
                ];
              };
            }
            {
              name = "python";
              auto-format = true;
            }
          ];

          language-server = {
            rust-analyzer = {
              config = {
                cargo = {
                  allFeatures = true;
                };
                check = {
                  command = "clippy";
                };
                procMacro = {
                  enable = false;
                  ignored = { };
                };
                diagnostics = {
                  disabled = [ "macro-error" ];
                };
              };
            };

            typescript-language-server = {
              command = "typescript-language-server";
              config.documentFormatting = false;
            };

            pylsp = {
              command = "pylsp";
              config.pylsp = {
                plugins.ruff.enabled = true;
                plugins.black.enable = true;
              };
            };
          };
        };
      };
    };
  };
}
