--- Migration: Create ranks table
--- grade is the hierarchy level (higher = more senior), used for
--- promotion/demotion ordering. Permission checks go through
--- HasPermissions once applied to the Rank model (see Task 6), not grade
--- comparisons.
return {
    up = function()
        Schema.create('ranks', function(table)
            table:id()
            table:integer('organization_id'):notNullable()
            table:string('name'):notNullable()
            table:integer('grade'):notNullable():default(0)
            table:timestamps()

            table:index({'organization_id'})
        end)

        print('[Migration] Created ranks table')
    end,

    down = function()
        Schema.drop('ranks')
        print('[Migration] Dropped ranks table')
    end
}
