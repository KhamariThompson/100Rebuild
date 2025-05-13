// Fix 4: Progress view loading
// This fix resolves issues with the ProgressView not loading and enhances error recovery:
// 1. Improved timeout and retry mechanism for network failures
// 2. Better UI experience with loading states
// 3. Proper handling of offline mode by using Firestore's cache
// 4. Added network connectivity monitoring to auto-retry on reconnection
// 5. Fixed data parsing issues that could cause loading failures
