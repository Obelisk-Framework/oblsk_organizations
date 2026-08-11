--- OrganizationService (server) - organizations, their departments and
--- ranks, and character membership within them. See
--- docs/superpowers/specs/2026-08-11-organizations-and-permissions-design.md.
OrganizationService = {}

--- Whether a character may hold membership in more than one organization
--- at once. This framework has no Config global convention (see the plan's
--- Global Constraints), so this is a plain constant, edit directly.
OrganizationService.ALLOW_MULTIPLE_MEMBERSHIPS = false

--- @param name string
--- @return number orgId
function OrganizationService.create(name)
    return QueryBuilder.new('organizations'):insert({
        name = name,
        created_at = Database.now(),
        updated_at = Database.now(),
    })
end

--- @param orgId number
--- @param name string
function OrganizationService.rename(orgId, name)
    QueryBuilder.new('organizations'):where('id', orgId):update({
        name = name,
        updated_at = Database.now(),
    })
end

--- Cascades: removes this organization's departments, ranks, memberships,
--- department-member rows, and every permission grant made to one of its
--- departments/ranks, so nothing is left pointing at a deleted
--- organization_id and no grant becomes an orphaned row.
--- @param orgId number
function OrganizationService.delete(orgId)
    local memberships = QueryBuilder.new('organization_memberships'):where('organization_id', orgId):getSync()
    for _, membership in ipairs(memberships) do
        QueryBuilder.new('organization_department_members'):where('membership_id', membership.id):delete()
    end

    local departments = QueryBuilder.new('departments'):where('organization_id', orgId):getSync()
    for _, department in ipairs(departments) do
        PermissionService.revokeAll('department', department.id)
    end

    local ranks = QueryBuilder.new('ranks'):where('organization_id', orgId):getSync()
    for _, rank in ipairs(ranks) do
        PermissionService.revokeAll('rank', rank.id)
    end

    QueryBuilder.new('organization_memberships'):where('organization_id', orgId):delete()
    QueryBuilder.new('departments'):where('organization_id', orgId):delete()
    QueryBuilder.new('ranks'):where('organization_id', orgId):delete()
    QueryBuilder.new('organizations'):where('id', orgId):delete()
end

--- @param orgId number
--- @param name string
--- @return number deptId
function OrganizationService.addDepartment(orgId, name)
    return QueryBuilder.new('departments'):insert({
        organization_id = orgId,
        name = name,
        created_at = Database.now(),
        updated_at = Database.now(),
    })
end

--- Cascades: removes this department's department-member rows and every
--- permission grant made to it.
--- @param deptId number
function OrganizationService.removeDepartment(deptId)
    QueryBuilder.new('organization_department_members'):where('department_id', deptId):delete()
    PermissionService.revokeAll('department', deptId)
    QueryBuilder.new('departments'):where('id', deptId):delete()
end

--- @param orgId number
--- @param name string
--- @param grade number higher = more senior
--- @return number rankId
function OrganizationService.addRank(orgId, name, grade)
    return QueryBuilder.new('ranks'):insert({
        organization_id = orgId,
        name = name,
        grade = grade,
        created_at = Database.now(),
        updated_at = Database.now(),
    })
end

--- Does not kick anyone from the organization: any membership that held
--- this rank has its rank_id set to nil instead, they simply have no rank
--- until OrganizationService.setRank (Task 8) gives them a new one.
--- Also revokes every permission grant made to this rank.
--- @param rankId number
function OrganizationService.removeRank(rankId)
    QueryBuilder.new('organization_memberships'):where('rank_id', rankId):update({
        rank_id = Database.NULL,
        updated_at = Database.now(),
    })
    PermissionService.revokeAll('rank', rankId)
    QueryBuilder.new('ranks'):where('id', rankId):delete()
end

--- @param characterId number
--- @param orgId number
--- @param rankId number
function OrganizationService.join(characterId, orgId, rankId)
    if not OrganizationService.ALLOW_MULTIPLE_MEMBERSHIPS then
        local existing = QueryBuilder.new('organization_memberships'):where('character_id', characterId):getSync()
        for _, membership in ipairs(existing) do
            OrganizationService.leave(characterId, membership.organization_id)
        end
    end

    QueryBuilder.new('organization_memberships'):insert({
        character_id = characterId,
        organization_id = orgId,
        rank_id = rankId,
        created_at = Database.now(),
        updated_at = Database.now(),
    })
