--- oblsk_organizations - Server Main
--- Registers the character permission delegate: any character's rank and
--- departments extend what PermissionService.can('character', ...) means,
--- without oblsk_characters ever depending on this module. See
--- docs/superpowers/specs/2026-08-11-organizations-and-permissions-design.md.
print('[oblsk_organizations] Loading...')

PermissionService.addDelegate('character', function(characterId)
    local refs = {}
    for _, membership in ipairs(OrganizationService.getMemberships(characterId)) do
        if membership.rank_id then
            table.insert(refs, { type = 'rank', id = membership.rank_id })
        end
        for _, deptId in ipairs(membership.department_ids) do
            table.insert(refs, { type = 'department', id = deptId })
        end
    end
    return refs
end)

print('[oblsk_organizations] Loaded successfully!')
