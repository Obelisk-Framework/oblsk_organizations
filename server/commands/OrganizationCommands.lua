--- oblsk_organizations - Admin Commands
--- Minimum viable surface for managing orgs/departments/ranks/memberships
--- without a UI. Every command resolves <serverId> to a character_id via
--- CharacterService.getActiveCharacterId, same pattern oblsk_accounts'
--- AccountCommands uses for accounts.
local function isAdmin(source)
    return source == 0 or IsPlayerAceAllowed(source, 'admin')
end

RegisterCommand('org-create', function(source, args)
    if not isAdmin(source) then return end

    local name = table.concat(args, ' ')
    if name == '' then
        print('Usage: /org-create <name>')
        return
    end

    local orgId = OrganizationService.create(name)
    print('[oblsk_organizations] created organization #' .. orgId .. ': ' .. name)
end, false)

RegisterCommand('org-delete', function(source, args)
    if not isAdmin(source) then return end

    local orgId = tonumber(args[1])
    if not orgId then
        print('Usage: /org-delete <orgId>')
        return
    end

    OrganizationService.delete(orgId)
    print('[oblsk_organizations] deleted organization #' .. orgId)
end, false)

RegisterCommand('org-adddept', function(source, args)
    if not isAdmin(source) then return end

    local orgId = tonumber(args[1])
    local name = table.concat(args, ' ', 2)
    if not orgId or name == '' then
        print('Usage: /org-adddept <orgId> <name>')
        return
    end

    local deptId = OrganizationService.addDepartment(orgId, name)
    print('[oblsk_organizations] added department #' .. deptId .. ' (' .. name .. ') to org #' .. orgId)
end, false)

RegisterCommand('org-removedept', function(source, args)
    if not isAdmin(source) then return end

    local deptId = tonumber(args[1])
    if not deptId then
        print('Usage: /org-removedept <deptId>')
        return
    end

    OrganizationService.removeDepartment(deptId)
    print('[oblsk_organizations] removed department #' .. deptId)
end, false)

RegisterCommand('org-addrank', function(source, args)
    if not isAdmin(source) then return end

    local orgId = tonumber(args[1])
    local grade = tonumber(args[2])
    local name = table.concat(args, ' ', 3)
    if not orgId or not grade or name == '' then
        print('Usage: /org-addrank <orgId> <grade> <name>')
        return
    end

    local rankId = OrganizationService.addRank(orgId, name, grade)
    print('[oblsk_organizations] added rank #' .. rankId .. ' (' .. name .. ', grade ' .. grade .. ') to org #' .. orgId)
end, false)

RegisterCommand('org-removerank', function(source, args)
    if not isAdmin(source) then return end

    local rankId = tonumber(args[1])
    if not rankId then
        print('Usage: /org-removerank <rankId>')
        return
    end

    OrganizationService.removeRank(rankId)
    print('[oblsk_organizations] removed rank #' .. rankId)
end, false)

RegisterCommand('org-join', function(source, args)
    if not isAdmin(source) then return end

    local targetId = tonumber(args[1])
    local orgId = tonumber(args[2])
    local rankId = tonumber(args[3])
    if not targetId or not orgId or not rankId then
        print('Usage: /org-join <serverId> <orgId> <rankId>')
        return
    end

    local characterId = CharacterService.getActiveCharacterId(targetId)
    if not characterId then
        print('[oblsk_organizations] player ' .. targetId .. ' has no active character')
        return
    end

    OrganizationService.join(characterId, orgId, rankId)
    print('[oblsk_organizations] character ' .. characterId .. ' joined org #' .. orgId)
end, false)

