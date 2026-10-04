# Field Voice: Test Utterances

Copy and paste these into the agent preview or the mobile app, or read them aloud to test speech recognition. Names are sample data; swap in HCPs your user can see.

How to use:
- English agent: `Field_Voice_Agent`. French agent: `Field_Voice_Agent_FR`.
- Each table lists what a good answer looks like. Answers should be short spoken sentences, with relative dates and names, never IDs.
- The agent should never say "PATI" unless you say it first.

## English

### Account and HCP summary (stored summary first)

| Say | Expect |
|---|---|
| Give me the account summary for Grace Liu | Stored summary read in a few sentences, then an offer for more |
| HCP summary for Andrew Kim | Same |
| What do I need to know about Jennifer Tran? | Same |
| Brief me on Aaron Morita | Summary, or a brief built from visits if none is stored |
| Tell me about Brian Sullivan | Same |
| What are the discussion points for Grace Liu? | Only the discussion part of the summary |
| What has changed with Grace Liu recently? | Only the recent changes |

### Visits

| Say | Expect |
|---|---|
| When is my next visit with Brian Sullivan? | Only the next visit |
| When did I last see Andrew Kim? | Only the last visit |
| What is my schedule tomorrow? | Up to three visits, relative times |
| Who should I see next? | The next planned visit |
| How many visits did I make with Jason Gupta this year? | A count |

### Affiliations

| Say | Expect |
|---|---|
| Where does Andrew Kim work? | Primary organization first, then others |
| Who is affiliated with UCSF? | Professionals linked to the organization |
| Who influences Grace Liu? | Related professionals, or "none on file" |

### Medical

| Say | Expect |
|---|---|
| Are there open inquiries for Andrew Kim? | Count, status, age |
| What medical insights do I have for Grace Liu? | Up to three, each with the HCP |

### Events

| Say | Expect |
|---|---|
| What is the status of my event plans? | Event plan status |
| What is the spend limit for my event plan? | Spend limit |

### Detailing (products, messages, leave-behinds, samples)

| Say | Expect |
|---|---|
| What products have I detailed to Andrew Kim? | Product names |
| What did I detail to Grace Liu? | Product names |
| What key messages did I deliver to Andrew Kim and how did he react? | Message count with positive, neutral and negative reactions |
| Do we have leave-behinds for Jennifer Tran? | Leave-behinds, or none on file |
| Any drop-ship samples for Brian Sullivan? | Sample requests, or none on file |
| What approved messages do we have? | Approved messages |

### Concepts (no data access)

| Say | Expect |
|---|---|
| What is a detail? | Glossary answer |
| What is detailing? | Glossary answer |

### Name resolution (speech-to-text errors)

| Say | Expect |
|---|---|
| Account summary for Aron Morita | Resolves to Aaron Morita, says the name aloud |
| What do I need to know about Jenifer Tran? | Resolves to Jennifer Tran |
| Tell me about Dr. Kim | Resolves without a long clarification |

### Off-topic and unclear

| Say | Expect |
|---|---|
| What is the weather today? | Polite decline |
| Tell me about the doctor | Asks which doctor |

## Français (`Field_Voice_Agent_FR`)

### Résumé du compte ou du professionnel de santé

| Dites | Attendu |
|---|---|
| Donne-moi le résumé du compte de Pierre Lefèvre. | Résumé enregistré en français parlé |
| Que dois-je savoir sur Marie-Claire Dubois ? | Même type de réponse |
| Fais-moi le résumé de Jean-Luc Bernard. | Même type de réponse |
| Fais-moi un résumé de Marie Claire Dubois. | Nom reconnu sans trait d'union |
| Parle-moi de Pierre Lefèvre. | Résumé |
| Quels sont les points de discussion pour Pierre Lefèvre ? | Partie discussion seulement |

### Visites

| Dites | Attendu |
|---|---|
| Quand est ma prochaine visite avec Jean-Luc Bernard ? | Prochaine visite seulement |
| Quelle est ma dernière visite avec Marie-Claire Dubois ? | Dernière visite seulement |
| Combien de visites ai-je faites chez Pierre Lefèvre cette année ? | Un nombre |
| Quel est mon planning demain ? | Jusqu'à trois visites |

### Affiliations

| Dites | Attendu |
|---|---|
| Où travaille Pierre Lefèvre ? | Établissement principal, puis les autres |
| Où travaille Pierre Lefebvre ? | Orthographe approximative, retrouvé quand même, le nom est dit à voix haute |
| Dans quels hôpitaux travaille Jean-Luc Bernard ? | Affiliations hospitalières |
| Qui influence Jean-Luc Bernard ? | Professionnels liés, ou aucun |

### Médical

| Dites | Attendu |
|---|---|
| Y a-t-il des demandes d'information en cours pour Marie-Claire Dubois ? | Nombre, statut, ancienneté |
| Quels insights médicaux ai-je pour Pierre Lefèvre ? | Jusqu'à trois |

### Présentation des produits (detailing)

| Dites | Attendu |
|---|---|
| Quels produits ai-je présentés à Marie-Claire Dubois ? | Noms des produits (à corriger : donne aujourd'hui le nombre et les dates) |
| Quels messages clés ai-je présentés à Jean Luc Bernard et comment a-t-il réagi ? | Nombre de messages avec réactions positives, neutres, négatives |
| Ai-je laissé des documents ou des échantillons à Jean-Luc Bernard ? | Éléments laissés, ou aucun |

### Concepts

| Dites | Attendu |
|---|---|
| Qu'est-ce qu'un detailing ? | Réponse du glossaire |

## Known gaps

- "Products detailed" answers give the count and visit timings instead of product names.
- The French key-message answer says "les trois plus récents" after the reaction ordering change.
- Action results are built in English and restated in French by the model.
