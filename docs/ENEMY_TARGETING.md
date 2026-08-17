# Enemy Targeting

Enemy Targeting can be switched between Manual and Auto during a match.

## Manual

The player chooses legal targets for enemy attacks in both the Build Area and the Hand. Manual choices never update AI target-preference learning because the AI did not make those choices.

## Auto

Auto chooses legal Build targets using the Enemy Attack AI and submits them through the same combat commands used by Manual targeting.

Every Auto attack is recorded, including blocked attacks, forced targets, and attacks against the Hand. During Full Assault, Auto selects the lowest-Health legal Hand card and uses the leftmost slot to break ties. Only genuine Build Area choices train the Build targeting preference; Hand and forced attacks remain useful attack observations without distorting that preference.

Disrupt, Shatter, Escape effects, and other non-attack prompts remain player choices in both modes.
