let
  jupyterLibPath = ../../..;
  jupyter = import jupyterLibPath {};

  iPythonWithPackages = jupyter.kernels.iPythonWith {
    name = "local-package";
    packages = p:
      let
        myPythonPackage = p.buildPythonPackage {
          pname = "my-python-package";
          version = "0.1.0";
          src = ./my-python-package;
        };
      in
        [ myPythonPackage ];
  };

  jupyterlabWithKernels = jupyter.jupyterlabWith {
    kernels = [ iPythonWithPackages ];
    extraPackages = p: [p.hello];
    directory = jupyter.mkDirectoryFromLockFile {
      lockfile = ./yarn.lock;
      packagefile = ./package.json;
      sha256 = "1a40kgc8kh7mzlmmswqis4wa80kvv5zv7j9g9n37ls4rw3d2plgn";
    };
  };
in
  jupyterlabWithKernels.env
