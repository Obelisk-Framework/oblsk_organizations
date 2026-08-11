--- Department Model - a pure grouping label within one Organization. See
--- docs/superpowers/specs/2026-08-11-organizations-and-permissions-design.md.
Department = BaseModel:extend('departments')

Department.primaryKey = 'id'
Department.timestamps = true
Department.fillable = { 'organization_id', 'name' }
Department.hidden = {}

HasPermissions.apply(Department, 'department')

return Department
