package megamekmobile.bridge;

import java.util.regex.Pattern;

/** Turns MegaMek's HTML-ish report strings into plain text for the phone's combat log. */
final class ReportText {

    private static final Pattern BREAK = Pattern.compile("(?i)<br\\s*/?>");
    private static final Pattern TAG = Pattern.compile("<[^>]*>");
    private static final Pattern NUMERIC_ENTITY = Pattern.compile("&#(\\d+);");

    private ReportText() {
    }

    static String plain(String html) {
        if (html == null) {
            return "";
        }
        String text = BREAK.matcher(html).replaceAll("\n");
        text = TAG.matcher(text).replaceAll("");
        text = NUMERIC_ENTITY.matcher(text).replaceAll(match -> {
            int code = Integer.parseInt(match.group(1));
            return java.util.regex.Matcher.quoteReplacement(new String(Character.toChars(code)));
        });
        text = text.replace("&nbsp;", " ")
              .replace("&lt;", "<")
              .replace("&gt;", ">")
              .replace("&quot;", "\"")
              .replace("&amp;", "&");
        return text.replaceAll("[ \\t]+", " ").replaceAll("\\n\\s*\\n+", "\n").strip();
    }
}
