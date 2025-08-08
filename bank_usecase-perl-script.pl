#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use Digest::SHA qw(sha256_hex);
use DateTime;

# Simple Banking System in Perl
# This example demonstrates account management, transactions, and balance calculations

package BankingSystem;

sub new {
    my $class = shift;
    my $self = {
        accounts => {},
        transactions => [],
        next_account_id => 1000001,
        next_transaction_id => 1
    };
    bless $self, $class;
    return $self;
}

# Create a new bank account
sub create_account {
    my ($self, $customer_name, $initial_deposit) = @_;
    
    my $account_id = $self->{next_account_id}++;
    
    $self->{accounts}->{$account_id} = {
        account_id => $account_id,
        customer_name => $customer_name,
        balance => $initial_deposit || 0,
        created_date => DateTime->now->strftime('%Y-%m-%d %H:%M:%S'),
        status => 'active'
    };
    
    # Record initial deposit transaction if provided
    if ($initial_deposit && $initial_deposit > 0) {
        $self->record_transaction($account_id, 'credit', $initial_deposit, 'Initial deposit');
    }
    
    print "Account created successfully. Account ID: $account_id\n";
    return $account_id;
}

# Process a deposit transaction
sub deposit {
    my ($self, $account_id, $amount, $description) = @_;
    
    return $self->process_transaction($account_id, 'credit', $amount, $description || 'Deposit');
}

# Process a withdrawal transaction
sub withdraw {
    my ($self, $account_id, $amount, $description) = @_;
    
    # Check if account has sufficient funds
    my $account = $self->{accounts}->{$account_id};
    if (!$account) {
        print "Error: Account $account_id not found\n";
        return 0;
    }
    
    if ($account->{balance} < $amount) {
        print "Error: Insufficient funds. Current balance: \$" . sprintf("%.2f", $account->{balance}) . "\n";
        return 0;
    }
    
    return $self->process_transaction($account_id, 'debit', $amount, $description || 'Withdrawal');
}

# Transfer money between accounts
sub transfer {
    my ($self, $from_account, $to_account, $amount, $description) = @_;
    
    # Validate both accounts exist
    unless ($self->{accounts}->{$from_account} && $self->{accounts}->{$to_account}) {
        print "Error: One or both accounts not found\n";
        return 0;
    }
    
    # Check sufficient funds
    if ($self->{accounts}->{$from_account}->{balance} < $amount) {
        print "Error: Insufficient funds for transfer\n";
        return 0;
    }
    
    # Process both transactions
    my $desc = $description || "Transfer to account $to_account";
    if ($self->process_transaction($from_account, 'debit', $amount, $desc)) {
        $desc = $description || "Transfer from account $from_account";
        if ($self->process_transaction($to_account, 'credit', $amount, $desc)) {
            print "Transfer successful: \$" . sprintf("%.2f", $amount) . " from $from_account to $to_account\n";
            return 1;
        }
    }
    return 0;
}

# Internal method to process transactions
sub process_transaction {
    my ($self, $account_id, $type, $amount, $description) = @_;
    
    my $account = $self->{accounts}->{$account_id};
    if (!$account) {
        print "Error: Account $account_id not found\n";
        return 0;
    }
    
    # Update balance
    if ($type eq 'credit') {
        $account->{balance} += $amount;
    } elsif ($type eq 'debit') {
        $account->{balance} -= $amount;
    }
    
    # Record transaction
    $self->record_transaction($account_id, $type, $amount, $description);
    
    print "Transaction successful: $type \$" . sprintf("%.2f", $amount) . " - $description\n";
    print "New balance: \$" . sprintf("%.2f", $account->{balance}) . "\n";
    
    return 1;
}

# Record transaction in transaction log
sub record_transaction {
    my ($self, $account_id, $type, $amount, $description) = @_;
    
    my $transaction = {
        transaction_id => $self->{next_transaction_id}++,
        account_id => $account_id,
        type => $type,
        amount => $amount,
        description => $description,
        timestamp => DateTime->now->strftime('%Y-%m-%d %H:%M:%S'),
        balance_after => $self->{accounts}->{$account_id}->{balance}
    };
    
    push @{$self->{transactions}}, $transaction;
}

