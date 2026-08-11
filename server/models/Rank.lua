--- Rank Model - one hierarchy level within one Organization. grade is the
--- ordering (higher = more senior); permission checks go through
--- HasPermissions, not grade comparisons. See
--- docs/superpowers/specs/2026-08-11-organizations-and-permissions-design.md.
Rank = BaseModel:extend('ranks')

Rank.primaryKey = 'id'
Rank.timestamps = true
Rank.fillable = { 'organization_id', 'name', 'grade' }
Rank.hidden = {}

HasPermissions.apply(Rank, 'rank')

return Rank
