/**
 * Spoken answers about medical insights, optionally for one HCP.
 */
public with sharing class FieldVoiceInsightsAction {

    public class Request {
        @InvocableVariable(label='HCP name' description='Optional. Limit to insights that mention one doctor or organization.')
        public String hcpName;
        @InvocableVariable(label='top' description='True for the most upvoted insights. Otherwise the newest come first.')
        public Boolean topOnly;
    }

    public class Result {
        @InvocableVariable(label='summary' description='Facts written as plain spoken sentences. Say them in your own words.')
        public String summary;
        @InvocableVariable(label='hcpName' description='The HCP that was matched, if one was named.')
        public String hcpName;
    }

    @InvocableMethod(label='Field Voice Medical Insights' description='Answers in spoken sentences about medical insights: what they say, who they mention, and how many upvotes they have.')
    public static List<Result> getInsights(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                run(req, res);
            } catch (Exception e) {
                res.summary = 'Something went wrong while looking up medical insights.';
            }
            results.add(res);
        }
        return results;
    }

    private static void run(Request req, Result res) {
        Account acct = null;
        String lead = '';
        Set<Id> insightIds = null;
        if (String.isNotBlank(req.hcpName)) {
            FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve(req.hcpName);
            if (r.account == null) { res.summary = r.message; return; }
            acct = r.account;
            res.hcpName = acct.Name;
            if (!r.exact) lead = 'I matched that to ' + acct.Name + '. ';
            insightIds = new Set<Id>();
            for (MedicalInsightAccount mia : [SELECT MedicalInsightId FROM MedicalInsightAccount WHERE AccountId = :acct.Id LIMIT 200]) {
                insightIds.add(mia.MedicalInsightId);
            }
            if (insightIds.isEmpty()) {
                res.summary = lead + 'I do not see any medical insights that mention ' + acct.Name + '.';
                return;
            }
        }

        String soql = 'SELECT Content, TopicNames, UpvoteCount, CreatedDate FROM MedicalInsight'
            + (insightIds != null ? ' WHERE Id IN :ids' : '')
            + (req.topOnly == true ? ' ORDER BY UpvoteCount DESC NULLS LAST, CreatedDate DESC' : ' ORDER BY CreatedDate DESC')
            + ' LIMIT 3';
        List<MedicalInsight> rows = Database.queryWithBinds(soql, new Map<String, Object>{'ids' => insightIds}, AccessLevel.USER_MODE);
        if (rows.isEmpty()) {
            res.summary = lead + 'I do not see any medical insights.';
            return;
        }

        // Which HCPs each insight mentions, so the answer names them.
        Map<Id, List<String>> namesByInsight = new Map<Id, List<String>>();
        for (MedicalInsightAccount mia : [
            SELECT MedicalInsightId, Account.Name FROM MedicalInsightAccount WHERE MedicalInsightId IN :rows
        ]) {
            if (!namesByInsight.containsKey(mia.MedicalInsightId)) namesByInsight.put(mia.MedicalInsightId, new List<String>());
            if (mia.Account != null) namesByInsight.get(mia.MedicalInsightId).add(mia.Account.Name);
        }

        List<String> parts = new List<String>();
        for (MedicalInsight mi : rows) {
            String text = FieldVoiceSpeech.shorten(mi.Content, 180);
            List<String> names = namesByInsight.get(mi.Id);
            String about = acct == null && names != null && !names.isEmpty() ? ', about ' + FieldVoiceSpeech.joinNatural(names) : '';
            String votes = mi.UpvoteCount != null && mi.UpvoteCount > 0 ? ', with ' + FieldVoiceSpeech.count((Integer) mi.UpvoteCount, 'upvote', 'upvotes') : '';
            parts.add('"' + text + '"' + about + votes + ', from ' + FieldVoiceSpeech.spokenDate(mi.CreatedDate));
        }
        res.summary = lead + (req.topOnly == true ? 'The top insights' : 'The latest insights') + (acct != null ? ' for ' + acct.Name : '') + ' are: ' + String.join(parts, '. Next: ') + '.';
    }
}
