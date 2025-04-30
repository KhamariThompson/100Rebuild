import Foundation

enum ProgressAction {
    case loadProgress
    case viewMilestone(milestoneId: String)
    case shareProgress
}

struct ProgressState {
    var overallProgress: Double = 0.0
    var milestones: [Milestone] = []
    var isLoading: Bool = false
    var error: String?
}

struct Milestone: Identifiable {
    let id: String
    let title: String
    let date: Date
    let isCompleted: Bool
}

class ProgressViewModel: ViewModel<ProgressState, ProgressAction> {
    init() {
        super.init(initialState: ProgressState())
    }
    
    override func handle(_ action: ProgressAction) {
        switch action {
        case .loadProgress:
            // TODO: Implement progress loading
            break
        case .viewMilestone(let milestoneId):
            // TODO: Implement milestone view
            break
        case .shareProgress:
            // TODO: Implement progress sharing
            break
        }
    }
} 