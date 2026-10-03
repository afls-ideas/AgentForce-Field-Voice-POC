/**
 * Resolves a spoken HCP name to an Account. Voice transcripts drop titles, swap
 * name order, and mishear first names, so this tolerates all three and asks the
 * rep to clarify when more than one Account fits.
 */
public with sharing class FieldVoiceHcpResolver {

    public class Resolution {
        public Account account;
        public Boolean exact = false;
        public String message; // spoken explanation when no single account was resolved
    }

    private static final Set<String> TITLES = new Set<String>{
        'dr', 'doctor', 'prof', 'professor', 'md', 'mr', 'mrs', 'ms', 'miss'
    };

    public static List<String> tokens(String raw) {
        List<String> out = new List<String>();
        if (String.isBlank(raw)) return out;
        for (String t : raw.toLowerCase().replaceAll('[.,]', ' ').split('\\s+')) {
            if (String.isNotBlank(t) && !TITLES.contains(t)) out.add(t);
        }
        return out;
    }

    public static Resolution resolve(String rawName) {
        Resolution r = new Resolution();
        List<String> qTokens = tokens(rawName);
        if (qTokens.isEmpty()) {
            r.message = 'I did not catch which doctor you mean. Could you say the name again?';
            return r;
        }

        Map<Id, Account> found = new Map<Id, Account>();
        try {
            List<String> searchTerms = new List<String>();
            for (String t : qTokens) {
                String clean = t.replaceAll('[^\\p{L}\\p{N}]', '');
                if (clean.length() > 0) searchTerms.add(clean);
            }
            if (!searchTerms.isEmpty()) {
                String q = String.join(searchTerms, ' AND ');
                List<List<SObject>> hits = [
                    FIND :q IN NAME FIELDS
                    RETURNING Account(Id, Name, IsPersonAccount)
                    LIMIT 10
                ];
                for (SObject o : hits[0]) found.put(o.Id, (Account) o);
            }
        } catch (Exception e) {
            // fall through to the fuzzy lookup below
        }

        List<Scored> scored = score(found.values(), qTokens);
        if (scored.isEmpty() || scored[0].score > 0) {
            addFuzzyCandidates(found, qTokens);
            scored = score(found.values(), qTokens);
        }

        if (scored.isEmpty()) {
            r.message = 'I could not find anyone named ' + String.join(qTokens, ' ') + '. Could you spell the name or try the last name only?';
            return r;
        }

        Scored best = scored[0];
        Boolean tie = scored.size() > 1 && scored[1].account.Id != best.account.Id
            && (scored[1].score - best.score) <= (best.score == 0 ? 0 : 2);
        if (tie) {
            List<String> names = new List<String>();
            for (Integer i = 0; i < Math.min(3, scored.size()); i++) {
                Account a = scored[i].account;
                names.add(a.Name);
            }
            r.message = 'I found more than one match: ' + FieldVoiceSpeech.joinNatural(names) + '. Which one do you mean?';
            return r;
        }

        r.account = best.account;
        r.exact = best.score == 0;
        return r;
    }

    private class Scored implements Comparable {
        Account account;
        Integer score;
        public Integer compareTo(Object other) {
            Scored o = (Scored) other;
            if (score != o.score) return score - o.score;
            Integer mine = account.IsPersonAccount == true ? 0 : 1;
            Integer theirs = o.account.IsPersonAccount == true ? 0 : 1;
            return mine - theirs;
        }
    }

    /** Lower is better. Each query token is matched to its closest name token, so word order does not matter. */
    private static List<Scored> score(List<Account> candidates, List<String> qTokens) {
        List<Scored> out = new List<Scored>();
        for (Account a : candidates) {
            List<String> cTokens = tokens(a.Name);
            if (cTokens.isEmpty()) continue;
            Integer total = 0;
            Integer misses = 0;
            Boolean anchored = false; // some long word matched exactly, e.g. the surname
            for (String q : qTokens) {
                Integer bestDist = 99;
                for (String c : cTokens) {
                    bestDist = Math.min(bestDist, q.getLevenshteinDistance(c));
                    if (c.startsWith(q) && q.length() >= 3) bestDist = Math.min(bestDist, 0);
                }
                Integer allowed = q.length() <= 2 ? 0 : (q.length() <= 4 ? 1 : Math.max(1, (Integer) Math.round(q.length() * 0.5)));
                if (bestDist <= allowed) {
                    total += bestDist * 2;
                    if (bestDist == 0 && q.length() >= 4) anchored = true;
                } else {
                    misses++;
                    total += 8;
                }
            }
            // One misheard word is forgiven when another word matched exactly.
            Boolean ok = misses == 0 || (misses == 1 && qTokens.size() > 1 && anchored);
            if (!ok) continue;
            Scored s = new Scored();
            s.account = a;
            s.score = total + Math.abs(cTokens.size() - qTokens.size());
            out.add(s);
        }
        out.sort();
        return out;
    }

    private static void addFuzzyCandidates(Map<Id, Account> found, List<String> qTokens) {
        Set<String> patterns = new Set<String>();
        for (String t : qTokens) {
            if (t.length() >= 3) patterns.add('%' + String.escapeSingleQuotes(t) + '%');
            if (t.length() >= 5) patterns.add('%' + String.escapeSingleQuotes(t.substring(0, 3)) + '%');
        }
        for (String p : patterns) {
            List<Account> rows = [
                SELECT Id, Name, IsPersonAccount FROM Account WHERE Name LIKE :p LIMIT 25
            ];
            for (Account a : rows) found.put(a.Id, a);
        }
    }
}
