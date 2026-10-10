import SwiftUI

/// What each release added, newest first, opened from Settings like About. Written into
/// the app rather than read from the repository, which never ships inside the bundle.
struct ReleaseNotesView: View {
    private struct Release: Identifiable {
        var name: String
        var notes: [String]
        var id: String { name }
    }

    private static let releases: [Release] = [
        Release(name: "1.2", notes: [
            "Eight colour themes, chosen in Settings, under Theme: Nox (the black page, still the default), Media nox, Carbo, Lux, Sepia, Vellum, Silva and Rosa. Light themes make the whole app light.",
            "Four fonts, under Font: Hoefler Text (the default), SF Pro, IBM Plex Mono and Comic Neue, each sized to read like Hoefler Text.",
            "Both are chosen from a gallery like the app icon's, each tile showing Easter Sunday's Magnificat antiphon and the canticle's opening as the office sets them.",
            "The page curl is now the default page turn; the slide is still a choice.",
            "Jump to date's colour dots have no outline, and a black day's dot is black on a light theme.",
            "Three new app icons, Northumberland Simple (the new default), Northumberland and Northumberland Inverted; the first default icon is now called Walters.",
        ]),
        Release(name: "1.1", notes: [
            "Ambrosian Compline as prayed: the Pater noster and Ave Maria written out in full, and the whole Pater noster where it is said secretly, as the Credo is.",
            "The Gloria Patri after each psalm keeps the psalm's alternation of upright and italic verses, and Salva nos, Domine, vigilantes is one antiphon.",
            "The rubrics the app carries out for you (the festal form, which Marian antiphon is said when) are no longer shown.",
            "The signs of the cross the Roman Compline has on the texts the two share: Converte nos, Deus in adiutorium, Nunc dimittis, Indulgentiam and Adiutorium nostrum.",
            "Each prayer is its own paragraph, spaced as in the Roman hours.",
        ]),
        Release(name: "1.0", notes: [
            "Ambrosian Compline (Completorium Ambrosianum, 1957): choose Ambrosianus in Settings, under Ritus. It follows the Ambrosian calendar and its four seasons, with its festal and ferial forms and the Marian antiphon of the season, in Latin.",
            "With English on, everything but the Matins lessons is shown side by side, so a response no longer sits under its own translation twice.",
            "More directions are red rubrics: (fit reverentia) and (bow head) in the psalms, the Te Deum's English directions, and the genuflection lines in hymns such as Ave maris stella and Pange lingua, and (hic genuflectitur) in the Dominican Prima's Gospel.",
            "The Ambrosian calendar names every Sunday and day of the season, moves a saint off a Sunday as its rubrics say, and shows its colours in Jump to date.",
            "Two more app icons: ChurchofAmbrose and Weissenau.",
        ]),
        Release(name: "Beta 5", notes: [
            "The Dominican office (Ordo Prædicatorum, 1962): choose Dominicanus in Settings, under Ritus, with the office of the day, the Little Office or the Office of the Dead.",
            "Every hour follows the Order's calendar and books as Divinum Officium has them, checked against it for every day from 2025 to 2040; where its data is in error, the app shows the corrected text.",
            "The English is the Order's own where it exists, else the Roman English of the same text; a Roman text whose Dominican Latin differs carries a small grey note.",
            "Prime reads the Rule of St Augustine, or the day's Gospel on feasts.",
        ]),
        Release(name: "Beta 4", notes: [
            "The Little Office of Our Lady, all eight hours, in its forms for Advent, Christmastide, Septuagesima to Easter and the rest of the year.",
            "The Office of the Dead: Matins, Lauds and Vespers.",
            "Choose the office in Settings, under Ritus, Romanus: the office of the day, the Little Office or the Office of the Dead. The hour picker lists that office's own hours.",
            "The Martyrology, an hour of its own after Prime in the day's office: the next day's entry, as read at Prime on the eve, in Latin.",
            "Jump to date shows a small dot of each day's liturgical colour.",
            "Directions such as (Fit reverentia) in the Te Deum are red rubrics, hidden with the rubrics.",
        ]),
        Release(name: "Beta 3", notes: [
            "Matins: the invitatory, the hymn, the nocturns with their lessons and responsories, and the Te Deum, as the 1960 rubrics order them.",
            "Ad Matutinum is first in the hour picker, and the app opens on it between midnight and five in the morning.",
            "Matins is checked against Divinum Officium for every day from 2025 to 2040, like the other hours.",
            "A new app icon: an illuminated B.",
        ]),
        Release(name: "Beta 2", notes: [
            "The day hours: Lauds, Prime, Terce, Sext, None and Compline, alongside Vespers.",
            "The app opens on the hour for the time of day; tap the hour's name at the top to switch hours.",
            "Every hour is checked against Divinum Officium for every day from 2025 to 2040, in both psalters and with the English.",
            "Chapters and short lessons show their Scripture reference above the text, like a psalm's number.",
            "Responses such as Deo grátias are set as indented italic lines, with no V. and R. marks.",
            "The Marian antiphon at Compline reads as one stanza.",
            "The last page always reaches the end of the hour, and a heading or reference is never left alone at the foot of a page.",
        ]),
        Release(name: "Beta 1", notes: [
            "The Vulgate psalter, now the default, with the Pius XII psalter as an option (Psalterium).",
            "The parallel English translation: Latin and English side by side, with the chapter and collect stacked in portrait.",
            "Hymns set in stanzas, and the table of contents jumps to the chosen section.",
        ]),
        Release(name: "Alpha", notes: [
            "Roman Vespers under the 1960 rubrics, computed for any date, fully offline.",
            "Book-like pages with a slide or page-curl turn, or a continuous vertical scroll.",
            "Settings for the priest's form, rubrics, text size and the reading mode.",
        ]),
    ]

    var body: some View {
        List {
            ForEach(Self.releases) { release in
                Section(release.name) {
                    ForEach(release.notes, id: \.self) { note in
                        Text(note)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Release notes")
    }
}

#Preview {
    NavigationStack {
        ReleaseNotesView()
    }
    .preferredColorScheme(.dark)
}
