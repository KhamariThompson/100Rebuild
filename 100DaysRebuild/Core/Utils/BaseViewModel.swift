import Foundation
import Combine

protocol BaseViewModel: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get set }
    func handle(_ action: Action)
}

// MARK: - View Model Base Class
class ViewModel<State, Action>: BaseViewModel {
    @Published var state: State
    
    init(initialState: State) {
        self.state = initialState
    }
    
    func handle(_ action: Action) {
        fatalError("handle(_:) must be implemented by subclasses")
    }
} 