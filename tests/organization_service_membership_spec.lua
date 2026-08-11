--- Unit tests for OrganizationService: membership and department
--- membership. Organization/department/rank CRUD is covered in
--- organization_service_crud_spec.lua (Task 7).
--- Run from the repository root:  lua5.4 tests/organization_service_membership_spec.lua
local scriptDir = arg[0]:match('(.*/)') or './'
local CORE_ROOT = scriptDir .. '../../..'

dofile(CORE_ROOT .. '/tests/support/fivem_stubs.lua')
dofile(CORE_ROOT .. '/core/server/ORM/Dialects/Init.lua')
dofile(CORE_ROOT .. '/core/server/ORM/Dialects/MySQL.lua')
dofile(CORE_ROOT .. '/core/server/ORM/Dialects/Postgres.lua')
dofile(CORE_ROOT .. '/core/server/ORM/Database.lua')
dofile(CORE_ROOT .. '/core/server/ORM/QueryBuilder.lua')
dofile(CORE_ROOT .. '/core/server/ORM/Schema.lua')
dofile(CORE_ROOT .. '/core/server/ORM/BaseModel.lua')
dofile(CORE_ROOT .. '/core/server/Services/PermissionService.lua')
dofile(CORE_ROOT .. '/core/server/Traits/HasPermissions.lua')
dofile(scriptDir .. '../server/models/Department.lua')
dofile(scriptDir .. '../server/models/Rank.lua')
dofile(scriptDir .. '../server/models/Organization.lua')
dofile(scriptDir .. '../server/models/OrganizationMembership.lua')
dofile(CORE_ROOT .. '/modules/oblsk_characters/server/models/Character.lua')
dofile(scriptDir .. '../server/services/OrganizationService.lua')

local makeFakeQueryBuilderModule = dofile(scriptDir .. 'support/fake_query_builder.lua')

local tests, failures, passed = {}, {}, 0
local function test(name, fn) tests[#tests + 1] = {name = name, fn = fn} end

local function eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format('%s\n     expected: %s\n     actual:   %s',
            msg or 'assertion failed', tostring(expected), tostring(actual)), 2)
    end
end

local function truthy(v, msg)
    if not v then error(msg or 'expected a truthy value', 2) end
end

local function withFakeDb(fn)
    local tables = {}
    local original = QueryBuilder
    QueryBuilder = makeFakeQueryBuilderModule(tables)

    OrganizationService.ALLOW_MULTIPLE_MEMBERSHIPS = false

    local ok, err = pcall(fn, tables)

    QueryBuilder = original
    if not ok then error(err, 2) end
end

test('join: creates a membership with the given rank', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)

        OrganizationService.join(1, orgId, rankId)

        eq(#tables.organization_memberships, 1)
        eq(tables.organization_memberships[1].character_id, 1)
        eq(tables.organization_memberships[1].organization_id, orgId)
        eq(tables.organization_memberships[1].rank_id, rankId)
    end)
end)

test('join: with ALLOW_MULTIPLE_MEMBERSHIPS false, joining a new org removes the old membership', function()
    withFakeDb(function(tables)
        local orgA = OrganizationService.create('LSPD')
        local orgB = OrganizationService.create('Ballas')
        local rankA = OrganizationService.addRank(orgA, 'Officer', 1)
        local rankB = OrganizationService.addRank(orgB, 'Member', 1)

        OrganizationService.join(1, orgA, rankA)
        OrganizationService.join(1, orgB, rankB)

        eq(#tables.organization_memberships, 1)
        eq(tables.organization_memberships[1].organization_id, orgB)
    end)
end)

test('join: with ALLOW_MULTIPLE_MEMBERSHIPS true, a character can hold two memberships', function()
    withFakeDb(function(tables)
        OrganizationService.ALLOW_MULTIPLE_MEMBERSHIPS = true

        local orgA = OrganizationService.create('LSPD')
        local orgB = OrganizationService.create('Ballas')
        local rankA = OrganizationService.addRank(orgA, 'Officer', 1)
        local rankB = OrganizationService.addRank(orgB, 'Member', 1)

        OrganizationService.join(1, orgA, rankA)
        OrganizationService.join(1, orgB, rankB)

        eq(#tables.organization_memberships, 2)
    end)
end)

test('leave: removes the membership and its department-member rows, returns true', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Officer', 1)
        local deptId = OrganizationService.addDepartment(orgId, 'Patrol')

        OrganizationService.join(1, orgId, rankId)
        OrganizationService.joinDepartment(1, orgId, deptId)

        local result = OrganizationService.leave(1, orgId)

        truthy(result, 'expected leave to return true on success')
        eq(#tables.organization_memberships, 0)
        eq(#tables.organization_department_members, 0)
    end)
end)

test('leave: returns false and is a no-op if the character has no membership in that org', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        eq(OrganizationService.leave(1, orgId), false)
    end)
end)

test('setRank: changes rank_id on the existing membership, returns true', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankA = OrganizationService.addRank(orgId, 'Officer', 1)
        local rankB = OrganizationService.addRank(orgId, 'Sergeant', 3)

        OrganizationService.join(1, orgId, rankA)
        local result = OrganizationService.setRank(1, orgId, rankB)

        truthy(result, 'expected setRank to return true on success')
        eq(tables.organization_memberships[1].rank_id, rankB)
    end)
end)

test('setRank: returns false and is a no-op if the character has no membership in that org', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Officer', 1)

        eq(OrganizationService.setRank(1, orgId, rankId), false)
    end)
end)

