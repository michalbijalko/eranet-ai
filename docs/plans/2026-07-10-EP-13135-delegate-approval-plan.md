# EP-13135 — Implementation Plan: Delegation of evaluation approval ("Delegovanie schvaľovania")

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Story:** EP-13135 · **Dev sub-task:** EP-13157 · **Epic:** EP-13132 · **Branch (both nested repos):** `feat/EP-13132`
**Commit messages (exact, one commit per nested repo):**
- server: `feat(EP-13135, EP-13157): add delegateApproval endpoint for supplier rating approval delegation`
- client: `feat(EP-13135, EP-13157): add approval delegation button and popup to supplier rating detail`

**Authoritative design:** `docs/plans/2026-07-10-EP-13135-delegate-approval-design.md` (decisions there are fixed).

**Goal:** Let the current approver or a responsible person re-assign the approval of a `Sent` supplier evaluation to another approver from the `sr_approval_persons` codebook, with history record and standard approval notification to the new approver.

**Architecture:** One new dedicated REST endpoint on the existing `SrRatingHeaderService` (mirrors `reopenRating`); client adds a button + a popup cloned from `approverSupplierRatingPopup`, a `$resource` action, and reuses the existing history/notification/toast flow. **No Liquibase, no entity/DAO/DTO change, no `ApplicationConfig` change** (the service class is already registered).

**Tech stack:** Java EE 7 / RESTEasy / EclipseLink (server); AngularJS 1.5 ES5 / ui.bootstrap / ui-select (client).

> All line numbers verified 2026-07-10 on `feat/EP-13132`. **Re-confirm by grepping the symbol/literal before editing** — files drift.

---

## Contract between slices (lockstep)

- **Endpoint (decided, follows `reopenRating` declaration + consumption):**
  `GET webresources/sc/srRatingHeader/delegateApproval/{ratingId}/{newApproverId}` → returns the updated `SrRatingHeader` JSON; errors are `400 BAD_REQUEST` via `WebApplicationException` (same as `reopenRating`). GET-with-mutation is the established module pattern (`reopenRating`, `sendNotificationForApprovers`) — do not "fix" it to POST.
- JSON shape unchanged (existing `SrRatingHeader` serialization — `approverId`, `approver.firstAndLastName` already consumed by the client).
- **Ordering: backend first**, then frontend (the resource action 404s until the endpoint exists).

---

## BACKEND slice (`publicERANET-server`) — executor-backend

Single file: `publicERANET-server/public-eranet/src/main/java/sk/innovis/eranetpublic/server/service/SrRatingHeaderService.java`

### B1. Extract approval-persons membership helper

Refactor `isApprover` (L360-369) so the `sr_approval_persons` parsing is reusable for validating an arbitrary user id (keeps logic in one place, per "well-named methods" rule):

```java
private boolean isApprover(final SystemUser currentUser) {
    return isApprovalPerson(currentUser.getId());
}

private boolean isApprovalPerson(final Integer userId) {
    final Setting approvalPersons = settingService.getByNameInternal(Setting.SETTING_NAME_SUPPLIER_RATING_APPROVAL_PERSONS);
    if (approvalPersons != null && approvalPersons.getValue() != null && userId != null) {
        final String[] approvalPersonsArr = approvalPersons.getValue().split(",");
        return Arrays.asList(approvalPersonsArr).contains(userId.toString());
    }
    return false;
}
```

Verify: `isApprover` has no other behaviour change; grep `isApprover(` for callers (used in this class only — confirm).

### B2. New endpoint `delegateApproval`

Add directly below `reopenRating` (L212-228), modelled on it:

