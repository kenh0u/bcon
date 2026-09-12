{
  lib,
  rustPlatform,
  pkg-config,
  makeWrapper,
  # runtime-linked libraries
  libdrm,
  mesa,
  libGL,
  libxkbcommon,
  libinput,
  systemd,
  dbus,
  fontconfig,
  freetype,
  libseat,
  wayland,
  # dlopen'd / spawned at runtime by bcon itself
  fcitx5-with-addons,
}:

let
  # Libraries resolved via dlopen() at runtime (EGL/GBM/fontconfig paths).
  drvLibPath = lib.makeLibraryPath [
    libdrm
    mesa
    mesa
    libGL
    libxkbcommon
    libinput
    systemd
    libseat
    wayland
    freetype
    fontconfig
  ];

  # bcon spawns these itself: dbus-daemon (private session bus) and fcitx5.
  runtimePath = lib.makeBinPath [
    dbus
    fcitx5-with-addons
  ];
in

rustPlatform.buildRustPackage {
  pname = "bcon";
  version = "1.4.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ../Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    libdrm
    mesa
    libGL
    libxkbcommon
    libinput
    systemd
    dbus
    fontconfig
    freetype
    libseat
    wayland
  ];

  postFixup = ''
    wrapProgram $out/bin/bcon \
      --prefix LD_LIBRARY_PATH : "${drvLibPath}" \
      --prefix PATH : "${runtimePath}" \
      --set FONTCONFIG_FILE ${fontconfig.out}/etc/fonts/fonts.conf
  '';

  meta = with lib; {
    description = "GPU-accelerated terminal emulator for the Linux console";
    homepage = "https://github.com/sanohiro/bcon";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "bcon";
  };
}
