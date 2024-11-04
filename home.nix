{ pkgs, lib, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kubkon = {
      home.username = "kubkon";
      home.stateVersion = "24.05";

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
    };
  };
}