```java
@GET
@Path("delegateApproval/{ratingId}/{newApproverId}")
public SrRatingHeader delegateApproval(@PathParam("ratingId") final Integer id, @PathParam("newApproverId") final Integer newApproverId) {
    final SrRatingHeader rating = getEntityByIdInternal(id);
    if (!Objects.equals(rating.getStatus(), SrRatingHeader.Status.Sent)) {
        throw new WebApplicationException(Response.Status.BAD_REQUEST);
    }
    final SystemUser currentUser = getCurrentUser();
    if (!isCurrentApprover(currentUser, rating) && !isResponsiblePerson(currentUser)
        && !currentUser.isInRole(SystemUserGroupType.systemAdministrator)) {
        throw new WebApplicationException(Response.Status.BAD_REQUEST);
    }
    if (!isApprovalPerson(newApproverId)) {
        throw new WebApplicationException(Response.Status.BAD_REQUEST);
    }
    final SystemUser newApprover = systemUserService.getEntityByIdInternal(newApproverId);
    if (newApprover == null) {
        throw new WebApplicationException(Response.Status.BAD_REQUEST);
    }
    rating.setApproverId(newApproverId);
    rating.setApprover(newApprover);
    return updateInternal(rating);
}
```

Notes for the executor (all verified):
- `isCurrentApprover(SystemUser, SrRatingHeader)` exists at L371-373; `isResponsiblePerson` at L386-395; `systemUserService` is already `@EJB`-injected (L69-70) and its API interface declares `getEntityByIdInternal(Integer)`.
- Entity mapping: `approverId` is the **writable** column; `approver` is `@ManyToOne(insertable=false, updatable=false)` (`SrRatingHeader.java` L161-166). Set **both** so the persisted FK changes *and* the returned JSON carries the new approver — exactly what `reopenRating` does when nulling them (L225-226).
- Status untouched — stays `Sent(2)`.
- Do **not** touch the generic `update()` permission block (L110-114) and do **not** send the notification here (client triggers `sendNotificationForApprovers` afterwards, mirroring send-for-approval).
- Class-level `@RolesAllowed(ROLE_NAME_USER)` + `@Path("sc/srRatingHeader")` already apply; no `ApplicationConfig` registration needed.

### B3. Backend verification

1. Build with JDK 8 from `publicERANET-server/`: `mvn -q -pl public-eranet -am compile` (or full `mvn clean package` per the deployment skill) → BUILD SUCCESS.
2. Deploy and smoke via browser dev-tools/curl (authenticated session):
   - as **current approver**: `GET webresources/sc/srRatingHeader/delegateApproval/{id}/{validApproverId}` → 200, response JSON has new `approverId`/`approver`.
   - as **responsible person** (not the approver): → 200.
   - as an unrelated user: → 400.
   - `newApproverId` **not** in `sr_approval_persons`: → 400, `approver_id` unchanged in DB.
   - rating with status != `Sent` (e.g. `InProgress`): → 400.
3. Commit (server repo only): `feat(EP-13135, EP-13157): add delegateApproval endpoint for supplier rating approval delegation`

---

## FRONTEND slice (`publicERANET-client`) — executor-frontend

### F1. i18n — one new key only

`app/scripts.no.min/langs/` (no `scripts/langs` source — edit these directly):
- `sk.js` (near `"SUPPLIER_RATING_APPROVAL"` ~L4763): `"SUPPLIER_RATING_DELEGATE_APPROVAL":"Delegovanie schvaľovania",`
- `en.js` (~L4514): `"SUPPLIER_RATING_DELEGATE_APPROVAL":"Delegation of approval",`
- `hr.js` (next to `"SUPPLIER_RATING_APPROVER"` L1306 — the only SUPPLIER_RATING key hr has, added by EP-13134; keep the English value precedent): `"SUPPLIER_RATING_DELEGATE_APPROVAL":"Delegation of approval",`

**Reuse — do not add:** field label `EDIT_ADMIN_USER_PERSON` = "Osoba" (sk.js L1021 — already the label used by the popup being cloned, so the cloned HTML needs **no label change**); button label `SUPPLIER_RATING_DELEGATE` = "Delegovať" (sk.js L4633); error `FORM_HAS_MISTAKES_ERROR`; toast `SUPPLIER_RATING_SAVED_SUCCESS` = "Hodnotenie bolo uložené." (precedent: evaluator delegation `delegateRating()` uses the same toast).

