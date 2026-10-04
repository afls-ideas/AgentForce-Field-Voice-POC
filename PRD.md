# Field Voice: Product Requirements

Status: living document. Last updated 2026-10-03.

## 1. Purpose

Give Life Sciences Cloud (LSC) field teams (sales reps, medical science liaisons, key account managers) a hands-free voice assistant in the Salesforce Mobile app. A rep can ask about visits, doctors, products detailed, events and more while driving or between calls, and hear short, natural answers built from their own org data.

Non-goals: writing or changing records by voice, custom objects or fields (standard objects only), replacing the text-based Agentforce agents.

## 2. Users and context

- Primary user: a field rep (for example a Field Sales Representative) on an iPad or phone, often moving, often speaking names imperfectly.
- Agent type: `AgentforceEmployeeAgent` with Agentforce Voice, published from Agent Script with the `sf` CLI.
- The agent only sees the text of the user's speech. Speech-to-text happens before the agent, so misheard names must be handled in the agent's own name resolution.

## 3. Principles

| # | Principle | What it means in practice |
|---|---|---|
| P1 | Voice-first answers | Plain spoken sentences. No bullets, tables, headings, markdown, or record IDs. Lead with the answer, at most three items, then one short follow-up question. |
| P2 | Relative dates | "tomorrow", "next Tuesday", "about three weeks ago", "October seventh". Skip the year unless it differs. |
| P3 | Names, not IDs | Every answer names the doctor or organization. Related names are queried, not left as IDs. |
| P4 | Seamless name resolution | A spoken name resolves to one account without unnecessary questions (section 5). |
| P5 | Grounded | Facts come only from action results. Never fabricate. |
| P6 | Respect access | Everything is `with sharing` and runs in user mode. |
| P7 | Compliance | Never recommend off-label promotion. Adverse events and quality complaints point to the company reporting process. |
| P8 | Standard objects only | No custom objects or fields are required. |
| P9 | Stored before computed | Prefer a pre-generated summary over rebuilding one from raw records. |

## 4. Functional requirements

### 4.1 Routing and topics

| ID | Requirement |
|---|---|
| R1 | A router subagent sends each request to a topic and never answers directly. Every topic has a way back to the router so the user can change subject. |
| R2 | Concept questions ("what is PATI", "what is a detail") are answered from a built-in glossary without data access. |
| R3 | Visit questions (schedule, last or next visit, who to see next, visit status) are answered from Visit data. |
| R4 | HCP and HCO questions (profile, targeting, affiliations, summary) are answered from one doctor's data. |
| R5 | Medical insights and inquiries are listed with the HCP each is for. |
| R6 | Event plan status and spend limits are answered from event plan data. |
| R7 | Any other LSC object is answered by one generic records topic driven by a catalog (section 4.4). |
| R8 | Unclear requests get a clarifying question. Off-topic requests are declined politely. |

### 4.2 HCP insights

| ID | Requirement |
|---|---|
| R9 | PATI snapshot: targeted or not, territory, last and next visit, visit count this year, open inquiries, insights. |
| R10 | Affiliations: primary organization, other organizations, related professionals, hard vs soft, strength (high, medium, low), influence direction (one way or both), active vs former. Works from an HCP (where do they work) and from an HCO (who is affiliated). |
| R11 | Provider summary first: for a general request ("summary", "brief me", "tell me about", "PATI summary") the agent reads the stored summary (`PrvdAccountTerritorySummary`, the Provider Summary card on the Account page) before building anything. |
| R12 | Only when no stored summary exists does the agent build a brief from visits, PATI, insights and inquiries. |
| R13 | Specific facts (next visit, last visit, visit count) skip the summary and go to the brief. |
| R14 | The stored summary can be read in parts: engagement, discussion points, recent changes. It prefers the signed-in user's own row and mentions how old the summary is. |
| R15 | The reader accepts the different JSON shapes found in the data (`keyInfo`, `changeInfo`, `summary`), strips emoji and markup, and classifies sections by name. |

### 4.3 Summary data

| ID | Requirement |
|---|---|
| R16 | Where a summary is blank for an account in a territory, populate it. Summaries for the US-W-San Francisco territory come from the sibling Power Agent project (`hcp_summaries_SF.md`, matched by account name) or are built from the account's own visits, inquiries and affiliations. |
| R17 | Stored format: `{"keyInfo":[{"sectionName":"...","sectionData":[{"data":"..."}]}],"changeInfo":[...]}` in `KeyInformationSummary`, with `KeyInfoSummaryDateTime` set. A row needs the account, territory, user and owner. |

### 4.4 Generic LSC object framework

