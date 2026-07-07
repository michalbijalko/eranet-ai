---
name: deploy
description: TTSK release process - Maven WAR build, WildFly deployment, and Liquibase migrations. Invoke manually when deploying a change. Do NOT run automatically.
disable-model-invocation: true
argument-hint: [environment]
---

# Deploy / release (TTSK)

Manual only — never deploy because code "looks ready." A human invokes this.

## Stack

- **Server:** Java EE 7 WAR deployed on **WildFly 26.1.3**.
- **Build:** Maven (`mvn clean package` produces `publicERANET-server/target/eranet-server-trnavavuctest-1.0-SNAPSHOT.war`).
- **Client:** Grunt (`grunt build` produces `publicERANET-client/dist/`).
- **Database migrations:** Liquibase CLI via `configS.bat` at project root.
- **DB containers:** MySQL 5.7 via Docker Compose in `publicERANET-server/`.

## Steps

**1. Build the server WAR**
```bash
cd publicERANET-server
mvn clean package
```

**2. Build the client**
```bash
cd publicERANET-client
npm install
bower install
grunt build
```

**3. Apply any new Liquibase migrations**
```
configS.bat
```
Run from the project root. Connects to the DB using the WildFly-bundled MySQL connector.
Always run migrations **before** deploying the new WAR.

**4. Deploy the WAR to WildFly**

Hot-deploy: copy (or replace) the WAR into WildFly's `deployments/` folder.
```bash
cp publicERANET-server/target/eranet-server-trnavavuctest-1.0-SNAPSHOT.war \
   <WILDFLY_HOME>/standalone/deployments/
```
WildFly detects the new WAR and redeploys automatically. Check the log for
`Deployed "eranet-server-trnavavuctest-1.0-SNAPSHOT.war"`.

**5. Verify**

Open the app in the browser and smoke-test the affected area. See `testing`.

## Dev environment quick start

```bash
# Start MySQL containers
cd publicERANET-server && docker compose up -d

# Apply migrations
configS.bat   # from project root

# Start client dev server (proxied to WildFly on 8080)
cd publicERANET-client && grunt serve
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| WAR won't start, JNDI lookup fails | Check WildFly data source `PublicTrnavavucDS` is configured and MySQL is up |
| `Aspose.Total.Java.lic` error at startup | Ensure the license file is in `META-INF/` (it is committed; check the build includes it) |
| Liquibase error on migration | Check changelog XML for the new changeset; verify DB connection in `configS.bat` |
| Client gives 404 for `webresources/sc/...` | WildFly not running or WAR not deployed; check WildFly admin console |
| `bower install` fails | Ensure Bower CLI is installed globally: `npm install -g bower` |
| `grunt build` fails | Run `npm install` first; check Node.js version ≥ 0.10 |

## Note on environments

There is currently one shared environment (WildFly + MySQL on dev machine or server).
If a separate test environment exists, confirm the WildFly host/port and DB connection
before deploying there.