Verify: exactly one occurrence of the new key per lang file.

### F2. Resource action — `app/scripts/service/resources/srRatingHeaders.js`

1. In `SrRatingHeadersResource` actions, after `reopenRating` (L18-21) add:

```js
delegateApproval: {
    method: 'GET',
    url: 'webresources/sc/srRatingHeader/delegateApproval/:ratingId/:newApproverId'
},
```

2. In the `SrRatingHeaders` factory, after `serviceResult.reopenRating` (L263-268) add:

```js
serviceResult.delegateApproval = function (ratingId, newApproverId, doneCallback) {
    var request = {
        ratingId: ratingId,
        newApproverId: newApproverId
    };
    SrRatingHeadersResource.delegateApproval(request, doneCallback);
};
```

### F3. New popup controller — `app/scripts/controllers/supplierRating/delegateApprovalSupplierRatingPopup.js` (create)

Clone of `approverSupplierRatingPopup.js` with two deliberate differences: **no `rating` resolve/mutation** (the select must start empty — `undefined`, never `null`, per the ui-select reset caveat), and the modal **closes with the selection** instead of writing into the rating:

```js
'use strict';

angular.module('controllers')
	.controller('DelegateApprovalSupplierRatingPopupController', ['$scope',
	'$uibModalInstance',
	'$translate',
	'Users',
	'Alerts',
	'ServerSettings',
	function defineDelegateApprovalSupplierRatingPopupController($scope,
		$uibModalInstance,
		$translate,
		Users,
		Alerts,
		ServerSettings) {

			$scope.selection = {
				approverId: undefined
			};
			$scope.close = $uibModalInstance.dismiss;

			var getApprovalPersons = function () {
				var approvalPersons = ServerSettings.getSetting(ServerSettings.SETTING_NAME_SUPPLIER_RATING_APPROVAL_PERSONS);
				if (approvalPersons && approvalPersons.value) {
					return approvalPersons.value.split(',').map(Number);
				}
				return [];
			};

			$scope.save = function () {
				$scope.submitted = true;
				if ($scope.popupForm.$invalid) {
					Alerts.error($translate.instant('FORM_HAS_MISTAKES_ERROR'));
					return;
				}
				var user = _.find($scope.users, {id: $scope.selection.approverId});
				$uibModalInstance.close({
					approverId: $scope.selection.approverId,
					approver: user
				});
			}

			Users.loadUsersActiveAndInactiveByIds(getApprovalPersons(), function afterLoadUsers(){
				$scope.users = Users.getCompanyUsers(false).items;
			});
		}
	]
);
```

### F4. New popup template — `app/views/supplierRating/delegateApprovalSupplierRatingPopup.html` (create)

Clone of `approverSupplierRatingPopup.html` with the title key swapped and the model rebased to `selection.approverId` (label stays `EDIT_ADMIN_USER_PERSON` = "Osoba"):

```html
<div class="modal-header">
	<h4 class="modal-title">{{'SUPPLIER_RATING_DELEGATE_APPROVAL'|translate}}
		<a class="btn btn-default pull-right modal-header-close-btn" data-ng-click='close()' title={{'CLOSE_DIALOG'|translate}}>
			<i class="fa fa-times"></i>
		</a>
	</h4>
</div>
<div class="modal-body">
	<form name="popupForm" class="smart-form">
		<div class="row">
			<section class="col col-4">
				<label class="label">{{'EDIT_ADMIN_USER_PERSON'|translate}}</label>
			</section>
			<section class="col col-8" data-ng-class='{"state-error": popupForm.approverId.$invalid && submitted}'>
				<ui-select
					name='approverId'
					data-ng-model='selection.approverId'
					search-enabled='true'
					required>
					<ui-select-match>{{$select.selected.formattedName}}</ui-select-match>
					<ui-select-choices repeat='user.id as user in users | filter: {formattedName: $select.search} | orderBy:"formattedName"'>
						<div ng-bind-html="user.formattedName | highlight: $select.search"></div>
					</ui-select-choices>
				</ui-select>
				<div class='note'>{{'MANDATORY'|translate}}</div>
			</section>
		</div>
	</form>
</div>
<div class="modal-footer">
	<button type="button" class="btn btn-primary" data-ng-click="save()">
		{{'SAVE'|translate}}
	</button>
	<button type="button" class="btn btn-default" data-ng-click="close()">
		{{'CANCEL'|translate}}
	</button>
</div>
<script type="text/javascript">
	pageSetUp();
</script>
```

