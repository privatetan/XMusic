import SwiftUI

struct BrowseListRowView: View {
    let symbol: String
    let title: String
    let count: Int

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.body)
                    .foregroundStyle(.white)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
