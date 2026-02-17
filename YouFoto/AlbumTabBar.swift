import SwiftUI

struct AlbumTabBar: View {
    @Binding var selected: AlbumFilter
    var ns: Namespace.ID

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AlbumFilter.allCases) { filter in
                Button {
                    selected = filter
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 20,
                                          weight: selected == filter ? .semibold : .regular))
                        Text(filter.rawValue)
                            .font(.system(size: 11,
                                          weight: selected == filter ? .semibold : .regular))
                    }
                    .foregroundStyle(selected == filter ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.18), value: selected)
    }
}
