import SwiftUI

struct HelpInstructionsView: View {

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                Text("Help")
                    .font(.system(size: 28, weight: .semibold))
                    .padding(.top, 6)

                Text("A few quick pointers to keep WOYP Plus calm and simple.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Back up & restore")
                        .font(.headline)

                    Text("Use this to export your data and import it again if you change phone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        DataBackupView()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                            Text("Import / Export")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.woypSlate.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.woypSlate.opacity(0.15).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