### F5. Register the new controller file — `app/index.html`

Add next to the existing popup registration (L950, `approverSupplierRatingPopup.js`):

```html
	<script src="scripts/controllers/supplierRating/delegateApprovalSupplierRatingPopup.js"></script>
```

That is the whole registration mechanism — the existing popups (`approverSupplierRatingPopup.js` L950, `delegateSupplierRatingPopup.js` L940) appear **only** in `index.html`; **no Gruntfile edit** (the build picks scripts up via the usemin block in `index.html`). Templates need no registration (`$uibModal` loads them by `templateUrl`).

### F6. Controller logic — `app/scripts/controllers/supplierRating/editSupplierRating.js`

1. **Show function** — next to `showReopenRating` (L227-229). Must **not** gate on `isEditDisabled` (a responsible person has `isEditDisabled === true` for a `Sent` rating yet must see the button); guard on `$scope.rating` like `showReopenRating` does:

```js
$scope.showDelegateApproval = function () {
    return $scope.rating && $scope.rating.status === Codebook.SUPPLIER_RATING_STATUS_SENT
        && ($scope.isApprover() || $rootScope.isSupplierRatingResponsiblePerson());
};
```

(`Codebook.SUPPLIER_RATING_STATUS_SENT` = 2, `codebook.js` L3022; `$scope.isApprover` L438-440; `$rootScope.isSupplierRatingResponsiblePerson` defined in `main.js` L369. Sysadmin deliberately **not** included — AC shows the button only to those two; server still allows sysadmin.)

2. **Action function** — next to `delegateRating` (L366-386), following the `reopenRating` save shape (push history → dedicated endpoint → `afterRatingSaved`):

```js
$scope.delegateApproval = function () {
    var oldApprover = $scope.rating.approver ? $scope.rating.approver.firstAndLastName : undefined;
    var modalInstance = $uibModal.open({
        templateUrl: 'views/supplierRating/delegateApprovalSupplierRatingPopup.html',
        controller: 'DelegateApprovalSupplierRatingPopupController'
    });
    modalInstance.result.then(function afterConfirmation(selection) {
        historyToSave.push(createHistoryItem('Delegovanie schvaľovania', selection.approver.firstAndLastName, oldApprover));
        SrRatingHeaders.delegateApproval($scope.rating.id, selection.approverId, function afterDelegate(data) {
            afterRatingSaved(data, function () {
                SrRatingHeaders.sendNotificationForApprovers($scope.rating.id);
                Alerts.success($translate.instant('SUPPLIER_RATING_SAVED_SUCCESS'));
            });
        });
    });
};
```

Why this shape (all verified in the file):
- `createHistoryItem` (L89-97) builds the `EntriesHistory` record; `afterRatingSaved` (L196-213) does the `EntriesHistory.bulkSave` of `historyToSave`, reloads history, recalculates `isEditDisabled` (which hides approve/save buttons for the old approver immediately), and sets the form pristine — same as the `reopenRating` flow (L299-308).
- History values use `firstAndLastName` from the popup's selected user — same source `sendRatingForConfirmation` uses after the approver popup (L276-277).
- Push history **before** the resource call so `afterRatingSaved`'s `bulkSave` includes it.
- `sendNotificationForApprovers` runs **after** the swap, so the standard approval email goes to the **new** approver (server reloads the rating, L183-186).

### F7. Button — `app/views/supplierRating/editSupplierRating.html`

