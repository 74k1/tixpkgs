{ lib
, python3Packages
, fetchFromGitHub
, idahelper
}:
python3Packages.buildPythonPackage rec {
  pname = "ida-ios-helper";
  version = "1.0.20";
  # format = "setuptools";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "yoavst";
    repo = "ida-ios-helper";
    rev = version;
    hash = "sha256-eUeOl42MPWUgMa/WCSzKu4MhDLwQdn95U64pxcfKCRc=";
  };

  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

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

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "IDA Plugin for ease the reversing of iOS usermode and kernelcache";
    homepage = "https://github.com/yoavst/ida-ios-helper";
    license = licenses.mit;
    maintainers = [ "74k1" ];
    platforms = platforms.all;
  };
}

