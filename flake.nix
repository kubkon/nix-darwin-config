{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
    }:
    let
      system = "aarch64-darwin";

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

      kuchiki = {
        username = "kubkon";
        systemName = "Kuchiki";
        name = "Jakub Konka";
        email = "kubkon@jakubkonka.com";
        git.extraConfig = {
          # Sign all commits
          commit.gpgsign = true;
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
          user.signingkey = "~/.ssh/id_ecdsa_sk.pub";
        };
      };

      kyoraku = kuchiki // {
        systemName = "kyoraku";
      };

      whois = kyoraku;

      configuration =
        {
          pkgs,
          pkgs-stable,
          system,
          ...
        }:
        {
          environment.systemPackages = [
            pkgs.fish
            pkgs-stable.yubico-piv-tool
            pkgs.ripgrep
            pkgs.rustfmt
            pkgs.tree
            pkgs.bloaty
            pkgs.pstree
            pkgs-stable.openssh
            pkgs.fzf
            pkgs.grc
            pkgs.git
            pkgs.helix
            pkgs.slack
            pkgs.discord
            pkgs.darwin.xcode_16_4
          ];

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          # Allow unfree
          nixpkgs.config.allowUnfree = true;

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
          system.stateVersion = 6;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = system;

          security.pam.services.sudo_local.touchIdAuth = true;
        };

      programs.ssh.enable = true;

    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#${whois.systemName}
      darwinConfigurations."${whois.systemName}" = nix-darwin.lib.darwinSystem {
        system = system;
        modules = [
          configuration
          home-manager.darwinModules.home-manager
          (import ./modules/home.nix)
        ];
        specialArgs = {
          pkgs-stable = import nixpkgs-stable {
            inherit system;
          };
          inherit
            whois
            inputs
            self
            system
            ;
        };
      };
    };
}
