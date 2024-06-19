#[allow(unused_const)]
module car_registration_system::car_registration_system {
    // Import necessary modules
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{self, Coin};
    use sui::object::{self, UID};
    use sui::balance::{self, Balance};
    use sui::tx_context::{self, TxContext};
    use std::option::{self, Option, none, some, is_some, contains, borrow};

    // Define error codes
    const EInvalidRegistration: u64 = 1;
    const EInvalidCar: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotRegistered: u64 = 5;
    const EInvalidWithdrawal: u64 = 7;
    const EAssignmentDeadlinePassed: u64 = 8;

    // Define struct for car registration
    struct CarRegistration has key, store {
        id: UID,
        owner: address,
        inspector: Option<address>,
        description: vector<u8>,
        registration_details: vector<u8>,
        documents: vector<vector<u8>>,
        fee: u64,
        escrow: Balance<SUI>,
        registrationScheduled: bool,
        dispute: bool,
        progress: u8,
        feedback: Option<vector<u8>>,
        rating: Option<u8>,
        registrationDeadline: Option<u64>,
        inspectionDeadline: Option<u64>,
    }

    // Function to book a car registration
    public entry fun book_car_registration(description: vector<u8>, registration_details: vector<u8>, documents: vector<vector<u8>>, fee: u64, ctx: &mut TxContext) {
        let registration_id = object::new(ctx);
        transfer::share_object(CarRegistration {
            id: registration_id,
            owner: tx_context::sender(ctx),
            inspector: none(),
            description,
            registration_details,
            documents,
            fee,
            escrow: balance::zero(),
            registrationScheduled: false,
            dispute: false,
            progress: 0,
            feedback: none(),
            rating: none(),
            registrationDeadline: none(),
            inspectionDeadline: none(),
        });
    }

    // Function to request a car inspection
    public entry fun request_car_inspection(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(!is_some(&car_registration.inspector), EInvalidRegistration);
        car_registration.inspector = some(tx_context::sender(ctx));
    }

    // Function to submit a car registration
    public entry fun submit_car_registration(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(contains(&car_registration.inspector, &tx_context::sender(ctx)), EInvalidCar);
        car_registration.registrationScheduled = true;
    }

    // Function to dispute a car registration
    public entry fun dispute_car_registration(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), EDispute);
        car_registration.dispute = true;
    }

    // Function to resolve a car registration dispute
    public entry fun resolve_car_registration(car_registration: &mut CarRegistration, resolved: bool, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), EDispute);
        assert!(car_registration.dispute, EAlreadyResolved);
        assert!(is_some(&car_registration.inspector), EInvalidRegistration);
        let escrow_amount = balance::value(&car_registration.escrow);
        let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx);
        if (resolved) {
            let inspector = *borrow(&car_registration.inspector);
            transfer::public_transfer(escrow_coin, inspector);
        } else {
            transfer::public_transfer(escrow_coin, car_registration.owner);
        };

        car_registration.inspector = none();
        car_registration.registrationScheduled = false;
        car_registration.dispute = false;
    }

    // Function to release payment for a car registration
    public entry fun release_payment(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), ENotRegistered);
        assert!(car_registration.registrationScheduled && !car_registration.dispute, EInvalidCar);
        assert!(is_some(&car_registration.inspector), EInvalidRegistration);
        let inspector = *borrow(&car_registration.inspector);
        let escrow_amount = balance::value(&car_registration.escrow);
        let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, inspector);

        car_registration.inspector = none();
        car_registration.registrationScheduled = false;
        car_registration.dispute = false;
    }

    // Function to add funds to a car registration
    public entry fun add_funds_to_registration(car_registration: &mut CarRegistration, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == car_registration.owner, ENotRegistered);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut car_registration.escrow, added_balance);
    }

    // Function to request a refund for a car registration
    public entry fun request_refund(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == car_registration.owner, ENotRegistered);
        assert!(!car_registration.registrationScheduled, EInvalidWithdrawal);
        let escrow_amount = balance::value(&car_registration.escrow);
        let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, car_registration.owner);

        car_registration.inspector = none();
        car_registration.registrationScheduled = false;
        car_registration.dispute = false;
    }

    // Function to cancel a car registration
    public entry fun cancel_car_registration(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered);

        if (is_some(&car_registration.inspector) && !car_registration.registrationScheduled && !car_registration.dispute) {
            let escrow_amount = balance::value(&car_registration.escrow);
            let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, car_registration.owner);
        };

        car_registration.inspector = none();
        car_registration.registrationScheduled = false;
        car_registration.dispute = false;
    }

    // Function to update car description
    public entry fun update_car_description(car_registration: &mut CarRegistration, new_description: vector<u8>, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), ENotRegistered);
        car_registration.description = new_description;
    }

    // Function to update registration fee
    public entry fun update_registration_fee(car_registration: &mut CarRegistration, new_fee: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), ENotRegistered);
        car_registration.fee = new_fee;
    }

    // Function to provide feedback
    public entry fun provide_feedback(car_registration: &mut CarRegistration, feedback: vector<u8>, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) && car_registration.registrationScheduled, ENotRegistered);
        car_registration.feedback = some(feedback);
    }

    // Function to provide rating
    public entry fun provide_rating(car_registration: &mut CarRegistration, rating: u8, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) && car_registration.registrationScheduled, ENotRegistered);
        car_registration.rating = some(rating);
    }

    // Function to set the deadline for car registration
    public entry fun set_registration_deadline(car_registration: &mut CarRegistration, deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered);
        car_registration.registrationDeadline = some(deadline);
    }

    // Function to set the deadline for car inspection
    public entry fun set_inspection_deadline(car_registration: &mut CarRegistration, deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered);
        car_registration.inspectionDeadline = some(deadline);
    }

    // Function to update the deadline for car registration
    public entry fun update_registration_deadline(car_registration: &mut CarRegistration, new_deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered);
        car_registration.registrationDeadline = some(new_deadline);
    }

    // Function to update the deadline for car inspection
    public entry fun update_inspection_deadline(car_registration: &mut CarRegistration, new_deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered);
        car_registration.inspectionDeadline = some(new_deadline);
    }

    // New Feature: Function to get the registration status
    public entry fun get_registration_status(car_registration: &CarRegistration, ctx: &mut TxContext): (u8, bool, bool) {
        (car_registration.progress, car_registration.registrationScheduled, car_registration.dispute)
    }
}
