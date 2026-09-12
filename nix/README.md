# Nix packaging

## Build

```bash
nix build .#bcon
./result/bin/bcon --help
```

The wrapper sets `LD_LIBRARY_PATH` (mesa/EGL/GBM and friends are dlopen'd at
runtime), `FONTCONFIG_FILE`, and a `PATH` prefix with `dbus` and `fcitx5`
(bcon spawns a private dbus-daemon and fcitx5 itself for Japanese input).

## NixOS module

```nix
# flake.nix of the host
{
  inputs.bcon.url = "github:kenh0u/bcon/feature/nixos";

  outputs = { self, nixpkgs, bcon, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        bcon.nixosModules.bcon
        {
          services.bcon = {
            enable = true;
            tty = "tty5"; # getty on tty5 is disabled automatically
            backend = "vt";
            config.font = {
              family = "Hack Nerd Font";
              fallback = [ "Noto Sans CJK JP" "Noto Color Emoji" ];
            };
          };
        }
      ];
    };
  };
}
```

Then `sudo nixos-rebuild test --flake .#myhost` and switch with `Ctrl+Alt+F5`.

### Building on a remote machine

For weak local machines, build on another host over SSH:

```bash
nix build .#bcon --max-jobs 0 \
  --builders 'ssh://buildhost x86_64-linux - 16 1 big-parallel'
```

The builder needs `kenhou` (or whoever runs the build) in
`nix.settings.trusted-users` on the builder to also benefit from its caches.
