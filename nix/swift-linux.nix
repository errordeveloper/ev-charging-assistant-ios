{ lib, stdenv, fetchurl, autoPatchelfHook, zlib, libxml2_13, curl, openssl, sqlite, ncurses, libuuid, clang }:

# The locked Nixpkgs source compiler is Swift 5.10.1. Use the official
# Swift 6 release with its SwiftPM, XCTest and Swift Testing libraries.
stdenv.mkDerivation {
  pname = "swift-linux";
  version = "6.0.3";
  src = fetchurl {
    url = "https://download.swift.org/swift-6.0.3-release/ubuntu2404/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04.tar.gz";
    sha256 = "33e923609f6d89ee455af0a017ae4941ce16878c4940882cbf6a1656de294e8b";
  };
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib zlib libxml2_13 curl openssl sqlite ncurses libuuid ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a usr/. "$out/"
    # LLDB requires Ubuntu's libedit ABI and Python. This package supplies
    # compiler/test tooling only; do not disguise an incompatible debugger ABI.
    rm -f "$out"/bin/lldb* "$out"/lib/liblldb*
    rm -rf "$out/local/lib/python3.12/dist-packages/lldb"
    # Swift selects the adjacent clang for linking. Use Nix's wrapper so
    # generated executables use the same libc and loader as the Swift runtime.
    rm -f "$out/bin/clang" "$out/bin/clang++"
    ln -s ${clang}/bin/clang "$out/bin/clang"
    ln -s ${clang}/bin/clang++ "$out/bin/clang++"
    runHook postInstall
  '';
  meta = {
    description = "Official Swift 6 toolchain for Linux package development";
    homepage = "https://www.swift.org/";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "swift";
  };
}
