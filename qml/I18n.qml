pragma Singleton
import QtQuick

// Interface text in the chosen language (see senada/i18n.py). Write text in English:
//   I18n.t("Settings"), I18n.t("Added to “{name}”", { name: n }),
//   I18n.n("{n} song", "{n} songs", count)
// Reading `table` inside these functions makes every binding that uses them follow
// a language change.
QtObject {
    property string lang: "en" // "en" | "id", for the rare text that is more than a lookup
    property var table: ({})   // English text -> current language; empty for English

    function fill(text, values) {
        if (values)
            for (const k in values)
                text = text.split("{" + k + "}").join(values[k])
        return text
    }
    function t(text, values) {
        return fill(table[text] || text, values)
    }
    function n(one, many, count, values) {
        const text = table[many] || (count === 1 ? one : many)
        return fill(text, Object.assign({ n: count }, values || {}))
    }
}
