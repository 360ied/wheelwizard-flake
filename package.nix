{
  lib,
  buildDotnetModule,
  desktop-file-utils,
  dotnetCorePackages,
  fetchFromGitHub,
  makeWrapper,
  # Runtime dependencies
  libglvnd,
}:
buildDotnetModule (finalAttrs: {
  pname = "wheelwizard";
  version = "2.5.3";

  src = fetchFromGitHub {
    owner = "TeamWheelWizard";
    repo = "WheelWizard";
    tag = "v${finalAttrs.version}";
    hash = "sha256-r8H2UCsasYTZ4sChzHbgFDKmccQEnYkA8WfR+UmLzrM=";
  };

  postPatch = ''
    rm -f .config/dotnet-tools.json
  '';

  projectFile = "WheelWizard";
  buildType = "Release";
  dotnet-sdk = dotnetCorePackages.sdk_10_0-bin;
  dotnet-runtime = dotnetCorePackages.runtime_10_0-bin;
  nugetDeps = ./deps.json;

  nativeBuildInputs = [
    makeWrapper
    desktop-file-utils
  ];

  runtimeDeps = [
    libglvnd
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/wheelwizard $out/bin
    cp -r WheelWizard/bin/Release/net10.0/*/* $out/lib/wheelwizard/

    makeWrapper $out/lib/wheelwizard/WheelWizard $out/bin/WheelWizard \
      --prefix PATH : ${lib.makeBinPath [ finalAttrs.dotnet-runtime ]}

    install -Dm444 Flatpak/io.github.TeamWheelWizard.WheelWizard.desktop -t $out/share/applications
    install -Dm444 Flatpak/io.github.TeamWheelWizard.WheelWizard-url-handler.desktop -t $out/share/applications
    install -Dm444 Flatpak/io.github.TeamWheelWizard.WheelWizard.png $out/share/icons/hicolor/256x256/apps/io.github.TeamWheelWizard.WheelWizard.png

    runHook postInstall
  '';

  postFixup = ''
    rm -f $out/bin/*.so $out/bin/*.dylib
  '';

  meta = {
    description = "WheelWizard, Retro Rewind Launcher";
    homepage = "https://github.com/TeamWheelWizard/WheelWizard";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
    mainProgram = "WheelWizard";
    maintainers = [ ];
  };
})
