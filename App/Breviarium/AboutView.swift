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
                    Text("The traditional Divine Office, per the 1960 rubrics. For private use.")
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
