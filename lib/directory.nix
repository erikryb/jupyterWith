{ pkgs }:

let
  jupyter = pkgs.python3Packages.jupyterlab;
in

{
  generateDirectory = pkgs.writeScriptBin "generate-directory" ''
    if [ $# -eq 0 ]
      then
        echo "Usage: generate-directory [EXTENSION]"
      else
        DIRECTORY="./jupyterlab"
        echo "Generating directory '$DIRECTORY' with extensions:"

        # we need to copy yarn.lock manually to the staging directory to get
        # write access this seems to be a bug in jupyterlab that doesn't
        # consider that it comes from a folder without read access only as in
        # Nix
        mkdir -p "$DIRECTORY"/staging
        cp ${jupyter}/lib/python3.7/site-packages/jupyterlab/staging/yarn.lock "$DIRECTORY"/staging
        chmod +w "$DIRECTORY"/staging/yarn.lock

        for EXT in "$@"; do echo "- $EXT"; done
        ${jupyter}/bin/jupyter-labextension install "$@" --app-dir="$DIRECTORY" --generate-config
        chmod -R +w "$DIRECTORY"/*
    fi
  '';

  generateLockFile = pkgs.writeScriptBin "generate-lockfile" ''
    if [ $# -eq 0 ]
      then
        echo "Usage: generate-lockfile [EXTENSION]"
      else
        DIRECTORY=$(mktemp -d)
        WORKDIR="workdir"

        mkdir -p "$DIRECTORY"/staging
        cp ${jupyter}/lib/python3.7/site-packages/jupyterlab/staging/yarn.lock "$DIRECTORY"/staging
        chmod +w "$DIRECTORY"/staging/yarn.lock

        echo "Generating lockfile for extensions:"

        for EXT in "$@"; do echo "- $EXT"; done
        ${jupyter}/bin/jupyter-labextension install "$@" --app-dir="$DIRECTORY"

        mkdir -p $WORKDIR/src
        mv "$DIRECTORY/staging/yarn.lock" $WORKDIR/src
        mv "$DIRECTORY/staging/package.json" $WORKDIR/src
        mv "$DIRECTORY/extensions" $WORKDIR
    fi
  '';

  mkDirectoryFromLockFile = { lockfile, packagefile, sha256 }:
    pkgs.stdenv.mkDerivation {
      name = "jupyterlab-from-lockfile";
      phases = [ "installPhase" ];
      nativeBuildInputs = [ pkgs.breakpointHook ];
      buildInputs = with pkgs; [
        jupyter
        nodejs
        nodePackages.webpack
        nodePackages.webpack-cli
      ];
      installPhase = ''
        export HOME=$TMP
        export FOLDER=folder

        # Copy the JupyterLab folder.
        mkdir -p $FOLDER
        cp -R ${jupyter}/lib/python3.7/site-packages/jupyterlab/* $FOLDER
        chmod -R +rw $FOLDER

        # Overwrite yarn.lock and package.json.
        cp ${lockfile} $FOLDER/staging/yarn.lock
        cp ${packagefile} $FOLDER/staging/package.json

        # Rebuild with jlpm.
        chmod +rw $FOLDER/staging/*
        cd $FOLDER/staging
        jlpm install
        jlpm build
        cd ../..

        # Move the Jupyter folder to the correct location.
        mkdir -p $out
        chmod -R +rw $FOLDER
        cp -r folder/{schemas,static,themes,staging,imports.css} $out

        # Install extensions in the folder.
        mkdir -p $out/extensions
        PREFIX=$FOLDER/staging/node_modules
        mkdir package
        for EXTENSION in jupyterlab-ihaskell; do
          cp -r $PREFIX/$EXTENSION/* package
          tar -cvzf $out/extensions/$EXTENSION-0.0.9.tgz package
          rm -rf package/*
        done
      '';

      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = sha256;
    };

  mkDirectoryWith = { extensions }:
    # Creates a JUPYTERLAB_DIR with the given extensions.
    # This operation is impure
    let extStr = pkgs.lib.concatStringsSep " " extensions; in
    pkgs.stdenv.mkDerivation {
      name = "jupyterlab-extended";
      phases = "installPhase";
      buildInputs = [ jupyter pkgs.nodejs ];
      installPhase = ''
        export HOME=$TMP

        mkdir -p appdir/staging
        cp ${jupyter}/lib/python3.7/site-packages/jupyterlab/staging/yarn.lock appdir/staging
        chmod +w appdir/staging/yarn.lock

        jupyter labextension install ${extStr} --app-dir=appdir --debug
        rm -rf appdir/staging/node_modules
        mkdir -p $out
        cp -r appdir/* $out
      '';
    };
}
