{ lib, stdenvNoCC, fetchurl, unzip, toolchain }:

stdenvNoCC.mkDerivation {
  pname = "xcodegen";
  inherit (toolchain.xcodegen) version;

  src = fetchurl {
    inherit (toolchain.xcodegen) url sha256;
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = "xcodegen";
  dontBuild = true;
  # Preserve the upstream universal binary and its signature.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/licenses/xcodegen"
    install -m 755 bin/xcodegen "$out/bin/xcodegen"
    cp -R share/xcodegen "$out/share/"
    install -m 644 LICENSE "$out/share/licenses/xcodegen/LICENSE"
    runHook postInstall
  '';

  meta = {
    description = "Xcode project generator with its bundled setting presets";
    homepage = "https://github.com/yonaskolb/XcodeGen";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "xcodegen";
  };
}
