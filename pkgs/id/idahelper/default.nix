{ lib
, python3Packages
}:

python3Packages.buildPythonPackage rec {
  pname = "idahelper";
  version = "1.0.18";

  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "sha256-8bi7V6z75gAigQvt0ttHrCYLkmRPrRg/dNR3HshZ/+g=";
  };

  pyproject = true;

  nativeBuildInputs = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  propagatedBuildInputs = [ ];

  pythonImportsCheck = [ "idahelper" ];
  doCheck = false;

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Standard library for IDA Pro plugins";
    homepage = "https://github.com/yoavst/idahelper";
    license = licenses.mit;
  };
}
