# AngularJS Bootstrap (ui.bootstrap) — Quick Reference

PSK uses AngularJS 1.5 + Bootstrap 3 + SmartAdmin + `ui.bootstrap` v1.3.3.
When uncertain about a directive, look at existing usage in `publicERANET-client/app/views/` first.

## Key directives

### Modal
```javascript
// Inject $uibModal, then:
var modalInstance = $uibModal.open({
    templateUrl: 'views/modals/myModal.html',
    controller: 'MyModalController',
    resolve: {
        item: function () { return $scope.selectedItem; }
    }
});
modalInstance.result.then(function (result) { /* confirmed */ }, function () { /* dismissed */ });
```

### Tabs
```html
<uib-tabset>
    <uib-tab heading="{{ 'TAB_LABEL' | translate }}">
        <!-- content -->
    </uib-tab>
</uib-tabset>
```

### Datepicker popup
```html
<input type="text" uib-datepicker-popup="dd.MM.yyyy"
       ng-model="myDate" is-open="dateOpen" />
<button ng-click="dateOpen = true">...</button>
```

### Pagination
```html
<uib-pagination total-items="totalCount" ng-model="currentPage"
                items-per-page="pageSize" max-size="5">
</uib-pagination>
```

### Tooltip
```html
<button uib-tooltip="{{ 'TOOLTIP_KEY' | translate }}">...</button>
```

## Bootstrap 3 grid

```html
<div class="row">
    <div class="col-md-6">left</div>
    <div class="col-md-6">right</div>
</div>
```

## Bootstrap 3 form pattern

```html
<div class="form-group" ng-class="{'has-error': form.field.$invalid && form.field.$dirty}">
    <label class="control-label">{{ 'FIELD_LABEL' | translate }}</label>
    <input type="text" class="form-control" ng-model="model.field" name="field" required />
    <span class="help-block" ng-show="form.field.$error.required">
        {{ 'VALIDATION_REQUIRED' | translate }}
    </span>
</div>
```

## ng-table

```html
<table ng-table="tableParams" class="table table-bordered table-hover">
    <tr ng-repeat="row in $data">
        <td data-title="'COLUMN_HEADER' | translate">{{ row.value }}</td>
    </tr>
</table>
```

## angular-ui-select (dropdown)

```html
<ui-select ng-model="selected" theme="bootstrap">
    <ui-select-match placeholder="{{ 'SELECT_PLACEHOLDER' | translate }}">
        {{ $select.selected.name }}
    </ui-select-match>
    <ui-select-choices repeat="item in items | filter: $select.search">
        <span ng-bind-html="item.name | highlight: $select.search"></span>
    </ui-select-choices>
</ui-select>
```
