# Outcome Tracking

## Schemas

`content-log.yaml`
```yaml
- id: post-2026-07-14
  date: 2026-07-14
  pillar: measurement
  format: long-post
  hook_type: specific-number
  claim: "fact-001"
  goal: "search visibility with PE operating partners"
  outcomes:
    d7:
      tier1: []
      tier2: ["Priya Raman (Kestrel) commented, then messaged"]
      tier3: ["4 profile views from target-profile companies", "2 saves"]
      tier4: { impressions: 4200, reactions: 61, comments: 9 }
    d30:
      tier1: ["Kestrel intro to a CMO search at a PE-backed data company"]
      tier2: []
      tier3: ["11 target-profile profile views"]
      tier4: { impressions: 5100, reactions: 68, comments: 11 }
  note: "The tier-1 outcome came through a comment thread, not the post itself."
```

That last note is the point of the whole schema. The impressions did nothing; one comment thread
produced the only thing that mattered.

`experiments.yaml`
```yaml
- id: exp-004
  hypothesis: "Leading the headline with the CAC number rather than the title increases
               profile views from search-firm partners"
  changed: "Headline v2 -> v3"
  started: 2026-06-01
  window_days: 30
  baseline: { search_appearances: 84, views: 61, target_profile_share: 0.18 }
  result:   { search_appearances: 79, views: 94, target_profile_share: 0.41 }
  conclusion: "Search appearances flat, views up 54%, target share more than doubled.
               The keyword surface didn't change; what changed is who clicked through."
  confidence: medium
  note: "One 30-day window, one change, no control. Directional only."
```

Record confidence and its limits. An experiment with no control over one month is directional, and
saying so protects the user from over-fitting to noise.

## The 30-day review

```
30 days - August

Published    4 posts, 1 article
Outcomes     1 search-firm conversation about a live CMO mandate (Kestrel)
             3 qualified conversations - 2 peer CMOs, 1 PE operating partner
             Target-profile share of profile views: 18% -> 41%
Profile      Headline v3 shipped Jun 1; About rewrite shipped Aug 12

Keep    The measurement pillar. Both tier-2 conversations came off those two posts.
Stop    Reposting the newsletter as a standalone post. Three attempts, nothing above tier 4.
Try     One leadership-pillar post. That pillar is at 0% and it's the one boards read.
```

Five lines of substance. An executive does not need a dashboard, and a dashboard invites optimizing
tier-4 numbers because they are the ones that move.

## Attribution honesty

Most of what matters cannot be cleanly attributed, and pretending otherwise is the failure mode of
every analytics tool.

1. **Report correlation as correlation.** "The three posts before that inquiry were all measurement
   pillar" — not "that pillar generated it."
2. **Refuse conclusions from too little data.** Two posts is not a trend. Say "not enough yet."
   The configured floor is five samples.
3. **Prefer the boring explanation.** Cadence, timing, and audience size explain more variance than
   hook selection.
4. **Never invent a metric.** If it is unavailable, say what would be needed to know it.
5. **Name the confound.** A post that outperformed the week a funding announcement dropped did not
   necessarily outperform.

## Diagnosing "it isn't working"

In order. The common cause is at the top; the expensive fix is at the bottom.

1. **Cadence** — is anything being published consistently? Most cases end here
2. **Audience** — who is actually seeing it? Check viewer composition before touching copy
3. **Positioning** — is the claim specific enough to be remembered?
4. **Profile conversion** — are people arriving and leaving? A content problem and a profile problem
   look identical from outside
5. **Content quality** — last. The most blamed and least often responsible

Routing straight to a rewrite is how these tools waste a user's time on the wrong problem.

## Concluding it is not worth it

If two quarters of consistent effort produced no tier-1 or tier-2 outcomes, say so and offer the
real options: the positioning is wrong, the audience is not on this platform, or the effort belongs
elsewhere.

A tool that always recommends more content is not analyzing anything. For some executives the honest
answer is that three deepened relationships would outperform a year of posting, and
`salience-engage` is where that work happens.
