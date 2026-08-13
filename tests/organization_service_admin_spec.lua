-- Unit tests for OrganizationService: organization/department/rank CRUD.
-- Membership and department-membership behavior is covered in
-- organization_service_membership_spec.lua (Task 8).
-- Run from the repository root:  lua5.4 tests/organization_service_admin_spec.lua
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

test('setDetails: updates short_code, colour and type', function()
    withFakeDb(function(tables)
        local orgId = OrganizationService.create('LSPD')
        local ok = OrganizationService.setDetails(orgId, { shortCode = 'LSPD', colour = '#3b82f6', type = 'Government' })

        eq(ok, true)
        eq(tables.organizations[1].short_code, 'LSPD')
        eq(tables.organizations[1].colour, '#3b82f6')
        eq(tables.organizations[1].type, 'Government')
    end)
end)

test('setDetails: rejects an unknown type', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local ok, reason = OrganizationService.setDetails(orgId, { shortCode = 'LSPD', colour = '#3b82f6', type = 'Cartel' })

        eq(ok, false)
        eq(reason, 'type must be Government or Business')
    end)
end)

test('setDetails: rejects a short code already used by a different organization', function()
    withFakeDb(function()
        local firstOrgId = OrganizationService.create('LSPD')
        OrganizationService.setDetails(firstOrgId, { shortCode = 'LSPD', colour = '#3b82f6', type = 'Government' })
        local secondOrgId = OrganizationService.create('Los Santos Police Dept (dupe)')

        local ok, reason = OrganizationService.setDetails(secondOrgId, { shortCode = 'LSPD', colour = '#10b981', type = 'Government' })

        eq(ok, false)
        eq(reason, 'short code already in use')
    end)
end)

test('setDetails: allows re-saving the same org with its own existing short code', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        OrganizationService.setDetails(orgId, { shortCode = 'LSPD', colour = '#3b82f6', type = 'Government' })

        local ok = OrganizationService.setDetails(orgId, { shortCode = 'LSPD', colour = '#10b981', type = 'Government' })

        eq(ok, true)
    end)
end)

test('list: returns organizations with departments, ranks (grade-ordered) and contact numbers', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        OrganizationService.setDetails(orgId, { shortCode = 'LSPD', colour = '#3b82f6', type = 'Government' })
        OrganizationService.addDepartment(orgId, 'Patrol')
        OrganizationService.addRank(orgId, 'Sergeant', 3)
        OrganizationService.addRank(orgId, 'Officer', 1)

        local orgs = OrganizationService.list()

        eq(#orgs, 1)
        eq(orgs[1].name, 'LSPD')
        eq(orgs[1].short_code, 'LSPD')
        eq(#orgs[1].departments, 1)
        eq(orgs[1].departments[1].name, 'Patrol')
        eq(#orgs[1].ranks, 2)
        eq(orgs[1].ranks[1].name, 'Officer')
        eq(orgs[1].ranks[2].name, 'Sergeant')
        eq(#orgs[1].contact_numbers, 0)
    end)
end)

print('Running OrganizationService admin unit tests\n')
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
