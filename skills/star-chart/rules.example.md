# star-chart rules

star-chart reads this file on every run. Change the values after the colons, and add one bullet
per entry in the sections below. Lines that are not bullets are ignored.

## Settings

- Stale cutoff (months without a push): 24
- Protect recent stars (days): 90
- Flag archived repos: yes
- Flag descriptions containing: deprecated, unmaintained
- Target number of Lists: 20

## Keep always

Repos matching these patterns are never proposed for unstarring. Match against owner/repo, ignoring
case; `*` matches anything. Add one bullet per pattern, such as an owner followed by `/*`.

## Categories to use

List names Claude should prefer when it proposes Lists. One bullet per name.

## Categories to avoid

List names or themes Claude should not propose. One bullet per entry.
