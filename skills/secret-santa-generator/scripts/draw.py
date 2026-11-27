#!/usr/bin/env python3
"""Draw Secret Santa assignments uniformly at random among all valid ones.

Reads one JSON object on stdin:

    {
      "participants": ["Alice", "Bob", "Carol"],
      "exclusions": [["Alice", "Bob"]],      # optional, symmetric
      "no_mutual_pairs": false                # optional, forbids A<->B
    }

Writes one JSON object on stdout with "status" set to "ok" (exit 0),
"impossible" or "too_constrained" (exit 2), or "error" (exit 1).

A draw is a uniformly random permutation that is accepted only if it is
valid, so every valid assignment is equally likely. Standard library only.
"""

import json
import random
import sys

MAX_TRIES = 200_000
SEARCH_NODE_LIMIT = 200_000


class InputError(Exception):
    pass


def make_rng(seed):
    # The seed exists for tests only. Real draws use the OS entropy source.
    return random.SystemRandom() if seed is None else random.Random(seed)


def clean(name):
    return " ".join(str(name).split())


def parse(payload):
    if not isinstance(payload, dict) or not isinstance(payload.get("participants"), list):
        raise InputError("Input must be an object with a 'participants' list.")
    people = [clean(n) for n in payload["participants"]]
    people = [n for n in people if n]
    if len(people) < 2:
        raise InputError("A Secret Santa needs at least two participants.")
    seen = {}
    for name in people:
        seen.setdefault(name.casefold(), []).append(name)
    dupes = [names for names in seen.values() if len(names) > 1]
    if dupes:
        listed = "; ".join(f"{names[0]} x{len(names)}" for names in dupes)
        raise InputError(f"Duplicate names (case-insensitive): {listed}.")
    index = {name.casefold(): i for i, name in enumerate(people)}

    banned = set()
    raw = payload.get("exclusions") or []
    if not isinstance(raw, list):
        raise InputError("'exclusions' must be a list of name pairs.")
    for pair in raw:
        if not isinstance(pair, list) or len(pair) != 2:
            raise InputError(f"Each exclusion must be a pair of two names: {pair!r}.")
        ids = []
        for name in pair:
            key = clean(name).casefold()
            if key not in index:
                raise InputError(f"Exclusion name '{clean(name)}' is not a participant.")
            ids.append(index[key])
        if ids[0] == ids[1]:
            raise InputError(f"Exclusion pairs '{people[ids[0]]}' with itself.")
        banned.add(frozenset(ids))
    return people, banned, bool(payload.get("no_mutual_pairs", False))


def allowed(n, banned):
    return [[j for j in range(n) if j != i and frozenset((i, j)) not in banned] for i in range(n)]


def has_perfect_matching(options):
    """Kuhn's augmenting-path algorithm: can every giver get a distinct recipient?"""
    n = len(options)
    owner = [-1] * n

    def augment(i, visited):
        for j in options[i]:
            if j not in visited:
                visited.add(j)
                if owner[j] == -1 or augment(owner[j], visited):
                    owner[j] = i
                    return True
        return False

    return all(augment(i, set()) for i in range(n))


def search_without_pairs(options):
    """Backtracking for a valid assignment with no 2-cycles.

    Returns True, False, or None when the node limit is reached.
    """
    n = len(options)
    target = [-1] * n
    taken = [False] * n
    nodes = 0

    def step(assigned):
        nonlocal nodes
        nodes += 1
        if nodes > SEARCH_NODE_LIMIT:
            raise TimeoutError
        if assigned == n:
            return True
        best, best_choices = None, None
        for i in range(n):
            if target[i] == -1:
                choices = [j for j in options[i] if not taken[j] and target[j] != i]
                if best_choices is None or len(choices) < len(best_choices):
                    best, best_choices = i, choices
        for j in best_choices:
            target[best], taken[j] = j, True
            if step(assigned + 1):
                return True
            target[best], taken[j] = -1, False
        return False

    try:
        return step(0)
    except TimeoutError:
        return None


def is_valid(perm, banned, no_mutual_pairs):
    for i, j in enumerate(perm):
        if i == j or frozenset((i, j)) in banned:
            return False
        if no_mutual_pairs and perm[j] == i:
            return False
    return True


def impossible(people, options, reason=None):
    stuck = [people[i] for i, o in enumerate(options) if not o]
    if stuck:
        reason = "No one is left for " + ", ".join(stuck) + " to give to."
    return {"status": "impossible", "reason": reason or "No assignment satisfies every rule."}


def run(payload):
    try:
        people, banned, no_mutual_pairs = parse(payload)
    except InputError as exc:
        return {"status": "error", "error": str(exc)}

    n = len(people)
    options = allowed(n, banned)
    if not has_perfect_matching(options):
        return impossible(people, options)
    if no_mutual_pairs and search_without_pairs(options) is False:
        return impossible(people, options, "Every assignment that fits the exclusions needs a mutual pair.")

    rng = make_rng(payload.get("seed"))
    perm = list(range(n))
    for _ in range(MAX_TRIES):
        rng.shuffle(perm)
        if is_valid(perm, banned, no_mutual_pairs):
            break
    else:
        return {
            "status": "too_constrained",
            "reason": f"No valid assignment turned up in {MAX_TRIES} random draws. "
                      "Remove an exclusion so a fair draw is practical.",
        }

    return {
        "status": "ok",
        "assignments": [{"giver": people[i], "recipient": people[j]} for i, j in enumerate(perm)],
        "summary": {
            "participants": n,
            "pairings": n,
            "exclusions": len(banned),
            "no_mutual_pairs": no_mutual_pairs,
            "validated": True,
        },
    }


def main():
    try:
        payload = json.loads(sys.stdin.read())
    except json.JSONDecodeError as exc:
        result = {"status": "error", "error": f"Input is not valid JSON: {exc}"}
    else:
        result = run(payload)
    print(json.dumps(result, indent=2))
    return {"ok": 0, "error": 1}.get(result["status"], 2)


if __name__ == "__main__":
    sys.exit(main())
