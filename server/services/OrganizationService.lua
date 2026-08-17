--- OrganizationService (server) - organizations, their departments and
--- ranks, and character membership within them. See
--- docs/superpowers/specs/2026-08-11-organizations-and-permissions-design.md.
---
--- Uses the Organization/Department/Rank/OrganizationMembership models via
--- BaseModel's :where(...) query proxy wherever a model exists for the
--- table (the framework's established convention, see e.g. VehicleService's
--- Vehicle:findSync/BaseVehicle:findSync). organization_department_members
--- is a pure junction table with no independent identity beyond the two ids
--- it links, so it stays raw QueryBuilder, same as vehicle_tunings.
OrganizationService = {}

--- Whether a character may hold membership in more than one organization
--- at once. This framework has no Config global convention (see the plan's
--- Global Constraints), so this is a plain constant, edit directly.
OrganizationService.ALLOW_MULTIPLE_MEMBERSHIPS = false

--- @param name string
--- @return number orgId
function OrganizationService.create(name)
    return Organization:create({ name = name }).id
end

--- @param orgId number
--- @param name string
function OrganizationService.rename(orgId, name)
    Organization:where('id', orgId):update({
        name = name,
        updated_at = Database.now(),
    })
end

--- Cascades: removes this organization's departments, ranks, memberships,
--- department-member rows, contact numbers, and every permission grant made to one of its
--- departments/ranks, so nothing is left pointing at a deleted
--- organization_id and no grant becomes an orphaned row.
--- @param orgId number
function OrganizationService.delete(orgId)
    local memberships = OrganizationMembership:where('organization_id', orgId):get()
    for _, membership in ipairs(memberships) do
        QueryBuilder.new('organization_department_members'):where('membership_id', membership.id):delete()
    end

    local departments = Department:where('organization_id', orgId):get()
    for _, department in ipairs(departments) do
        PermissionService.revokeAll('department', department.id)
    end

    local ranks = Rank:where('organization_id', orgId):get()
    for _, rank in ipairs(ranks) do
        PermissionService.revokeAll('rank', rank.id)
    end

    OrganizationMembership:where('organization_id', orgId):delete()
    Department:where('organization_id', orgId):delete()
    Rank:where('organization_id', orgId):delete()
    QueryBuilder.new('organization_contact_numbers'):where('organization_id', orgId):delete()
    Organization:where('id', orgId):delete()
end

--- @param orgId number
--- @param name string
--- @return number deptId
function OrganizationService.addDepartment(orgId, name)
    return Department:create({ organization_id = orgId, name = name }).id
end

--- Cascades: removes this department's department-member rows and every
--- permission grant made to it.
--- @param deptId number
function OrganizationService.removeDepartment(deptId)
    QueryBuilder.new('organization_department_members'):where('department_id', deptId):delete()
    PermissionService.revokeAll('department', deptId)
    Department:where('id', deptId):delete()
end

--- @param orgId number
--- @param name string
--- @param grade number higher = more senior
--- @return number rankId
function OrganizationService.addRank(orgId, name, grade)
    return Rank:create({ organization_id = orgId, name = name, grade = grade }).id
end

--- Does not kick anyone from the organization: any membership that held
--- this rank has its rank_id set to nil instead, they simply have no rank
--- until OrganizationService.setRank gives them a new one. Also revokes
--- every permission grant made to this rank.
--- @param rankId number
function OrganizationService.removeRank(rankId)
    OrganizationMembership:where('rank_id', rankId):update({
        rank_id = Database.NULL,
        updated_at = Database.now(),
    })
    PermissionService.revokeAll('rank', rankId)
    Rank:where('id', rankId):delete()
end

--- @param characterId number
--- @param orgId number
--- @param rankId number
function OrganizationService.join(characterId, orgId, rankId)
    if not OrganizationService.ALLOW_MULTIPLE_MEMBERSHIPS then
        local existing = OrganizationMembership:where('character_id', characterId):get()
        for _, membership in ipairs(existing) do
            OrganizationService.leave(characterId, membership.organization_id)
        end
    end

    OrganizationMembership:create({
        character_id = characterId,
        organization_id = orgId,
        rank_id = rankId,
    })
end

--- Cascades: removes this membership's department-member rows.
--- @param characterId number
--- @param orgId number
--- @return boolean true if a membership existed and was removed, false if it was a no-op
function OrganizationService.leave(characterId, orgId)
    local membership = OrganizationMembership
        :where('character_id', characterId):where('organization_id', orgId):first()
    if not membership then
        return false
    end

    QueryBuilder.new('organization_department_members'):where('membership_id', membership.id):delete()
    OrganizationMembership:where('id', membership.id):delete()
    return true
end

