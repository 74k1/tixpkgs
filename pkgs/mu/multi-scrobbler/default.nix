{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "multi-scrobbler";
  version = "0.15.0";

  src = fetchFromGitHub {
    owner = "FoxxMD";
    repo = "multi-scrobbler";
    rev = version;
    hash = "sha256-vhda31xPLxGmnaU/3AnsrcafPvSE1IIbuRmj6xlttjc=";
  };

  npmDepsHash = "sha256-M0F0YnQ35YEioMzt4lJiUM/Iqfrb7/zwUG/vFGl+JSY=";

  npmBuildScript = "build:frontend";

  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  env = {
    npm_config_nodedir = nodejs_24;
  };

  postPatch = ''
    # Fix sqlite-up 0.5.0 API changes: Migrator is no longer generic, apply() takes no args
    substituteInPlace src/backend/common/database/appMigrator.ts \
      --replace-fail 'new Migrator<MigrateBaseContext>(' 'new Migrator(' \
      --replace-fail 'await migrator.apply({db, logger})' 'await migrator.apply()'

    # Rewrite 001_lifecycleLoc.ts migration to work without drizzle context (only raw db from sqlite-up 0.5.0)
    cat > src/backend/common/database/appMigrations/001_lifecycleLoc.ts << 'MIGEOF'
    import type { SqliteDatabase } from 'sqlite-up';

    export const up = async (db: SqliteDatabase): Promise<void> => {
        console.log('Migrating Play lifecycle data to top-level location...');

        let more = true;
        let offset = 0,
            processed = 0,
            updated = 0;
        while (more) {
            const selectStmt = db.prepare('SELECT id, play FROM plays ORDER BY id LIMIT 100 OFFSET ?');
            const rows = await selectStmt.all(offset) as Array<{id: number, play: string}>;
            for (const row of rows) {
                try {
                    const play = JSON.parse(row.play);
                    const lifecycle = play?.meta?.lifecycle;
                    if (lifecycle === undefined) {
                        processed++;
                        continue;
                    }
                    const { steps = [], scrobble } = lifecycle;
                    if (steps.length > 0) {
                        play.lifecycle = structuredClone(steps);
                    }
                    if (scrobble !== undefined) {
                        play.scrobble = structuredClone(scrobble);
                    }
                    delete play.meta.lifecycle;
                    const updateStmt = db.prepare('UPDATE plays SET play = ? WHERE id = ?');
                    await updateStmt.run(JSON.stringify(play), row.id);
                    updated++;
                    processed++;
                } catch (e) {
                    console.warn('Failed to migrate Play', row.id, e);
                }
            }
            offset += 100;
            console.log('Migration Progress: Processed ' + processed + ' | Updated ' + updated);
            if (rows.length < 100) {
                more = false;
            }
        }
    };

    export const down = async (db: SqliteDatabase): Promise<void> => {
        // Rollback not implemented
    };
    MIGEOF
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname}

    cp package.json package-lock.json $out/share/${pname}/
    cp -r dist public src $out/share/${pname}/
    cp -r node_modules $out/share/${pname}/

    makeWrapper ${lib.getExe nodejs_24} $out/bin/${pname} \
      --chdir $out/share/${pname} \
      --set NODE_ENV production \
      --add-flags ./src/backend/index.ts

    makeWrapper ${lib.getExe nodejs_24} $out/bin/${pname}-service \
      --set NODE_ENV production \
      --add-flags $out/share/${pname}/src/backend/index.ts

    runHook postInstall
  '';

  meta = {
    description = "Scrobble plays from multiple sources to multiple clients";
    homepage = "https://multi-scrobbler.app";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ _74k1 ];
    mainProgram = "multi-scrobbler";
  };
}