# Get account balance
sub get_balance {
    my ($self, $account_id) = @_;
    
    my $account = $self->{accounts}->{$account_id};
    if (!$account) {
        print "Error: Account $account_id not found\n";
        return undef;
    }
    
    return $account->{balance};
}

# Get account information
sub get_account_info {
    my ($self, $account_id) = @_;
    
    my $account = $self->{accounts}->{$account_id};
    if (!$account) {
        print "Error: Account $account_id not found\n";
        return undef;
    }
    
    print "\n--- Account Information ---\n";
    print "Account ID: $account->{account_id}\n";
    print "Customer: $account->{customer_name}\n";
    print "Balance: \$" . sprintf("%.2f", $account->{balance}) . "\n";
    print "Created: $account->{created_date}\n";
    print "Status: $account->{status}\n";
    
    return $account;
}

# Generate account statement
sub generate_statement {
    my ($self, $account_id, $days) = @_;
    $days ||= 30; # Default to last 30 days
    
    my $account = $self->{accounts}->{$account_id};
    if (!$account) {
        print "Error: Account $account_id not found\n";
        return;
    }
    
    print "\n--- Account Statement for $account->{customer_name} ---\n";
    print "Account ID: $account_id\n";
    print "Statement Period: Last $days days\n";
    print "Current Balance: \$" . sprintf("%.2f", $account->{balance}) . "\n\n";
    
    print sprintf("%-12s %-10s %-10s %-15s %-30s\n", 
                  "Date", "Trans ID", "Type", "Amount", "Description");
    print "-" x 80 . "\n";
    
    my @account_transactions = grep { $_->{account_id} == $account_id } @{$self->{transactions}};
    
    foreach my $trans (reverse @account_transactions) {
        my $amount_str = ($trans->{type} eq 'credit' ? '+' : '-') . sprintf("%.2f", $trans->{amount});
        print sprintf("%-12s %-10s %-10s \$%-14s %-30s\n",
                      substr($trans->{timestamp}, 0, 10),
                      $trans->{transaction_id},
                      uc($trans->{type}),
                      $amount_str,
                      $trans->{description});
    }
}

# Calculate interest (simple example)
sub calculate_interest {
    my ($self, $account_id, $annual_rate) = @_;
    $annual_rate ||= 0.02; # Default 2% annual interest
    
    my $account = $self->{accounts}->{$account_id};
    if (!$account) {
        print "Error: Account $account_id not found\n";
        return 0;
    }
    
    my $daily_rate = $annual_rate / 365;
    my $interest = $account->{balance} * $daily_rate;
    
    if ($interest > 0) {
        $self->deposit($account_id, $interest, "Daily interest payment");
        return $interest;
    }
    
    return 0;
}

# Main program demonstration
package main;

# Create banking system instance
my $bank = BankingSystem->new();

print "=== Banking System Demo ===\n\n";

# Create some accounts
my $account1 = $bank->create_account("John Doe", 1000.00);
my $account2 = $bank->create_account("Jane Smith", 500.00);
my $account3 = $bank->create_account("Bob Johnson", 0);

print "\n";

# Perform some transactions
$bank->deposit($account1, 250.00, "Salary deposit");
$bank->withdraw($account1, 100.00, "ATM withdrawal");
$bank->deposit($account3, 300.00, "Initial funding");

print "\n";

# Transfer money between accounts
$bank->transfer($account1, $account2, 200.00, "Loan repayment");

print "\n";

# Display account information
$bank->get_account_info($account1);
$bank->get_account_info($account2);

print "\n";

# Generate statement
$bank->generate_statement($account1);

print "\n";

# Calculate and apply interest
print "Applying daily interest...\n";
$bank->calculate_interest($account1, 0.05); # 5% annual rate
$bank->calculate_interest($account2, 0.05);

print "\n--- Final Balances ---\n";
foreach my $acc_id ($account1, $account2, $account3) {
    my $balance = $bank->get_balance($acc_id);
    if (defined $balance) {
        print "Account $acc_id: \$" . sprintf("%.2f", $balance) . "\n";
    }
}