--- No-op if the character has no membership in this org, or if rankId
--- doesn't belong to orgId.
--- @param characterId number
--- @param orgId number
--- @param rankId number
--- @return boolean true on success, false if it was a no-op
function OrganizationService.setRank(characterId, orgId, rankId)
    local rank = Rank:where('id', rankId):where('organization_id', orgId):first()
    if not rank then
        return false
    end

    local membership = OrganizationMembership
        :where('character_id', characterId):where('organization_id', orgId):first()
    if not membership then
        return false
    end

    OrganizationMembership
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
    local department = Department:where('id', deptId):where('organization_id', orgId):first()
    if not department then
        return false
    end

    local membership = OrganizationMembership
        :where('character_id', characterId):where('organization_id', orgId):first()
    if not membership then
        return false
    end

    local existing = QueryBuilder.new('organization_department_members')
        :where('membership_id', membership.id):where('department_id', deptId):first()
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
    local membership = OrganizationMembership
        :where('character_id', characterId):where('organization_id', orgId):first()
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
    local membership = OrganizationMembership
        :where('character_id', characterId):where('organization_id', orgId):first()
    if not membership then
        return nil
    end

    local deptRows = QueryBuilder.new('organization_department_members')
        :where('membership_id', membership.id):get()
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

--- Roster of every character currently a member of an organization. Unlike
--- getMembership/getMemberships (per-character lookups), this is a
--- per-org listing, added for consumers like oblsk_mdt's staff roster that
--- need "who's in this org" rather than "what orgs is this character in".
--- @param orgId number
--- @return table[] one entry per member: { character_id, name, rank }
function OrganizationService.listMembers(orgId)
    local memberships = OrganizationMembership:where('organization_id', orgId):get()

    local members = {}
    for _, membership in ipairs(memberships) do
        local character = Character:find(membership.character_id)
        local rank = membership.rank_id and Rank:where('id', membership.rank_id):first()

        table.insert(members, {
            character_id = membership.character_id,
            name = character and (character.first_name .. ' ' .. character.last_name) or nil,
            rank = rank and rank.name or nil,
        })
    end
    return members
end

--- @param characterId number
--- @return table[] one entry per org the character belongs to, same shape as getMembership's non-nil return
function OrganizationService.getMemberships(characterId)
    local rows = OrganizationMembership:where('character_id', characterId):get()

    local memberships = {}
    for _, row in ipairs(rows) do
        table.insert(memberships, OrganizationService.getMembership(characterId, row.organization_id))
    end
    return memberships
end

--- @param orgId number
--- @param details table { shortCode, colour, type }
--- @return boolean ok
--- @return string|nil reason present only when ok is false
function OrganizationService.setDetails(orgId, details)
    if details.type ~= 'Government' and details.type ~= 'Business' then
        return false, 'type must be Government or Business'
    end

    if details.shortCode and details.shortCode ~= '' then
        local existing = Organization:where('short_code', details.shortCode):first()
        if existing and existing.id ~= orgId then
            return false, 'short code already in use'
        end
    end

    Organization:where('id', orgId):update({
        short_code = details.shortCode,
        colour = details.colour,
        type = details.type,
        updated_at = Database.now(),
    })
    return true
end

--- @param orgId number
--- @param number string
--- @param label string
--- @return number contactId
function OrganizationService.addContactNumber(orgId, number, label)
    return QueryBuilder.new('organization_contact_numbers'):insert({
        organization_id = orgId,
        number = number,
        label = label,
        enabled = true,
        created_at = Database.now(),
        updated_at = Database.now(),
    })
end

--- @param contactId number
function OrganizationService.removeContactNumber(contactId)
    QueryBuilder.new('organization_contact_numbers'):where('id', contactId):delete()
end

--- @param contactId number
--- @param enabled boolean
function OrganizationService.toggleContactNumber(contactId, enabled)
    QueryBuilder.new('organization_contact_numbers'):where('id', contactId):update({
        enabled = enabled,
        updated_at = Database.now(),
    })
end

--- Every organization with its departments, ranks (grade-ordered, lowest
--- first) and contact numbers eager-loaded, for the admin panel's org list.
--- @return table[]
function OrganizationService.list()
    local orgs = QueryBuilder.new('organizations'):get()

    local result = {}
    for _, org in ipairs(orgs) do
        local departments = Department:where('organization_id', org.id):get()
        local ranks = Rank:where('organization_id', org.id):orderBy('grade', 'asc'):get()
        local contactNumbers = QueryBuilder.new('organization_contact_numbers'):where('organization_id', org.id):get()

        table.insert(result, {
            id = org.id,
            name = org.name,
            short_code = org.short_code,
            colour = org.colour,
            type = org.type,
            departments = departments,
            ranks = ranks,
            contact_numbers = contactNumbers,
        })
    end
    return result
end

return OrganizationService