In the footer button block (L323-374), insert **after the approve button** (`showApproveRating()`, L352-358) and before the reopen button (L359-365):

```html
								<button 
									type="button"	
									class='btn btn-default'
									data-ng-show='showDelegateApproval()' 
									data-ng-click='delegateApproval()'>
									{{'SUPPLIER_RATING_DELEGATE'|translate}}
								</button>
```

Same "Delegovať" label as the evaluator-delegation button (L366-372) — they can never be visible together (`showDelegateRating` requires status < Sent, this one requires status === Sent).

### F8. Frontend verification & commit

- Karma/Jasmine: the Karma 0.12 suite **does not start on modern Node** (see `docs/codebase/TESTING.md` caveat) and the single existing spec is a broken scaffold — **do not invent tests or fight Karma**; rely on the manual smoke below.
- JSHint-level sanity: the new controller follows the existing array-DI ES5 pattern; hard-reload the app (`index.html` change) and confirm no console errors on the supplier-rating detail.
- Commit (client repo only, after user confirms the smoke test): `feat(EP-13135, EP-13157): add approval delegation button and popup to supplier rating detail`

---

## Smoke test per acceptance criterion (run after both slices are deployed)

Setup: a rating in **Odoslané na schválenie** (status 2) with approver A; users A (approver), B (another entry in `sr_approval_persons`), R (in `sr_responsible_persons`), X (unrelated).

1. **Button visibility (AC 1-2):** detail as A → "Delegovať" visible next to Schváliť; as R → visible (even though the rest of the form is read-only for R); as X / sysadmin → hidden; on a rating in `InProgress` or `Closed` → hidden (only the *evaluator* Delegovať may show pre-Sent — that one is unchanged).
2. **Popup (AC 3):** click → title "Delegovanie schvaľovania", one field labelled "Osoba", ui-select **empty** on open, options = exactly the `sr_approval_persons` users, Uložiť/Zrušiť.
3. **Validation (AC 4):** Uložiť with empty select → toast "Formulár obsahuje chyby.", popup stays open, field marked with error state.
4. **Delegation (AC 5):** pick B, Uložiť → success toast; detail reloads; status still Odoslané na schválenie. As A: rating gone from the "awaiting my approval" list; reopening the detail shows no Schváliť/Delegovať buttons. As B: rating appears in the awaiting list; Schváliť and Delegovať now visible and working.
5. **Notification (AC 6):** approval email sent to B only (check mail log / dev SMTP); nothing to A. (Same template as standard send-for-approval.)
6. **Activity record (AC 7):** history for the rating contains attribute "Delegovanie schvaľovania" with oldValue = A's name, newValue = B's name (visible via the attribute-history popup or `ce_change_entries` rows for `HISTORY_OBJECT_SUPPLIER_RATING`).
7. **Overview column (AC 8):** Prehľad hodnotení "Schvaľovateľ" column shows B; filtering that column by B's surname matches the row, by A's surname no longer does.
8. **Regression:** standard send-for-approval, approve, and reopen flows unchanged; delegation by re-picking the current approver is a harmless no-op (saves, re-notifies A).

---

## Open questions / risks (none blocking)

1. **Success toast wording** — plan reuses `SUPPLIER_RATING_SAVED_SUCCESS` ("Hodnotenie bolo uložené."), the exact precedent of evaluator delegation. If the user wants a delegation-specific message, add a key at F1 — decision for the user, default is reuse.
2. **Sysadmin sees no button** (server permits, UI hides) — per design decision table; surfacing only for awareness.
3. **`WebApplicationException(BAD_REQUEST)` gives the client no error toast** — identical behaviour to `reopenRating`; the UI prevents all 400 paths (button visibility + required select + codebook-sourced options), so a 400 only occurs on races/tampering. Accepted, matches module behaviour.
4. **Line drift** — re-grep every cited symbol (`reopenRating`, `isApprover`, `serviceResult.reopenRating`, footer buttons, index.html L950, lang anchors) before editing.
