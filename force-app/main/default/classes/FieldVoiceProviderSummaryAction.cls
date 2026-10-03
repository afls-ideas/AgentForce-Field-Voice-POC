/**
 * Reads the stored Provider Summary (Provider Account Territory Summary) for an HCP or HCO
 * as spoken sentences: engagement highlights, discussion points, and what changed recently.
 */
public with sharing class FieldVoiceProviderSummaryAction {

    public class Request {
        @InvocableVariable(label='HCP or HCO name' description='The doctor or organization, exactly as the user said it.' required=true)
        public String hcpName;
        @InvocableVariable(label='part' description='Optional. engagement for key activities, discussion for talking points for the next visit, changes for recent changes such as affiliations or publications. Leave blank for a short overview.')
        public String part;
    }

    public class Result {
        @InvocableVariable(label='summary' description='Facts written as plain spoken sentences. Say them in your own words.')
        public String summary;
        @InvocableVariable(label='hcpName' description='The full name of the account that was matched.')
        public String hcpName;
    }

    @InvocableMethod(label='Field Voice Provider Summary' description='Reads the stored provider summary for an HCP or HCO: key activities, discussion points, and recent changes.' callout=false)
    public static List<Result> getSummary(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                run(req, res);
            } catch (Exception e) {
                res.summary = 'Something went wrong while reading the provider summary.';
            }
            results.add(res);
        }
        return results;
    }

    private static void run(Request req, Result res) {
        FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve(req.hcpName);
        if (r.account == null) {
            res.summary = r.message;
            return;
        }
        res.hcpName = r.account.Name;
        List<PrvdAccountTerritorySummary> rows = [
            SELECT UserId, KeyInformationSummary, KeyInfoSummaryDateTime, ChangeInformationSummary, Territory2.Name
            FROM PrvdAccountTerritorySummary
            WHERE AccountId = :r.account.Id
            WITH USER_MODE
            ORDER BY KeyInfoSummaryDateTime DESC NULLS LAST
            LIMIT 20
        ];
        PrvdAccountTerritorySummary chosen;
        for (PrvdAccountTerritorySummary row : rows) {
            if (String.isBlank(row.KeyInformationSummary)) {
                continue;
            }
            if (row.UserId == UserInfo.getUserId()) {
                chosen = row;
                break;
            }
            if (chosen == null) {
                chosen = row;
            }
        }
        if (chosen == null) {
            res.summary = 'There is no provider summary on file for ' + r.account.Name + ' yet.';
            return;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(chosen.KeyInformationSummary);
        List<String> engagement = new List<String>();
        List<String> discussion = new List<String>();
        List<String> changes = new List<String>();
        List<String> other = new List<String>();
        for (String bucket : new List<String>{'keyInfo', 'summary', 'changeInfo'}) {
            if (!body.containsKey(bucket)) {
                continue;
            }
            for (Object s : (List<Object>) body.get(bucket)) {
                Map<String, Object> section = (Map<String, Object>) s;
                String name = ((String) section.get('sectionName') == null ? '' : (String) section.get('sectionName')).toLowerCase();
                List<String> target = bucket == 'changeInfo' ? changes
                    : name.contains('discussion') || name.contains('talking') ? discussion
                    : name.contains('activit') || name.contains('engagement') || name.contains('glance') ? engagement
                    : other;
                for (Object d : (List<Object>) section.get('sectionData')) {
                    String text = (String) ((Map<String, Object>) d).get('data');
                    if (!String.isBlank(text)) {
                        target.add(clean(text));
                    }
                }
            }
        }
        if (!String.isBlank(chosen.ChangeInformationSummary) && changes.isEmpty()) {
            changes.add(FieldVoiceSpeech.shorten(clean(chosen.ChangeInformationSummary), 200));
        }

        String part = String.isBlank(req.part) ? '' : req.part.trim().toLowerCase();
        List<String> picked = new List<String>();
        if (part.startsWith('eng') || part.startsWith('act')) {
            picked.addAll(top(engagement, 3));
        } else if (part.startsWith('disc') || part.startsWith('talk')) {
            picked.addAll(top(discussion, 3));
        } else if (part.startsWith('chan') || part.startsWith('new') || part.startsWith('recent')) {
            picked.addAll(top(changes, 3));
        } else {
            picked.addAll(top(engagement, 2));
            picked.addAll(top(discussion, 1));
            picked.addAll(top(other, engagement.isEmpty() && discussion.isEmpty() ? 2 : 1));
        }
        if (picked.isEmpty()) {
            picked.addAll(top(other, 3));
        }
        if (picked.isEmpty()) {
            res.summary = 'The provider summary for ' + r.account.Name + ' has nothing under that topic.';
            return;
        }
        String age = chosen.KeyInfoSummaryDateTime == null ? '' : ' The summary was generated ' + FieldVoiceSpeech.spokenDate(chosen.KeyInfoSummaryDateTime) + '.';
        res.summary = 'Provider summary for ' + r.account.Name + '. ' + String.join(picked, ' ') + age
            + (part == '' && (!discussion.isEmpty() || !changes.isEmpty()) ? ' There is more under discussion points and recent changes.' : '');
    }

    private static List<String> top(List<String> items, Integer n) {
        List<String> out = new List<String>();
        for (Integer i = 0; i < Math.min(n, items.size()); i++) {
            out.add(items[i]);
        }
        return out;
    }

    // stored summaries carry emoji and markup that mean nothing when spoken
    private static String clean(String s) {
        String t = s.replaceAll('[^\\p{L}\\p{N}\\p{P}\\p{Zs}$%+]', '').replaceAll('\\s+', ' ').trim();
        return t.endsWith('.') || t.endsWith('!') || t.endsWith('?') ? t : t + '.';
    }
}
