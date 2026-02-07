{ lib
, python3Packages
}:

python3Packages.buildPythonPackage rec {
  pname = "idahelper";
  version = "1.0.17";

  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "sha256-mzbzRVQZ6+7So3IHZdCCLhWfnesqAJrsj+48h1gdEE8=";
  };

  pyproject = true;

  nativeBuildInputs = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  propagatedBuildInputs = [ ];

  pythonImportsCheck = [ "idahelper" ];
  doCheck = false;

  meta = with lib; {
    description = "Standard library for IDA Pro plugins";
    homepage = "https://github.com/yoavst/idahelper";
    license = licenses.mit;
  };
}
