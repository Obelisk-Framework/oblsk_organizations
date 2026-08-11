--- Migration: Create organizations table
return {
    up = function()
        Schema.create('organizations', function(table)
            table:id()
            table:string('name')
            table:timestamps()
        end)

        print('[Migration] Created organizations table')
    end,

    down = function()
        Schema.drop('organizations')
        print('[Migration] Dropped organizations table')
    end
}
