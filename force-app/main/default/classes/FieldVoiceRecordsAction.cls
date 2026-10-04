/**
 * One action that answers questions about any Life Sciences Cloud object. It matches
 * what the user said ("presentations", "the Paris event", "who is attending") to a
 * catalog entry (or discovers the object from schema describe), builds a user-mode
 * dynamic query, resolves the doctor by name, and returns spoken-friendly facts with
 * related names instead of IDs.
 */
public with sharing class FieldVoiceRecordsAction {

    public class Request {
        @InvocableVariable(label='object' description='What kind of record the user is asking about, in their words, for example presentations, managed events, event participants, sample limits, experts, activity plans, territories.' required=true)
        public String objectName;
        @InvocableVariable(label='HCP name' description='Optional. A doctor, exactly as the user said it, to narrow the records to that person.')
        public String hcpName;
        @InvocableVariable(label='search text' description='Optional. Words from the record name, such as Paris or Immunexis.')
        public String searchText;
        @InvocableVariable(label='status' description='Optional. A status value such as Active, Draft, Approved, Execute, Concluded, Planned, Completed.')
        public String status;
        @InvocableVariable(label='timeframe' description='Optional. upcoming for things that have not happened yet, past for things that already happened. Leave blank for any time.')
        public String timeframe;
        @InvocableVariable(label='mode' description='Optional. list (default) to read out records, count for only how many, explain for what this kind of record is and what it holds.')
        public String mode;
        @InvocableVariable(label='max results' description='Optional. How many records to read out, 1 to 5. Default 3.')
        public Integer maxResults;
    }

    public class Result {
        @InvocableVariable(label='summary' description='Facts written as plain spoken sentences. Say them in your own words.')
        public String summary;
        @InvocableVariable(label='object' description='The kind of record that was matched.')
        public String objectLabel;
        @InvocableVariable(label='hcpName' description='The full name of the doctor that was matched, if any.')
        public String hcpName;
    }

    @InvocableMethod(label='Field Voice LSC Records' description='Looks up records of any Life Sciences Cloud object, such as presentations, managed events, sessions, participants, sample limits, experts, activity plans and goals, products, and territories, and returns spoken-friendly facts.' callout=false)
    public static List<Result> getRecords(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                run(req, res);
            } catch (Exception e) {
                res.summary = 'Something went wrong while looking that up.';
            }
            results.add(res);
        }
        return results;
    }

    private static void run(Request req, Result res) {
        String phrase = req.objectName == null ? '' : req.objectName;
        FieldVoiceLscCatalog.Def def = match(phrase);
        if (def == null) {
            def = discover(phrase);
        }
        if (def == null) {
            res.summary = 'I could not tell which kind of record that is. I can look up ' + catalogNames() + '.';
            return;
        }
        res.objectLabel = def.label;

        String mode = String.isBlank(req.mode) ? 'list' : req.mode.trim().toLowerCase();
        Schema.DescribeSObjectResult objDescribe = globalDescribe().get(def.objectName).getDescribe();
        if (!objDescribe.isAccessible()) {
            res.summary = 'You do not have access to ' + def.plural + '.';
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

        if (mode == 'explain') {
            res.summary = explain(def, fieldMap);
            return;
        }

        List<String> conditions = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();
        String scopeNote = '';

        if (!String.isBlank(req.hcpName)) {
            FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve(req.hcpName);
            if (r.account == null) {
                res.summary = r.message;
                return;
            }
            res.hcpName = r.account.Name;
            if (def.hcpFilter != null) {
                conditions.add('(' + def.hcpFilter + ')');
                binds.put('hcpId', r.account.Id);
                scopeNote = ' for ' + r.account.Name;
            } else {
                scopeNote = ' Note that ' + def.plural + ' are not tied to a specific doctor, so this covers everyone.';
            }
        }

        String nameField = def.nameField;
        if (!String.isBlank(req.searchText)) {
            List<String> words = FieldVoiceHcpResolver.tokens(req.searchText);
            Integer i = 0;
            for (String w : words) {
                if (w.length() < 2) {
                    continue;
                }
                List<String> likes = new List<String>{nameField + ' LIKE :s' + i};
                for (String viaField : def.searchVia) {
                    Column vc = buildColumn(viaField, fieldMap);
                    if (vc != null && vc.relationship != null) {
                        likes.add(vc.selectExpr + ' LIKE :s' + i);
                    }
                }
                conditions.add('(' + String.join(likes, ' OR ') + ')');
                binds.put('s' + i, '%' + String.escapeSingleQuotes(w) + '%');
                i++;
            }
        }
        if (!String.isBlank(req.status) && def.statusField != null && accessible(fieldMap, def.statusField)) {
            conditions.add(def.statusField + ' = :statusValue');
            binds.put('statusValue', req.status.trim());
        }

        String timeframe = String.isBlank(req.timeframe) ? '' : req.timeframe.trim().toLowerCase();
        Boolean dateIsDatetime = false;
        String orderBy = def.orderBy;
        if (def.dateField != null && accessible(fieldMap, def.dateField)) {
            dateIsDatetime = fieldMap.get(def.dateField).getDescribe().getType() == Schema.DisplayType.DATETIME;
            Object nowValue = dateIsDatetime ? (Object) Datetime.now() : (Object) Date.today();
            if (timeframe == 'upcoming') {
                conditions.add(def.dateField + ' >= :nowValue');
                binds.put('nowValue', nowValue);
                orderBy = def.dateField + ' ASC';
            } else if (timeframe == 'past') {
                conditions.add(def.dateField + ' < :nowValue');
                binds.put('nowValue', nowValue);
                orderBy = def.dateField + ' DESC';
            } else if (orderBy == null) {
                orderBy = def.dateField + ' DESC';
            }
        }
        if (orderBy == null) {
            orderBy = nameField + ' ASC';
        }
        String whereClause = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');

        Integer total = Database.countQueryWithBinds('SELECT COUNT() FROM ' + def.objectName + whereClause, binds, AccessLevel.USER_MODE);
        if (total == 0) {
            res.summary = 'There are no matching ' + def.plural + scopeNote + '.';
            return;
        }
        if (mode == 'count') {
            res.summary = 'There ' + (total == 1 ? 'is ' : 'are ') + FieldVoiceSpeech.count(total, def.label, def.plural) + scopeNote + '.';
            return;
        }

        Integer lim = req.maxResults == null ? 3 : Math.min(Math.max(req.maxResults, 1), 5);
        List<Column> columns = columns(def, fieldMap);
        Column titleCol = def.titleField == null ? null : buildColumn(def.titleField, fieldMap);
        List<String> selects = new List<String>{'Id', nameField};
        if (titleCol != null) {
            selects.add(titleCol.selectExpr);
        }
        for (Column c : columns) {
            selects.add(c.selectExpr);
        }
        String soql = 'SELECT ' + String.join(selects, ', ') + ' FROM ' + def.objectName + whereClause
            + ' ORDER BY ' + orderBy + ' NULLS LAST LIMIT ' + lim;
        List<SObject> rows = Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);

        Map<Id, String> childText = childCounts(def, rows);
        List<String> sentences = new List<String>();
        for (SObject row : rows) {
            sentences.add(describeRow(row, nameField, titleCol, columns, childText.get(row.Id)));
        }
        String lead = total == 1
            ? 'There is one ' + def.label + scopeNote + '. '
            : 'There are ' + total + ' ' + def.plural + scopeNote + (total > rows.size() ? ', here are the first ' + rows.size() + '. ' : '. ');
        res.summary = lead + String.join(sentences, ' ') + statusBreakdown(def, fieldMap, whereClause, binds, total, req.status);
    }

    // "By reaction type: 26 positive and 14 neutral." gives the whole picture even when only a few rows are read out.
    private static String statusBreakdown(FieldVoiceLscCatalog.Def def, Map<String, Schema.SObjectField> fieldMap,
            String whereClause, Map<String, Object> binds, Integer total, String statusFilter) {
        if (total < 2 || def.statusField == null || !String.isBlank(statusFilter) || !accessible(fieldMap, def.statusField)) {
            return '';
        }
        Schema.DescribeFieldResult fd = fieldMap.get(def.statusField.toLowerCase()).getDescribe();
        if (fd.getType() != Schema.DisplayType.PICKLIST) {
            return '';
        }
        List<String> bits = new List<String>();
        for (AggregateResult ar : (List<AggregateResult>) Database.queryWithBinds(
                'SELECT ' + def.statusField + ' st, COUNT(Id) n FROM ' + def.objectName + whereClause + ' GROUP BY ' + def.statusField,
                binds, AccessLevel.USER_MODE)) {
            if (ar.get('st') != null) {
                bits.add(ar.get('n') + ' ' + String.valueOf(ar.get('st')).toLowerCase());
            }
        }
        return bits.isEmpty() ? '' : ' By ' + fd.getLabel().toLowerCase() + ': ' + FieldVoiceSpeech.joinNatural(bits) + '.';
    }

    private static Map<String, Schema.SObjectType> globalCache;

    private static Map<String, Schema.SObjectType> globalDescribe() {
        if (globalCache == null) {
            globalCache = Schema.getGlobalDescribe();
        }
        return globalCache;
    }

    // ---- matching --------------------------------------------------------------

    private static String normalize(String s) {
        if (s == null) {
            return '';
        }
        List<String> out = new List<String>();
        for (String w : s.toLowerCase().replaceAll('[^a-z0-9 ]', ' ').split(' ')) {
            if (w.length() == 0) {
                continue;
            }
            if (w.length() > 3 && w.endsWith('s') && !w.endsWith('ss')) {
                w = w.substring(0, w.length() - 1);
            }
            out.add(w);
        }
        return ' ' + String.join(out, ' ') + ' ';
    }

    private static FieldVoiceLscCatalog.Def match(String phrase) {
        String p = normalize(phrase);
        if (p.trim().length() == 0) {
            return null;
        }
        FieldVoiceLscCatalog.Def best;
        Integer bestScore = 0;
        for (FieldVoiceLscCatalog.Def d : FieldVoiceLscCatalog.all()) {
            List<String> names = new List<String>(d.synonyms);
            names.add(d.label);
            names.add(d.plural);
            names.add(d.key.replace('_', ' '));
            for (String n : names) {
                String ns = normalize(n);
                Integer score = 0;
                if (ns == p) {
                    score = 1000;
                } else if (p.contains(ns)) {
                    score = 100 + ns.length();
                } else if (ns.contains(p) && p.trim().length() >= 4) {
                    score = 20 + p.length();
                }
                if (score > bestScore) {
                    bestScore = score;
                    best = d;
                }
            }
        }
        return best;
    }

    // Schema-driven fallback for LSC objects that are not in the catalog.
    private static FieldVoiceLscCatalog.Def discover(String phrase) {
        String p = normalize(phrase);
        if (p.trim().length() < 3) {
            return null;
        }
        // Compare against API names only (cheap); describe just the winner.
        String squashed = p.replace(' ', '');
        String bestName;
        Integer bestScore = 0;
        for (String name : globalDescribe().keySet()) {
            if (name.contains('__') || name.endsWith('share') || name.endsWith('history') || name.endsWith('feed') || name.endsWith('event')) {
                continue;
            }
            String stem = name.endsWith('s') && !name.endsWith('ss') ? name.substring(0, name.length() - 1) : name;
            Integer score = 0;
            if (stem == squashed || name == squashed) {
                score = 1000;
            } else if (squashed.length() >= 6 && (stem.startsWith(squashed) || squashed.startsWith(stem) && stem.length() >= 6)) {
                score = 100 + stem.length();
            }
            if (score > bestScore) {
                bestScore = score;
                bestName = name;
            }
        }
        if (bestName == null) {
            return null;
        }
        Schema.DescribeSObjectResult d = globalDescribe().get(bestName).getDescribe();
        if (!d.isAccessible() || !d.isQueryable()) {
            return null;
        }
        FieldVoiceLscCatalog.Def def = new FieldVoiceLscCatalog.Def();
        def.key = bestName;
        def.objectName = d.getName();
        def.label = d.getLabel().toLowerCase();
        def.plural = d.getLabelPlural().toLowerCase();
        def.description = 'A ' + def.label + ' record.';
        Map<String, Schema.SObjectField> fm = d.fields.getMap();
        def.nameField = 'Id';
        List<String> picked = new List<String>();
        for (Schema.SObjectField f : fm.values()) {
            Schema.DescribeFieldResult fd = f.getDescribe();
            if (fd.isNameField() && (def.nameField == 'Id' || fd.getName() == 'Name')) {
                def.nameField = fd.getName();
            }
        }
        for (String candidate : new List<String>{'Status', 'Type', 'Category', 'StartDateTime', 'EndDateTime', 'StartDate', 'EndDate', 'Description'}) {
            if (fm.containsKey(candidate.toLowerCase()) && fm.get(candidate.toLowerCase()).getDescribe().isAccessible()) {
                picked.add(candidate);
            }
        }
        def.fields = picked;
        if (fm.containsKey('status')) {
            def.statusField = 'Status';
        }
        for (String dateCandidate : new List<String>{'StartDateTime', 'StartDate', 'EffectiveStartDate'}) {
            if (fm.containsKey(dateCandidate.toLowerCase())) {
                def.dateField = dateCandidate;
                break;
            }
        }
        if (fm.containsKey('accountid')) {
            def.hcpFilter = 'AccountId = :hcpId';
        }
        return def;
    }

    private static String catalogNames() {
        List<String> names = new List<String>();
        for (FieldVoiceLscCatalog.Def d : FieldVoiceLscCatalog.all()) {
            names.add(d.plural);
        }
        return FieldVoiceSpeech.joinNatural(names);
    }

    // ---- columns and formatting -------------------------------------------------

    private class Column {
        String selectExpr;
        String label;
        String fieldName;
        String relationship;
        String relationshipName;
        Schema.DisplayType type;
    }

    private static Boolean accessible(Map<String, Schema.SObjectField> fieldMap, String fieldName) {
        Schema.SObjectField f = fieldMap.get(fieldName.toLowerCase());
        return f != null && f.getDescribe().isAccessible();
    }

    private static Column buildColumn(String name, Map<String, Schema.SObjectField> fieldMap) {
        if (!accessible(fieldMap, name)) {
            return null;
        }
        Schema.DescribeFieldResult fd = fieldMap.get(name.toLowerCase()).getDescribe();
        Column c = new Column();
        c.fieldName = fd.getName();
        c.type = fd.getType();
        c.label = fd.getLabel().toLowerCase().replaceAll(' id$', '').replace('start date time', 'starts').replace('end date time', 'ends');
        if (c.type == Schema.DisplayType.REFERENCE) {
            List<Schema.SObjectType> targets = fd.getReferenceTo();
            if (targets.size() != 1 || fd.getRelationshipName() == null) {
                return null;
            }
            // Account and Contact flag several fields (Suffix, Salutation...) as name fields; Name is the one to speak
            Map<String, Schema.SObjectField> targetFields = targets[0].getDescribe().fields.getMap();
            String targetName = 'Name';
            if (!targetFields.containsKey('name')) {
                for (Schema.SObjectField tf : targetFields.values()) {
                    if (tf.getDescribe().isNameField()) {
                        targetName = tf.getDescribe().getName();
                    }
                }
            }
            c.relationship = fd.getRelationshipName();
            c.relationshipName = targetName;
            c.selectExpr = c.relationship + '.' + targetName;
        } else {
            c.selectExpr = c.fieldName;
        }
        return c;
    }

    private static List<Column> columns(FieldVoiceLscCatalog.Def def, Map<String, Schema.SObjectField> fieldMap) {
        List<Column> cols = new List<Column>();
        for (String name : def.fields) {
            if (name == def.titleField) {
                continue; // already spoken as the headline
            }
            Column c = buildColumn(name, fieldMap);
            if (c != null) {
                cols.add(c);
            }
        }
        return cols;
    }

    private static String describeRow(SObject row, String nameField, Column titleCol, List<Column> columns, String childText) {
        List<String> parts = new List<String>();
        for (Column c : columns) {
            String value = valueText(row, c);
            if (value == null) {
                continue;
            }
            parts.add(c.label + ' ' + value);
            if (parts.size() == 5) {
                break;
            }
        }
        String name = titleCol == null ? null : valueText(row, titleCol);
        if (name == null) {
            name = String.valueOf(row.get(nameField));
        }
        String text = name + (parts.isEmpty() ? '.' : ': ' + FieldVoiceSpeech.joinNatural(parts) + '.');
        if (!String.isBlank(childText)) {
            text += ' It has ' + childText + '.';
        }
        return text;
    }

    private static String valueText(SObject row, Column c) {
        Object raw;
        if (c.relationship != null) {
            SObject parent = row.getSObject(c.relationship);
            raw = parent == null ? null : parent.get(c.relationshipName);
        } else {
            raw = row.get(c.fieldName);
        }
        if (raw == null) {
            return null;
        }
        if (raw instanceof Datetime) {
            // only fields that carry a time of day get one; "activation date" is a day
            return c.label.endsWith('time') || c.label == 'starts' || c.label == 'ends'
                ? FieldVoiceSpeech.spokenDateTime((Datetime) raw)
                : FieldVoiceSpeech.spokenDate((Datetime) raw);
        }
        if (raw instanceof Date) {
            Date d = (Date) raw;
            return FieldVoiceSpeech.spokenDate(Datetime.newInstance(d.year(), d.month(), d.day(), 12, 0, 0));
        }
        if (raw instanceof Boolean) {
            return (Boolean) raw ? 'yes' : null;
        }
        if (raw instanceof Decimal || raw instanceof Integer || raw instanceof Double || raw instanceof Long) {
            Decimal n = (Decimal) raw;
            if (c.type == Schema.DisplayType.PERCENT) {
                return n.setScale(0).format() + ' percent';
            }
            if (c.type == Schema.DisplayType.CURRENCY) {
                return money(n);
            }
            return (n == n.setScale(0) ? n.setScale(0) : n.setScale(1)).format();
        }
        String s = String.valueOf(raw);
        if (s.length() == 0 || s.startsWith('{') || s.startsWith('[') || Pattern.matches('[a-zA-Z0-9]{15,18}', s)) {
            return null; // raw JSON and record IDs mean nothing out loud
        }
        return FieldVoiceSpeech.shorten(s, 80);
    }

    private static String money(Decimal n) {
        Decimal abs = n.abs();
        if (abs >= 1000000) {
            return (n / 1000000).setScale(1).format() + ' million dollars';
        }
        if (abs >= 1000) {
            return (n / 1000).setScale(0).format() + ' thousand dollars';
        }
        return n.setScale(0).format() + ' dollars';
    }

    private static Map<Id, String> childCounts(FieldVoiceLscCatalog.Def def, List<SObject> rows) {
        Map<Id, List<String>> pieces = new Map<Id, List<String>>();
        Set<Id> ids = new Map<Id, SObject>(rows).keySet();
        for (FieldVoiceLscCatalog.ChildLink link : def.children) {
            try {
                String soql = 'SELECT ' + link.lookupField + ' parentId, COUNT(Id) cnt FROM ' + link.objectName
                    + ' WHERE ' + link.lookupField + ' IN :ids GROUP BY ' + link.lookupField;
                for (AggregateResult ar : (List<AggregateResult>) Database.queryWithBinds(soql, new Map<String, Object>{'ids' => ids}, AccessLevel.USER_MODE)) {
                    Id pid = (Id) ar.get('parentId');
                    Integer cnt = (Integer) ar.get('cnt');
                    if (!pieces.containsKey(pid)) {
                        pieces.put(pid, new List<String>());
                    }
                    pieces.get(pid).add(FieldVoiceSpeech.count(cnt, link.singular, link.plural));
                }
            } catch (Exception e) {
                // child object not readable for this user; leave it out
            }
        }
        Map<Id, String> out = new Map<Id, String>();
        for (Id pid : pieces.keySet()) {
            out.put(pid, FieldVoiceSpeech.joinNatural(pieces.get(pid)));
        }
        return out;
    }

    private static String explain(FieldVoiceLscCatalog.Def def, Map<String, Schema.SObjectField> fieldMap) {
        List<String> labels = new List<String>();
        for (Column c : columns(def, fieldMap)) {
            labels.add(c.label);
        }
        String text = def.description;
        if (!labels.isEmpty()) {
            text += ' It tracks things like ' + FieldVoiceSpeech.joinNatural(labels) + '.';
        }
        if (def.hcpFilter != null) {
            text += ' It can be looked up for a specific doctor.';
        }
        return text;
    }
}