test('setRank: returns false and is a no-op if the rank belongs to a different org', function()
    withFakeDb(function(tables)
        local orgA = OrganizationService.create('LSPD')
        local orgB = OrganizationService.create('Ballas')
        local rankA = OrganizationService.addRank(orgA, 'Officer', 1)
        local foreignRank = OrganizationService.addRank(orgB, 'Shot Caller', 5)

        OrganizationService.join(1, orgA, rankA)
        local result = OrganizationService.setRank(1, orgA, foreignRank)

        eq(result, false)
        eq(tables.organization_memberships[1].rank_id, rankA)
    end)
end)

test('joinDepartment: adds the character to a department within their org, returns true', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Officer', 1)
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')

        OrganizationService.join(1, orgId, rankId)
        local result = OrganizationService.joinDepartment(1, orgId, deptId)

        truthy(result, 'expected joinDepartment to return true on success')
        eq(#tables.organization_department_members, 1)
        eq(tables.organization_department_members[1].department_id, deptId)
    end)
end)

test('joinDepartment: is a no-op and returns false if the character has no membership in that org', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')

        local result = OrganizationService.joinDepartment(1, orgId, deptId)

        eq(result, false)
        eq(#(tables.organization_department_members or {}), 0)
    end)
end)

test('joinDepartment: is a no-op and returns false if the department belongs to a different org', function()
    withFakeDb(function(tables)
        local orgA = OrganizationService.create('LSPD')
        local orgB = OrganizationService.create('Ballas')
        local rankA = OrganizationService.addRank(orgA, 'Officer', 1)
        local foreignDept = OrganizationService.addDepartment(orgB, 'Turf')

        OrganizationService.join(1, orgA, rankA)
        local result = OrganizationService.joinDepartment(1, orgA, foreignDept)

        eq(result, false)
        eq(#(tables.organization_department_members or {}), 0)
    end)
end)

test('leaveDepartment: removes just that department-member row, returns true', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Officer', 1)
        local dept1 = OrganizationService.addDepartment(orgId, 'SWAT')
        local dept2 = OrganizationService.addDepartment(orgId, 'Patrol')

        OrganizationService.join(1, orgId, rankId)
        OrganizationService.joinDepartment(1, orgId, dept1)
        OrganizationService.joinDepartment(1, orgId, dept2)

        local result = OrganizationService.leaveDepartment(1, orgId, dept1)

        truthy(result, 'expected leaveDepartment to return true on success')
        eq(#tables.organization_department_members, 1)
        eq(tables.organization_department_members[1].department_id, dept2)
    end)
end)

test('leaveDepartment: returns false and is a no-op if the character has no membership in that org', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')

        eq(OrganizationService.leaveDepartment(1, orgId, deptId), false)
    end)
end)

test('getMembership: returns organization_id, rank_id, and department_ids', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Officer', 1)
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')

        OrganizationService.join(1, orgId, rankId)
        OrganizationService.joinDepartment(1, orgId, deptId)

        local membership = OrganizationService.getMembership(1, orgId)
        eq(membership.organization_id, orgId)
        eq(membership.rank_id, rankId)
        eq(#membership.department_ids, 1)
        eq(membership.department_ids[1], deptId)
    end)
end)

test('getMembership: returns nil for an org the character never joined', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        eq(OrganizationService.getMembership(1, orgId), nil)
    end)
end)

test('listMembers: returns one entry per member with name and rank', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)

        local characterId = QueryBuilder.new('characters'):insert({ first_name = 'John', last_name = 'Doe' })
        OrganizationService.join(characterId, orgId, rankId)

        local members = OrganizationService.listMembers(orgId)
        eq(#members, 1)
        eq(members[1].character_id, characterId)
        eq(members[1].name, 'John Doe')
        eq(members[1].rank, 'Sergeant')
    end)
end)

test('listMembers: rank is nil for a member with no rank assigned', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')

        local characterId = QueryBuilder.new('characters'):insert({ first_name = 'Jane', last_name = 'Roe' })
        OrganizationService.join(characterId, orgId, nil)

        local members = OrganizationService.listMembers(orgId)
        eq(#members, 1)
        eq(members[1].rank, nil)
    end)
end)

test('listMembers: returns an empty table for an org with no members', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        eq(#OrganizationService.listMembers(orgId), 0)
    end)
end)

test('getMemberships: returns one entry per org the character belongs to', function()
    withFakeDb(function()
        OrganizationService.ALLOW_MULTIPLE_MEMBERSHIPS = true

        local orgA = OrganizationService.create('LSPD')
        local orgB = OrganizationService.create('Ballas')
        local rankA = OrganizationService.addRank(orgA, 'Officer', 1)
        local rankB = OrganizationService.addRank(orgB, 'Member', 1)

        OrganizationService.join(1, orgA, rankA)
        OrganizationService.join(1, orgB, rankB)

        local memberships = OrganizationService.getMemberships(1)
        eq(#memberships, 2)
    end)
end)

print('Running OrganizationService membership unit tests\n')
for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
        passed = passed + 1
        print('  ok   - ' .. t.name)
    else
        failures[#failures + 1] = t.name
        print('  FAIL - ' .. t.name)
        print('         ' .. tostring(err):gsub('\n', '\n         '))
    end
end

print(string.format('\n%d passed, %d failed', passed, #failures))
os.exit(#failures == 0 and 0 or 1)
