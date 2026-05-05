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

  withPiper ? true,
  piper-tts,
  piper-phonemize,
  rubberband,
  onnxruntime,
  autoPatchelfHook,
  spdlog,
  # setuptools,
  # onnxruntime-tools,
  # onnxruntime-gpu,
  # onnxruntime-native,
  # piper-phonemize-native,

  libsOnly ? false,
}:

let
  piper-src = fetchFromGitHub {
    owner = "rhasspy";
    repo = "piper";
    rev = "2023.11.14-2";
    hash = "sha256-3ynWyNcdf1ffU3VoDqrEMrm5Jo5Zc5YJcVqwLreRCsI=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  preUnpack = ''
    set -o xtrace
  '';
  preFailure = ''
    set +o xtrace
  '';

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
    # autoPatchelfHook
    # python3Packages.setuptools
    # python3Packages.onnxruntime-native
    # python3Packages.piper-phonemize-native
    # python3Packages.piper-phonemize-native.espeak-ng
    # python3Packages.piper-phonemize.onnxruntime-native
    # python3Packages.piper-phonemize.piper-phonemize-native
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
  ]
  ++ lib.optionals withPiper [
    # piper-tts
    # piper-phonemize
    # rubberband
    # onnxruntime
    # piper-src
    # finalAttrs.src
    # (lib.getLib stdenv.cc.cc)
    # spdlog
    # onnxruntime.dev
    # python3Packages.onnxruntime-tools
    # onnxruntime-gpu
    # onnxruntime.protobuf
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
      (withFeature withPiper "piper")
      # "CXXFLAGS=\"-I${finalAttrs.src}/include -I${lib.getInclude piper-phonemize}/include/piper-phonemize\""
      # ''\'CXXFLAGS=${
      #   toString [
      #     # "-I${finalAttrs.src}/include"
      #     # "-I${piper-src}/src/cpp"
      #     # "-I${lib.getInclude piper-phonemize}/include"
      #     # "-I${lib.getInclude piper-phonemize}/include/onnxruntime"
      #     # "-I${lib.getInclude piper-phonemize}/include/piper-phonemize"
      #   ]
      # }\' ''
    ];

  postPatch = lib.optionalString withPico ''
    substituteInPlace src/modules/pico.c --replace-fail "/usr/share/pico/lang" "${svox}/share/pico/lang"
  '';

  installFlags = [
    "sysconfdir=${placeholder "out"}/etc"
  ];

  env = lib.attrsets.optionalAttrs withPiper {
    #   # needs to be declared twice annoyingly
    #   ORT_STRATEGY = "system";

    #   # lib.concatMapStringsSep " " (pkg: "-I${lib.getInclude pkg}/include")
    CPPFLAGS = toString [
      # #include <speechd_types.h>
      # https://github.com/brailcom/speechd/blob/60b1e9ef1d3a49f4661e6c8772f923193ee64777/src/modules/module_utils.h#L39
      # https://github.com/brailcom/speechd/blob/60b1e9ef1d3a49f4661e6c8772f923193ee64777/src/modules/spd_module_main.h#L32
      # #include <fdsetconv.h>
      # https://github.com/brailcom/speechd/blob/60b1e9ef1d3a49f4661e6c8772f923193ee64777/src/modules/module_utils.c#L26
      "-I${lib.getInclude finalAttrs.src}/include"

      # #include <onnxruntime_cxx_api.h>
      # https://github.com/brailcom/speechd/blob/60b1e9ef1d3a49f4661e6c8772f923193ee64777/src/modules/cxxpiper.cpp#L39
      "-I${lib.getInclude onnxruntime}/include"

      # #include <json.hpp>
      # https://github.com/brailcom/speechd/blob/60b1e9ef1d3a49f4661e6c8772f923193ee64777/src/modules/cxxpiper.cpp#L40
      "-I${lib.getInclude piper-src}/src/cpp"

      # #include <piper-phonemize/phoneme_ids.hpp>
      # https://github.com/rhasspy/piper/blob/38917ffd8c0e219c6581d73e07b30ef1d572fce1/src/cpp/piper.hpp#L12
      "-I${lib.getInclude piper-phonemize}/include"

      # #include <rubberband/RubberBandStretcher.h>
      # https://github.com/brailcom/speechd/blob/60b1e9ef1d3a49f4661e6c8772f923193ee64777/src/modules/cxxpiper.cpp#L44
      "-I${lib.getInclude rubberband}/include"
      # "-I${lib.getInclude piper-phonemize}/include/onnxruntime"
      # "-I${lib.getInclude piper-phonemize}/include/piper-phonemize"
      # "-I${lib.getInclude onnxruntime.dev}/include"
    ];
    #   CXXFLAGS = finalAttrs.env.CPPFLAGS;
    #   LDFLAGS = toString [
    #     "-lpthread"
    #     "-L${lib.getLib piper-phonemize}/lib"
    #     "-L${lib.getLib onnxruntime}/lib"
    #   ];
  };
  preConfigure = ''
    echo "$CPPFLAGS $LDFLAGS";
  '';
  # CXXFLAGS = lib.optionals withPiper [
  #   "-I${lib.getInclude finalAttrs.src}/include"
  #   "-I${lib.getInclude piper-phonemize}/include/piper-phonemize"
  #   "-I${piper-phonemize}/include/piper-phonemize"
  # ];

  # env.CXXFLAGS = "CXXFLAGS=\"-I${finalAttrs.src}/include -I${lib.getInclude piper-phonemize}/include/piper-phonemize\""; # env.CXXFLAGS = lib.traceValSeq "-I${lib.getInclude piper-phonemize}/include/piper-phonemize";
  # CXXFLAGS = lib.traceValSeq [
  #     "-I${lib.getInclude piper-phonemize}/include/piper-phonemize"
  #   ];
  # preConfigure = lib.optionalString withPiper ''
  #   export CXXFLAGS="${
  #     toString [
  #       "-I${finalAttrs.src}/include"
  #       "-I${piper-src}/src/cpp"
  #       # "-I${lib.getInclude piper-phonemize}/include"
  #       # "-I${lib.getInclude piper-phonemize}/include/onnxruntime"
  #       # "-I${lib.getInclude piper-phonemize}/include/piper-phonemize"
  #     ]
  #   }"
  #   export CPPFLAGS="$CXXFLAGS"
  #   export LDFLAGS="-L${lib.getInclude piper-phonemize}/lib"
  # '';
  # preConfigure = lib.optionalString withPiper ''
  #   export CXXFLAGS="$'''{CXXFLAGS:-} -I${finalAttrs.src}/include"
  #   export CXXFLAGS="$'''{CXXFLAGS:-} -I${lib.getInclude piper-phonemize}/include/piper-phonemize"
  # '';
  # export CXXFLAGS="${CXXFLAGS:-} -I${finalAttrs.src}/include -I${lib.getInclude piper-phonemize}/include/piper-phonemize"

  # LDFLAGS = lib.optionals withPiper [
  #   "-L${lib.getInclude piper-phonemize}/lib"
  # ];

  # dontUseNinjaBuild = true;
  preBuild = ''
    ls -al
    ls -al src/modules/
    echo "$(realpath .)/src/modules/Makefile"
    echo "$(pwd)/src/modules/Makefile"
    # ls -al $out
    echo "CPPFLAGS $CPPFLAGS";
    echo "LDFLAGS $LDFLAGS";
  '';

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
