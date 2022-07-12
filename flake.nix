{
  nixConfig.extra-substituters = [ "https://cache.iog.io" "https://arm-haskell-cc.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" "arm-haskell-cc.cachix.org-1:pzLPMMzguVbBBfLkarXkFcWh3ezSY7tCkSEzPNvPIGk=" ];

  description = "A very basic flake";
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix";
  # inputs.haskellNix.url = "/home/afo/archive/prj/22-2_fpga/haskell/iohk";
  inputs.nixpkgs.follows = "haskellNix/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils, haskellNix }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (system:
      let
        overlays = [
          haskellNix.overlay

          #ffmpeg
          (self: super: {
            libavformat = self.ffmpeg;
            libavcodec = self.ffmpeg;
            libavdevice = self.ffmpeg;
            libswscale = self.ffmpeg;
            libswresample = self.ffmpeg;
          })

          (final: prev: {
            # This overlay adds our project to pkgs
            helloProject =
              final.haskell-nix.project' {
                src = ./.;
                compiler-nix-name = "ghc923";
                # This is used by `nix develop .` to open a shell for use with
                # `cabal`, `hlint` and `haskell-language-server`
                shell.tools = {
                  cabal = { };
                  hlint = { };
                  haskell-language-server = { };
                };
                # Non-Haskell shell tools go here
                shell.buildInputs = with pkgs; [
                  nixpkgs-fmt
                ];
                # This adds `js-unknown-ghcjs-cabal` to the shell.
                # shell.crossPlatforms = p: [p.ghcjs];

                modules = [
                  ({lib, ...}: {
                    packages.ghci.flags.ghci = lib.mkForce true;
                    packages.libiserv.flags.network = lib.mkForce true;
                  })
                  ({pkgs, ...}: {
                    packages.hello.components.exes.hello = {
                      configureFlags = pkgs.lib.optionals pkgs.stdenv.targetPlatform.isMusl [
                        "--disable-executable-dynamic"
                        "--disable-shared"
                        "--ghc-option=-optl=-pthread"
                        "--ghc-option=-optl=-static"
                        "--ghc-option=-optl=-L${prev.gmp6.override { withStatic = true; }}/lib"
                        "--ghc-option=-optl=-L${prev.zlib}/lib"
                        "--ghc-option=-optl=-L${prev.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib"
                        "--ghc-option=-optl=-L${prev.numactl.overrideAttrs (old: { dontDisableStatic = true; })}/lib"
                        "--ghc-option=-optl=-L${prev.ffmpeg.overrideAttrs (old: { dontDisableStatic = true; })}/lib"
                      ];
                    };
                  })
                ];
              };
          })
        ];
        inherit (haskellNix) config;
        pkgs = import nixpkgs { inherit system overlays config; };
        flake = pkgs.helloProject.flake {
          # This adds support for `nix build .#js-unknown-ghcjs-cabal:hello:exe:hello`
          # crossPlatforms = p: [p.ghcjs];
        };
        crossSystem = pkgs.lib.systems.examples.armv7l-hf-multiplatform; # raspberryPi; #armv7l-hf-multiplatform; #muslpi; 
        pkgsCross = import nixpkgs { inherit system overlays config crossSystem; };
        flakeCross = pkgsCross.helloProject.flake { };
        # flakeCross = pkgs.pkgsCross.muslpi.helloProject.flake { };
      in
      flake // {
        # Built by `nix build .`
        defaultPackage = flake.packages."hello:exe:hello";
        packages.cross = flakeCross.packages."hello:exe:hello";
      });
}
