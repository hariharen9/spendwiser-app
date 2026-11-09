import '../models/subscription.dart';

abstract interface class ISubscriptionRepository {
  Future<void> addSubscription({
    required String name,
    required double price,
    required int renewsInDays,
  });

  Future<void> updateSubscription(Subscription subscription);

  Future<void> toggleSubscription(String subscriptionId);

  Future<void> removeSubscription(String subscriptionId);

  Future<void> addRecurring({
    required String name,
    required double amount,
    required RecurringFrequency frequency,
    required bool isIncome,
  });

  Future<void> updateRecurring(RecurringTransaction recurring);

  Future<void> removeRecurring(String recurringId);
}
