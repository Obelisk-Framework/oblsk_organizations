--- Migration: Create organization_department_members table
--- Many-to-many: a character (via their membership row) can belong to 0-n
--- departments within the organization they're already a member of.
return {
    up = function()
        Schema.create('organization_department_members', function(table)
            table:id()
            table:integer('membership_id')
            table:integer('department_id')
            table:timestamps()

            table:index({'membership_id'})
            table:index({'department_id'})
            table:unique({'membership_id', 'department_id'})
        end)

        print('[Migration] Created organization_department_members table')
    end,

    down = function()
        Schema.drop('organization_department_members')
        print('[Migration] Dropped organization_department_members table')
    end
}
