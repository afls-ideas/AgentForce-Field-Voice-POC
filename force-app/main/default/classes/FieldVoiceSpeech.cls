/**
 * Helpers that turn data into speech-friendly phrases: relative dates instead of
 * full calendar dates, and natural lists instead of bullets.
 */
public with sharing class FieldVoiceSpeech {

    public static String ordinal(Integer n) {
        Integer m100 = Math.mod(n, 100);
        if (m100 >= 11 && m100 <= 13) return n + 'th';
        Integer m10 = Math.mod(n, 10);
        if (m10 == 1) return n + 'st';
        if (m10 == 2) return n + 'nd';
        if (m10 == 3) return n + 'rd';
        return n + 'th';
    }

    public static String dayName(Date d) {
        return Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('EEEE');
    }

    public static String monthDay(Date d) {
        return Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('MMMM') + ' ' + ordinal(d.day());
    }

    /** A date in the user's time zone as something a person would say. */
    public static String spokenDate(Datetime dt) {
        if (dt == null) return 'at an unknown time';
        Date d = Date.valueOf(dt.format('yyyy-MM-dd'));
        Integer diff = Date.today().daysBetween(d);
        if (diff == 0) return 'today';
        if (diff == 1) return 'tomorrow';
        if (diff == -1) return 'yesterday';
        if (diff >= 2 && diff <= 6) return 'on ' + dayName(d);
        if (diff >= 7 && diff <= 13) return 'next ' + dayName(d);
        if (diff <= -2 && diff >= -6) return 'last ' + dayName(d);
        if (diff < -6 && diff >= -60) {
            Integer weeks = Math.max(1, (Integer) Math.round(-diff / 7.0));
            return weeks == 1 ? 'about a week ago' : 'about ' + weeks + ' weeks ago';
        }
        if (diff < -60 && diff >= -330) {
            return 'about ' + (Integer) Math.round(-diff / 30.0) + ' months ago';
        }
        if (diff < -330) return 'over a year ago';
        String phrase = 'on ' + monthDay(d);
        return d.year() == Date.today().year() ? phrase : phrase + ', ' + d.year();
    }

    /** Same as spokenDate but adds a time of day, for things on the calendar. */
    public static String spokenDateTime(Datetime dt) {
        if (dt == null) return 'at an unknown time';
        return spokenDate(dt) + ' at ' + dt.format('h:mm a').replace(':00', '');
    }

    public static String joinNatural(List<String> items) {
        if (items == null || items.isEmpty()) return '';
        if (items.size() == 1) return items[0];
        if (items.size() == 2) return items[0] + ' and ' + items[1];
        List<String> head = new List<String>();
        for (Integer i = 0; i < items.size() - 1; i++) head.add(items[i]);
        return String.join(head, ', ') + ', and ' + items[items.size() - 1];
    }

    public static String count(Integer n, String singular, String plural) {
        return n + ' ' + (n == 1 ? singular : plural);
    }

    /** Trim long free text so it is comfortable to hear. */
    public static String shorten(String text, Integer maxChars) {
        if (String.isBlank(text)) return '';
        String t = text.replaceAll('\\s+', ' ').trim();
        if (t.length() <= maxChars) return t;
        Integer cut = t.lastIndexOf(' ', maxChars);
        return t.substring(0, cut > 0 ? cut : maxChars) + '...';
    }
}
