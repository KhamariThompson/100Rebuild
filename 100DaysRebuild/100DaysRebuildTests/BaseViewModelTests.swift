import XCTest
@testable import 100DaysRebuild

final class BaseViewModelTests: XCTestCase {
    func testViewModelInitialization() {
        // Given
        let initialState = TestState(value: 0)
        
        // When
        let viewModel = TestViewModel(initialState: initialState)
        
        // Then
        XCTAssertEqual(viewModel.state.value, 0)
    }
    
    func testViewModelActionHandling() {
        // Given
        let viewModel = TestViewModel(initialState: TestState(value: 0))
        
        // When
        viewModel.handle(.increment)
        
        // Then
        XCTAssertEqual(viewModel.state.value, 1)
    }
}

// MARK: - Test Types
private struct TestState {
    var value: Int
}

private enum TestAction {
    case increment
    case decrement
}

private class TestViewModel: ViewModel<TestState, TestAction> {
    override func handle(_ action: TestAction) {
        switch action {
        case .increment:
            state.value += 1
        case .decrement:
            state.value -= 1
        }
    }
} 