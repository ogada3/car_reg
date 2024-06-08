#[allow(unused_const)]
module car_registration_system::car_registration_system {
    // Import necessary modules
    use sui::transfer; // Import transfer module for handling token transfers
    use sui::sui::SUI; // Import SUI module for SUI token operations
    use sui::coin::{Self, Coin}; // Import Coin module for dealing with coins
    use sui::object::{Self, UID}; // Import Object module for managing objects
    use sui::balance::{Self, Balance}; // Import Balance module for balance operations
    use sui::tx_context::{Self, TxContext}; // Import TxContext module for transaction context operations
    use std::option::{Option, none, some, is_some, contains, borrow}; // Import Option module for optional values

    // Define error codes
    const EInvalidRegistration: u64 = 1; // Error code for invalid registration
    const EInvalidCar: u64 = 2; // Error code for invalid car
    const EDispute: u64 = 3; // Error code for dispute
    const EAlreadyResolved: u64 = 4; // Error code for already resolved disputes
    const ENotRegistered: u64 = 5; // Error code for car not registered
    const EInvalidWithdrawal: u64 = 7; // Error code for invalid withdrawal
    const EAssignmentDeadlinePassed: u64 = 8; // Error code for passed assignment deadline

    // Define struct for car registration
    struct CarRegistration has key, store {
        id: UID, // Unique identifier for registration
        owner: address, // Address of the owner of the car
        inspector: Option<address>, // Optional address of the inspector
        description: vector<u8>, // Description of the car
        registration_details: vector<u8>, // Details of the registration
        documents: vector<vector<u8>>, // Documents related to registration
        fee: u64, // Registration fee
        escrow: Balance<SUI>, // Escrow balance for payment
        registrationScheduled: bool, // Flag indicating if registration is scheduled
        dispute: bool, // Flag indicating if there is a dispute
        progress: u8, // Progress of registration process (0-100%)
        feedback: Option<vector<u8>>, // Optional feedback provided
        rating: Option<u8>, // Optional rating provided
        registrationDeadline: Option<u64>, // Optional deadline for registration
        inspectionDeadline: Option<u64>, // Optional deadline for inspection
    }

    // Function to book a car registration
    public entry fun book_car_registration(description: vector<u8>, registration_details: vector<u8>, documents: vector<vector<u8>>, fee: u64, ctx: &mut TxContext) {
        let registration_id = object::new(ctx); // Generate a new unique registration ID
        transfer::share_object(CarRegistration { // Share the CarRegistration object
            id: registration_id, // Assign the registration ID
            owner: tx_context::sender(ctx), // Set the owner address
            inspector: none(), // Set the inspector to None initially
            description: description, // Set the car description
            registration_details: registration_details, // Set the registration details
            documents: documents, // Set the registration documents
            fee: fee, // Set the registration fee
            escrow: balance::zero(), // Initialize the escrow balance to zero
            registrationScheduled: false, // Initialize registration scheduling flag to false
            dispute: false, // Initialize dispute flag to false
            progress: 0, // Initialize progress to 0%
            feedback: none(), // Set feedback to None initially
            rating: none(), // Set rating to None initially
            registrationDeadline: none(), // Initialize registration deadline to None
            inspectionDeadline: none(), // Initialize inspection deadline to None
        });
    }

    // Function to request a car inspection
    public entry fun request_car_inspection(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(!is_some(&car_registration.inspector), EInvalidRegistration); // Assert if inspector is already assigned
        car_registration.inspector = some(tx_context::sender(ctx)); // Assign the sender as the inspector
    }

    // Function to submit a car registration
    public entry fun submit_car_registration(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(contains(&car_registration.inspector, &tx_context::sender(ctx)), EInvalidCar); // Assert if sender is not the assigned inspector
        car_registration.registrationScheduled = true; // Set registration scheduled flag to true
    }

