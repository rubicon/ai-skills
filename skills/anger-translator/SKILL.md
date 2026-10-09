---
name: anger-translator
version: 0.2.0  # x-release-please-version
description: >-
  Use when the user has a heated, angry, or frustrated draft (email, Slack,
  text, letter) and wants it sendable at work without losing its force, or asks
  to "anger translate" it, "make this professional without softening it", "say
  this without getting fired", "tone this down", "make this less angry",
  "clean up this rant before I send it", or "keep it firm but not hostile".
---

# Anger Translator

Turn what the user is angry about into a message they can send at work: the same grievance, the same ask, the same seriousness, with nothing in it that could get them disciplined or fired.

**Direction.** Heat goes in, firmness comes out. "Anger translate" here never means making a calm message angrier.

**The test for every output.** The recipient cannot miss how serious this is, and the message survives being forwarded to the recipient's manager, to HR, or as a screenshot.

## 1. Read the draft

Work out, from the draft and the request:

- **Emotion and intensity** (1-10).
- **Intent**: the outcome the user actually wants (stop the late shipments, get the title, get the harassment dealt with).
- **Audience and power**: writing up (to a boss or skip-level), across (peer), down (the user manages them), or out (client, vendor, contractor). Plus channel, and who else sees it (public channel, CCs, thread).
- **Stakes**: is this a formal complaint (harassment, discrimination, safety, pay) that HR or a lawyer may read later?

When something cannot be inferred, assume, state the assumption in the Read line, and still deliver the message. If the assumption is make-or-break (who the recipient is relative to the user, or whether this is a formal complaint), end the answer with one question to confirm it.

## 2. Keep the substance, remove the heat

**Keep**, at full strength:
- Every fact the user gave, including counts ("third time"), dates, quotes of what the other person said, and dollar amounts.
- A quote attached with only what the user gave: "Kevin also said I would 'be too distracted soon anyway'" or "On [date], Kevin said ...". Never supply the occasion ("when I asked", "when I raised this") yourself.
- The ask, stated plainly as what the user needs.
- Any consequence the user stated ("or we're done", "or I'm calling your boss"), rewritten as a calm conditional: "If X isn't resolved by [date], I'll [the user's own consequence]."
- Protected-class facts that are the substance of a complaint (pregnancy, race, age, disability, religion, sex), stated neutrally. "After I told Kevin I was pregnant" stays.

**Remove**: profanity, insults, sarcasm, all-caps, threats of harm, character attacks, contempt aimed at someone's identity, and guesses about motives.

**Convert** conclusions the user cannot prove into the facts behind them, using only facts already in the draft. "You lied" becomes "The date you gave me on the 3rd changed on the 10th" when the draft gives those dates. If the draft has no facts behind the conclusion, remove it and say in Watch out what evidence would support it.

**Carry the intensity through firmness**: specifics, short declarative sentences, a direct ask, a deadline. If the user gave no date, put `[date]` and leave it for the user to fill in; never make one up. (An already-calm draft is the exception; see section 4.)

## 3. Never add what the user did not say

The translated message adds no facts (including connecting context such as "when I asked him about it" or "my performance hasn't changed" that the user never said), no new asks or demands, no apologies, no self-blame ("which is on me"), no softeners ("just", "sorry to bother", "I value our relationship", "help me understand what I was missing"), no new escalation, and no new recipients or CCs. Where a specific is missing, use a `[bracketed placeholder]`. If you think an ask, a recipient, or a next step is missing, suggest it in Watch out; the message itself carries only what the user said.

## 4. Adjust for the situation

- **Writing up**: no ultimatums the user did not make; frame asks as what the user needs and what they have done.
- **Writing down** (the user manages the recipient): private, not in a group channel; the expectation, its business reason, and an opening to raise a cause. Keep a job-loss threat as a consequence, but name it with a placeholder the manager fills in, "If this continues, [the consequence you are prepared to apply]", and add a Watch out to check the company's HR process before putting job consequences in writing. Do not invent a process the user did not mention.
- **Already calm**: change little or nothing, and say so. Add no force, deadlines, placeholders, or consequences.
- **User asks to keep profanity or sarcasm**: the message still contains none, including mild words like "damn" or "hell", and including when the user is senior or says it's fine in their culture. One profane word is what gets screenshotted and forwarded. Keep the edge with short, blunt sentences, and add a Removed bullet saying you declined the request.
- **Not in English**: write the whole answer in the user's language, including the labels and the Removed categories.
- **Threads and CCs**: leave quoted earlier messages untouched; do not add or remove recipients.

Always deliver the translated message, even when you think it should not be sent as written. Put that advice in Watch out, not in place of the draft.

## 5. Answer in this shape

1. `**Read:**` one line: emotion, intensity, intent, audience. Example: "Furious, 9/10. Intent: brochures delivered before Thursday. Audience: vendor, external."
2. The translated message, once, in a quote block. One version only.
3. `**Removed:**` one bullet per category of what was cut, in the form `Category: why it hurts the user.` The category is one of: Profanity, Insult, Sarcasm, All-caps, Threat, Character attack, Identity contempt, Unprovable accusation, Motive guess. A consequence the user stated is kept, not removed, so it never appears here. Never repeat a threat, slur, or identity remark from the draft; the category name says enough. Example: "Threat: a written threat can get you fired and gives them grounds to dismiss the complaint."
4. `**Watch out:**` only when there is a real political or legal risk: wrong channel, going over someone's head, a claim to verify before sending, a formal complaint the user may want on record with HR. These are suggestions for the user to act on; nothing here changes the message. Omit it otherwise.

Do not send anything. The user sends.

## Example

User: "Anger translate this for our print vendor: 'Are you f***ing kidding me? THIRD time the brochures are late. Trade show is Thursday. Your rep never answers. Get them here or we're done.'"

**Read:** Furious, 9/10. Intent: brochures delivered before Thursday's trade show. Audience: vendor, external.

> Hi [Name],
>
> This is the third time our brochure order has shipped late, and our trade show is Thursday. I need the brochures delivered by [day/time]. I have not been able to reach [rep name] by phone.
>
> If they don't arrive in time for the show, we'll be moving our print work to another vendor.
>
> [Your name]

**Removed:**
- Profanity: it lets them answer your tone instead of your deadline.
- All-caps: the count of late shipments already carries the emphasis.

**Watch out:**
- Add the order number and the dates of the two earlier late shipments if you have them; they make "third time" hard to dispute.
