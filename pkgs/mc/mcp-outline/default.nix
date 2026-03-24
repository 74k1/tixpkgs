{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

python3Packages.buildPythonApplication rec {
  pname = "mcp-outline";
  version = "1.8.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Vortiago";
    repo = "mcp-outline";
    tag = "v${version}";
    hash = "sha256-3QjwnoEfregVCNlC24qczGWUOo4zQbcwLkh0e6F9hxc=";
  };

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
    pythonRelaxDepsHook
  ];

  dependencies = with python3Packages; [
    mcp
    httpx
    python-dotenv
  ];

  pythonRelaxDeps = [
    "mcp"
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-asyncio
    pytest-cov-stub
    anyio
  ];

  # Integration and e2e tests require a running MCP server / Docker stack
  disabledTestPaths = [
    "tests/e2e"
  ];

  pytestFlagsArray = [
    "-m"
    "'not integration and not e2e'"
    "--ignore=tests/features/test_dynamic_tools.py"
  ];

  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  pythonImportsCheck = [ "mcp_outline" ];

  meta = {
    description = "A Model Context Protocol (MCP) server for Outline";
    homepage = "https://github.com/Vortiago/mcp-outline";
    changelog = "https://github.com/Vortiago/mcp-outline/releases/tag/${src.tag}";
    license = lib.licenses.mit;
    maintainers = [ "74k1" ];
    mainProgram = "mcp-outline";
  };
}
