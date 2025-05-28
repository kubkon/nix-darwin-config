{
  pkgs,
  lib,
  whois,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kubkon = {
      home.username = "${whois.username}";
      home.stateVersion = "24.11";

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
        extraConfig = lib.mkBefore ''
          PKCS11Provider=${pkgs.yubico-piv-tool}/lib/libykcs11.dylib
        '';
      };

      programs.git = {
        enable = true;
        ignores = [ ".swp" ];
        userEmail = "${whois.email}";
        userName = "${whois.name}";
      };
      programs.git.extraConfig = whois.git.extraConfig;

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

      programs.zed-editor = {
        enable = true;

        extensions = [
          "nix"
          "toml"
        ];

        userSettings = {
          vim_mode = true;
          vim = {
            default_mode = "helix_normal";
          };
          scrollbar = {
            show = "never";
          };
          load_direnv = "shell_hook";

          lsp = {
            rust-analyzer = {
              initialization_options = {
                inlayHints = {
                  maxLength = null;
                  lifetimeElisionHints = {
                    enable = "skip_trivial";
                    useParameterNames = true;
                  };
                  closureReturnTypeHints = {
                    enable = "always";
                  };
                };

                checkOnSave = true;
                cargo = {
                  allTargets = true;
                };
                check = {
                  workspace = true;
                };
              };
            };
          };

          assistant = {
            enabled = true;
            version = "2";
            default_open_ai_model = null;
            default_model = {
              provider = "zed.dev";
              model = "claude-3-5-sonnet-latest";
            };
          };
        };

        userKeymaps = [
          {
            context = "Workspace";
            bindings = {
              "space f" = "file_finder::Toggle";
            };
          }
        ];
      };

      programs.helix = {
        enable = true;
        defaultEditor = true;

        settings = {
          theme = "tokyonight";
          editor = {
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
