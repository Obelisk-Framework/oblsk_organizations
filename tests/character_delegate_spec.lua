--- Integration test: the character permission delegate this module
--- registers at boot (main.lua) makes PermissionService.can('character', ...)
--- see grants made to a character's rank or departments.
--- Run from the repository root:  lua5.4 tests/character_delegate_spec.lua
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

-- 'character' has no model in this repo (oblsk_characters owns that one),
-- so it's registered directly; 'rank'/'department' are already registered
-- by Rank.lua/Department.lua's own HasPermissions.apply calls above.
PermissionService.registerType('character', {})

dofile(scriptDir .. '../server/main.lua')

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

    local ok, err = pcall(fn, tables)

    QueryBuilder = original
    if not ok then error(err, 2) end
end

test('a grant on a character\'s rank is visible via PermissionService.can("character", ...)', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Sergeant', 3)
        OrganizationService.join(1, orgId, rankId)

        eq(PermissionService.can('character', 1, 'manage_bank'), false)
        PermissionService.grant('rank', rankId, 'manage_bank')
        truthy(PermissionService.can('character', 1, 'manage_bank'))
    end)
end)

test('a grant on a character\'s department is visible via PermissionService.can("character", ...)', function()
    withFakeDb(function()
        local orgId = OrganizationService.create('LSPD')
        local rankId = OrganizationService.addRank(orgId, 'Officer', 1)
        local deptId = OrganizationService.addDepartment(orgId, 'SWAT')
        OrganizationService.join(1, orgId, rankId)
        OrganizationService.joinDepartment(1, orgId, deptId)

        eq(PermissionService.can('character', 1, 'deploy_swat'), false)
        PermissionService.grant('department', deptId, 'deploy_swat')
        truthy(PermissionService.can('character', 1, 'deploy_swat'))
    end)
end)

test('a character with no membership at all is simply never granted anything via the delegate', function()
    withFakeDb(function()
        eq(PermissionService.can('character', 999, 'manage_bank'), false)
    end)
end)

print('Running character permission delegate integration tests\n')
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
