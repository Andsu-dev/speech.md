import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavSection
    @Binding var isCollapsed: Bool

    @Namespace private var selectionPill

    private var width: CGFloat { isCollapsed ? 64 : 236 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, isCollapsed ? 0 : 20)
                .padding(.top, 18)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)

            VStack(spacing: 2) {
                ForEach(NavSection.primary) { section in
                    NavRow(
                        section: section,
                        isSelected: section == selection,
                        isCollapsed: isCollapsed,
                        namespace: selectionPill,
                        action: { selection = section }
                    )
                }
            }
            .padding(.horizontal, isCollapsed ? 8 : 12)

            Spacer(minLength: 24)

            VStack(spacing: 2) {
                NavRow(
                    section: .settings,
                    isSelected: selection == .settings,
                    isCollapsed: isCollapsed,
                    namespace: selectionPill,
                    action: { selection = .settings }
                )
                LinkRow(title: "GitHub", icon: BrandIcon.github, url: Links.repository, isCollapsed: isCollapsed)
                LinkRow(title: "@andersonbrdev", icon: BrandIcon.x, url: Links.profile, isCollapsed: isCollapsed)
            }
            .padding(.horizontal, isCollapsed ? 8 : 12)
            .padding(.bottom, 16)
        }
        .frame(width: width)
        .background(Theme.sidebarBackground)
        .overlay(alignment: .topTrailing) {
            collapseToggle
                .padding(.top, 16)
                .padding(.trailing, isCollapsed ? 0 : 10)
                .frame(maxWidth: isCollapsed ? .infinity : nil, alignment: isCollapsed ? .center : .trailing)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isCollapsed)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: selection)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 17, weight: .semibold))
            if !isCollapsed {
                Text("speech.md")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .fixedSize()
            }
        }
        .foregroundStyle(Theme.textPrimary)
        // some quando colapsado: o botão de expandir ocupa o mesmo canto
        .opacity(isCollapsed ? 0 : 1)
    }

    private var collapseToggle: some View {
        Button {
            isCollapsed.toggle()
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .help(isCollapsed ? "Expandir barra lateral" : "Recolher barra lateral")
    }
}

private struct NavRow: View {
    let section: NavSection
    let isSelected: Bool
    let isCollapsed: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .frame(width: 19)
                    .scaleEffect(isSelected ? 1.06 : 1)
                    .symbolEffect(.bounce, options: .speed(1.4), isActive: isSelected)
                if !isCollapsed {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .fixedSize()
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 0 : 11)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.surface)
                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.surfaceHover)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .help(isCollapsed ? section.rawValue : "")
    }
}

private struct LinkRow: View {
    let title: String
    let icon: Image
    let url: URL
    let isCollapsed: Bool

    @State private var isHovering = false

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 11) {
                icon
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .frame(width: 19)
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 13))
                        .fixedSize()
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .opacity(isHovering ? 1 : 0)
                }
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 0 : 11)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Theme.surfaceHover : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { isHovering = $0 }
        .help(isCollapsed ? title : "")
    }
}
