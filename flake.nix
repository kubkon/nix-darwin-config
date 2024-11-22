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
            eval "$(/opt/homebrew/bin/brew shellenv)"
          '';
        };
        users.knownUsers = [ "kubkon" ];
        users.users.kubkon = {
          uid = 501;
          shell = pkgs.fish;
          home = "/Users/kubkon";
        };

        homebrew = {
          enable = true;
          taps = [];
          brews = [ "openssh" "ykman" "llvm" ];
          casks = [ "kitty" ];
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
              servers = {
                zls.enable = true;
                rust_analyzer = {
                  enable = true;
                  installRustc = true;
                  installCargo = true;
                  settings = {
                    checkOnSave = true;
                    check = {
                      command = "clippy";
                    };
                    # inlayHints = {
                    #   enable = true;
                    #   showParameterNames = true;
                    #   parameterHintsPrefix = "<- ";
                    #   otherHintsPrefix = "=> ";
                    # };
                    procMacro = {
                      enable = true;
                    };
                  };
                };
              };
            };

            cmp = {
              enable = true;
              settings = {
                completion = { completeopt = "menu,menuone,noinsert"; };
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
                  "<Tab>" =
                    "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
                  "<C-j>" = "cmp.mapping.select_next_item()";
                  "<C-k>" = "cmp.mapping.select_prev_item()";
                  "<C-e>" = "cmp.mapping.abort()";
                  "<C-b>" = "cmp.mapping.scroll_docs(-4)";
                  "<C-f>" = "cmp.mapping.scroll_docs(4)";
                  "<C-Space>" = "cmp.mapping.complete()";
                  "<CR>" = "cmp.mapping.confirm({ select = true })";
                  "<S-CR>" =
                    "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })";
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
                format_on_save = {
                  lsp_fallback = "fallback";
                  timeout_ms = 500;
                };
                notify_on_error = true;
                formatters_by_ft.rust = [ "rustfmt" ];
              };
            };
          };

          extraConfigLua = ''
            -- LSP Diagnostics Options Setup 
            local sign = function(opts)
              vim.fn.sign_define(opts.name, {
                texthl = opts.name,
                text = opts.text,
                numhl = ""
              })
            end

            sign({ name = 'DiagnosticSignError', text = '' })
            sign({ name = 'DiagnosticSignWarn', text = '' })
            sign({ name = 'DiagnosticSignHint', text = '' })
            sign({ name = 'DiagnosticSignInfo', text = '' })

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

            vim.cmd([[
            set signcolumn=yes
            autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
            ]])

            -- Use LspAttach autocommand to only map the following keys
            -- after the language server attaches to the current buffer
            vim.api.nvim_create_autocmd('LspAttach', {
              group = vim.api.nvim_create_augroup('UserLspConfig', {}),
              callback = function(ev)
                -- Enable completion triggered by <c-x><c-o>
                vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

                -- Buffer local mappings.
                -- See `:help vim.lsp.*` for documentation on any of the below functions
                local opts = { buffer = ev.buf }
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
                vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
                vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
                vim.keymap.set('n', '<space>wl', function()
                  print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                end, opts)
                vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
                vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
                vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
                vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                vim.keymap.set('n', '<space>f', function()
                  vim.lsp.buf.format { async = true }
                end, opts)
              end,
            })
          '';
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
