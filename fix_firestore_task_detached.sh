#!/bin/bash
# This script documents the pattern to fix Firestore Task.detached issues
# The actual fixes need to be done manually in specific files

echo "Pattern to fix:"
echo "1. Remove: Task.detached { and closing }.value"
echo "2. Remove: let fs = self.firestore (or firestoreInstance)"
echo "3. Replace: fs. with self.firestore."
echo ""
echo "Files that need fixes:"
echo "- Services/GroupChallengeService.swift"  
echo "- Services/FirebaseService.swift"
echo ""
echo "The general pattern is:"
echo "  BEFORE:"
echo "    try await Task.detached {"
echo "      let fs = self.firestore"  
echo "      _ = try await fs.runTransaction { ... }"
echo "    }.value"
echo ""
echo "  AFTER:"
echo "    _ = try await firestore.runTransaction { ... }"
echo "      // Use self.firestore inside the transaction closure"
