#[allow(lint(self_transfer))]
module gas_station::gas_station;
use sui::coin::{Self, Coin};
use usdc::usdc::USDC;
use sui::balance::{Self, Balance};
use sui::event;
use sui::clock::{Self, Clock};

// ======== Constants ========
const ENotAdmin: u64 = 1;
const ECannotRemoveLastAdmin: u64 = 2;
const EAdminAlreadyExists: u64 = 3;
const EAdminNotFound: u64 = 4;
const EInsufficientPayment: u64 = 5;
const ENoBalance: u64 = 6;

// ======== Types ========

/// Main gas station object that holds all state
public struct GasStation has key, store {
    id: UID,
    /// List of admin addresses
    admins: vector<address>,
    /// Gas price in USDC (with 6 decimals, so 100_000 = 0.1 USDC)
    gas_price: u64,
    /// Balance of collected USDC payments
    balance: Balance<USDC>,
}


// ======== Events ========

/// Event emitted when a new admin is added
public struct AdminAdded has copy, drop {
    admin: address,
    added_by: address,
}

/// Event emitted when an admin is removed
public struct AdminRemoved has copy, drop {
    admin: address,
    removed_by: address,
}

/// Event emitted when gas price is updated
public struct GasPriceUpdated has copy, drop {
    old_price: u64,
    new_price: u64,
    updated_by: address,
}

/// Event emitted when a user pays transaction fee
public struct TransactionFeePaid has copy, drop {
    user: address,
    amount: u64,
    timestamp: u64,
}

/// Event emitted when admin withdraws funds
public struct FundsWithdrawn has copy, drop {
    admin: address,
    amount: u64,
}

// ======== Init Function ========

/// Initialize the gas station with the deployer as the first admin
fun init(ctx: &mut TxContext) {

    let mut admins = vector::empty<address>();
    vector::push_back(&mut admins, ctx.sender());
    let gas_station = GasStation {
        id: object::new(ctx),
        admins,
        gas_price: 100_000, // Default: 0.1 USDC (100000 micro-USDC)
        balance: balance::zero<USDC>(),
    };

    transfer::share_object(gas_station);
}

// ======== Admin Module Functions ========

/// Check if an address is an admin
public fun is_admin(gas_station: &GasStation, addr: address): bool {
    vector::contains(&gas_station.admins, &addr)
}

/// Add a new admin (only existing admins can do this)
public fun add_admin(
    gas_station: &mut GasStation, 
    new_admin: address, 
    ctx: &mut TxContext
) {
    assert!(is_admin(gas_station, ctx.sender()), ENotAdmin);
    assert!(!is_admin(gas_station, new_admin), EAdminAlreadyExists);

    vector::push_back(&mut gas_station.admins, new_admin);

    event::emit(AdminAdded {
        admin: new_admin,
        added_by: ctx.sender(),
    });
}

/// Remove an admin (only existing admins can do this, cannot remove last admin)
public fun remove_admin(
    gas_station: &mut GasStation, 
    admin_to_remove: address, 
    ctx: &mut TxContext
) {
    assert!(is_admin(gas_station, ctx.sender()), ENotAdmin);
    assert!(vector::length(&gas_station.admins) > 1, ECannotRemoveLastAdmin);

    let (found, index) = vector::index_of(&gas_station.admins, &admin_to_remove);
    assert!(found, EAdminNotFound);

    vector::remove(&mut gas_station.admins, index);

    event::emit(AdminRemoved {
        admin: admin_to_remove,
        removed_by: ctx.sender(),
    });
}

/// Set the gas price (only admins can do this)
public fun set_gas_price(
    gas_station: &mut GasStation, 
    new_price: u64, 
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    assert!(is_admin(gas_station, sender), ENotAdmin);

    let old_price = gas_station.gas_price;
    gas_station.gas_price = new_price;

    event::emit(GasPriceUpdated {
        old_price,
        new_price,
        updated_by: sender,
    });
}


/// Withdraw all collected USDC funds (only admins can do this)
public fun withdraw_funds(
    gas_station: &mut GasStation, 
    ctx: &mut TxContext
) {

    assert!(is_admin(gas_station, ctx.sender()), ENotAdmin);
    
    let amount = balance::value(&gas_station.balance);
    assert!(amount > 0, ENoBalance);

    let withdrawn_balance = balance::withdraw_all(&mut gas_station.balance);
    let coin = coin::from_balance(withdrawn_balance, ctx);
    transfer::public_transfer(coin, ctx.sender());

    event::emit(FundsWithdrawn {
        admin: ctx.sender(),
        amount,
    });
}

// ======== User Module Functions ========

/// Pay transaction fee - user sends USDC to cover gas costs
public fun pay_transaction_fee(
    gas_station: &mut GasStation,
    payment: Coin<USDC>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let payment_amount = coin::value(&payment);
    
    // Check if payment is sufficient
    assert!(payment_amount == gas_station.gas_price, EInsufficientPayment);

    // Add payment to gas station balance
    balance::join(&mut gas_station.balance, coin::into_balance(payment));

    // Emit payment event
    event::emit(TransactionFeePaid {
        user: ctx.sender(),
        amount: payment_amount,
        timestamp: clock::timestamp_ms(clock),
    });
}

// ======== View Functions ========

/// Get current gas price
public fun get_gas_price(gas_station: &GasStation): u64 {
    gas_station.gas_price
}

/// Get current balance of collected fees
public fun get_balance(gas_station: &GasStation): u64 {
    balance::value(&gas_station.balance)
}

/// Get list of admins
public fun get_admins(gas_station: &GasStation): vector<address> {
    gas_station.admins
}

/// Get number of admins
public fun get_admin_count(gas_station: &GasStation): u64 {
    vector::length(&gas_station.admins)
}

// ======== Test Helper Functions ========

#[test_only]
/// Initialize gas station for testing
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
