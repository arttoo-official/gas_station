# Gas Station Sui Smart Contract

A comprehensive gas station smart contract on Sui that allows users to pay transaction fees in USDC and provides admin functionality to manage the system.

# Variables
## Mainnet
- `GAS_STATION_ID` = `0x664795ea2e9c69b3ed979131568a62184019861d32ccaa37eff74bc970d618dd`
- `PACKAGE_ID` = `0x9aefb4cc2e22ef63330fc33c765d9e91472f73ed8e91d68ebf72130fed81b8ba`
## Testnet
- `PACKAGE_ID` = `0xf6beef6be358a9bc6e9f5289fed76d00a39b02a004d8401a8bf2cd2d77ec29dd`
- `GAS_STATION_ID` = `0xa3d74f7487a605133f0a14e8f78347245ed5f5ebfe901a72b85a2d01ec32b1c8`

## Features

### Admin Module
- ✅ **Admin Management**: Add and remove admin users (without caps to prevent loss)
- ✅ **Minimum Admin Requirement**: Always maintains at least 1 admin user
- ✅ **Gas Price Setting**: Admins can set USDC gas price (e.g., 0.1 USDC)
- ✅ **Fund Withdrawal**: Admins can withdraw collected USDC funds

### User Module  
- ✅ **Transaction Fee Payment**: Users pay fixed USDC amount set by admins
- ✅ **Event Emission**: All payments emit events for tracking
- ✅ **Overpayment Allowed**: Users can pay more than required amount

### Security Features
- ✅ **No Capability Objects**: Uses address-based admin system to prevent loss
- ✅ **Admin Protection**: Cannot remove the last admin
- ✅ **Payment Validation**: Ensures sufficient payment before processing

## Contract Structure

```
gas_station::gas_station
├── Admin Functions
│   ├── add_admin()
│   ├── remove_admin() 
│   ├── set_gas_price()
│   ├── withdraw_funds()
│   └── withdraw_all_funds()
├── User Functions
│   └── pay_transaction_fee()
└── View Functions
    ├── get_gas_price()
    ├── get_balance()
    ├── get_admins()
    ├── get_admin_count()
    └── is_admin()
```

## Events

- `AdminAdded`: When a new admin is added
- `AdminRemoved`: When an admin is removed  
- `GasPriceUpdated`: When gas price is changed
- `TransactionFeePaid`: When user pays transaction fee
- `FundsWithdrawn`: When admin withdraws funds

## Usage

### Deployment
```bash
sui move build
sui client publish --gas-budget 100000000
```

### Admin Operations
```bash
# Add new admin
sui client call --function add_admin --module gas_station --package <PACKAGE_ID> --args <GAS_STATION_ID> <NEW_ADMIN_ADDRESS> --gas-budget 10000000

# Set gas price (amount in micro-USDC, e.g., 100000 = 0.1 USDC)  
sui client call --function set_gas_price --module gas_station --package <PACKAGE_ID> --args <GAS_STATION_ID> 100000 --gas-budget 10000000

# Withdraw funds
sui client call --function withdraw_funds --module gas_station --package <PACKAGE_ID> --args <GAS_STATION_ID> <AMOUNT> --gas-budget 10000000
```

### User Operations
```bash
# Pay transaction fee
sui client call --function pay_transaction_fee --module gas_station --package <PACKAGE_ID> --args <GAS_STATION_ID> <USDC_COIN_ID> --gas-budget 10000000
```

## Testing

Run the comprehensive test suite:

```bash
sui move test
```

The tests cover:
- Admin management (add/remove)
- Gas price setting
- User payments (exact, overpay, underpay)
- Fund withdrawal
- Access control
- Edge cases

## Gas Price Format

Gas prices are stored in micro-USDC (6 decimal places):
- `100000` = 0.1 USDC
- `1000000` = 1.0 USDC  
- `50000` = 0.05 USDC

## Error Codes

- `ENotAdmin (1)`: Caller is not an admin
- `ECannotRemoveLastAdmin (2)`: Cannot remove the last admin
- `EAdminAlreadyExists (3)`: Admin already exists
- `EAdminNotFound (4)`: Admin not found for removal
- `EInsufficientPayment (5)`: Payment less than required gas price
- `ENoBalance (6)`: No funds available for withdrawal


## Security Considerations

- Admin addresses are stored in contract state (no capability objects to lose)
- Always maintains at least one admin
- Payment validation prevents underpayment/overpayment
- Event emission for audit trails
- Access control on all admin functions

