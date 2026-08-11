--- Unit tests for Department/Rank's HasPermissions wiring.
--- Run from the repository root:  lua5.4 tests/department_rank_model_spec.lua
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

local makeFakeQueryBuilderModule = dofile(CORE_ROOT .. '/tests/support/fake_query_builder.lua')

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

test('Department.permissionType is "department"', function()
    eq(Department.permissionType, 'department')
end)

test('Rank.permissionType is "rank"', function()
    eq(Rank.permissionType, 'rank')
end)

test('a Department instance can grant and check its own permission', function()
    local tables = { departments = { { id = 1, organization_id = 1, name = 'SWAT' } } }
    local original = QueryBuilder
    QueryBuilder = makeFakeQueryBuilderModule(tables)

    local ok, err = pcall(function()
        local instance = Department:findSync(1)
        eq(instance:can('deploy_swat'), false)
        instance:grant('deploy_swat')
        truthy(instance:can('deploy_swat'))
    end)

    QueryBuilder = original
    if not ok then error(err, 2) end
end)

test('a Rank instance can grant and check its own permission', function()
    local tables = { ranks = { { id = 1, organization_id = 1, name = 'Sergeant', grade = 3 } } }
    local original = QueryBuilder
    QueryBuilder = makeFakeQueryBuilderModule(tables)

    local ok, err = pcall(function()
        local instance = Rank:findSync(1)
        eq(instance:can('manage_bank'), false)
        instance:grant('manage_bank')
        truthy(instance:can('manage_bank'))
    end)

    QueryBuilder = original
    if not ok then error(err, 2) end
end)

print('Running Department/Rank model unit tests\n')
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