end

--- Cascades: removes this membership's department-member rows.
--- @param characterId number
--- @param orgId number
--- @return boolean true if a membership existed and was removed, false if it was a no-op
function OrganizationService.leave(characterId, orgId)
    local membership = QueryBuilder.new('organization_memberships')
        :where('character_id', characterId):where('organization_id', orgId):firstSync()
    if not membership then
        return false
    end

    QueryBuilder.new('organization_department_members'):where('membership_id', membership.id):delete()
    QueryBuilder.new('organization_memberships'):where('id', membership.id):delete()
    return true
end

--- No-op if the character has no membership in this org, or if rankId
--- doesn't belong to orgId.
--- @param characterId number
--- @param orgId number
--- @param rankId number
--- @return boolean true on success, false if it was a no-op
function OrganizationService.setRank(characterId, orgId, rankId)
    local rank = QueryBuilder.new('ranks'):where('id', rankId):where('organization_id', orgId):firstSync()
    if not rank then
        return false
    end

    local membership = QueryBuilder.new('organization_memberships')
        :where('character_id', characterId):where('organization_id', orgId):firstSync()
    if not membership then
        return false
    end

    QueryBuilder.new('organization_memberships')
        :where('character_id', characterId):where('organization_id', orgId)
        :update({ rank_id = rankId, updated_at = Database.now() })
    return true
end

--- No-op if the character has no membership in this org (joining a
--- department without an existing membership is not an implicit join),
--- or if deptId doesn't belong to orgId.
--- @param characterId number
--- @param orgId number
--- @param deptId number
--- @return boolean true on success, false if it was a no-op
function OrganizationService.joinDepartment(characterId, orgId, deptId)
    local department = QueryBuilder.new('departments'):where('id', deptId):where('organization_id', orgId):firstSync()
    if not department then
        return false
    end

    local membership = QueryBuilder.new('organization_memberships')
        :where('character_id', characterId):where('organization_id', orgId):firstSync()
    if not membership then
        return false
    end

    local existing = QueryBuilder.new('organization_department_members')
        :where('membership_id', membership.id):where('department_id', deptId):firstSync()
    if existing then
        return false
    end

    QueryBuilder.new('organization_department_members'):insert({
        membership_id = membership.id,
        department_id = deptId,
        created_at = Database.now(),
        updated_at = Database.now(),
    })
    return true
end

--- @param characterId number
--- @param orgId number
--- @param deptId number
--- @return boolean true if a department-member row existed and was removed, false if it was a no-op
function OrganizationService.leaveDepartment(characterId, orgId, deptId)
    local membership = QueryBuilder.new('organization_memberships')
        :where('character_id', characterId):where('organization_id', orgId):firstSync()
    if not membership then
        return false
    end

    QueryBuilder.new('organization_department_members')
        :where('membership_id', membership.id):where('department_id', deptId):delete()
    return true
end

--- @param characterId number
--- @param orgId number
--- @return table|nil { organization_id, rank_id, department_ids } or nil if no membership
function OrganizationService.getMembership(characterId, orgId)
    local membership = QueryBuilder.new('organization_memberships')
        :where('character_id', characterId):where('organization_id', orgId):firstSync()
    if not membership then
        return nil
    end

    local deptRows = QueryBuilder.new('organization_department_members')
        :where('membership_id', membership.id):getSync()
    local departmentIds = {}
    for _, row in ipairs(deptRows) do
        table.insert(departmentIds, row.department_id)
    end

    return {
        organization_id = membership.organization_id,
        rank_id = membership.rank_id,
        department_ids = departmentIds,
    }
end

--- @param characterId number
--- @return table[] one entry per org the character belongs to, same shape as getMembership's non-nil return
function OrganizationService.getMemberships(characterId)
    local rows = QueryBuilder.new('organization_memberships'):where('character_id', characterId):getSync()

    local memberships = {}
    for _, row in ipairs(rows) do
        table.insert(memberships, OrganizationService.getMembership(characterId, row.organization_id))
    end
    return memberships
end

return OrganizationService
