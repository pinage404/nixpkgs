{
  stdenv,
  lib,
  replaceVars,
  pkg-config,
  fetchFromGitHub,
  fetchpatch,
  python3Packages,
  gettext,
  itstool,
  libtool,
  texinfo,
  systemdMinimal,
  util-linux,
  autoreconfHook,
  glib,
  dotconf,
  libsndfile,

  withLibao ? true,
  libao,

  withPipewire ? true,
  pipewire,

  withPulse ? false,
  libpulseaudio,

  withAlsa ? false,
  alsa-lib,

  withOss ? false,

  withFlite ? true,
  flite,

  withEspeak ? true,
  espeak,
  sonic,
  pcaudiolib,
  mbrola,

  withPico ? true,
  svox,
  runtimeShell,

  libsOnly ? false,
}:

stdenv.mkDerivation (finalAttrs: {
  name = "speech-dispatcher";

  src = fetchFromGitHub {
    owner = "brailcom";
    repo = "speechd";
    rev = "22a9a5adfcd300fae0671c42a44d3db940b4147b";
    sha256 = "sha256-kxjbydolhUF+Cj8ptImwSDLV3Zz6Kcp/4qLgLYqNPCE=";
  };

  patches = [
    (replaceVars ./fix-paths.patch {
      utillinux = util-linux;
      # patch context
      bindir = null;
    })
  ]
  ++ lib.optionals (withEspeak && espeak.mbrolaSupport) [
    # Replace FHS paths.
    (replaceVars ./fix-mbrola-paths.patch {
      inherit mbrola;
    })
  ];

  nativeBuildInputs = [
    pkg-config
    autoreconfHook
    gettext
    libtool
    itstool
    texinfo
    python3Packages.wrapPython
  ];

  buildInputs = [
    glib
    dotconf
    libsndfile
    libao
    libpulseaudio
    python3Packages.python
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    systemdMinimal # libsystemd
  ]
  ++ lib.optionals withPipewire [
    pipewire
  ]
  ++ lib.optionals withAlsa [
    alsa-lib
  ]
  ++ lib.optionals withEspeak [
    espeak
    sonic
    pcaudiolib
  ]
  ++ lib.optionals withFlite [
    flite
  ]
  ++ lib.optionals withPico [
    svox
  ];

  pythonPath = [
    python3Packages.pyxdg
  ];

  configureFlags =
    let
      inherit (lib) withFeature;
    in
    [
      "--sysconfdir=/etc"
      # Audio method falls back from left to right.
      "--with-default-audio-method=\"libao,pulse,pipewire,alsa,oss\""
      "--with-systemdsystemunitdir=${placeholder "out"}/lib/systemd/system"
      "--with-systemduserunitdir=${placeholder "out"}/lib/systemd/user"
      (withFeature withPipewire "pipewire")
      (withFeature withPulse "pulse")
      (withFeature withLibao "libao")
      (withFeature withAlsa "alsa")
      (withFeature withOss "oss")
      (withFeature withEspeak "espeak-ng")
      (withFeature withFlite "flite")
      (withFeature withPico "pico")
    ];

  postPatch = lib.optionalString withPico ''
    substituteInPlace src/modules/pico.c --replace-fail "/usr/share/pico/lang" "${svox}/share/pico/lang"
  '';

  installFlags = [
    "sysconfdir=${placeholder "out"}/etc"
  ];

  postInstall =
    if libsOnly then
      ''
        rm -rf $out/{bin,etc,lib/speech-dispatcher,lib/systemd,libexec,share}
      ''
    else
      ''
        wrapPythonPrograms
      '';

  enableParallelBuilding = true;

  meta = {
    description =
      "Common high-level interface to speech synthesis"
      + lib.optionalString libsOnly " - client libraries only";
    homepage = "https://devel.freebsoft.org/speechd";
    changelog = "https://github.com/brailcom/speechd/blob/${finalAttrs.version}/NEWS";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [
      berce
      jtojnar
    ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    # TODO: remove checks for `withPico` once PR #375450 is merged
    platforms = if withAlsa || withPico then lib.platforms.linux else lib.platforms.unix;
    mainProgram = "speech-dispatcher";
  };
})
