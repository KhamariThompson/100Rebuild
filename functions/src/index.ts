import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Clean up stale friend requests and challenge invitations
export const cleanupStaleRequests = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const twoWeeksAgo = new Date(now.toMillis() - 14 * 24 * 60 * 60 * 1000); // 14 days ago
    const twoWeeksAgoTimestamp =
      admin.firestore.Timestamp.fromDate(twoWeeksAgo);

    console.log(
      `Starting cleanup of stale requests older than ${twoWeeksAgo.toISOString()}`
    );

    try {
      // 1. Clean up stale friend requests
      const friendRequestsQuery = await db
        .collectionGroup("incoming")
        .where("status", "==", "pending")
        .where("createdAt", "<", twoWeeksAgoTimestamp)
        .get();

      console.log(
        `Found ${friendRequestsQuery.size} stale friend requests to clean up`
      );

      const friendRequestBatch = db.batch();
      let friendRequestCount = 0;

      friendRequestsQuery.forEach((doc) => {
        const data = doc.data();

        // Update the request status to expired
        friendRequestBatch.update(doc.ref, {
          status: "expired",
          updatedAt: now,
        });

        // Also update the corresponding outgoing request
        if (data.fromUserId && data.toUserId) {
          const outgoingRef = db
            .collection("friendRequests")
            .doc(data.fromUserId)
            .collection("outgoing")
            .doc(doc.id);

          friendRequestBatch.update(outgoingRef, {
            status: "expired",
            updatedAt: now,
          });
        }

        friendRequestCount++;

        // Commit in batches of 500 (Firestore limit)
        if (friendRequestCount >= 500) {
          friendRequestBatch.commit();
          friendRequestCount = 0;
        }
      });

      // Commit any remaining updates
      if (friendRequestCount > 0) {
        await friendRequestBatch.commit();
        console.log(
          `Updated ${friendRequestCount} friend requests to expired status`
        );
      }

      // 2. Clean up stale challenge invitations
      const challengeInvitesQuery = await db
        .collectionGroup("challengeInvitations")
        .where("status", "==", "pending")
        .where("createdAt", "<", twoWeeksAgoTimestamp)
        .get();

      console.log(
        `Found ${challengeInvitesQuery.size} stale challenge invitations to clean up`
      );

      const challengeInviteBatch = db.batch();
      let challengeInviteCount = 0;

      challengeInvitesQuery.forEach((doc) => {
        const data = doc.data();

        // Update the invitation status to expired
        challengeInviteBatch.update(doc.ref, {
          status: "expired",
          updatedAt: now,
        });

        // Also update the corresponding invitation in the challenge's invitees collection
        if (data.challengeId && data.toUserId) {
          const challengeInviteRef = db
            .collection("challengeInvites")
            .doc(data.challengeId)
            .collection("invitees")
            .doc(data.toUserId);

          challengeInviteBatch.update(challengeInviteRef, {
            status: "expired",
            updatedAt: now,
          });
        }

        challengeInviteCount++;

        // Commit in batches of 500 (Firestore limit)
        if (challengeInviteCount >= 500) {
          challengeInviteBatch.commit();
          challengeInviteCount = 0;
        }
      });

      // Commit any remaining updates
      if (challengeInviteCount > 0) {
        await challengeInviteBatch.commit();
        console.log(
          `Updated ${challengeInviteCount} challenge invitations to expired status`
        );
      }

      console.log("Cleanup completed successfully");
      return null;
    } catch (error) {
      console.error("Error cleaning up stale requests:", error);
      return null;
    }
  });

// Add other Cloud Functions here
