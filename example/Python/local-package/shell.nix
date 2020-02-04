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
      sha256 = "14bgy5xx1sinzihhzak8dgabs0ih7ajhiahwf5frnwn45zdn78lx";
    };
  };
in
  jupyterlabWithKernels.env
