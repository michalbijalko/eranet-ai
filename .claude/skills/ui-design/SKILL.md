---
name: ui-design
description: How to build UI in PSK - Bootstrap 3 + SmartAdmin theme + AngularJS Bootstrap (ui.bootstrap). Use whenever building, styling, or restyling any UI - components, pages, layouts, forms, tables - or when the user mentions "dizajn", "UI", "vzhľad", "komponenty", "frontend look". Always reuse existing components; never hand-roll CSS to fake the look.
---

# UI & design system (PSK)

PSK uses **Bootstrap 3** + the **SmartAdmin** jQuery admin theme + **AngularJS Bootstrap
(`ui.bootstrap`)** for all UI. The look is data-dense: tables, forms, and dashboards.
Do not introduce a new component library or redesign. Reuse what is already here.

## Component toolkit

| Need | Use |
|------|-----|
| Grid / layout | Bootstrap 3 grid (`col-xs-*`, `col-sm-*`, `col-md-*`, `col-lg-*`) |
| Buttons | Bootstrap `.btn .btn-primary`, `.btn-default`, `.btn-danger`, etc. |
| Forms | Bootstrap `.form-group`, `.form-control`, `.has-error` / `.has-success` |
| Modals | `ui.bootstrap` `$uibModal` service + `<div uib-modal-*>` directives |
| Dropdowns (select) | `angular-ui-select` (`ui-select` directive) or `angular-ui-select2` for legacy |
| Data tables | `ng-table` directive (`ng-table`, `ng-table-pagination`) |
| Date/time pickers | SmartAdmin jQuery widgets (`$.fn.datepicker`) or `ui.bootstrap` datepicker |
| File upload | `ng-file-upload` (`ngf-drop`, `ngf-select`) |
| Rich text | `ng-ckeditor` (`ng-ckeditor` directive) |
| Alerts / notifications | `Alerts.error()`, `Alerts.success()`, `Alerts.longError()` from `alerts.js` — wraps SmartAdmin `$.smallBox()` |
| Icons | SmartAdmin icon font or Bootstrap Glyphicons (`glyphicon glyphicon-*`) |
| Panels / cards | Bootstrap `.panel .panel-default`, `.panel-heading`, `.panel-body` |
| Tabs | `ui.bootstrap` `uib-tabset` / `uib-tab` directives |
| Pagination | `ng-table` pagination or `ui.bootstrap` `uib-pagination` |

## Rules

- **Copy existing screen patterns.** Before building a new screen, find the most similar
  existing view in `publicERANET-client/app/views/` and copy its structure.
- **Reuse existing directives.** Directives in `app/scripts/directives/` (e.g.,
  `datetimeCell`, `decimalInput`, `attachmentsCell`) already solve common table-cell
  rendering problems.
- **No inline style attributes.** Use Bootstrap utility classes or existing SmartAdmin
  CSS classes. If a new style is genuinely needed, add it to the appropriate existing
  stylesheet, not as `style="..."` on an element.
- **Mind ancestor-scoped theme CSS.** The same class can render differently by context —
  e.g. `.smart-form .label` forces `display:block` + larger font. When copying an existing
  component's look, replicate its rendering context (or the ancestor rule); identical
  classes ≠ identical result.
- **Localization.** All user-visible text must use `{{ 'TRANSLATION_KEY' | translate }}`
  via `angular-translate`. Translation keys in English; Slovak values in
  `publicERANET-client/app/i18n/sk.json`.
- **Date and number formatting.** Use the existing filters (e.g.,
  `harmonogramTaskStatusFilter`, `undefinedNumberFilter`) or `$filter('date')` with Slovak
  locale settings. Do not hardcode date format strings.

## SmartAdmin layout

The shell layout is managed by SmartAdmin directives in `app.js` / `app.config.js`.
The sidebar and topbar are SmartAdmin components. Do not rebuild them — only add
menu items in the route config in `ng.app.js`.

## References

For detailed AngularJS Bootstrap (`ui.bootstrap`) API, see the official docs for
version `~1.3.3` (the pinned Bower version). When uncertain about a directive's API,
look at how it is used in the existing views rather than guessing from memory.
