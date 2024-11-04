{ pkgs, lib, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kubkon = {
      home.username = "kubkon";
      home.stateVersion = "24.05";

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
        signing.signByDefault = true;
      };
    };
  };
}
