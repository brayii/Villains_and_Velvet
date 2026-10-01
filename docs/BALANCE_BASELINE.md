# Balance Baseline

Use this baseline before changing Hero card values. Raw statistics are useful
for spotting candidates, but they do not establish that a Hero is too strong
or too weak because abilities depend on board state and team composition.

## Current Hero packages

Each Hero contributes one Normal, one Ability, and one Special definition to
the 45-card Player Deck. The table sums those three unique definitions before
deck-copy counts and ability effects.

| Hero | Unlock victories | Base Attack | Base Health | Main value source |
| --- | ---: | ---: | ---: | --- |
| Goblin | 0 | 16 | 7 | Attack after defeating a Minion |
| Skeleton | 0 | 11 | 12 | Attack shared across a mixed Build |
| Orc | 0 | 7 | 19 | Forced enemy targeting |
| Vampire | 1 | 15 | 9 | Attack plus card recovery or draw |
| Witch | 2 | 10 | 13 | Reduced Minion defeat cost |
| Troll | 3 | 14 | 18 | Increased enemy cost and one prevented defeat |

These totals are descriptive. They must not be treated as a single power score.
For example, Orc Health protects other cards only while Guard or Fortress is
in the Build, while Witch value depends on which Minions can cross a defeat
threshold after the reduction.

## Required evaluation

Evaluate candidate balance changes with repeatable seeded matches. Use the same
Leader, Scenario, Minion Set, Enemy Event mix, targeting policy, and seed set
for every team being compared. Include the original Goblin/Skeleton/Orc team as
the control.

Record at least:

- wins and losses;
- Leader Health remaining;
- turns per match;
- cards drawn and recovered;
- Minions defeated;
- Attack lost because no legal target could be defeated;
- Enemy targeting regret from the existing seeded evaluator; and
- the seed and complete three-Hero team.

Do not change a card from a single match or raw-stat comparison. A proposed
change should improve a repeated weakness without creating a material
regression in other teams that use the same Hero.

## Current conclusion

The repository has deterministic targeting evaluation and extensive startup
self-checks, but it does not yet contain a multi-match outcome dataset covering
all Hero teams. Current evidence supports retaining the card values until that
campaign exists.
