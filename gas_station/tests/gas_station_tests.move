#[test_only]
module gas_station::gas_station_tests {
    use gas_station::gas_station::{Self, GasStation, ENotAdmin, ECannotRemoveLastAdmin, EInsufficientPayment, ENoBalance};
    use usdc::usdc::USDC;
    use sui::test_scenario::{Self as ts};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self};

    // Test addresses
    const ADMIN: address = @0xA;
    const USER1: address = @0xB;
    const USER2: address = @0xC;
    const NEW_ADMIN: address = @0xD;

    #[test]
    fun test_init_creates_gas_station_with_admin() {
        let mut scenario = ts::begin(ADMIN);
        
        // Initialize the gas station
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        
        ts::next_tx(&mut scenario, ADMIN);
        
        // Check that gas station was created and shared
        let gas_station = ts::take_shared<GasStation>(&scenario);
        
        // Verify initial state
        assert!(gas_station::is_admin(&gas_station, ADMIN), 0);
        assert!(gas_station::get_gas_price(&gas_station) == 100_000, 1); // 0.1 USDC
        assert!(gas_station::get_balance(&gas_station) == 0, 2);
        assert!(gas_station::get_admin_count(&gas_station) == 1, 3);
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    fun test_admin_can_add_new_admin() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ADMIN);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        // Add new admin
        gas_station::add_admin(&mut gas_station, NEW_ADMIN, ts::ctx(&mut scenario));
        
        // Verify new admin was added
        assert!(gas_station::is_admin(&gas_station, NEW_ADMIN), 0);
        assert!(gas_station::get_admin_count(&gas_station) == 2, 1);
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ENotAdmin)]
    fun test_non_admin_cannot_add_admin() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, USER1); // Switch to non-admin
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        // This should fail
        gas_station::add_admin(&mut gas_station, NEW_ADMIN, ts::ctx(&mut scenario));
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    fun test_admin_can_remove_admin_when_multiple_exist() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ADMIN);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        // Add second admin
        gas_station::add_admin(&mut gas_station, NEW_ADMIN, ts::ctx(&mut scenario));
        assert!(gas_station::get_admin_count(&gas_station) == 2, 0);
        
        // Remove the new admin
        gas_station::remove_admin(&mut gas_station, NEW_ADMIN, ts::ctx(&mut scenario));
        
        // Verify admin was removed
        assert!(!gas_station::is_admin(&gas_station, NEW_ADMIN), 1);
        assert!(gas_station::get_admin_count(&gas_station) == 1, 2);
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ECannotRemoveLastAdmin)]
    fun test_cannot_remove_last_admin() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ADMIN);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        // This should fail - cannot remove the last admin
        gas_station::remove_admin(&mut gas_station, ADMIN, ts::ctx(&mut scenario));
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    fun test_admin_can_set_gas_price() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ADMIN);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        // Set new gas price
        let new_price = 200_000; // 0.2 USDC
        gas_station::set_gas_price(&mut gas_station, new_price, ts::ctx(&mut scenario));
        
        // Verify price was updated
        assert!(gas_station::get_gas_price(&gas_station) == new_price, 0);
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ENotAdmin)]
    fun test_non_admin_cannot_set_gas_price() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, USER1); // Switch to non-admin
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        // This should fail
        gas_station::set_gas_price(&mut gas_station, 200_000, ts::ctx(&mut scenario));
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    fun test_user_can_pay_transaction_fee() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, USER1);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        
        // Create USDC coin for payment
        let payment_amount = 100_000; // Exact gas price
        let payment = coin::mint_for_testing<USDC>(payment_amount, ts::ctx(&mut scenario));
        
        // Pay transaction fee
        gas_station::pay_transaction_fee(&mut gas_station, payment, &clock, ts::ctx(&mut scenario));
        
        // Verify balance was updated
        assert!(gas_station::get_balance(&gas_station) == payment_amount, 0);
        
        clock::destroy_for_testing(clock);
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EInsufficientPayment)]
    fun test_user_cannot_overpay_transaction_fee() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, USER1);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        
        // Create USDC coin for payment (overpay) - this should now fail since exact payment is required
        let payment_amount = 150_000; // More than gas price
        let payment = coin::mint_for_testing<USDC>(payment_amount, ts::ctx(&mut scenario));
        
        // This should fail - exact payment required
        gas_station::pay_transaction_fee(&mut gas_station, payment, &clock, ts::ctx(&mut scenario));
        
        clock::destroy_for_testing(clock);
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EInsufficientPayment)]
    fun test_user_cannot_underpay_transaction_fee() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, USER1);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        
        // Create USDC coin for insufficient payment
        let payment_amount = 50_000; // Less than gas price
        let payment = coin::mint_for_testing<USDC>(payment_amount, ts::ctx(&mut scenario));
        
        // This should fail
        gas_station::pay_transaction_fee(&mut gas_station, payment, &clock, ts::ctx(&mut scenario));
        
        clock::destroy_for_testing(clock);
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    fun test_admin_can_withdraw_funds() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        
        // First, have users pay some fees
        ts::next_tx(&mut scenario, USER1);
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment1 = coin::mint_for_testing<USDC>(100_000, ts::ctx(&mut scenario));
        gas_station::pay_transaction_fee(&mut gas_station, payment1, &clock, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock);
        ts::return_shared(gas_station);
        
        ts::next_tx(&mut scenario, USER2);
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment2 = coin::mint_for_testing<USDC>(100_000, ts::ctx(&mut scenario));
        gas_station::pay_transaction_fee(&mut gas_station, payment2, &clock, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock);
        ts::return_shared(gas_station);
        
        // Now admin withdraws all funds
        ts::next_tx(&mut scenario, ADMIN);
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        let total_balance = gas_station::get_balance(&gas_station);
        assert!(total_balance == 200_000, 0);
        
        // Withdraw all funds
        gas_station::withdraw_funds(&mut gas_station, ts::ctx(&mut scenario));
        
        // Check balance is now zero
        assert!(gas_station::get_balance(&gas_station) == 0, 1);
        
        // Check that admin received the coin
        ts::next_tx(&mut scenario, ADMIN);
        let withdrawn_coin = ts::take_from_sender<Coin<USDC>>(&scenario);
        assert!(coin::value(&withdrawn_coin) == 200_000, 2);
        
        ts::return_to_sender(&scenario, withdrawn_coin);
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    fun test_admin_can_withdraw_multiple_payments() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        
        // Have user pay fee multiple times  
        ts::next_tx(&mut scenario, USER1);
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment1 = coin::mint_for_testing<USDC>(100_000, ts::ctx(&mut scenario));
        gas_station::pay_transaction_fee(&mut gas_station, payment1, &clock, ts::ctx(&mut scenario));
        
        let payment2 = coin::mint_for_testing<USDC>(100_000, ts::ctx(&mut scenario));
        gas_station::pay_transaction_fee(&mut gas_station, payment2, &clock, ts::ctx(&mut scenario));
        
        let payment3 = coin::mint_for_testing<USDC>(100_000, ts::ctx(&mut scenario));
        gas_station::pay_transaction_fee(&mut gas_station, payment3, &clock, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock);
        ts::return_shared(gas_station);
        
        // Admin withdraws all
        ts::next_tx(&mut scenario, ADMIN);
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        gas_station::withdraw_funds(&mut gas_station, ts::ctx(&mut scenario));
        
        // Check balance is now zero
        assert!(gas_station::get_balance(&gas_station) == 0, 0);
        
        // Check that admin received the coin
        ts::next_tx(&mut scenario, ADMIN);
        let withdrawn_coin = ts::take_from_sender<Coin<USDC>>(&scenario);
        assert!(coin::value(&withdrawn_coin) == 300_000, 1);
        
        ts::return_to_sender(&scenario, withdrawn_coin);
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ENotAdmin)]
    fun test_non_admin_cannot_withdraw_funds() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        
        // Have user pay fee first
        ts::next_tx(&mut scenario, USER1);
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment = coin::mint_for_testing<USDC>(100_000, ts::ctx(&mut scenario));
        gas_station::pay_transaction_fee(&mut gas_station, payment, &clock, ts::ctx(&mut scenario));
        clock::destroy_for_testing(clock);
        
        // Non-admin tries to withdraw - should fail
        gas_station::withdraw_funds(&mut gas_station, ts::ctx(&mut scenario));
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ENoBalance)]
    fun test_cannot_withdraw_from_empty_balance() {
        let mut scenario = ts::begin(ADMIN);
        
        gas_station::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ADMIN);
        
        let mut gas_station = ts::take_shared<GasStation>(&scenario);
        
        // Try to withdraw from empty balance - should fail
        gas_station::withdraw_funds(&mut gas_station, ts::ctx(&mut scenario));
        
        ts::return_shared(gas_station);
        ts::end(scenario);
    }
}