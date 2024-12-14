{ lib
, python3Packages
, fetchFromGitHub
, fetchPypi
, writeTextFile
}:

let
  slskd-api = python3Packages.buildPythonPackage rec {
    pname = "slskd-api";
    version = "0.1.5";
    format = "pyproject";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-LmWP7bnK5IVid255qS2NGOmyKzGpUl3xsO5vi5uJI88=";
    };

    nativeBuildInputs = [
      python3Packages.pip
      python3Packages.setuptools-git-versioning
      python3Packages.wheel
    ];

    propagatedBuildInputs = [
      python3Packages.requests
    ];
  };

  defaultConfig = writeTextFile {
    name = "soularr-default-config.ini";
    text = /* ini */ ''
      [Lidarr]
      api_key = yourlidarrapikeygoeshere
      host_url = http://localhost:8686
      download_dir = /lidarr/path/to/slskd/downloads

      [Slskd]
      api_key = yourslskdapikeygoeshere
      host_url = http://localhost:5030
      download_dir = /path/to/your/Slskd/downloads
      delete_searches = False
      stalled_timeout = 3600

      [Release Settings]
      use_most_common_tracknum = True
      allow_multi_disc = True
      accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
      accepted_formats = CD,Digital Media,Vinyl

      [Search Settings]
      search_timeout = 5000
      maximum_peer_queue = 50
      minimum_peer_upload_speed = 0
      allowed_filetypes = flac,mp3
      search_for_tracks = True
      album_prepend_artist = False
      track_prepend_artist = True
      search_type = incrementing_page
      number_of_albums_to_grab = 10
      remove_wanted_on_failure = False

      [Logging]
      level = INFO
      format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
      datefmt = %Y-%m-%dT%H:%M:%S%z
    '';
  };
in
python3Packages.buildPythonPackage rec {
  pname = "soularr";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "mrusse";
    repo = pname;
    rev = "9248e59044e05ab8083b3065df8ddcab03232332";
    hash = "sha256-pTQX8GWTlKTASu1sT1fobKHB70gUHTRGqvrlgYQt1B8=";
  };

  preBuild = ''
    cat > setup.py << PYTHON
from setuptools import setup

with open("requirements.txt") as f:
    install_requires = f.read().splitlines()

setup(
  name='${pname}',
  version='${version}',
  author='mrusse',
  description='${meta.description}',
  install_requires=install_requires,
  scripts=[
    '${pname}.py',
  ],
)
PYTHON
  '';

  postInstall = ''
    mv -v $out/bin/${pname}.py $out/bin/${pname}
    
    mkdir -p $out/share/${pname}
    cp ${defaultConfig} $out/share/${pname}/config.ini.example
  '';

  dependencies = [
    python3Packages.music-tag
    python3Packages.pyarr
    slskd-api
  ];

  build-system = [
    python3Packages.pip
  ];

  meta = {
    description = "A Python script that connects Lidarr with Soulseek!";
    homepage = "https://github.com/mrusse/soularr";
    maintainers = [ "74k1" ];
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
