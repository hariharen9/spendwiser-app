import '../models/loan.dart';

abstract interface class ILoanRepository {
  Future<Loan> addLoan({
    required String name,
    required String lender,
    required LoanType type,
    required double principal,
    required double rate,
    required int years,
    required int emiDay,
  });

  Future<void> updateLoan(Loan loan);

  Future<void> removeLoan(String loanId);

  Future<void> recordLoanPayment({
    required String loanId,
    required double amount,
    required LoanPaymentType type,
    required DateTime date,
    required String accountId,
  });

  Future<void> deleteLoanPayment(String loanId, int paymentIndex);
}
