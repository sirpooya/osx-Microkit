import SwiftUI

/// Left column of the main window: mode switcher, mode-specific content
/// (action catalog or lighting targets), and the Settings row pinned to the
/// bottom. The top 52 pt stay clear for the native traffic lights.
struct AppSidebarView: View {
    @Bindable var store: AppStore
    let runtime: AppRuntime

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: FMTheme.toolbarHeight)

            VStack(spacing: 16) {
                modeSwitcher

                FMSectionDivider()

                switch store.mode {
                case .actions:
                    ActionCatalogView(store: store)
                case .lights:
                    LightingTargetListView(store: store)
                default:
                    MicrokitModeNote(mode: store.mode)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            FMSectionDivider()
            settingsRow
        }
        .background(FMTheme.controlSurface)
    }

    private var modeSwitcher: some View {
        VStack(spacing: 8) {
            ForEach(AppMode.allCases) { mode in
                SidebarRow(
                    title: mode.title,
                    iconAssetName: mode.iconAssetName,
                    systemSymbol: mode.systemSymbol,
                    isSelected: store.mode == mode,
                    isEmphasized: store.mode == mode
                ) {
                    store.mode = mode
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var settingsRow: some View {
        Button {
            // Microkit: settings open in their own window.
            SettingsWindowController.shared.show(store: store, runtime: runtime)
        } label: {
            HStack(spacing: 8) {
                FigmaAssetImage(fileName: "settings-gear.svg", template: true)
                    .foregroundStyle(FMTheme.textPrimary)
                    .frame(width: 18, height: 18)
                Text("Settings")
                    .font(FMTheme.body)
                    .foregroundStyle(FMTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .modifier(InteractiveRowBackground(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(8)
    }
}

/// Selectable row used for the mode switcher and the lights target list.
private struct SidebarRow: View {
    let title: String
    let iconAssetName: String
    var systemSymbol: String?
    let isSelected: Bool
    var isEmphasized = false
    var selectionFill: Color = FMTheme.navSelectionFill
    var cornerRadius: CGFloat = 8
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    if let systemSymbol {
                        Image(systemName: systemSymbol)
                            .font(.system(size: 13, weight: .medium))
                    } else {
                        FigmaAssetImage(fileName: iconAssetName, template: true)
                    }
                }
                .foregroundStyle(FMTheme.textPrimary)
                .frame(width: 18, height: 18)
                Text(title)
                    .font(isEmphasized ? FMTheme.headline : FMTheme.body)
                    .foregroundStyle(FMTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .modifier(InteractiveRowBackground(
                isSelected: isSelected,
                selectionFill: selectionFill,
                cornerRadius: cornerRadius
            ))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Actions mode

/// Search field plus the categorized, collapsible catalog of Figma actions.
/// Rows are draggable; dropping one on a key, dial, or scroller — or on a
/// shortcut field in the inspector — assigns it.
private struct ActionCatalogView: View {
    @Bindable var store: AppStore
    @State private var expandedCategories = Set(ShortcutCategory.allCases.filter { !$0.startsCollapsed })
    @FocusState private var isSearchFocused: Bool
    @State private var customShortcutPresentation: CustomShortcutPresentation?

    /// Action assigned to the selected slot on the current layer — the only
    /// row that carries the blue highlight.
    private var assignedActionID: String? {
        guard let slotID = store.selectedSlotID else { return nil }
        return store.action(for: slotID)?.id
    }

    var body: some View {
        VStack(spacing: 16) {
            searchField
                .padding(.horizontal, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ShortcutCategory.allCases) { category in
                            categoryGroup(category)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.never)
                // Content fades into the sidebar surface as it scrolls past the
                // top and bottom edges, instead of being hard-clipped.
                .overlay(alignment: .top) { scrollFade(edge: .top) }
                .overlay(alignment: .bottom) { scrollFade(edge: .bottom) }
                .onChange(of: store.selectedSlotID) {
                    revealAssignedAction(proxy)
                }
                .onChange(of: store.currentLayer) {
                    revealAssignedAction(proxy)
                }
            }
        }
        .sheet(item: $customShortcutPresentation) { presentation in
            switch presentation {
            case .create:
                CustomShortcutSheet(store: store)
            case let .edit(action):
                CustomShortcutSheet(store: store, action: action)
            }
        }
    }

    private func scrollFade(edge: VerticalEdge) -> some View {
        LinearGradient(
            colors: [FMTheme.controlSurface, FMTheme.controlSurface.opacity(0)],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: 16)
        .allowsHitTesting(false)
    }

    /// Expands the category of the assigned action and scrolls to it, so the
    /// highlight is visible whenever a key is selected.
    private func revealAssignedAction(_ proxy: ScrollViewProxy) {
        guard let actionID = assignedActionID,
              let action = store.actions.first(where: { $0.id == actionID })
        else { return }
        expandedCategories.insert(action.category)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(actionID, anchor: .center)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(FMTheme.textSecondary)
                .frame(width: 18, height: 18)
            TextField("Find...", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(FMTheme.body)
                .focused($isSearchFocused)
                .onExitCommand {
                    store.searchText = ""
                    isSearchFocused = false
                }

            if isSearchFocused || !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(FMTheme.textSecondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Clear search and dismiss focus")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(FMTheme.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSearchFocused ? FMTheme.accent : FMTheme.separator,
                    lineWidth: isSearchFocused ? 2 : 0.75
                )
        )
        .animation(.easeInOut(duration: 0.1), value: isSearchFocused)
        .onChange(of: store.searchFocusRequestID) {
            isSearchFocused = true
        }
    }

    private var isSearching: Bool {
        !store.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// While searching, every category with matches stays open so results
    /// are never hidden behind a collapsed header.
    private func isExpanded(_ category: ShortcutCategory) -> Bool {
        isSearching || expandedCategories.contains(category)
    }

    @ViewBuilder
    private func categoryGroup(_ category: ShortcutCategory) -> some View {
        let matches = store.filteredActions(in: category)

        // While searching, categories without a hit disappear entirely and
        // the header count shows the number of matches instead of the total.
        if !(isSearching && matches.isEmpty) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button {
                        if expandedCategories.contains(category) {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            FigmaAssetImage(fileName: "chevron-small.svg", template: true)
                                .foregroundStyle(FMTheme.textSecondary)
                                .rotationEffect(.degrees(isExpanded(category) ? 0 : -90))
                                .frame(width: 8, height: 8)
                            Text(category.displayName)
                                .font(FMTheme.headline)
                                .foregroundStyle(FMTheme.textPrimary)
                            Spacer(minLength: 0)
                            if category != .custom {
                                Text("\(isSearching ? matches.count : store.count(in: category))")
                                    .font(FMTheme.body)
                                    .foregroundStyle(FMTheme.textSecondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if category == .custom {
                        Button {
                            customShortcutPresentation = .create
                        } label: {
                            FigmaAssetImage(fileName: "plus.svg", template: true)
                                .foregroundStyle(FMTheme.textSecondary)
                                .frame(width: 14, height: 14)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Add custom shortcut")
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .modifier(InteractiveRowBackground(cornerRadius: 5))

                if isExpanded(category) {
                    ForEach(matches) { action in
                        ActionRow(action: action, isAssignedToSelection: assignedActionID == action.id) {
                            guard let slotID = store.selectedSlotID else { return }
                            store.assign(actionID: action.id, to: slotID)
                        } onEdit: {
                            customShortcutPresentation = .edit(action)
                        } onDelete: {
                            store.deleteCustomShortcut(id: action.id)
                        }
                        .id(action.id)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

private enum CustomShortcutPresentation: Identifiable {
    case create
    case edit(FigmaAction)

    var id: String {
        switch self {
        case .create: "create"
        case let .edit(action): "edit-\(action.id)"
        }
    }
}

/// Deliberately not a Button: on macOS a button claims the mouse-down, which
/// prevents the drag gesture from ever starting. The blue highlight marks the
/// action assigned to the selected key; a tap assigns the action to it. The
/// row itself is the drag source for assignment.
private struct ActionRow: View {
    let action: FigmaAction
    let isAssignedToSelection: Bool
    let assignToSelection: () -> Void
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        if action.isDirectlyAssignable {
            row.draggable(action.id) {
                dragPreview
            }
        } else {
            row
        }
    }

    private var row: some View {
        rowContents
            .padding(.leading, 24)
            .padding(.trailing, 8)
            .frame(height: 32)
            .modifier(InteractiveRowBackground(
                isSelected: isAssignedToSelection,
                selectionFill: FMTheme.groupHeaderFill,
                cornerRadius: 5
            ))
            .contentShape(Rectangle())
            .onTapGesture(perform: assignToSelection)
            .help(action.note ?? action.title)
            .contextMenu {
                if action.category == .custom {
                    if let onEdit {
                        Button("Edit shortcut", action: onEdit)
                    }
                    if let onDelete {
                        Button("Delete shortcut", role: .destructive, action: onDelete)
                    }
                }
            }
    }

    private var rowContents: some View {
        HStack(spacing: 8) {
            // Only actions with a key texture in the Figma set get an icon;
            // for the rest there is no matching physical keycap, so the slot
            // stays empty and just keeps the labels aligned.
            Group {
                if action.figmaAssetName != nil {
                    ActionGlyph(action: action, size: 14, tint: FMTheme.textPrimary)
                } else {
                    Color.clear
                }
            }
            .frame(width: 18, height: 18)

            Text(action.title)
                .font(FMTheme.body)
                .foregroundStyle(FMTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if action.assignability != .direct {
                Image(systemName: action.assignability.symbol)
                    .font(FMTheme.caption)
                    .foregroundStyle(.tertiary)
                    .help(action.assignability.label)
            } else if let chord = action.chord {
                KeycapStrip(chord: chord, compact: true)
            } else if let shortcutLabel = action.shortcutLabel {
                Text(shortcutLabel)
                    .font(.caption2.monospaced().weight(.medium))
                    .foregroundStyle(FMTheme.textPrimary)
                    .padding(.horizontal, 5)
                    .frame(minHeight: 18)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(FMTheme.keycapBorder, lineWidth: 1)
                    }
            }
        }
    }

    private var dragPreview: some View {
        rowContents
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(width: 220)
            .background(FMTheme.controlSurface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(FMTheme.separator, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
    }
}

// MARK: - Lights mode

private struct LightingTargetListView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 4) {
            ForEach(LightingTarget.allCases) { target in
                SidebarRow(
                    title: target.title,
                    iconAssetName: target.iconAssetName,
                    isSelected: store.selectedLightingTarget == target,
                    selectionFill: FMTheme.groupHeaderFill,
                    cornerRadius: 5
                ) {
                    store.selectedLightingTarget = target
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

/// Shared pointer feedback for every interactive row in the sidebar.
private struct InteractiveRowBackground: ViewModifier {
    var isSelected = false
    var selectionFill: Color = .clear
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                isSelected ? selectionFill : (isHovered ? FMTheme.hoverFill : .clear),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.10), value: isHovered)
    }
}
