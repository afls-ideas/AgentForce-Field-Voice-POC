/**
 * Spoken answers about affiliations. For an HCP: the organizations they are tied to
 * (primary first) and the other professionals they are connected to, with strength
 * and influence. For an HCO: the HCPs affiliated with it.
 */
public with sharing class FieldVoiceAffiliationsAction {

    public class Request {
        @InvocableVariable(label='HCP or HCO name' description='The doctor or organization, exactly as the user said it.' required=true)
        public String accountName;
        @InvocableVariable(label='related type' description='Optional. organizations to hear only about hospitals and practices, or people to hear only about other professionals and their influence.')
        public String relatedType;
        @InvocableVariable(label='include inactive' description='True to also include affiliations that are no longer active.')
        public Boolean includeInactive;
    }

    public class Result {
        @InvocableVariable(label='summary' description='Facts written as plain spoken sentences. Say them in your own words.')
        public String summary;
        @InvocableVariable(label='hcpName' description='The full name of the account that was matched.')
        public String hcpName;
    }

    @InvocableMethod(label='Field Voice Affiliations' description='Answers in spoken sentences about an HCP or HCO affiliations: primary and other organizations, related professionals, strength, and influence.')
    public static List<Result> getAffiliations(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                run(req, res);
            } catch (Exception e) {
                res.summary = 'Something went wrong while looking up affiliations.';
            }
            results.add(res);
        }
        return results;
    }

    private class Link {
        Id otherId;
        String otherName;
        Boolean otherIsPerson;
        String strength;
        String influence;
        String affType;
        String role;
        Boolean isPrimary;
        Integer rank() {
            Integer s = strength == 'High' ? 0 : (strength == 'Medium' ? 1 : (strength == 'Low' ? 2 : 3));
            return (isPrimary == true ? 0 : 100) + s * 10 + (affType == 'Hard' ? 0 : 5);
        }
    }

    private class ByRank implements System.Comparator<Link> {
        public Integer compare(Link a, Link b) {
            return a.rank() - b.rank();
        }
    }

    private static void run(Request req, Result res) {
        FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve(req.accountName);
        if (r.account == null) { res.summary = r.message; return; }
        Account subject = r.account;
        res.hcpName = subject.Name;
        String lead = r.exact ? '' : 'I matched that to ' + subject.Name + '. ';
        Boolean subjectIsPerson = subject.IsPersonAccount == true;
        String type = String.isBlank(req.relatedType) ? '' : req.relatedType.toLowerCase();
        Boolean wantPeople = type.startsWith('peop') || type.startsWith('prof') || type.startsWith('infl');
        Boolean wantOrgs = type.startsWith('org');

        List<ProviderAffiliation> rows = [
            SELECT AccountId, AccountName, RelatedAccountId, RelatedAccountName, AffiliationStrengthType,
                   InfluenceType, AffiliationType, Role, IsPrimary, IsActive,
                   IsAccountPersonAccount, IsRelatedAccountPersonAccount
            FROM ProviderAffiliation
            WHERE (AccountId = :subject.Id OR RelatedAccountId = :subject.Id)
            LIMIT 200
        ];

        Map<Id, Link> byOther = new Map<Id, Link>();
        Integer inactive = 0;
        for (ProviderAffiliation pa : rows) {
            if (pa.IsActive != true && req.includeInactive != true) { inactive++; continue; }
            Boolean subjectIsFirst = pa.AccountId == subject.Id;
            Link l = new Link();
            l.otherId = subjectIsFirst ? pa.RelatedAccountId : pa.AccountId;
            l.otherName = subjectIsFirst ? pa.RelatedAccountName : pa.AccountName;
            l.otherIsPerson = subjectIsFirst ? pa.IsRelatedAccountPersonAccount == true : pa.IsAccountPersonAccount == true;
            l.strength = pa.AffiliationStrengthType;
            l.influence = pa.InfluenceType;
            l.affType = pa.AffiliationType;
            l.role = pa.Role;
            l.isPrimary = pa.IsPrimary;
            if (String.isBlank(l.otherName) || l.otherId == subject.Id) continue;
            if (wantPeople && !l.otherIsPerson) continue;
            if (wantOrgs && l.otherIsPerson) continue;
            Link existing = byOther.get(l.otherId);
            if (existing == null || l.rank() < existing.rank()) byOther.put(l.otherId, l);
        }

        List<Link> orgs = new List<Link>();
        List<Link> people = new List<Link>();
        for (Link l : byOther.values()) (l.otherIsPerson ? people : orgs).add(l);
        orgs.sort(new ByRank());
        people.sort(new ByRank());

        if (orgs.isEmpty() && people.isEmpty()) {
            res.summary = lead + 'I do not see any ' + (req.includeInactive == true ? '' : 'active ') + 'affiliations for ' + subject.Name + '.'
                + (inactive > 0 ? ' There ' + (inactive == 1 ? 'is one inactive affiliation' : 'are ' + inactive + ' inactive ones') + ' on record.' : '');
            return;
        }

        List<String> s = new List<String>();
        if (subjectIsPerson) {
            if (!orgs.isEmpty()) s.add(describeOrgs(subject.Name, orgs));
            if (!people.isEmpty()) s.add(describePeople(subject.Name, people, !orgs.isEmpty()));
        } else {
            // An organization: the people tied to it.
            List<Link> all = new List<Link>();
            all.addAll(people);
            all.addAll(orgs);
            s.add(describeMembers(subject.Name, all));
        }
        if (inactive > 0 && req.includeInactive != true) {
            s.add('There ' + (inactive == 1 ? 'is also one inactive affiliation' : 'are also ' + inactive + ' inactive ones') + ' I left out.');
        }
        res.summary = lead + String.join(s, ' ');
    }

    private static String describeOrgs(String who, List<Link> orgs) {
        List<String> parts = new List<String>();
        Link first = orgs[0];
        String out = who + ' is affiliated with ' + FieldVoiceSpeech.count(orgs.size(), 'organization', 'organizations') + '.';
        Integer startAt = 0;
        if (first.isPrimary == true) {
            out += ' The primary one is ' + first.otherName + typeNote(first) + '.';
            startAt = 1;
        }
        Integer shown = 0;
        for (Integer i = startAt; i < orgs.size() && shown < 3; i++) {
            parts.add(orgs[i].otherName + typeNote(orgs[i]));
            shown++;
        }
        if (!parts.isEmpty()) {
            Integer more = orgs.size() - startAt - shown;
            out += (startAt == 1 ? ' The others include ' : ' They include ') + FieldVoiceSpeech.joinNatural(parts)
                + (more > 0 ? ', and ' + more + ' more' : '') + '.';
        }
        return out;
    }

    private static String describePeople(String who, List<Link> people, Boolean alsoOrgs) {
        List<String> parts = new List<String>();
        for (Integer i = 0; i < people.size() && i < 3; i++) {
            Link l = people[i];
            List<String> bits = new List<String>();
            if (String.isNotBlank(l.strength)) bits.add(l.strength.toLowerCase() + ' strength');
            String infl = influenceText(l.influence);
            if (infl != null) bits.add(infl);
            String roleText = roleText(l.role);
            if (roleText != null) bits.add(roleText);
            parts.add(l.otherName + (bits.isEmpty() ? '' : ', ' + String.join(bits, ', ')));
        }
        Integer more = people.size() - parts.size();
        return (alsoOrgs ? 'They are also connected to ' : who + ' is connected to ')
            + FieldVoiceSpeech.count(people.size(), 'other professional', 'other professionals') + ': '
            + String.join(parts, '; ') + (more > 0 ? '; and ' + more + ' more' : '') + '.';
    }

    private static String describeMembers(String orgName, List<Link> all) {
        Integer primaryCount = 0;
        for (Link l : all) if (l.isPrimary == true) primaryCount++;
        List<String> names = new List<String>();
        for (Integer i = 0; i < all.size() && i < 3; i++) names.add(all[i].otherName);
        String out = orgName + ' has ' + FieldVoiceSpeech.count(all.size(), 'affiliated professional', 'affiliated professionals') + '.';
        if (primaryCount > 0) out += ' For ' + primaryCount + ' of them it is the primary affiliation.';
        out += ' They include ' + FieldVoiceSpeech.joinNatural(names) + (all.size() > 3 ? ', and ' + (all.size() - 3) + ' more' : '') + '.';
        return out;
    }

    private static String typeNote(Link l) {
        if (l.affType == 'Hard') return ', a hard affiliation';
        if (l.affType == 'Soft') return ', a soft affiliation';
        return '';
    }

    private static String influenceText(String influence) {
        if (influence == 'Bidirectional') return 'influence goes both ways';
        if (influence == 'Unidirectional') return 'influence goes one way';
        if (influence == 'Neutral') return 'neutral influence';
        return null;
    }

    private static String roleText(String role) {
        if (role == null) return null;
        String r = role.toLowerCase();
        if (r.contains('consult')) return 'a consulting relationship';
        if (r.contains('attending')) return 'an attending relationship';
        return null;
    }
}