    // Function to dispute a car registration
    public entry fun dispute_car_registration(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), EDispute); // Assert if sender is not the owner of the car
        car_registration.dispute = true; // Set dispute flag to true
    }

    // Function to resolve a car registration dispute
    public entry fun resolve_car_registration(car_registration: &mut CarRegistration, resolved: bool, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), EDispute); // Assert if sender is not the owner of the car
        assert!(car_registration.dispute, EAlreadyResolved); // Assert if dispute is not ongoing
        assert!(is_some(&car_registration.inspector), EInvalidRegistration); // Assert if inspector is not assigned
        let escrow_amount = balance::value(&car_registration.escrow); // Get the escrow balance
        let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx); // Take the escrow balance
        if (resolved) {
            let inspector = *borrow(&car_registration.inspector); // Get the inspector address
            transfer::public_transfer(escrow_coin, inspector); // Transfer escrow balance to inspector
        } else {
            transfer::public_transfer(escrow_coin, car_registration.owner); // Refund escrow balance to owner
        };

        car_registration.inspector = none(); // Reset inspector
        car_registration.registrationScheduled = false; // Reset registration scheduled flag
        car_registration.dispute = false; // Reset dispute flag
    }

    // Function to release payment for a car registration
    public entry fun release_payment(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), ENotRegistered); // Assert if sender is not the owner
        assert!(car_registration.registrationScheduled && !car_registration.dispute, EInvalidCar); // Assert if registration is not scheduled or there's a dispute
        assert!(is_some(&car_registration.inspector), EInvalidRegistration); // Assert if inspector is not assigned
        let inspector = *borrow(&car_registration.inspector); // Get the inspector address
        let escrow_amount = balance::value(&car_registration.escrow); // Get the escrow balance
        let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx); // Take the escrow balance
        transfer::public_transfer(escrow_coin, inspector); // Transfer escrow balance to inspector

        car_registration.inspector = none();
        car_registration.registrationScheduled = false; // Reset registration scheduled flag
        car_registration.dispute = false; // Reset dispute flag
    }

    // Function to add funds to a car registration
    public entry fun add_funds_to_registration(car_registration: &mut CarRegistration, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == car_registration.owner, ENotRegistered); // Assert if sender is not the owner
        let added_balance = coin::into_balance(amount); // Convert coin to balance
        balance::join(&mut car_registration.escrow, added_balance); // Add balance to escrow
    }

    // Function to request a refund for a car registration
    public entry fun request_refund(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == car_registration.owner, ENotRegistered); // Assert if sender is not the owner
        assert!(car_registration.registrationScheduled == false, EInvalidWithdrawal); // Assert if registration is scheduled
        let escrow_amount = balance::value(&car_registration.escrow); // Get the escrow balance
        let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx); // Take the escrow balance
        transfer::public_transfer(escrow_coin, car_registration.owner); // Refund escrow balance to owner

        // Reset registration state
        car_registration.inspector = none();
        car_registration.registrationScheduled = false;
        car_registration.dispute = false;
    }

    // Function to cancel a car registration
    public entry fun cancel_car_registration(car_registration: &mut CarRegistration, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered);

        // Refund funds to the owner if not yet paid
        if (is_some(&car_registration.inspector) && !car_registration.registrationScheduled && !car_registration.dispute) {
            let escrow_amount = balance::value(&car_registration.escrow); // Get the escrow balance
            let escrow_coin = coin::take(&mut car_registration.escrow, escrow_amount, ctx); // Take the escrow balance
            transfer::public_transfer(escrow_coin, car_registration.owner); // Refund escrow balance to owner
        };

        // Reset registration state
        car_registration.inspector = none();
        car_registration.registrationScheduled = false;
        car_registration.dispute = false;
    }

    // Function to update car description
    public entry fun update_car_description(car_registration: &mut CarRegistration, new_description: vector<u8>, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), ENotRegistered); // Assert if sender is not the owner
        car_registration.description = new_description; // Update car description
    }

    // Function to update registration fee
    public entry fun update_registration_fee(car_registration: &mut CarRegistration, new_fee: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx), ENotRegistered); // Assert if sender is not the owner
        car_registration.fee = new_fee; // Update registration fee
    }

    // Function to provide feedback
    public entry fun provide_feedback(car_registration: &mut CarRegistration, feedback: vector<u8>, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) && car_registration.registrationScheduled, ENotRegistered); // Assert if sender is not the owner or registration is not scheduled
        car_registration.feedback = some(feedback); // Set feedback
    }

    // Function to provide rating
    public entry fun provide_rating(car_registration: &mut CarRegistration, rating: u8, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) && car_registration.registrationScheduled, ENotRegistered); // Assert if sender is not the owner or registration is not scheduled
        car_registration.rating = some(rating); // Set rating
    }

    // Function to set the deadline for car registration
    public entry fun set_registration_deadline(car_registration: &mut CarRegistration, deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered); // Assert if sender is not the owner or inspector
        car_registration.registrationDeadline = some(deadline); // Set registration deadline
    }

    // Function to set the deadline for car inspection
    public entry fun set_inspection_deadline(car_registration: &mut CarRegistration, deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered); // Assert if sender is not the owner or inspector
        car_registration.inspectionDeadline = some(deadline); // Set inspection deadline
    }

    // Function to update the deadline for car registration
    public entry fun update_registration_deadline(car_registration: &mut CarRegistration, new_deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered); // Assert if sender is not the owner or inspector
        car_registration.registrationDeadline = some(new_deadline); // Update registration deadline
    }

    // Function to update the deadline for car inspection
    public entry fun update_inspection_deadline(car_registration: &mut CarRegistration, new_deadline: u64, ctx: &mut TxContext) {
        assert!(car_registration.owner == tx_context::sender(ctx) || contains(&car_registration.inspector, &tx_context::sender(ctx)), ENotRegistered); // Assert if sender is not the owner or inspector
        car_registration.inspectionDeadline = some(new_deadline); // Update inspection deadline
    }
}

