--- Organization Model - an in-game organization (a job like police/EMS, or
--- a gang). See docs/superpowers/specs/2026-08-11-organizations-and-permissions-design.md.
Organization = BaseModel:extend('organizations')

Organization.primaryKey = 'id'
Organization.timestamps = true
Organization.fillable = { 'name', 'short_code', 'colour', 'type' }
Organization.hidden = {}

return Organization