RegisterCommand('org-leave', function(source, args)
    if not isAdmin(source) then return end

    local targetId = tonumber(args[1])
    local orgId = tonumber(args[2])
    if not targetId or not orgId then
        print('Usage: /org-leave <serverId> <orgId>')
        return
    end

    local characterId = CharacterService.getActiveCharacterId(targetId)
    if not characterId then
        print('[oblsk_organizations] player ' .. targetId .. ' has no active character')
        return
    end

    if OrganizationService.leave(characterId, orgId) then
        print('[oblsk_organizations] character ' .. characterId .. ' left org #' .. orgId)
    else
        print('[oblsk_organizations] character ' .. characterId .. ' has no membership in org #' .. orgId)
    end
end, false)

RegisterCommand('org-setrank', function(source, args)
    if not isAdmin(source) then return end

    local targetId = tonumber(args[1])
    local orgId = tonumber(args[2])
    local rankId = tonumber(args[3])
    if not targetId or not orgId or not rankId then
        print('Usage: /org-setrank <serverId> <orgId> <rankId>')
        return
    end

    local characterId = CharacterService.getActiveCharacterId(targetId)
    if not characterId then
        print('[oblsk_organizations] player ' .. targetId .. ' has no active character')
        return
    end

    if OrganizationService.setRank(characterId, orgId, rankId) then
        print('[oblsk_organizations] set character ' .. characterId .. '\'s rank in org #' .. orgId .. ' to #' .. rankId)
    else
        print('[oblsk_organizations] character ' .. characterId .. ' has no membership in org #' .. orgId)
    end
end, false)

RegisterCommand('org-adddeptmember', function(source, args)
    if not isAdmin(source) then return end

    local targetId = tonumber(args[1])
    local orgId = tonumber(args[2])
    local deptId = tonumber(args[3])
    if not targetId or not orgId or not deptId then
        print('Usage: /org-adddeptmember <serverId> <orgId> <deptId>')
        return
    end

    local characterId = CharacterService.getActiveCharacterId(targetId)
    if not characterId then
        print('[oblsk_organizations] player ' .. targetId .. ' has no active character')
        return
    end

    if OrganizationService.joinDepartment(characterId, orgId, deptId) then
        print('[oblsk_organizations] added character ' .. characterId .. ' to department #' .. deptId)
    else
        print('[oblsk_organizations] character ' .. characterId .. ' has no membership in org #' .. orgId)
    end
end, false)

RegisterCommand('org-removedeptmember', function(source, args)
    if not isAdmin(source) then return end

    local targetId = tonumber(args[1])
    local orgId = tonumber(args[2])
    local deptId = tonumber(args[3])
    if not targetId or not orgId or not deptId then
        print('Usage: /org-removedeptmember <serverId> <orgId> <deptId>')
        return
    end

    local characterId = CharacterService.getActiveCharacterId(targetId)
    if not characterId then
        print('[oblsk_organizations] player ' .. targetId .. ' has no active character')
        return
    end

    if OrganizationService.leaveDepartment(characterId, orgId, deptId) then
        print('[oblsk_organizations] removed character ' .. characterId .. ' from department #' .. deptId)
    else
        print('[oblsk_organizations] character ' .. characterId .. ' has no membership in org #' .. orgId)
    end
end, false)

RegisterCommand('org-grant', function(source, args)
    if not isAdmin(source) then return end

    local ownerType = args[1]
    local ownerId = tonumber(args[2])
    local key = args[3]
    if not ownerType or not ownerId or not key then
        print('Usage: /org-grant <ownerType> <ownerId> <key>')
        return
    end

    PermissionService.grant(ownerType, ownerId, key)
    print('[oblsk_organizations] granted "' .. key .. '" to ' .. ownerType .. ' #' .. ownerId)
end, false)

RegisterCommand('org-revoke', function(source, args)
    if not isAdmin(source) then return end

    local ownerType = args[1]
    local ownerId = tonumber(args[2])
    local key = args[3]
    if not ownerType or not ownerId or not key then
        print('Usage: /org-revoke <ownerType> <ownerId> <key>')
        return
    end

    PermissionService.revoke(ownerType, ownerId, key)
    print('[oblsk_organizations] revoked "' .. key .. '" from ' .. ownerType .. ' #' .. ownerId)
end, false)
