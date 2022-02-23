{ lib
, buildPythonPackage
, fetchFromGitHub
, karton-core
, malduck
}:

buildPythonPackage rec {
  pname = "karton-config-extractor";
  version = "2.0.2";

  src = fetchFromGitHub {
    owner = "CERT-Polska";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-r0WMtfau5zeVDSjxy2h96INQl8bm4EP0IAcgnGPhTtk=";
  };

  propagatedBuildInputs = [
    karton-core
    malduck
  ];

  postPatch = ''
    substituteInPlace requirements.txt \
      --replace "malduck==4.1.0" "malduck"
  '';

  # Project has no tests
  doCheck = false;
  pythonImportsCheck = [ "karton.config_extractor" ];

  meta = with lib; {
    description = "Static configuration extractor for the Karton framework";
    homepage = "https://github.com/CERT-Polska/karton-config-extractor";
    license = with licenses; [ bsd3 ];
    maintainers = with maintainers; [ fab ];
  };
}
