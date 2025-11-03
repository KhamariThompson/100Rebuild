/Volumes/NoodleDev/khamarit/Desktop/100Rebuild/100DaysRebuild/Features/Social/ViewModels/SocialViewModel.swift:326:36 Non-sendable type 'Firestore' in asynchronous access to nonisolated(unsafe) property 'firestore' cannot cross actor boundary
/Volumes/NoodleDev/khamarit/Desktop/100Rebuild/100DaysRebuild/Features/Social/ViewModels/SocialViewModel.swift:327:58 Main actor-isolated property 'username' can not be referenced from a Sendable closure
#!/bin/bash

echo "Fixing all Firestore transaction calls permanently..."

# Fix all transaction calls by removing the assignment and changing return type
for file in \
    100DaysRebuild/Services/FriendService.swift \
    100DaysRebuild/Services/GroupChallengeService.swift \
    100DaysRebuild/Services/UserSession.swift \
    100DaysRebuild/Features/Social/ViewModels/SocialViewModel.swift \
    100DaysRebuild/Features/Settings/ViewModels/ChangeUsernameViewModel.swift
do
    if [ -f "$file" ]; then
        # Replace all instances of "_ = try await firestore.runTransaction { " with "try await firestore.runTransaction { "
        sed -i '' 's/_ = try await firestore\.runTransaction { /try await firestore.runTransaction { /g' "$file"
        sed -i '' 's/-> Int?/-> Any?/g' "$file"
        echo "✓ Fixed $file"
    fi
done

echo "Done! All transactions fixed permanently."
