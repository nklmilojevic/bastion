{
  description = "bastion - SSH jump box and Claude Code Telegram agent for the home cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    claude-code-overlay = {
      url = "github:nklmilojevic/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    talosctl = {
      url = "github:nklmilojevic/talosctl-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sofka.url = "github:nklmilojevic/sofka";
  };

  nixConfig = {
    extra-substituters = [ "https://nkl-sofka.cachix.org" ];
    extra-trusted-public-keys = [
      "nkl-sofka.cachix.org-1:hLg9frFNJynrxe7SSBb/p6pbawlpZmG10bw+wLsTufw="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      claude-code-overlay,
      talosctl,
      sofka,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      overlays = [
        claude-code-overlay.overlays.default
        talosctl.overlays.default
      ];

      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system overlays;
              config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude" ];
            }
          )
        );
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          image = pkgs.callPackage ./image.nix {
            sofka = sofka.packages.${pkgs.stdenv.hostPlatform.system}.default;
            rev = self.shortRev or self.dirtyShortRev or "dev";
          };
        in
        {
          default = image;
          inherit image;
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            shellcheck
            skopeo
            zizmor
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
