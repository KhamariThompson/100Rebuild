import SwiftUI
import Firebase

struct EnhancedCheckInHistoryView: View {
    let challenge: Challenge
    
    @StateObject private var viewModel: CheckInHistoryViewModel
    @State private var viewMode: ViewMode = .timeline
    @State private var selectedCheckIn: Models_CheckInRecord?
    @State private var showDetailView = false
    @State private var selectedDate: Date?
    @State private var selectedCheckIns: [Models_CheckInRecord] = []
    @State private var scrollOffset: CGFloat = 0
    
    // Custom gradient for check-in history header
    private let historyGradient = LinearGradient(
        gradient: Gradient(colors: [Color.theme.accent, Color.orange]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // View mode options
    enum ViewMode {
        case timeline
        case calendar
    }
    
    init(challenge: Challenge) {
        self.challenge = challenge
        self._viewModel = StateObject(wrappedValue: CheckInHistoryViewModel(challenge: challenge))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.theme.background
                .ignoresSafeArea()
            
            // Content with scroll tracking
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer to push content below the header
                    Color.clear
                        .frame(height: 110)
                    
                    // Mode Toggle
                    Picker("View Mode", selection: $viewMode) {
                        Text("Timeline").tag(ViewMode.timeline)
                        Text("Calendar").tag(ViewMode.calendar)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Main content
                    if viewModel.isLoading && viewModel.checkIns.isEmpty {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(maxHeight: .infinity)
                    } else if viewModel.checkIns.isEmpty {
                        emptyStateView
                    } else {
                        Group {
                            switch viewMode {
                            case .timeline:
                                timelineView
                            case .calendar:
                                calendarView
                            }
                        }
                    }
                }
                .trackScrollOffset($scrollOffset)
            }
            
            // Overlay the dynamic header
            ScrollAwareHeaderView(
                title: "Check-In History",
                scrollOffset: $scrollOffset,
                subtitle: challenge.title,
                accentGradient: historyGradient
            ) {
                // Display stats about this challenge's check-ins
                if !viewModel.checkIns.isEmpty {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("\(challenge.daysCompleted) days")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Streak: \(challenge.streakCount)")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.loadInitialCheckIns()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showDetailView) {
            if let checkIn = selectedCheckIn {
                CheckInDetailModalView(
                    viewModel: viewModel,
                    checkIn: checkIn,
                    challengeTitle: challenge.title
                )
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            Task {
                await viewModel.loadInitialCheckIns()
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.theme.subtext.opacity(0.5))
            
            Text("No check-ins yet")
                .font(.headline)
                .foregroundColor(.theme.text)
            
            Text("Complete your first day to see it here")
                .font(.subheadline)
                .foregroundColor(.theme.subtext)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // Navigate to check-in view
            }) {
                Text("Check In Now")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                    )
            }
            .padding(.top, 16)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        ScrollView {
            LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                // Group check-ins by month
                ForEach(Array(viewModel.groupedCheckIns.keys.sorted().reversed()), id: \.self) { monthYear in
                    Section(header: timelineMonthHeader(monthYear)) {
                        ForEach(viewModel.groupedCheckIns[monthYear] ?? []) { checkIn in
                            TimelineCheckInCard(checkIn: checkIn)
                                .onTapGesture {
                                    selectedCheckIn = checkIn
                                    showDetailView = true
                                }
                        }
                    }
                }
                
                // Load more indicator
                if viewModel.hasMoreData {
                    Button(action: {
                        Task {
                            await viewModel.loadMoreCheckInsIfNeeded()
                        }
                    }) {
                        HStack {
                            Text("Load More")
                                .font(.subheadline)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding(.leading, 4)
                            }
                        }
                        .foregroundColor(.theme.accent)
                        .padding(.vertical, 12)
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal)
        }
        .background(Color.theme.background)
    }
    
    private func timelineMonthHeader(_ monthYear: String) -> some View {
        HStack {
            Text(monthYear)
                .font(.headline)
                .foregroundColor(.theme.text)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 3, x: 0, y: 1)
                )
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.theme.background)
    }
    
    // MARK: - Calendar View
    
    private var calendarView: some View {
        VStack(spacing: 0) {
            // Month selector
            HStack {
                Button(action: {
                    let newDate = Calendar.current.date(
                        byAdding: .month,
                        value: -1,
                        to: viewModel.selectedMonth
                    ) ?? viewModel.selectedMonth
                    viewModel.setSelectedMonth(newDate)
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.theme.accent)
                        .padding(8)
                }
                
                Spacer()
                
                // Current month display
                Text(monthYearString(from: viewModel.selectedMonth))
                    .font(.headline)
                    .foregroundColor(.theme.text)
                
                Spacer()
                
                Button(action: {
                    let newDate = Calendar.current.date(
                        byAdding: .month,
                        value: 1,
                        to: viewModel.selectedMonth
                    ) ?? viewModel.selectedMonth
                    viewModel.setSelectedMonth(newDate)
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.theme.accent)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Day of week headers
            HStack(spacing: 0) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color.theme.surface)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(viewModel.calendarDates, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: selectedDate == date,
                        checkIn: viewModel.checkInsByDate[date]
                    )
                    .onTapGesture {
                        if let checkIn = viewModel.checkInsByDate[date] {
                            selectedDate = date
                            selectedCheckIn = checkIn
                            showDetailView = true
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Legend and stats
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.theme.accent)
                        .frame(width: 12, height: 12)
                    
                    Text("Check-In")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    Text("No check-in")
                        .font(.caption)
                        .foregroundColor(.theme.subtext)
                }
                
                Spacer()
                
                Text("\(viewModel.checkIns.count) total check-ins")
                    .font(.caption)
                    .foregroundColor(.theme.subtext)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Spacer()
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Timeline Card View

struct TimelineCheckInCard: View {
    let checkIn: Models_CheckInRecord
    
    var body: some View {
        VStack {
            // Day indicator and circle
            HStack(alignment: .top, spacing: 12) {
                // Day circle
                ZStack {
                    Circle()
                        .fill(Color.theme.accent)
                        .frame(width: 40, height: 40)
                    
                    Text("\(checkIn.dayNumber)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Card content
                VStack(alignment: .leading, spacing: 12) {
                    // Header with day number and date
                    HStack {
                        Text("Day \(checkIn.dayNumber)")
                            .font(.headline)
                            .foregroundColor(.theme.accent)
                        
                        Spacer()
                        
                        Text(checkIn.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.theme.subtext)
                    }
                    
                    // Photo if available
                    if checkIn.photoURL != nil {
                        AsyncImage(url: checkIn.photoURL) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.theme.surface)
                                    .overlay(ProgressView())
                                    .frame(height: 160)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.theme.surface)
                                    .overlay(
                                        Image(systemName: "photo.fill")
                                            .foregroundColor(.theme.subtext.opacity(0.5))
                                    )
                                    .frame(height: 160)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .cornerRadius(12)
                    }
                    
                    // If there's a note, show a preview
                    if let note = checkIn.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.theme.text)
                            .lineLimit(2)
                            .padding(.vertical, 4)
                    }
                    
                    // Quote if available (preview)
                    if let quote = checkIn.quote {
                        HStack {
                            Text("\"\(quote.text)\"")
                                .font(.caption)
                                .italic()
                                .foregroundColor(.theme.subtext)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    
                    // Footer with indicators
                    HStack {
                        if checkIn.photoURL != nil {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                        
                        if let note = checkIn.note, !note.isEmpty {
                            Image(systemName: "text.quote")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                        
                        Spacer()
                        
                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(.theme.accent)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
                )
            }
            
            // Connector line
            Rectangle()
                .fill(Color.theme.accent.opacity(0.5))
                .frame(width: 2)
                .frame(height: 30)
                .padding(.leading, 19)
                .offset(y: -5)
        }
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let checkIn: Models_CheckInRecord?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(checkIn != nil ? Color.theme.accent.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.theme.accent : Color.clear, lineWidth: 2)
                )
            
            VStack(spacing: 4) {
                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundColor(checkIn != nil ? .theme.text : .theme.subtext)
                
                // Photo thumbnail or indicator if available
                if checkIn?.photoURL != nil {
                    ZStack {
                        Circle()
                            .fill(Color.theme.accent)
                            .frame(width: 8, height: 8)
                    }
                } else if let note = checkIn?.note, !note.isEmpty {
                    ZStack {
                        Circle()
                            .fill(Color.theme.subtext)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .aspectRatio(1, contentMode: .fill)
    }
}

// Preview removed to avoid sample data usage in production code 