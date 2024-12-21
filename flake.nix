{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    home-manager.url = "github:nix-community/home-manager/master";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nixvim, home-manager }:
    let
      configuration = { pkgs, ... }: {
        environment.systemPackages = [
          pkgs.fish 
          pkgs.yubico-piv-tool
          pkgs.ripgrep
          pkgs.rustfmt
          pkgs.tree
          pkgs.bloaty
          pkgs.pstree
          pkgs.openssh
        ];

        # Auto upgrade nix package and the daemon service.
        services.nix-daemon.enable = true;
        # nix.package = pkgs.nix;

        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        # Enable alternative shell support in nix-darwin.
        programs.fish = {
          enable = true;
          shellInit = ''
            for p in /run/current-system/sw/bin
              if not contains $p $fish_user_paths
                set -g fish_user_paths $p $fish_user_paths
              end
            end
          '';
        };
        users.knownUsers = [ "kubkon" ];
        users.users.kubkon = {
          uid = 501;
          shell = pkgs.fish;
          home = "/Users/kubkon";
        };

        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        system.stateVersion = 5;

        # The platform the configuration will be used on.
        nixpkgs.hostPlatform = "aarch64-darwin";

        security.pam.enableSudoTouchIdAuth = true;

        programs.nixvim = {
          enable = true;

          globals.mapleader = " ";

          keymaps = [
            {
              mode = "n";
              key = "<CR>";
              options.silent = true;
              action = ":nohlsearch<CR>";
            }
            # Telescope config
            {
              key = "<leader>ff";
              action = "<cmd>Telescope find_files<CR>";
            }
            {
              key = "<leader>fg";
              action = "<cmd>Telescope live_grep<CR>";
            }
            {
              key = "<leader>fb";
              action = "<cmd>Telescope buffers<CR>";
            }
            {
              key = "<leader>fh";
              action = "<cmd>Telescope help_tags<CR>";
            }
          ];

          opts = {
            number = true;
            relativenumber = true;
            expandtab = true;
            shiftwidth = 2;
          };

          colorschemes.tokyonight.enable = true;

          plugins = {
            telescope = {
              enable = true;
              extensions = { fzf-native = { enable = true; }; };
            };

            harpoon = {
              enable = true;
              enableTelescope = true;
              keymaps = {
                addFile = "<leader>a";
                toggleQuickMenu = "<C-o>";
                navFile = {
                  "1" = "<C-h>";
                  "2" = "<C-n>";
                  "3" = "<C-e>";
                  "4" = "<C-i>";
                };
              };
            };

            lsp = {
              enable = true;
              inlayHints = true;
              servers = {
                eslint.enable = true;
                zls.enable = true;
              };
              keymaps = {
                diagnostic = {
                  "<leader>E" = "open_float";
                  "[" = "goto_prev";
                  "]" = "goto_next";
                  "<leader>do" = "setloclist";
                };
                lspBuf = {
                  "K" = "hover";
                  "gD" = "declaration";
                  "gd" = "definition";
                  "gr" = "references";
                  "gI" = "implementation";
                  "gy" = "type_definition";
                  "<leader>ca" = "code_action";
                  "<leader>cr" = "rename";
                  "<leader>wl" = "list_workspace_folders";
                  "<leader>wr" = "remove_workspace_folder";
                  "<leader>wa" = "add_workspace_folder";
                  "<C-k>" = "signature_help";
                };
              };
              preConfig = ''
                vim.diagnostic.config({
                    virtual_text = false,
                    signs = true,
                    update_in_insert = true,
                    underline = true,
                    severity_sort = false,
                    float = {
                        border = 'rounded',
                        source = 'always',
                        header = "",
                        prefix = "",
                    },
                })

                vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
                  vim.lsp.handlers.hover,
                  {border = 'rounded'}
                )

                vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
                  vim.lsp.handlers.signature_help,
                  {border = 'rounded'}
                )
              '';
              postConfig = ''
                local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
                for type, icon in pairs(signs) do
                  local hl = "DiagnosticSign" .. type
                  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
                end
              '';
            };

            cmp = {
              enable = true;
              settings = {
                completion = {
                  completeopt = "menu,menuone,noinsert";
                };
                autoEnableSources = true;
                experimental = { ghost_text = true; };
                performance = {
                  debounce = 60;
                  fetchingTimeout = 200;
                  maxViewEntries = 30;
                };
                formatting = { fields = [ "kind" "abbr" "menu" ]; };
                sources = [
                  { name = "nvim_lsp"; }
                  { name = "emoji"; }
                  {
                    name = "buffer"; # text within current buffer
                    option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
                    keywordLength = 3;
                  }
                  {
                    name = "path"; # file system paths
                    keywordLength = 3;
                  }
                ];

                window = {
                  completion = { border = "solid"; };
                  documentation = { border = "solid"; };
                };

                mapping = {
                  "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
                  "<C-j>" = "cmp.mapping.select_next_item()";
                  "<C-k>" = "cmp.mapping.select_prev_item()";
                  "<C-e>" = "cmp.mapping.abort()";
                  "<C-b>" = "cmp.mapping.scroll_docs(-4)";
                  "<C-f>" = "cmp.mapping.scroll_docs(4)";
                  "<C-Space>" = "cmp.mapping.complete()";
                  "<CR>" = "cmp.mapping.confirm({ select = true })";
                  "<S-CR>" = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })";
                };
              };
            };
            cmp-nvim-lsp.enable = true;
            cmp-path.enable = true;
            cmp-buffer.enable = true;

            lualine.enable = true;
            bufferline.enable = true;
            web-devicons.enable = true;
            treesitter.enable = true;
            commentary.enable = true;
            zig.enable = true;

            conform-nvim = {
              enable = true;
              settings = {
                notify_on_error = false;
                formatters_by_ft = {
                  rust = [ "cargo" "fmt" ];
                };
                format_on_save = {
                  lsp_fallback = true;
                  timeout_ms = 500;
                };
              };
            };

            rustaceanvim = {
              enable = true;
              settings = {
                rustAnalyzerPackage = null;
                tools.clippy_enable = true;
                server = {
                  default_settings = {
                    rust-analyzer = {
                      cargo = { 
                        allFeatures = true;
                      };
                      check = {
                        command = "clippy";
                      };
                    };
                    inlayHints = { 
                      lifetimeElisionHints = { 
                        enable = "always";
                      };
                    };
                  };
                };
              };
            };

            typescript-tools = {
              enable = true;
              settings.on_attach = ''
                function(client, bufnr)
                    client.server_capabilities.documentFormattingProvider = false
                    client.server_capabilities.documentRangeFormattingProvider = false
                end
              '';
            };
          };
        };
      };

      programs.ssh.enable = true;

    in {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#main
      darwinConfigurations."zkkubkon" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [ 
          configuration 
          nixvim.nixDarwinModules.nixvim
          home-manager.darwinModules.home-manager (import ./home.nix)
        ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."simple".pkgs;
    };
}
