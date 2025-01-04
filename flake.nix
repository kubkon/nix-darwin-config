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
      byakuya = {
        username = "kubkon";
        systemName = "byakuya";
        name = "Jakub Konka";
        email = "kubkon@jakubkonka.com";
        git.extraConfig = {
          # Sign all commits
          commit.gpgsign = true;
          gpg.format = "openpgp";
          user.signingkey = "DCEE0CE2EE812D32942750663AEF55DD984C8344";
        };
      };
      zkkubkon = {
        username = "kubkon";
        systemName = "zkkubkon";
        name = "Jakub Konka";
        email = "jakub@vlayer.xyz";
        git.extraConfig = {
          # Sign all commits using ssh key
          commit.gpgsign = true;
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
          user.signingkey = "~/.ssh/id_ed25519_sk.pub";
        };
      };
      whois = byakuya;

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
          pkgs.fzf
          pkgs.grc
          pkgs.git
          pkgs.helix
          pkgs.nixfmt
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
        users.knownUsers = [ "${whois.username}" ];
        users.users.${whois.username} = {
          uid = 501;
          shell = pkgs.fish;
          home = "/Users/${whois.username}";
        };

        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        system.stateVersion = 5;

        # The platform the configuration will be used on.
        nixpkgs.hostPlatform = "aarch64-darwin";

        security.pam.enableSudoTouchIdAuth = true;
      };

      programs.ssh.enable = true;

    in {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#main
      darwinConfigurations."${whois.systemName}" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          configuration
          nixvim.nixDarwinModules.nixvim
          (import ./modules/nvim.nix)
          home-manager.darwinModules.home-manager
          (import ./modules/home.nix)
        ];
        specialArgs = { inherit whois inputs self; };
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."simple".pkgs;
    };
}
