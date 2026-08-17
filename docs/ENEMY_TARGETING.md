# Enemy Targeting

Enemy Targeting can be switched between Manual and Auto during a match.

## Manual

The player chooses legal targets for enemy attacks in both the Build Area and the Hand. Manual choices never update AI target-preference learning.

## Auto

Auto chooses legal Build targets using the Enemy Attack AI and submits them through the same combat commands used by Manual targeting.

During Full Assault, Auto also chooses legal Hand targets. It selects the lowest-Health legal Hand card and uses the leftmost slot to break ties. Hand targets are deterministic and do not update conditional weighting, Health weighting, reward learning, or meaningful-choice counts.

Disrupt, Shatter, Escape effects, and other non-attack prompts remain player choices in both modes.
