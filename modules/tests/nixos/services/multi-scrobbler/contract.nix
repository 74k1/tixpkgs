{ lib, pkgs, tixpkgs, ... }:
let
  contractFile = ../../../../nixos/services/multi-scrobbler/contract.json;
  packageRoot = "${tixpkgs.multi-scrobbler}/share/multi-scrobbler";
in
pkgs.runCommand "multi-scrobbler-module-contract" { } ''
  ${lib.getExe pkgs.nodejs_24} --input-type=module - ${contractFile} ${packageRoot} <<'NODE'
  import { readFile } from 'node:fs/promises';
  import { pathToFileURL } from 'node:url';

  const [contractPath, packageRoot] = process.argv.slice(2);
  const contract = JSON.parse(await readFile(contractPath, 'utf8'));
  const configRoot = packageRoot + '/src/backend/common/infrastructure/config';
  const sourceModule = await import(pathToFileURL(configRoot + '/source/sourcesMap.ts'));
  const clientModule = await import(pathToFileURL(configRoot + '/client/clientsMap.ts'));
  const sourceMap = sourceModule.sourceConfigSchemaMapAsync;
  const clientMap = clientModule.clientConfigSchemaMapAsync;

  function compare(label, expected, actual) {
    const expectedSet = new Set(expected);
    const actualSet = new Set(actual);
    const missing = [...actualSet].filter(value => !expectedSet.has(value)).sort();
    const obsolete = [...expectedSet].filter(value => !actualSet.has(value)).sort();
    if (missing.length || obsolete.length) {
      console.error(label + ': missing from module: ' + missing.join(', '));
      console.error(label + ': absent upstream: ' + obsolete.join(', '));
      process.exitCode = 1;
    }
  }

  compare('Source types', contract.sourceTypes, Object.keys(sourceMap));
  compare('Client types', contract.clientTypes, Object.keys(clientMap));
  const prefixes = [];
  for (const loadSchema of [...Object.values(sourceMap), ...Object.values(clientMap)]) {
    const [, , envSchema] = await loadSchema();
    if (typeof envSchema?.prefix !== 'string' || envSchema.prefix.length === 0) {
      throw new Error('Upstream environment schema has no prefix');
    }
    prefixes.push(envSchema.prefix + '_');
  }
  compare('Environment prefixes', contract.environmentPrefixes, prefixes);
  NODE
  touch "$out"
''
