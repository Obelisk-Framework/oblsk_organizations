--- Migration: Create departments table
--- Pure grouping label within one organization. Not a hierarchy of its
--- own, permission checks go through HasPermissions once applied to the
--- Department model (see Task 6).
return {
    up = function()
        Schema.create('departments', function(table)
            table:id()
            table:integer('organization_id'):notNullable()
            table:string('name'):notNullable()
            table:timestamps()

            table:index({'organization_id'})
        end)

        print('[Migration] Created departments table')
    end,

    down = function()
        Schema.drop('departments')
        print('[Migration] Dropped departments table')
    end
}
