import SwiftUI

/// `CLAUDE.md`'s About screen requirement: "Include the MIT notice on the About screen."
/// The licence text is reproduced verbatim from `data/divinum-officium/LICENSE` (the
/// pinned commit `data/SOURCE.md` records) rather than read at runtime, since the
/// submodule checkout itself never ships inside the app bundle -- only the compiled data
/// file does.
struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Breviarium")
                        .font(.title2.bold())
                    Text("The traditional Divine Office: the Roman office per the 1960 rubrics, the Dominican office of 1962, and Ambrosian Compline of 1957.")
                        .foregroundStyle(Theme.chrome)
                }
                .padding(.vertical, 4)
            }

            // The app's own licence (decided 6 October 2026, `NOTICE.md`).
            Section("Licence") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Breviarium is free software, licensed under the GNU General Public License, version 3 or any later version. You may share and change it; any version you distribute must remain free, with its source.")
                    Text("Copyright © 2026 Eduardo Pavone. Source: github.com/ColdFrozenYeti/Breviarium")
                        .font(.footnote)
                        .foregroundStyle(Theme.chrome)
                }
                .padding(.vertical, 4)
            }

            Section("Text source") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latin and English texts are drawn from Divinum Officium.")
                    // Plain text, not a tappable Link -- CLAUDE.md's "fully offline, no
                    // network calls of any kind" is strict enough that this stays inert
                    // rather than handing off to a browser, even though nothing in the
                    // app itself would be making the request.
                    Text("github.com/DivinumOfficium/divinum-officium")
                        .font(.footnote)
                        .foregroundStyle(Theme.chrome)
                    Text("Pinned commit: 126a07f91ede04664108abb6fb20ace3f4de14b9")
                        .font(.footnote)
                        .foregroundStyle(Theme.chrome)
                }
                .padding(.vertical, 4)
            }

            // Beta 6: the Ambrosian Compline's source, used with its owners' permission
            // (`NOTICE.md`; asked for by the user, 9 October 2026).
            Section("Ambrosian source") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Completorium Ambrosianum is transcribed from Church of Ambrose's digitisation of the 1957 Breviarium Ambrosianum (Ad Completorium Quotidianum iuxta ritum Sanctæ Ecclesiæ Mediolanensis, Milan 2025), and the Ambrosian calendar from their scans of the 1954 Missale Ambrosianum, with spelling normalised and misprints corrected.")
                    Text("Published under CC BY-NC-ND 4.0, and included in Breviarium with the permission of its owners. This transcription is not covered by Breviarium's licence: it may be shared only as part of Breviarium or under Church of Ambrose's own licence.")
                    Text("mrchurch.it")
                        .font(.footnote)
                        .foregroundStyle(Theme.chrome)
                }
                .padding(.vertical, 4)
            }

            Section("Divinum Officium licence") {
                Text(Self.divinumOfficiumLicenseText)
                    .font(.footnote)
                    .foregroundStyle(Theme.chrome)
                    .padding(.vertical, 4)
            }
        }
        .navigationTitle("About")
    }

    private static let divinumOfficiumLicenseText = """
        MIT License

        Copyright (c) 2026 Divinum Officium

        Permission is hereby granted, free of charge, to any person obtaining a copy \
        of this software and associated documentation files (the "Software"), to deal \
        in the Software without restriction, including without limitation the rights \
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is \
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
        SOFTWARE.
        """
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
