import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// A beautiful modal view showing check-in details for a specific day
struct CheckInDayDetailView: View {
    let date: Date
    let challengeId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var checkInDetails: CheckInDetails? = nil
    @State private var isLoading = true
    @State private var downloadedImage: UIImage? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.theme.background
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let details = checkInDetails {
                    detailsView(details)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.theme.subtext)
                            .font(.system(size: 22, weight: .semibold))
                    }
                }
            }
        }
        .task {
            await loadCheckInDetails()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.theme.accent)

            Text("Loading check-in...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64, weight: .medium))
                .foregroundColor(.theme.subtext.opacity(0.5))

            Text("No Check-In")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)

            Text("No check-in was recorded for this day.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Details View

    private func detailsView(_ details: CheckInDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                // Header Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.green)

                        Text("Check-In Complete")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.theme.text)
                    }

                    HStack(spacing: 16) {
                        Label {
                            Text("Day \(details.dayNumber)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.theme.subtext)

                        if let duration = details.durationInMinutes {
                            Label {
                                Text("\(duration) min")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            } icon: {
                                Image(systemName: "clock")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.theme.subtext)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.theme.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
                )

                // Photo Section
                if let photoURL = details.photoURL {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.theme.accent)
                            Text("Photo")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.theme.text)
                        }

                        if let image = downloadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                        } else {
                            // Loading placeholder
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.theme.surface)
                                .frame(height: 200)
                                .overlay(
                                    ProgressView()
                                        .tint(.theme.accent)
                                )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.theme.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }

                // Note Section
                if let note = details.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.theme.accent)
                            Text("Journal Entry")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.theme.text)
                        }

                        Text(note)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.theme.text)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.theme.surface)
                            .shadow(color: Color.theme.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                }

                // Additional Info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Details")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.theme.text)

                    VStack(spacing: 12) {
                        infoRow(icon: "calendar", title: "Date", value: formattedDate)
                        Divider()
                        infoRow(icon: "clock", title: "Time", value: formattedTime)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.theme.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            .padding()
        }
    }

    // MARK: - Helper Views

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.theme.accent)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.theme.text)
        }
    }

    // MARK: - Date Formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Data Loading

    private func loadCheckInDetails() async {
        isLoading = true
        errorMessage = nil

        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        do {
            // Query all challenges to find check-ins for this date
            let db = Firestore.firestore()
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            // If challengeId is provided, query that specific challenge
            if let challengeId = challengeId {
                let checkInsRef = db.collection("users")
                    .document(userId)
                    .collection("challenges")
                    .document(challengeId)
                    .collection("checkIns")

                let query = checkInsRef
                    .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                    .whereField("date", isLessThan: Timestamp(date: endOfDay))
                    .limit(to: 1)

                let snapshot = try await query.getDocuments()

                if let document = snapshot.documents.first {
                    let data = document.data()
                    let details = CheckInDetails(from: data)
                    self.checkInDetails = details

                    // Download photo if available
                    if let photoURLString = details.photoURL,
                       let photoURL = URL(string: photoURLString) {
                        await downloadPhoto(from: photoURL)
                    }
                }
            } else {
                // Query all challenges for this user
                let challengesRef = db.collection("users")
                    .document(userId)
                    .collection("challenges")

                let challengesSnapshot = try await challengesRef.getDocuments()

                // Search through each challenge's check-ins
                for challengeDoc in challengesSnapshot.documents {
                    let checkInsRef = challengeDoc.reference.collection("checkIns")
                    let query = checkInsRef
                        .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                        .whereField("date", isLessThan: Timestamp(date: endOfDay))
                        .limit(to: 1)

                    let checkInSnapshot = try await query.getDocuments()

                    if let document = checkInSnapshot.documents.first {
                        let data = document.data()
                        let details = CheckInDetails(from: data)
                        self.checkInDetails = details

                        // Download photo if available
                        if let photoURLString = details.photoURL,
                           let photoURL = URL(string: photoURLString) {
                            await downloadPhoto(from: photoURL)
                        }

                        break // Found a check-in, stop searching
                    }
                }
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to load check-in: \(error.localizedDescription)"
            isLoading = false
            print("Error loading check-in details: \(error)")
        }
    }

    private func downloadPhoto(from url: URL) async {
        do {
            let image = try await PhotoStorageService.shared.downloadCheckInPhoto(from: url)
            await MainActor.run {
                self.downloadedImage = image
            }
        } catch {
            print("Failed to download photo: \(error)")
        }
    }
}

// MARK: - Check-In Details Model

struct CheckInDetails {
    let dayNumber: Int
    let note: String?
    let photoURL: String?
    let durationInMinutes: Int?

    init(from data: [String: Any]) {
        self.dayNumber = data["dayNumber"] as? Int ?? 0
        self.note = data["note"] as? String
        self.photoURL = data["photoURL"] as? String
        self.durationInMinutes = data["durationInMinutes"] as? Int
    }
}

// MARK: - Preview

struct CheckInDayDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CheckInDayDetailView(
            date: Date(),
            challengeId: nil
        )
        .preferredColorScheme(.dark)
    }
}
