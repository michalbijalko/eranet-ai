---
name: app-foundation
description: What every new module or feature area in PSK needs before feature work begins - correct layer setup, dev environment running, migrations in place, and existing patterns followed. Use whenever adding a new Java service, a new AngularJS screen area, or setting up a fresh dev environment. Apply early; these are prerequisites, not features.
---

# Module / feature foundation (PSK)

PSK is a brownfield system. We extend it ticket by ticket — no new frameworks or rewrites.
Before touching code, ensure the following are in place.

## Dev environment checklist

1. **WildFly 26.1.3 running** — WAR deployed at context root `/public` (or as configured).
2. **MySQL containers up** — `docker compose up -d` in `publicERANET-server/` starts both:
   - `eranet_mysql` on port 3307 (application DB)
   - `jackrabbit_mysql` on port 3308 (JCR/document store)
3. **Liquibase migrations applied** — run `configS.bat` from project root before first boot and after pulling new changelog files. Schema must match the running code.
4. **Aspose license present** — `publicERANET-server/src/main/resources/META-INF/Aspose.Total.Java.lic` must exist at startup; it is committed to the repo.
5. **Client dependencies installed** — in `publicERANET-client/`: `npm install` then `bower install`. Run `grunt serve` for the dev server on port 9000.

## Adding a new Java EE service

- Create a `@Stateless` EJB that extends `BaseService<YourEntity>` — this gives you date formats, logger injection, and the service-layer pattern.
- Create a matching `YourEntityDao` that extends `BaseDao<YourEntity>` — never call `EntityManager` directly in a service.
- Add `@Path`, `@Produces(MediaType.APPLICATION_JSON)`, `@Consumes(MediaType.APPLICATION_JSON)` to the service class.
- Register the new service class in `ApplicationConfig.java` (`getClasses()` set).
- Apply `@RolesAllowed(SystemUserGroup.ROLE_NAME_USER)` to the class; use `@PermitAll` only for genuinely public endpoints.
- Register every new `@Entity` in `persistence.xml` (`<class>…</class>`). A successful Maven build is NOT enough — an unlisted entity only fails at deploy (EclipseLink "uses a non-entity … as target entity" at WildFly startup).

## Adding a new AngularJS screen

- Controller in `publicERANET-client/app/scripts/controllers/` — extend the `controllers` module, follow the `PascalCaseController` naming, use array DI notation.
- REST resource factory in `publicERANET-client/app/scripts/service/resources/` — two parts: `EntityNameResource` (`$resource`) + `EntityName` (business wrapper). URL base: `webresources/sc/`.
- Route added in the `eranetPublic.config([...])` block in `ng.app.js`.
- View template in `publicERANET-client/app/views/`.
- New files must be listed in `Gruntfile.js` (or picked up by glob patterns) so Grunt includes them in the build.

## Scope discipline

Implement exactly what the Jira ticket asks for — no more, no less. Read the ticket (via the Atlassian MCP) before writing any code. See `coding-conventions` and `issue-tracking`.
