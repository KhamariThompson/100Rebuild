import SwiftUI

// Import the common ShareSheet
import Foundation

struct EnhancedCheckInView: View {
    // Dependencies
    @ObservedObject var challengesViewModel: ChallengesViewModel
    @StateObject private var viewModel = CheckInViewModel()
    @StateObject private var milestoneViewModel = MilestoneCelebrationViewModel()
    
    // Challenge data
    let challenge: Challenge
    
    // Navigation and state
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessView = false
    @State private var showMilestoneView = false
    @State private var showNotePrompt = false
    
    var body: some View {
        Group {
            if showMilestoneView {
                // Display milestone celebration
                MilestoneCelebrationModal(
                    dayNumber: challenge.daysCompleted + 1,
                    challengeId: challenge.id.uuidString,
                    challengeTitle: challenge.title,
                    isPresented: $showMilestoneView
                )
                .onDisappear {
                    // When milestone view is dismissed, decide what to show next
                    if showNotePrompt {
                        showNotePrompt = true
                    } else {
                        // Update timer before dismissing
                        Task {
                            await challengesViewModel.refreshChallenges()
                        }
                        dismiss()
                    }
                }
            } else if showSuccessView {
                // Display success view with quote
                CheckInSuccessView(
                    challenge: challenge,
                    quote: viewModel.currentQuote,
                    dayNumber: challenge.daysCompleted + 1,
                    showMilestone: false, // We're handling milestones differently now
                    milestoneMessage: "",
                    milestoneEmoji: "",
                    showNotePrompt: $showNotePrompt,
                    isPresented: $showSuccessView,
                    viewModel: viewModel
                )
                .onDisappear {
                    // When success view is dismissed, check if we should show milestone
                    if viewModel.isMilestoneDay && milestoneViewModel.shouldShowMilestone(
                        challengeId: challenge.id.uuidString,
                        day: challenge.daysCompleted + 1
                    ) {
                        showMilestoneView = true
                    } else if showNotePrompt {
                        showNotePrompt = true
                    } else {
                        // Update timer before dismissing
                        Task {
                            await challengesViewModel.refreshChallenges()
                        }
                        dismiss()
                    }
                }
            } else if showNotePrompt {
                // Display reflection prompt
                CheckInNotePromptView(
                    challenge: challenge,
                    dayNumber: challenge.daysCompleted + 1,
                    prompt: viewModel.currentPrompt,
                    viewModel: viewModel,
                    isPresented: $showNotePrompt
                )
                .onDisappear {
                    // Update timer before dismissing
                    Task {
                        await challengesViewModel.refreshChallenges()
                    }
                    dismiss()
                }
            } else {
                // Initial check-in confirmation screen
                initialCheckInView
            }
        }
        .navigationBarHidden(showSuccessView || showNotePrompt || showMilestoneView)
        .onAppear {
            // Set up the check-in
            Task {
                await viewModel.prepareForCheckIn(
                    challengeId: challenge.id.uuidString,
                    currentDay: challenge.daysCompleted + 1,
                    challengeTitle: challenge.title
                )
            }
            
            // Sync seen milestones from cloud
            Task {
                await milestoneViewModel.syncSeenMilestones(challengeId: challenge.id.uuidString)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var initialCheckInView: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Daily Check-In")) {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundColor(.theme.text)
                            .padding(.vertical, 4)
                        
                        HStack {
                            Text("Day \(challenge.daysCompleted + 1) of 100")
                                .font(.subheadline)
                                .foregroundColor(.theme.subtext)
                            
                            Spacer()
                            
                            Text("Current streak: \(challenge.streakCount) days")
                                .font(.caption)
                                .foregroundColor(.theme.subtext)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ready to check in for today?")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            Text("You'll have a chance to add notes and a photo after confirming.")
                                .font(.subheadline)
                                .foregroundColor(.theme.subtext)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section {
                        Button(action: {
                            performCheckIn()
                        }) {
                            HStack {
                                Spacer()
                                
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                    
                                    Text("Processing...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                } else {
                                    Text("Complete Check-In")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.theme.accent)
                            )
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .navigationTitle("Check In")
                .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            }
            // Add keyboard handling
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard if tapped outside of any input field
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                              to: nil, from: nil, for: nil)
            }
        }
    }
    
    private func performCheckIn() {
        Task {
            // Perform the check-in
            await viewModel.performCheckIn()
            
            // If successful, show the success view
            if !viewModel.showError {
                // Update the last check-in time immediately for better UX
                challengesViewModel.lastCheckInDate = Date()
                
                showSuccessView = true
                
                // Refresh the challenges list
                await challengesViewModel.refreshChallenges()
            }
        }
    }
}

// Preview removed to avoid sample data usage in production code 