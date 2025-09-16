{
  description = "Flake for ...";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            hugo
          ];
        };

        # Builds and minifies website
        # run with "nix run ."
        apps.default = {
          type = "app";
          program =
            let
              script = pkgs.writeShellScriptBin "build" ''
                # Enables "**" glob pattern to be recursive
                shopt -s globstar

                ${pkgs.hugo}/bin/hugo build
                ${pkgs.minhtml}/bin/minhtml public/**/*.{html,css,js}

                echo "Built and minified files"
                echo "Ensure you clear ./public before running this script to remove unused files"
              '';
            in
            "${script}/bin/build";
        };
      }
    );
}
