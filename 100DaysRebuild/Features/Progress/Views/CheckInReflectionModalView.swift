import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CheckInReflectionModalView: View {
    let selectedDate: Date
    let challengeId: String
    @ObservedObject var viewModel: CheckInReflectionViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var animateContent = false
    
    init(selectedDate: Date, challengeId: String) {
        self.selectedDate = selectedDate
        self.challengeId = challengeId
        self.viewModel = CheckInReflectionViewModel(challengeId: challengeId)
    }
    
    var body: some View {
        ZStack {
            backgroundView
            modalContentView
        }
        .onAppear {
            loadDataAndAnimate()
        }
    }
    
    // MARK: - Sub-Views
    
    private var backgroundView: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                dismiss()
            }
    }
    
    private var modalContentView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            headerView
            contentView
        }
        .padding(AppSpacing.l)
        .background(modalBackground)
        .frame(maxWidth: min(UIScreen.main.bounds.width * 0.9, 400))
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.8, 600))
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .opacity(animateContent ? 1.0 : 0.0)
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate, style: .date)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.theme.text)
                
                Text("Check-in Reflection")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.theme.subtext)
            }
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.theme.subtext)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else if let checkIn = viewModel.checkInRecord {
            checkInDataView(checkIn: checkIn)
        } else if viewModel.showError {
            errorView
        } else {
            noDataView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: AppSpacing.m) {
            ProgressView()
                .tint(.theme.accent)
            
            Text("Loading check-in data...")
                .font(.system(size: 16))
                .foregroundColor(.theme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
    
    private func checkInDataView(checkIn: Models_CheckInRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                photoSection(checkIn: checkIn)
                noteSection(checkIn: checkIn)
                quoteSection(checkIn: checkIn)
            }
        }
    }
    
    @ViewBuilder
    private func photoSection(checkIn: Models_CheckInRecord) -> some View {
        if let photoURL = checkIn.photoURL {
            AsyncImage(url: photoURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface)
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .tint(.theme.accent)
                    )
            }
        }
    }
    
    @ViewBuilder
    private func noteSection(checkIn: Models_CheckInRecord) -> some View {
        if let note = checkIn.note, !note.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Reflection Note")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.theme.text)
                
                Text(note)
                    .font(.system(size: 15))
                    .foregroundColor(.theme.text)
                    .padding(AppSpacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.theme.surface.opacity(0.6))
                    )
            }
        }
    }
    
    @ViewBuilder
    private func quoteSection(checkIn: Models_CheckInRecord) -> some View {
        if let quote = checkIn.quote {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Daily Quote")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.theme.text)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("\"\(quote.text)\"")
                        .font(.system(size: 15, design: .serif))
                        .italic()
                        .foregroundColor(.theme.text)
                    
                    Text("— \(quote.author)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.theme.subtext)
                }
                .padding(AppSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.theme.accent.opacity(0.1))
                )
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.theme.accent)
            
            Text("Error loading data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.theme.text)
            
            Text(viewModel.errorMessage)
                .font(.system(size: 14))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
    
    private var noDataView: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 32))
                .foregroundColor(.theme.subtext)
            
            Text("No check-in data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.theme.text)
            
            Text("No check-in was recorded for this day.")
                .font(.system(size: 14))
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
    
    private var modalBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.theme.background)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func loadDataAndAnimate() {
        // Load check-in data for the selected date
        Task {
            await viewModel.loadCheckInData(for: selectedDate)
        }
        
        // Animate appearance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animateContent = true
        }
    }
}

#Preview {
    CheckInReflectionModalView(
        selectedDate: Date(),
        challengeId: "sample-challenge-id"
    )
} 