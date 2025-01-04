{ pkgs, lib, whois, ... }: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kubkon = {
      home.username = "${whois.username}";
      home.stateVersion = "24.11";
      home.sessionVariables = { EDITOR = "nvim"; };

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
        font-size = 12
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
                "diagnostics"
                "file-name"
                "separator"
                "version-control"
              ];
              right = [ "position" "position-percentage" "total-line-numbers" ];
              separator = "⌥ ";
            };
            lsp = { display-inlay-hints = true; };
          };

        };
        languages.language = [{
          name = "nix";
          auto-format = true;
          formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
        }];
      };
    };
  };
}
