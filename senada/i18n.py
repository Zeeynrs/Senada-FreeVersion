"""The two interface languages: English (the default) and Indonesian.

Text is written in English where it is used, in Python as tr("...") and in QML as
I18n.t("..."). When Indonesian is chosen, the English text is looked up in
translations.ID; anything missing there simply stays English.

Placeholders use {name}: tr("Added to “{name}”", name=n). Counted text has an English
singular and plural and one Indonesian form, keyed by the plural:
trn("{n} song", "{n} songs", count).
"""

from .translations import ID

LANGUAGES = ("en", "id")
DEFAULT = "en"

_lang = DEFAULT


def language() -> str:
    return _lang


def set_language(lang: str) -> str:
    global _lang
    _lang = lang if lang in LANGUAGES else DEFAULT
    return _lang


def table() -> dict:
    """English text -> text in the current language (empty for English)."""
    return ID if _lang == "id" else {}


def tr(text: str, **values) -> str:
    out = table().get(text, text)
    return out.format(**values) if values else out


def trn(one: str, many: str, n: int, **values) -> str:
    out = table().get(many) or (one if n == 1 else many)
    return out.format(n=n, **values)
