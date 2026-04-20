import SwiftUI

// Reusable text editor sheet for editing Flock / InsideTalk / Distributors posts
struct PostEditSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let title: String
    @State var text: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .background(AppTheme.surfaceVariant)
                    .cornerRadius(8)
                    .padding(16)
                    .scrollContentBackground(.hidden)
                
                Spacer()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .foregroundColor(AppTheme.goldPrimary)
                    .fontWeight(.bold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
