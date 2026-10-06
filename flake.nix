{
  description = "EV Charging Assistant development tools; Xcode is supplied by the host";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
      toolchain = builtins.fromJSON (builtins.readFile ./config/toolchain.json);
    in
    {
      packages = forAllSystems (pkgs: rec {
        xcodegen = pkgs.callPackage ./nix/xcodegen.nix { inherit toolchain; };
        default = xcodegen;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [
            pkgs.git
            self.packages.${pkgs.stdenv.hostPlatform.system}.xcodegen
          ];
        };
      });
    };
}
