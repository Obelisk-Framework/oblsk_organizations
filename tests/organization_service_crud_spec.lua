--- Unit tests for OrganizationService: organization/department/rank CRUD.
--- Membership and department-membership behavior is covered in
--- organization_service_membership_spec.lua (Task 8).
--- Run from the repository root:  lua5.4 tests/organization_service_crud_spec.lua
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
dofile(CORE_ROOT .. '/core/server/Models/Permission.lua')
dofile(CORE_ROOT .. '/core/server/Services/PermissionService.lua')
dofile(CORE_ROOT .. '/core/server/Traits/HasPermissions.lua')
dofile(scriptDir .. '../server/models/Department.lua')
dofile(scriptDir .. '../server/models/Rank.lua')
dofile(scriptDir .. '../server/models/Organization.lua')
dofile(scriptDir .. '../server/models/OrganizationMembership.lua')
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

local function withFakeDb(fn)
    local tables = {}
    local original = QueryBuilder
    QueryBuilder = makeFakeQueryBuilderModule(tables)

    PermissionService.registerType('rank', {})
    PermissionService.registerType('department', {})

    local ok, err = pcall(fn, tables)

    QueryBuilder = original
    if not ok then error(err, 2) end
end

test('create: inserts an organization row and returns its id', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('Los Santos Police Department')
        eq(#tables.organizations, 1)
        eq(tables.organizations[1].id, orgId)
        eq(tables.organizations[1].name, 'Los Santos Police Department')
    end)
end)

test('rename: updates the organization name', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        OrganizationService.rename(orgId, 'Los Santos Police Department')
        eq(tables.organizations[1].name, 'Los Santos Police Department')
    end)
end)

test('delete: removes the organization and its departments/ranks/memberships', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        OrganizationService.addDepartment(orgId, 'SWAT')
        OrganizationService.addRank(orgId, 'Sergeant', 3)
        QueryBuilder.new('organization_memberships'):insert({
            character_id = 1, organization_id = orgId, rank_id = nil,
            created_at = Database.now(), updated_at = Database.now(),
        })

        OrganizationService.delete(orgId)

        eq(#tables.organizations, 0)
        eq(#tables.departments, 0)
        eq(#tables.ranks, 0)
        eq(#tables.organization_memberships, 0)
    end)
end)

test('delete: revokes every permission granted to any department/rank that belonged to it', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)

        PermissionService.grant('department', deptId, 'manage_fleet')
        PermissionService.grant('rank', rankId, 'manage_bank')

        local otherOrgId = OrganizationService.create('Ballas')
        local otherRankId = OrganizationService.addRank(otherOrgId, 'Shot Caller', 5)
        PermissionService.grant('rank', otherRankId, 'manage_bank')

        OrganizationService.delete(orgId)

        eq(#PermissionService.list('department', deptId), 0)
        eq(#PermissionService.list('rank', rankId), 0)
        eq(#PermissionService.list('rank', otherRankId), 1)
    end)
end)

test('addDepartment: inserts a department scoped to the organization', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')

        eq(#tables.departments, 1)
        eq(tables.departments[1].id, deptId)
        eq(tables.departments[1].organization_id, orgId)
        eq(tables.departments[1].name, 'SWAT')
    end)
end)

test('removeDepartment: removes the department and its department-member rows', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')
        QueryBuilder.new('organization_department_members'):insert({
            membership_id = 1, department_id = deptId,
            created_at = Database.now(), updated_at = Database.now(),
        })

        OrganizationService.removeDepartment(deptId)

        eq(#tables.departments, 0)
        eq(#tables.organization_department_members, 0)
    end)
end)

test('removeDepartment: also revokes every permission granted to that department', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')
        local otherDeptId = OrganizationService.addDepartment(orgId, 'Patrol')

        PermissionService.grant('department', deptId, 'manage_fleet')
        PermissionService.grant('department', otherDeptId, 'manage_fleet')

        OrganizationService.removeDepartment(deptId)

        eq(#PermissionService.list('department', deptId), 0)
        eq(#PermissionService.list('department', otherDeptId), 1)
    end)
end)

test('addRank: inserts a rank scoped to the organization with the given grade', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)

        eq(#tables.ranks, 1)
        eq(tables.ranks[1].id, rankId)
        eq(tables.ranks[1].organization_id, orgId)
        eq(tables.ranks[1].name, 'Sergeant')
        eq(tables.ranks[1].grade, 3)
    end)
end)

test('removeRank: removes the rank and nils out rank_id on any membership that held it', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)
        local membershipId = QueryBuilder.new('organization_memberships'):insert({
            character_id = 1, organization_id = orgId, rank_id = rankId,
            created_at = Database.now(), updated_at = Database.now(),
        })

        OrganizationService.removeRank(rankId)

        eq(#tables.ranks, 0)
        local membership = QueryBuilder.new('organization_memberships'):where('id', membershipId):first()
        eq(membership.rank_id, nil)
    end)
end)

test('removeRank: bumps updated_at on any membership that held it', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)
        local membershipId = QueryBuilder.new('organization_memberships'):insert({
            character_id = 1, organization_id = orgId, rank_id = rankId,
            created_at = Database.now(), updated_at = nil,
        })

        OrganizationService.removeRank(rankId)

        local membership = QueryBuilder.new('organization_memberships'):where('id', membershipId):first()
        eq(membership.updated_at, Database.now())
    end)
end)

test('removeRank: also revokes every permission granted to that rank', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)
        local otherRankId = OrganizationService.addRank(orgId, 'Officer', 1)

        PermissionService.grant('rank', rankId, 'manage_bank')
        PermissionService.grant('rank', otherRankId, 'manage_bank')

        OrganizationService.removeRank(rankId)

        eq(#PermissionService.list('rank', rankId), 0)
        eq(#PermissionService.list('rank', otherRankId), 1)
    end)
end)

print('Running OrganizationService CRUD unit tests\n')
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
