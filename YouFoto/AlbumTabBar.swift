import SwiftUI

struct AlbumTabBar: View {
    @Binding var selected: AlbumFilter
    var ns: Namespace.ID

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(AlbumFilter.allCases) { filter in
                    let isSelected = selected == filter
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selected = filter
                        }
                    } label: {
                        Image(systemName: filter.icon)
                            .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.88))
                            .frame(width: 48, height: 44)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.tint.opacity(0.72))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
                                        }
                                        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(filter.rawValue)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.18), value: selected)
    }
}
