{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bcon;
  tomlFormat = pkgs.formats.toml { };
in

{
  options.services.bcon = {
    enable = lib.mkEnableOption ''
      bcon, a GPU-accelerated terminal emulator running directly on the Linux console.

      Replaces getty on the configured VT. Switch to it with Ctrl+Alt+F{n}.
    '';

    package = lib.mkOption {
      type = lib.types.package;
      description = "The bcon package to run.";
    };

    tty = lib.mkOption {
      type = lib.types.str;
      default = "tty5";
      example = "tty3";
      description = ''
        Virtual terminal to run bcon on. getty on this VT is disabled.
        Switch with Ctrl+Alt+F{n}, where n is the number in this option.
      '';
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "vt"
        "seatd"
        "auto"
      ];
      default = "vt";
      description = ''
        Session management backend. `vt` takes direct VT control and runs as
        root (simplest, matches the upstream systemd unit). `seatd` uses
        libseat/logind; enable `services.seatd` for it.
      '';
    };

    config = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          font = {
            family = "Hack Nerd Font";
            fallback = [ "Noto Sans CJK JP" "Noto Color Emoji" ];
          };
        }
      '';
      description = ''
        Configuration written to {file}`/etc/bcon/config.toml`.
        Layered on top of built-in defaults; per-user settings in
        {file}`~/.config/bcon/config.toml` override it further.
      '';
    };

    fonts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        nerd-fonts.hack
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];
      defaultText = lib.literalExpression ''
        with pkgs; [ nerd-fonts.hack noto-fonts-cjk-sans noto-fonts-color-emoji ]
      '';
      description = "Font packages to install (fontconfig discovers them automatically).";
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = cfg.fonts;
    fonts.fontconfig.enable = lib.mkDefault true;

    environment.etc."bcon/config.toml" = lib.mkIf (cfg.config != { }) {
      source = tomlFormat.generate "bcon-config.toml" cfg.config;
    };

    systemd.services."getty@${cfg.tty}".enable = lib.mkForce false;

    systemd.services."bcon@${cfg.tty}" = {
      description = "bcon terminal emulator on ${cfg.tty}";
      documentation = [ "https://github.com/sanohiro/bcon" ];
      after = [
        "systemd-user-sessions.service"
        "plymouth-quit-wait.service"
      ];
      conflicts = [ "getty@${cfg.tty}.service" ];
      before = [ "getty@${cfg.tty}.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = lib.optional (cfg.config != { }) config.environment.etc."bcon/config.toml".source;

      environment = {
        BCON_BACKEND = cfg.backend;
        RUST_LOG = "info";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/bcon";
        WorkingDirectory = "/root";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "journal";
        TTYPath = "/dev/${cfg.tty}";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
        Restart = "always";
        RestartSec = "1";
        LimitNOFILE = 65535;

        # DRM/input device access plus the capabilities `login` needs to
        # switch to a user.
        CapabilityBoundingSet = [
          "CAP_SYS_TTY_CONFIG"
          "CAP_SYS_ADMIN"
          "CAP_SETUID"
          "CAP_SETGID"
          "CAP_SETPCAP"
          "CAP_DAC_OVERRIDE"
          "CAP_AUDIT_WRITE"
          "CAP_CHOWN"
          "CAP_FOWNER"
        ];
        AmbientCapabilities = [ "CAP_SYS_TTY_CONFIG" ];
      };
    };
  };
}
