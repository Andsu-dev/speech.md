import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SnippetsView: View {
    let store: SnippetStore

    @State private var editing: Snippet?
    @State private var importReport: String?
    @State private var importAnchor = MenuAnchorView()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if store.snippets.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.snippets.enumerated()), id: \.element.id) { index, snippet in
                            if index > 0 {
                                Divider().overlay(Theme.border)
                            }
                            SnippetRow(
                                snippet: snippet,
                                onEdit: { editing = snippet },
                                onDelete: { store.delete(snippet) }
                            )
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
        }
        .alert(
            importReport ?? "",
            isPresented: Binding(
                get: { importReport != nil },
                set: { if !$0 { importReport = nil } }
            )
        ) {
            Button("OK") { importReport = nil }
        }
        .sheet(item: $editing) { snippet in
            SnippetEditor(snippet: snippet) { updated in
                store.save(updated)
                editing = nil
            } onCancel: {
                editing = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t("Dicionário", "Dictionary"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(t("Fale o atalho e ele vira o texto completo: email, link, prompt que você repete sempre.", "Speak the shortcut and it becomes the full text: email, link, a prompt you repeat all the time."))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button {
                PopUpMenu.show(
                    [
                        PopUpMenu.Item(
                            t("Importar do Wispr Flow", "Import from Wispr Flow"),
                            isEnabled: WisprFlowImport.isAvailable
                        ) { runImport(from: nil) },
                        PopUpMenu.Item(t("Importar de um arquivo…", "Import from a file…")) {
                            chooseFile()
                        }
                    ],
                    from: importAnchor
                )
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .help(t("Importar dicionário", "Import dictionary"))
            .background { MenuAnchor(view: importAnchor) }

            Button {
                editing = Snippet(trigger: "", expansion: "")
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text(t("Novo atalho", "New shortcut"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.contrastSurface)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(Theme.contrastSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText, .plainText, .data]
        panel.allowsMultipleSelection = false
        panel.message = t(
            "Escolha o banco do Wispr Flow (flow.sqlite) ou um arquivo com os atalhos.",
            "Pick the Wispr Flow database (flow.sqlite) or a file with the shortcuts."
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runImport(from: url)
    }

    private func runImport(from url: URL?) {
        do {
            let added = try WisprFlowImport.read(from: url)
            let saved = store.merge(added)
            importReport = saved == 0
                ? t("Nada novo: o dicionário já está aqui.", "Nothing new: the dictionary is already here.")
                : t("\(saved) atalhos importados do Wispr Flow.", "\(saved) shortcuts imported from Wispr Flow.")
        } catch {
            importReport = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(t("Nenhum atalho cadastrado", "No shortcuts yet"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(t("Ex.: falar “meu email” vira seu endereço completo.", "Example: saying “my email” becomes your full address."))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text(snippet.trigger)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.surfaceHover, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)

            Text(snippet.expansion)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(isHovering ? Theme.surfaceHover.opacity(0.5) : .clear)
        .onHover { isHovering = $0 }
    }
}

private struct SnippetEditor: View {
    @State var snippet: Snippet
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(snippet.trigger.isEmpty ? t("Novo atalho", "New shortcut") : t("Editar atalho", "Edit shortcut"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Quando eu falar", "When I say"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                TextField(t("meu email", "my email"), text: $snippet.trigger)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Escreva isto", "Write this"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                TextEditor(text: $snippet.expansion)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(height: 96)
                    .padding(6)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    }
            }

            HStack {
                Spacer()
                Button(t("Cancelar", "Cancel"), action: onCancel)
                    .pointerStyle(.link)
                Button(t("Salvar", "Save")) { onSave(snippet) }
                    .buttonStyle(.borderedProminent)
                    .pointerStyle(.link)
                    .disabled(!snippet.isValid)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Theme.canvas)
    }
}
