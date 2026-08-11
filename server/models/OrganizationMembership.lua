--- OrganizationMembership Model - one character's membership row in one
--- Organization (character_id, organization_id, rank_id). See
--- docs/superpowers/specs/2026-08-11-organizations-and-permissions-design.md.
OrganizationMembership = BaseModel:extend('organization_memberships')

OrganizationMembership.primaryKey = 'id'
OrganizationMembership.timestamps = true
OrganizationMembership.fillable = { 'character_id', 'organization_id', 'rank_id' }
OrganizationMembership.hidden = {}

return OrganizationMembership