| ID | Requirement |
|---|---|
| R18 | A catalog holds, per object: description, spoken synonyms, speakable fields, status field, date field, headline field, HCP filter, searchable related names and child counts. Adding an object means adding one entry. |
| R19 | The generic action matches the user's words to an object (stemmed synonyms), falls back to matching API names for unlisted objects, and reports clearly when nothing matches. |
| R20 | Supported inputs: object, HCP name, search text, status, timeframe (upcoming, past), mode (list, count, explain), max results. |
| R21 | Catalogued objects today: presentations and pages, presentation access and content, managed events, sessions, participants, types, budgets, products, event plans, sample limits, product details, product messages, product discussions, approved messages (product guidance), leave-behinds, drop-ship samples, account product info, experts, surveys, assessments, activity plans and goals, goal definitions, territories. |
| R22 | Detailing vocabulary: "detailing" is the general term for presenting a product. "Products detailed", "what did I detail", "product details" map to product details. "Key messages" and "how did they react" map to product messages with their positive, neutral or negative reaction. "Leave-behinds", "sample requests" and "approved messages" map to their own objects. These questions route to the records topic, not the visits topic, even when a doctor or visit is named. |

### 4.5 Name resolution

| ID | Requirement |
|---|---|
| R23 | One shared resolver turns a spoken name into an account. It strips titles, accepts any name order, and runs SOSL plus a fuzzy fallback. |
| R24 | Scoring tolerates speech-to-text errors: a vowel-insensitive skeleton distance adds one point of tolerance, and a miss costs more the further the name is from the best match. |
| R25 | Ties go to the candidate the user actually works with (a visit or active PATI visible to them). The agent asks "which one" only when candidates stay genuinely close, and says the matched name aloud so the user can correct it. |

### 4.6 Languages

| ID | Requirement |
|---|---|
| R26 | One agent per language, copied from the English agent. `Field_Voice_Agent_FR` sets the agent language to French, uses French welcome and error messages, and is told to answer in spoken French with "vous". |
| R27 | The voice block uses the V2 properties (`language` with `default_locale`) so the platform selects the French voice persona, speech recognition model and speech output model. V1 and V2 voice properties cannot be mixed. |
| R28 | Action results stay in English; the agent restates them in French. Localizing the Apex wording is a later step. |

## 5. Non-functional requirements

| ID | Requirement |
|---|---|
| N1 | Salesforce API version 67.0 everywhere (`sourceApiVersion` and package versions). |
| N2 | Apex is `with sharing` and uses `WITH USER_MODE` or `AccessLevel.USER_MODE`. |
| N3 | Stay within governor limits: cache the global describe, never describe every object, and filter long-text fields in Apex, not SOQL. |
| N4 | Each action returns a `summary` string and, when known, the matched `hcpName`. |
| N5 | Access is granted through the `Field_Voice_Agent_Access` permission set, which lists every class. Adding an action means adding its class there. |
| N6 | Published repo contains no org names, usernames, credentials or record IDs. |
| N7 | Every change is verified with Apex tests plus a live `sf agent preview` run against real data. |

## 6. Architecture summary

```
Field_Voice_Agent
└── agent_router
    ├── lsc_concepts       glossary
    ├── lsc_visits         FieldVoiceVisitsAction
    ├── lsc_hcp_insights   FieldVoiceProviderSummaryAction (first), FieldVoiceHcpBriefAction, FieldVoiceAffiliationsAction
    ├── lsc_medical        FieldVoiceInquiriesAction, FieldVoiceInsightsAction
    ├── lsc_events         FieldVoiceEventPlanAction
    ├── lsc_records        FieldVoiceRecordsAction + FieldVoiceLscCatalog
    ├── general_crm        standard IdentifyRecordByName, QueryRecords
    └── ambiguous_question, off_topic
```

Shared helpers: `FieldVoiceHcpResolver` (names) and `FieldVoiceSpeech` (spoken dates, lists, counts). See `README.md` for the class table and deploy steps.

## 7. Platform findings that shaped the design

- Agent Script: one `@InvocableMethod` per class; `target: "apex://Class"`; re-activate after every publish.
- Apex: `when`, `where`, `select` are reserved words; long-text fields cannot be filtered or aggregated in SOQL; `Account` flags several fields as name fields, so prefer `Name`; `Account.BillingCity` is unreadable for rep profiles; PATI date fields are read-only.
- Search Agent voice does not work (not supported), so voice runs on a power agent.
- Mobile Insights related list needs field access on `MedicalInsightAccount` (object read also requires Account and Contact read).

## 8. Test and acceptance

| Scenario | Expected |
|---|---|
| "Give me the provider summary for Grace Liu" | Reads the stored summary in a few sentences and offers more. |
| "Tell me about" a doctor with no stored summary | Builds a brief from visits and PATI. |
| "When is my next visit with Brian Sullivan" | Answers only the next visit. |
| "Aaron Morita" said aloud | Resolves to Aaron Morita without asking about similar names. |
| "What products have I detailed to Andrew Kim" | Names the products in priority order from product details. |
| "What key messages did I deliver and how did he react" | Summarizes messages with positive, neutral, negative reactions. |
| "Do we have leave-behinds or drop-ship samples for X" | Answers from those objects, or says none on file. |
| "What is a detail" | Glossary answer, no data call. |

## 9. Open items

- Revert the non-working voice setup on the Search Agent in the org (unanswered).
- `general_crm` still uses standard query actions and gives no related names.
- Regenerate the mobile metadata cache if a newly granted object still shows "not found" on the device.
- Extend the catalog as new LSC objects appear (the generic action already falls back to API-name discovery).
