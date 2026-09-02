{
  description = "bastion - SSH jump box and Claude Code Telegram agent for the home cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Same overlays nix-config uses on the laptop, so the bastion runs the very
    # same claude, talosctl and sofka builds.
    claude-code-overlay = {
      url = "github:nklmilojevic/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    talosctl = {
      url = "github:nklmilojevic/talosctl-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # No nixpkgs follows here on purpose: sofka's release workflow warms
    # nkl-sofka.cachix.org with the derivation built against its own pinned
    # nixpkgs, and overriding it would force a from-source Rust build.
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

      # x86_64-linux is what the cluster runs; aarch64-linux exists so the image
      # can be built and smoke-tested locally through an aarch64 Linux builder.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # sofka is deliberately NOT applied as an overlay: its overlay re-evaluates
      # package.nix against this flake's nixpkgs, which yields a different
      # derivation from the one its release workflow pushes to
      # nkl-sofka.cachix.org. Taking `sofka.packages.<system>.default` keeps the
      # cached build (see the image call below).
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
