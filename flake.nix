{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
    hasql-api.url = "github:mkleczek/hasql-api";
    hasql-pool.url = "github:mkleczek/hasql-pool";
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = builtins.filter (s: s != "mipsel-linux") nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.haskell-flake.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
        inputs.mission-control.flakeModule
      ];
      perSystem = { self', system, lib, config, pkgs, ... }: {

        # Typically, you just want a single project named "default". But
        # multiple projects are also possible, each using different GHC version.
        haskellProjects.main = {
          # If you have a .cabal file in the root, this option is determined
          # automatically. Otherwise, specify all your local packages here.
          # packages.example.root = ./.;

          # The base package set representing a specific GHC version.
          # By default, this is pkgs.haskellPackages.
          # You may also create your own. See https://haskell.flake.page/package-set
          # basePackages = pkgs.haskellPackages;

          # Dependency overrides go here. See https://haskell.flake.page/dependency
          source-overrides = {
            hasql-api = inputs.hasql-api;
            hasql-pool = inputs.hasql-pool;
          };
          # overrides = self: super: { };

          devShell = {
            tools = hp: {
              treefmt = config.treefmt.build.wrapper;
            } // config.treefmt.build.programs;
            hlsCheck.enable = true;
          };
        };

        treefmt.config = {
          inherit (config.flake-root) projectRootFile;
          package = pkgs.treefmt;

          programs.ormolu.enable = true;
          programs.nixpkgs-fmt.enable = true;
          programs.cabal-fmt.enable = true;
          programs.hlint.enable = true;

          # We use fourmolu
          programs.ormolu.package = pkgs.haskellPackages.fourmolu;
          settings.formatter.ormolu = {
            options = [
              "--ghc-opt"
              "-XImportQualifiedPost"
            ];
          };
        };

        # Dev shell scripts.
        mission-control.scripts = {
          docs = {
            description = "Start Hoogle server for project dependencies";
            exec = ''
              echo http://127.0.0.1:8888
              hoogle serve -p 8888 --local
            '';
            category = "Dev Tools";
          };
          repl = {
            description = "Start the cabal repl";
            exec = ''
              cabal repl "$@"
            '';
            category = "Dev Tools";
          };
          fmt = {
            description = "Format the source tree";
            exec = "${lib.getExe config.treefmt.build.wrapper}";
            category = "Dev Tools";
          };
          run = {
            description = "Run the project with ghcid auto-recompile";
            exec = ''
              ghcid -c "cabal repl exe:hasql-api" --warnings -T :main
            '';
            category = "Primary";
          };
        };

        # haskell-flake doesn't set the default package, but you can do it here.
        packages.default = self'.packages.main-hasql-notifications;
        # Default shell.
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            self'.devShells.main
            config.mission-control.devShell
          ];
        };
      };
    };
}
