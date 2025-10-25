import Foundation
import SwiftUI

// MARK: - Funnel Models

/// Represents a single question in the onboarding funnel
struct FunnelQuestion {
    let id: Int
    let question: String
    let subtitle: String?
    let type: QuestionType
    let options: [String]
    let isRequired: Bool
    
    enum QuestionType {
        case multipleChoice
        case freeText
    }
}

/// User's answers to the funnel questions
struct FunnelAnswers {
    var answers: [Int: String] = [:]
    var freeTextAnswer: String = ""
    
    // MARK: - Answer Accessors
    
    var commitment: String {
        answers[1] ?? "Move body"
    }
    
    var motivation: String {
        answers[2] ?? "Need momentum"
    }
    
    var biggestObstacle: String {
        answers[3] ?? "Procrastination"
    }
    
    var dailyTime: String {
        answers[4] ?? "15–20 min"
    }
    
    var preferredTime: String {
        answers[5] ?? "Evening"
    }
    
    var accountabilityStyle: String {
        answers[6] ?? "Streaks/badges"
    }
    
    var motivationTone: String {
        answers[7] ?? "Gentle nudge"
    }
    
    var customCommitmentName: String {
        freeTextAnswer.isEmpty ? commitment : freeTextAnswer
    }
    
    // MARK: - Persistence
    
    private static let storageKey = "FunnelAnswers"
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }
    
    static func load() -> FunnelAnswers {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(FunnelAnswers.self, from: data) else {
            return FunnelAnswers()
        }
        return decoded
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

extension FunnelAnswers: Codable {}

/// Manages the funnel questions and answers
class FunnelModel: ObservableObject {
    @Published var answers = FunnelAnswers()
    @Published var currentStep: Int = 1
    
    // MARK: - Questions Definition
    
    let questions: [FunnelQuestion] = [
        FunnelQuestion(
            id: 1,
            question: "What are you committing to check in for 100 days?",
            subtitle: nil,
            type: .multipleChoice,
            options: ["Move body", "Study & focus", "Create", "Save money", "Mindfulness", "Other"],
            isRequired: true
        ),
        FunnelQuestion(
            id: 2,
            question: "What pushed you to start today?",
            subtitle: nil,
            type: .multipleChoice,
            options: ["I'm done breaking promises", "I need momentum now", "A health/wellness wake-up call", "I want discipline that lasts", "Other"],
            isRequired: true
        ),
        FunnelQuestion(
            id: 3,
            question: "What usually derails you?",
            subtitle: nil,
            type: .multipleChoice,
            options: ["Procrastination", "No time", "Low energy", "Forgetfulness", "Fear of failing"],
            isRequired: true
        ),
        FunnelQuestion(
            id: 4,
            question: "How much time can you honestly give most days?",
            subtitle: nil,
            type: .multipleChoice,
            options: ["5–10 min", "15–20 min", "30 min", "45+ min"],
            isRequired: true
        ),
        FunnelQuestion(
            id: 5,
            question: "When are you most likely to check in?",
            subtitle: nil,
            type: .multipleChoice,
            options: ["Morning", "Afternoon", "Evening", "Flexible"],
            isRequired: true
        ),
        FunnelQuestion(
            id: 6,
            question: "How should we keep you accountable?",
            subtitle: nil,
            type: .multipleChoice,
            options: ["Streaks & badges", "Smart reminders", "Partner/friends", "Quiet/solo"],
            isRequired: true
        ),
        FunnelQuestion(
            id: 7,
            question: "If you miss a day, what tone helps you bounce back?",
            subtitle: nil,
            type: .multipleChoice,
            options: ["Tough love", "Gentle nudge", "Data-driven", "Encouragement"],
            isRequired: true
        ),
        FunnelQuestion(
            id: 8,
            question: "Name your 100-day commitment",
            subtitle: "This becomes the title of your daily reminder. Keep it short & specific.",
            type: .freeText,
            options: [],
            isRequired: true
        )
    ]
    
    var totalSteps: Int {
        questions.count
    }
    
    var progress: Double {
        Double(currentStep) / Double(totalSteps)
    }
    
    var currentQuestion: FunnelQuestion? {
        questions.first { $0.id == currentStep }
    }
    
    var isLastStep: Bool {
        currentStep >= totalSteps
    }
    
    var canProceed: Bool {
        if currentStep == 8 {
            return !answers.freeTextAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return answers.answers[currentStep] != nil
    }
    
    // MARK: - Actions
    
    func selectAnswer(_ answer: String) {
        answers.answers[currentStep] = answer
        saveAnswers()
    }
    
    func setFreeTextAnswer(_ text: String) {
        answers.freeTextAnswer = text
        saveAnswers()
    }
    
    func nextStep() {
        guard canProceed else { return }
        
        if !isLastStep {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        }
    }
    
    func previousStep() {
        guard currentStep > 1 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
    }
    
    func reset() {
        answers = FunnelAnswers()
        currentStep = 1
        FunnelAnswers.clear()
    }
    
    private func saveAnswers() {
        answers.save()
    }
    
    // MARK: - Initialization
    
    init() {
        self.answers = FunnelAnswers.load()
    }
}

// MARK: - Streak Setup Configuration

/// Configuration derived from funnel answers for personalized streak setup
struct StreakConfiguration {
    let dailyTimeWindow: String
    let reminderStyle: String
    let backupPlan: String
    let motivationTone: String
    let commitmentName: String
    
    /// Generates a personalized streak configuration from funnel answers
    static func from(answers: FunnelAnswers) -> StreakConfiguration {
        let timeWindow = generateTimeWindow(
            dailyTime: answers.dailyTime,
            preferredTime: answers.preferredTime
        )
        
        let reminderStyle = generateReminderStyle(
            preferredTime: answers.preferredTime,
            accountabilityStyle: answers.accountabilityStyle
        )
        
        let backupPlan = generateBackupPlan(obstacle: answers.biggestObstacle)
        
        return StreakConfiguration(
            dailyTimeWindow: timeWindow,
            reminderStyle: reminderStyle,
            backupPlan: backupPlan,
            motivationTone: answers.motivationTone,
            commitmentName: answers.customCommitmentName
        )
    }
    
    private static func generateTimeWindow(dailyTime: String, preferredTime: String) -> String {
        let timeAdjective = preferredTime.lowercased()
        return "\(timeAdjective.capitalized), ~\(dailyTime)"
    }
    
    private static func generateReminderStyle(preferredTime: String, accountabilityStyle: String) -> String {
        let timeMapping: [String: String] = [
            "Morning": "8:00 AM",
            "Afternoon": "2:00 PM", 
            "Evening": "7:30 PM",
            "Flexible": "6:00 PM"
        ]
        
        let time = timeMapping[preferredTime] ?? "7:30 PM"
        
        if accountabilityStyle.contains("Smart reminders") {
            return "Smart reminder \(time)"
        } else if accountabilityStyle.contains("Quiet") {
            return "Gentle reminder \(time)"
        } else {
            return "Daily reminder \(time)"
        }
    }
    
    private static func generateBackupPlan(obstacle: String) -> String {
        switch obstacle {
        case "Procrastination":
            return "1-minute micro-check-in before bed"
        case "No time":
            return "30-second quick check-in during a break"
        case "Low energy":
            return "Simple voice note when energy is low"
        case "Forgetfulness":
            return "Evening backup reminder if missed"
        case "Fear of failing":
            return "Progress over perfection mindset reset"
        default:
            return "1-minute micro-check-in before bed"
        }
    }
}
