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

                # Uploading one file is quicker than many small files
                ${pkgs.ouch}/bin/ouch c ${dest} ${upload}
                scp ${upload} tyevps:~/website/nginx/
                ssh tyevps "cd website/nginx; bash update.sh"

                rm -r ${dest} ${upload}

                echo "Built, uploaded, and deployed website."
              '';
            in
            "${upload_script}/bin/build";
        };

        # Generates the syntax highlightling css file, which works for both dark and light mode.
        apps."highlighting" = {
          type = "app";
          program =
            let
              dest = "assets/syntax_highlighting.css";
              # Get themes from https://gohugo.io/quick-reference/syntax-highlighting-styles/
              dark_theme = "monokai";
              light_theme = "monokailight";
              script = pkgs.writeShellScriptBin "syntax_highlighting" ''

                echo "/* Script generated file. Do not edit. */" > ${dest}
                ${pkgs.hugo}/bin/hugo gen chromastyles --style=${dark_theme} >> ${dest}
                echo "@media (prefers-color-scheme: light) {" >> ${dest}
                ${pkgs.hugo}/bin/hugo gen chromastyles --style=${light_theme} >> ${dest}
                echo "}" >> ${dest}

                echo "Regenderated 'assets/syntax_highlighting.css'"
              '';
            in
            "${script}/bin/syntax_highlighting";
        };

        # Performed slightly better (compression) than "woff2_compress" cli tool
        apps."fontConvert" = {
          type = "app";
          program = "${pkgs.writers.writePython3 "font_convert"
            {
              libraries = [
                pkgs.python313Packages.fonttools
                pkgs.python313Packages.brotli
              ];
            }
            ''
              import sys
              import os


              def convert(file, format):
                  from fontTools.ttLib import TTFont
                  font = TTFont(file)
                  font.flavor = format
                  out = os.path.splitext(file)[0]+f".{format}"
                  font.save(out)


              files = sys.argv[1:]
              if len(files) == 0:
                  exit("Please provide input files to convert")

              for file in files:
                  convert(file, "woff2")
                  convert(file, "woff")
            ''
          }";
        };
      }
    );
}
