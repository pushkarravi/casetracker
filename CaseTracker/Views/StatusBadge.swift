import SwiftUI

struct StatusBadge: View {
    let category: StatusCategory

    var body: some View {
        Label(category.label, systemImage: category.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(category.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.14), in: Capsule())
    }
}

#Preview {
    VStack(alignment: .leading) {
        ForEach(StatusCategory.allCases, id: \.self) { StatusBadge(category: $0) }
    }
    .padding()
}
