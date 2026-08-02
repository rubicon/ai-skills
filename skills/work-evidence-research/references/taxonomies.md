# Evidence taxonomies — project types, evidence types/formats/tiers, metrics

The classification vocabulary for `work-evidence-research`.  Keep the axes distinct:
**format** (file extension) helps *retrieval*; **genre + artifact role** and
**evidence tier** drive *classification*.  Format and genre never set strength on
their own.

---

## Project-type concept clusters

Treat a project-type request as a **cluster of related terms**, never a single
keyword.  Search the whole cluster; "website" alone misses most of the work.  The six
default buckets (customize per corpus):

| Bucket | Cluster terms |
|--------|---------------|
| Website / web | redesign, site launch, CMS migration, sitemap, information architecture, UX/UI, responsive, landing page, web build, WordPress / Drupal / Webflow |
| Analytics / measurement | GA4, Google Tag Manager, tagging, data layer, dashboard, conversion tracking, attribution, reporting, KPI |
| Paid media / advertising | PPC, SEM, paid search, paid social, programmatic, display, media buy, ad ops, campaign management |
| Marketing automation / CRM | email, nurture, drip, lifecycle, lead scoring, segmentation, HubSpot / Marketo / Salesforce, journey |
| Brand / creative / messaging | brand refresh, identity, logo, positioning, messaging, creative, content, copywriting, style guide |
| Mobile / app / product | app build, iOS, Android, product growth, onboarding, feature, mobile UX |

---

## Evidence types (document genre)

The *kind* of artifact, independent of how strong it is:

- **Contractual / financial** — proposal, SOW / contract, change order, invoice.
- **Planning / requirements** — project plan, requirements / spec, creative brief,
  kickoff deck.
- **Presentations / decks** — pitch / new-business deck, capabilities deck, QBR /
  review deck, case-study slides, strategy / recommendations presentation.
- **Results / measurement** — campaign report, analytics / measurement report,
  dashboard export, A/B-test readout.
- **Delivery artifacts** — the site / app / creative files themselves, screenshots,
  staging URLs.
- **Third-party / public** — published case study, press, awards, client reference
  sheet / roster.

A genre is not a strength.  The same genre can be primary proof, corroborating
context, or a weak mention depending on content.

---

## File formats (the retrieval lane)

Used to *find* candidates, never to judge strength.  Map formats to likely genres to
drive discovery:

| Format | Likely genres |
|--------|---------------|
| `.ppt`, `.pptx`, `.key` (+ Google Slides) | decks, presentations, QBRs, case-study slides |
| `.xls`, `.xlsx`, `.csv` (+ Google Sheets) | analytics / reporting / measurement data, budgets |
| `.doc`, `.docx`, `.pdf` (+ Google Docs) | proposals, SOWs, briefs, requirements, invoices |
| `.md`, `.html` | notes, web content, deliverables |

Format never determines tier — a `.pdf` can be a signed SOW *or* an unsigned draft.

---

## Evidence-strength tiers

| Tier | Meaning | Example |
|------|---------|---------|
| **Confirmed** | Direct artifact proving the relationship / work | signed SOW or contract, invoice, client-addressed proposal, the deliverable file, published case study, campaign report attributing the work |
| **Probable** | Strong indirect signal, no direct artifact | client on an internal roster / deck, corroborated resume mention |
| **Needs verification** | Single weak or ambiguous mention | one passing reference, unclear addressee |
| **Role/employer** | Work done as an employee *for* the company, not *for* an external client (not an agency client) | keep separate from client work |
| **Duplicate/alias** | Same entity under different names, or an unresolved naming conflict | flag, do not silently merge |

**Tier is set by artifact role** — the function a source plays for a specific claim
(**primary proof** / **corroborating** / **mention**) — judged from content, role,
and the person's relationship to the client (employer vs. agency).  Never from file
extension or genre label.  A `.docx` proposal can outweigh a `.pdf` roster mention; a
`.csv` may hold strong metrics yet prove no client relationship; the same `.pptx` can
be primary results proof *or* a title-slide mention.

**Tier confirms the relationship/work, not the results.**  A Confirmed project can
still have unproven outcome metrics — confirm each metric separately against an
artifact, and quarantine any asserted result that lacks one.  Confirming the
relationship never auto-upgrades the outcome.

**One source can support more than one classification** when materially justified — a
deck naming two clients yields a row per client; a file that is both a deliverable and
a results readout can be cited as evidence for both.  Judge per claim, not per file.

---

## Metric taxonomy

Separate these strictly; only the first is an outcome.

| Category | Examples | Outcome? |
|----------|----------|----------|
| **Actual outcomes** | revenue lift, conversion-rate change, traffic / lead growth, cost reduction, ranking gains, engagement lift | **Yes** |
| **Scope / operational** | budget, hours, timeline, page count, # templates, team size, # campaigns | No |
| **Client profile** | client revenue, headcount, market size | No — describes the client |
| **Awards / public proof** | awards, press, recognition | Supporting proof, not an outcome metric |
| **Quarantined claims** | asserted results with no supporting artifact | No — quarantine, never upgrade |

---

## Cross-reference

Pass routing and conflict handling:  `workflow-modes.md`.  Output skeletons and the
quoted-CSV rules:  `output-formats.md`.
