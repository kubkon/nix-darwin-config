{ pkgs, lib, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kubkon = {
      home.username = "kubkon";
      home.stateVersion = "24.05";
      home.sessionVariables = {
        EDITOR = "nvim";
      };

      programs.direnv.enable = true;
      programs.direnv.nix-direnv.enable = true;
      programs.fish.enable = true;

      programs.ssh = {
        enable = true;
        extraConfig = lib.mkBefore ''
        PKCS11Provider=${pkgs.yubico-piv-tool}/lib/libykcs11.dylib
        '';
      };

      programs.git = {
        enable = true;
        ignores = [ ".swp" ];
        userEmail = "jakub@vlayer.xyz";
        userName = "Jakub Konka";
        extraConfig = {
          # Sign all commits using ssh key
          commit.gpgsign = true;
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
          user.signingkey = "~/.ssh/id_ed25519_sk.pub";
        };
      };

      home.file."~/.config/ghostty".text = ''
      font-size = 12
      background = 282828
      foreground = dedede
      keybind = cmd+d=new_split:right
      keybind = cmd+left_bracket=goto_split:left
      keybind = cmd+right_bracket=goto_split:right
      keybind = cmd+shift+left_bracket=previous_tab
      keybind = cmd+shift+right_bracket=next_tab
      '';
    };
  };
}
