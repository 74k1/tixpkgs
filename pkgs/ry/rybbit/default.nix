{
  lib,
  buildNpmPackage,
  nodejs,
  importNpmLock,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "rybbit";
  version = "1.6.1";

  src = fetchFromGitHub {
    owner = "rybbit-io";
    repo = "rybbit";
    rev = "v${version}";
    hash = "sha256-w/nuNp0ojXic8xxyeNxV+sn+831VhGGx3MktzR94dDk=";
  };

  npmDepsHash = "sha256-7Wdf8NaizgIExeX+Kc8wn5f20al0bnxRpFoPy6p40jw=";

  npmDeps = importNpmLock.buildNodeModules {
    npmRoot = ./server;
    inherit nodejs;
  };

  meta = with lib; {
    description = "open-source and privacy-friendly alternative to Google Analytics that is 10x more intuitive.";
    homepage = "https://www.rybbit.io/";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ "74k1" ];
    mainProgram = "rybbit";
  };
}
