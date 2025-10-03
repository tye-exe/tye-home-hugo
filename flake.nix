{
  description = "Flake for hugo website";

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

        # Run with "nix run ."
        apps.default = {
          type = "app";
          program =
            let
              dest = "server_upload";
              upload = "upload.tar";
              upload_script = pkgs.writeShellScriptBin "build" ''
                # Enables "**" glob pattern to be recursive
                shopt -s globstar

                ${pkgs.hugo}/bin/hugo build -d ${dest}
                ${pkgs.minhtml}/bin/minhtml ${dest}/**/*.{html,css,js}

                ${pkgs.ouch}/bin/ouch c ${dest} ${upload}
                scp ${upload} tyevps:~/website/nginx/
                ssh tyevps "cd website/nginx; bash update.sh"

                rm -r ${dest} ${upload}

                echo "Built, uploaded, and deployed website."
              '';
            in
            "${upload_script}/bin/build";
        };
      }
    );
}
