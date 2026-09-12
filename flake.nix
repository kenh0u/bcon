{
  description = "bcon - GPU-accelerated terminal emulator for the Linux console (DRM/KMS, no X11/Wayland)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = self.packages.${system}.bcon;
          bcon = pkgs.callPackage ./nix/package.nix {
            libseat = pkgs.seatd;
            fcitx5-with-addons = pkgs.qt6Packages.fcitx5-with-addons;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc
            cargo
            clippy
            rustfmt
            pkg-config
            libdrm
            mesa
            libgbm
            libGL
            libxkbcommon
            libinput
            systemd
            dbus
            fontconfig
            freetype
            seatd
            wayland
          ];
        };
      }
    )
    // {
      overlays.default =
        final: _prev:
        {
          bcon = final.callPackage ./nix/package.nix {
            libseat = final.seatd;
            fcitx5-with-addons = final.qt6Packages.fcitx5-with-addons;
          };
        };

      nixosModules = {
        default = self.nixosModules.bcon;
        bcon = {
          pkgs,
          lib,
          ...
        }:
        {
          imports = [ ./nix/module.nix ];
          nixpkgs.overlays = [ self.overlays.default ];
          services.bcon.package = lib.mkDefault pkgs.bcon;
        };
      };
    };
}
