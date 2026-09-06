import SwiftUI

struct SnippetsView: View {
    let store: SnippetStore

    @State private var editing: Snippet?

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
                Text("Dicionário")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Fale o atalho e ele vira o texto completo — email, link, prompt que você repete sempre.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button {
                editing = Snippet(trigger: "", expansion: "")
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Novo atalho")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(Theme.textPrimary, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Nenhum atalho cadastrado")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Ex.: falar “meu email” vira seu endereço completo.")
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
            Text(snippet.trigger.isEmpty ? "Novo atalho" : "Editar atalho")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Quando eu falar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                TextField("meu email", text: $snippet.trigger)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Escreva isto")
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
                Button("Cancelar", action: onCancel)
                Button("Salvar") { onSave(snippet) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!snippet.isValid)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(Theme.canvas)
    }
}
