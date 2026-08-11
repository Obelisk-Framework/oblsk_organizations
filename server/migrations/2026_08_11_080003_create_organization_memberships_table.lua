--- Migration: Create organization_memberships table
--- One row per character per organization they belong to. rank_id is
--- nullable: removing a rank a membership pointed at (OrganizationService.
--- removeRank) clears this to nil rather than deleting the membership or
--- cascading further.
return {
    up = function()
        Schema.create('organization_memberships', function(table)
            table:id()
            table:integer('character_id'):notNullable()
            table:integer('organization_id'):notNullable()
            table:integer('rank_id')
            table:timestamps()

            table:index({'character_id'})
            table:index({'organization_id'})
            table:unique({'character_id', 'organization_id'})
        end)

        print('[Migration] Created organization_memberships table')
    end,

    down = function()
        Schema.drop('organization_memberships')
        print('[Migration] Dropped organization_memberships table')
    end
}
