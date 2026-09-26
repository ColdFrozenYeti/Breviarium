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
