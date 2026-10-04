# Field Voice: Test Utterances

Copy and paste these into the agent preview or the mobile app, or read them aloud to test speech recognition. Names are sample data; swap in HCPs your user can see.

How to use:
- One agent per language (`Field_Voice_Agent`, `Field_Voice_Agent_FR`, `_DE`, `_IT`, `_ES`, `_JP`, `_KR`, `_BR`). English and French have the full set; the others have the five core questions.
- Each table lists what a good answer looks like. Answers should be short spoken sentences, with relative dates and names, never IDs.
- The agent should never say "PATI" unless you say it first.

## Test matrix

Last run: 2026-10-04, in the agent preview against live data (`sf agent preview --use-live-actions`). Each agent was asked the five questions below about one sample HCP in its own language, and every answer was checked against the records in the org. Reaction counts, product counts, workplaces and next visits matched the data.

| Agent | Language | Sample HCP | Summary | Next visit | Workplace | Products presented | Key messages and reactions |
|---|---|---|---|---|---|---|---|
| `Field_Voice_Agent` | English | several (see below) | Pass | Pass | Pass | Pass | Pass |
| `Field_Voice_Agent_FR` | French | Amélie Robin | Pass | Weekday wrong once | Pass | Pass | Pass |
| `Field_Voice_Agent_DE` | German | Klaus Müller | Pass | Pass | Pass | Pass | Pass |
| `Field_Voice_Agent_ES` | Spanish | Ana López Serrano | Pass | Pass | Pass | Pass | Pass |
| `Field_Voice_Agent_IT` | Italian | Alessia Santoro | Pass | Pass | Pass | Pass | Pass |
| `Field_Voice_Agent_BR` | Portuguese (Brazil) | Ricardo Silva | Pass | Pass | Pass | Pass | Pass |
| `Field_Voice_Agent_JP` | Japanese | 健 山本 | Pass | Pass | Pass | Pass | Pass |
| `Field_Voice_Agent_KR` | Korean | 민준 이 | Pass | Pass | Pass | Pass | Pass |

What "Pass" means: the answer is in the agent's language, uses spoken sentences and relative dates, names the HCP, and its facts match the org. Summaries are read from the stored Provider Summary. Not yet tested in the non-English languages: misspelled names, concept questions, events, leave-behinds and samples. English and French cover those above.

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
| Quels produits ai-je présentés à Marie-Claire Dubois ? | Noms des produits |
| Quels messages clés ai-je présentés à Jean Luc Bernard et comment a-t-il réagi ? | Nombre de messages avec réactions positives, neutres, négatives |
| Ai-je laissé des documents ou des échantillons à Jean-Luc Bernard ? | Éléments laissés, ou aucun |

### Concepts

| Dites | Attendu |
|---|---|
| Qu'est-ce qu'un detailing ? | Réponse du glossaire |

## Other languages

The same five questions work in every language. Replace the HCP with one from your own territory.

### Deutsch (`Field_Voice_Agent_DE`)

- Gib mir die Kontozusammenfassung für Klaus Müller.
- Wann ist mein nächster Besuch bei Klaus Müller?
- Wo arbeitet Klaus Müller?
- Welche Produkte habe ich Klaus Müller vorgestellt?
- Welche Kernbotschaften habe ich Klaus Müller gegeben und wie hat er reagiert?

### Español (`Field_Voice_Agent_ES`)

- Dame el resumen de la cuenta de Ana López Serrano.
- ¿Cuándo es mi próxima visita con Ana López Serrano?
- ¿Dónde trabaja Ana López Serrano?
- ¿Qué productos le he presentado a Ana López Serrano?
- ¿Qué mensajes clave le di a Ana López Serrano y cómo reaccionó?

### Italiano (`Field_Voice_Agent_IT`)

- Dammi il riepilogo dell'account di Alessia Santoro.
- Quando è la mia prossima visita con Alessia Santoro?
- Dove lavora Alessia Santoro?
- Quali prodotti ho presentato ad Alessia Santoro?
- Quali messaggi chiave ho presentato ad Alessia Santoro e come ha reagito?

### Português do Brasil (`Field_Voice_Agent_BR`)

- Me dê o resumo da conta de Ricardo Silva.
- Quando é minha próxima visita com Ricardo Silva?
- Onde Ricardo Silva trabalha?
- Quais produtos eu apresentei para Ricardo Silva?
- Quais mensagens-chave eu apresentei para Ricardo Silva e como ele reagiu?

### 日本語 (`Field_Voice_Agent_JP`)

- 健 山本のアカウントの概要を教えてください。
- 健 山本との次の訪問はいつですか？
- 健 山本はどこで働いていますか？
- 健 山本にどの製品を説明しましたか？
- 健 山本にどのキーメッセージを伝えて、反応はどうでしたか？

### 한국어 (`Field_Voice_Agent_KR`)

- 민준 이 계정 요약을 알려 주세요.
- 민준 이와의 다음 방문은 언제인가요?
- 민준 이는 어디에서 근무하나요?
- 민준 이에게 어떤 제품을 설명했나요?
- 민준 이에게 어떤 핵심 메시지를 전달했고 반응은 어땠나요?

## Known gaps

- The French next-visit answer named the wrong weekday once in the last run.
- The French key-message answer says "les trois plus récents" after the reaction ordering change.
- Action results are built in English and restated in French by the model.
