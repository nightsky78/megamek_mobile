package megamekmobile.bridge;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class ReportTextTest {

    @Test
    void stripsTagsAndDecodesEntities() {
        String html = "<span class='warning'>Wolverine &amp; Co</span><br>takes 5&nbsp;damage &#40;CT&#41;";
        assertEquals("Wolverine & Co\ntakes 5 damage (CT)", ReportText.plain(html));
    }

    @Test
    void nullIsEmpty() {
        assertEquals("", ReportText.plain(null));
    }
}
