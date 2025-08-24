select
    s.*,
    ts_rank(textsearchable_index_col, to_tsquery('english', {{searchInput.value.trim().split(" ").join(" & ")}})) AS rank

from shoots s
-- LEFT JOIN
--   marked_shoots ms ON s."Shoot ID"  = ms.shoot_id AND ms.user_id = {{current_user.id}}

where
    (
        -- if the future switch is true, only show future shoots
        ({{futureSwitch.value}} != true OR "Start Date" > NOW())

            -- notable shoots only
            AND
        ({{notableSwitch.value}} != true OR "Shoot Type" != 'None')

            -- AND
            -- ({{markedSwitch.value}} != true OR ms.shoot_id IS NOT NULL)

            AND
            -- if the marked switch is true, only show marked shoots
        ({{shootTypeSelectList.value.length}} = 0 OR "Event Type" = ANY({{shootTypeSelectList.value}}))

            AND
        ({{monthSelectList.value.length}} = 0 OR to_char("Start Date",'Mon') = ANY({{monthSelectList.selectedLabels}}))

            AND
        ({{statesSelectList.value.length}} = 0 OR "State" = ANY({{statesSelectList.value}}))

            AND
        ({{notabilitySelectList.value.length}} = 0 OR "Shoot Type" = ANY({{notabilitySelectList.value}})))

  and
    (({{searchInput.value}}::text = '') OR
     (textsearchable_index_col @@ to_tsquery('english', {{searchInput.value.trim().split(" ").map(token => token + ":*").join(" & ")}}))
        )

ORDER BY "Start Date" asc