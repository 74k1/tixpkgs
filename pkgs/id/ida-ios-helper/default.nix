{ lib
, python3Packages
, fetchurl
, idahelper
}:
python3Packages.buildPythonPackage rec {
  pname = "ida-ios-helper";
  version = "1.0.19";  # Check PyPI for latest version
  # format = "setuptools";
  pyproject = true;

  # src = fetchPypi {
  #   inherit pname version;
  #   sha256 = lib.fakeSha256;
  # };

  src = fetchurl {
    url = "https://github.com/yoavst/ida-ios-helper/releases/download/${version}/ida_ios_helper-${version}.tar.gz";
    hash = "sha256-SDH+KoOopd+bbPXQGfq6i4mRD3H2O2SMMoOcD8EE1eU=";
  };

  nativeBuildInputs = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  propagatedBuildInputs = [
    idahelper
  ];

  # Skip tests if they require IDA Pro to be installed
  doCheck = false;

  # pythonImportsCheck = [ "ida_ios_helper" ];
  pythonImportsCheck = [ ];

  meta = with lib; {
    description = "IDA Plugin for ease the reversing of iOS usermode and kernelcache";
    homepage = "https://github.com/yoavst/ida-ios-helper";
    license = licenses.mit;
    maintainers = [ "74k1" ];
    platforms = platforms.all;
  };
}

