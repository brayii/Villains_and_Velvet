# Enemy Targeting

Enemy Targeting can be switched between Manual and Auto during a match.

## Manual

The player chooses legal targets for enemy attacks in the Build Area. Manual choices never update AI target-preference learning because the AI did not make those choices.

## Auto

Auto chooses legal Build targets using the Enemy Attack AI and submits them through the same combat commands used by Manual targeting.

Every Auto attack is recorded, including blocked attacks and forced targets. Only genuine Build Area choices train the Build targeting preference; forced attacks remain useful attack observations without distorting that preference. Full Assault follows the same Build-only targeting rule as every other enemy attack.

Build scoring uses each card's actual Enemy destruction cost, including card effects that modify that cost. Overall Auto performance and genuine Build-choice performance use separate reward histories so forced and blocked turns do not distort Build targeting.

Bounded exploration remains available for seeded evaluation but is disabled in normal play until testing demonstrates a reliable improvement. Complete AI stress checks are retained for development builds; production startup runs only lightweight content, configuration, and saved-data validation.

Disrupt, Shatter, Escape effects, and other non-attack prompts remain player choices in both modes.
