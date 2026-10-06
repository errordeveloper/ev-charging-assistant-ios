{
  description = "EV Charging Assistant: Linux package tests and macOS iOS development";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
      toolchain = builtins.fromJSON (builtins.readFile ./config/toolchain.json);
    in
    {
      packages = forAllSystems (pkgs: if pkgs.stdenv.hostPlatform.isDarwin then rec {
        xcodegen = pkgs.callPackage ./nix/xcodegen.nix { inherit toolchain; };
        default = xcodegen;
      } else rec {
        swift = pkgs.callPackage ./nix/swift-linux.nix { };
        default = swift;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [ pkgs.git ] ++
            (if pkgs.stdenv.hostPlatform.isDarwin then [
              self.packages.${pkgs.stdenv.hostPlatform.system}.xcodegen
            ] else [
              self.packages.${pkgs.stdenv.hostPlatform.system}.swift
              pkgs.coreutils
              pkgs.clang
            ]);
          shellHook = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            # Cloud tasks may have a read-only home directory.
            export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$PWD/.build/cache}"
            export CLANG_MODULE_CACHE_PATH="''${CLANG_MODULE_CACHE_PATH:-$PWD/.build/clang-cache}"
            export SWIFT_MODULECACHE_PATH="''${SWIFT_MODULECACHE_PATH:-$PWD/.build/swift-cache}"
            export CPATH="${pkgs.lib.getDev pkgs.stdenv.cc.libc}/include''${CPATH:+:$CPATH}"
          '';
        };
      });
    };
}
