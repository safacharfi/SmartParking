pragma solidity >=0.5.16 <0.9.0;
// SPDX_License_Identifier: MIT

contract SmartParking {
    address public owner;

    struct Vehicle {
        string brand;
        string licensePlate;
    }

    struct User {
        string firstName;
        string lastName;
        string phoneNumber;
        uint balance;
        Vehicle[] vehicles;
        bool isVehicleRegistered;
    }

    struct Booking {
        address user;
        uint parkingId;
        string spotName;
        uint payment;
        uint duration;
        uint timestamp;
    }

    struct ParkingLot {
        bool[] availableSpots;
        uint pricePerHour;
    }

    mapping(address => User) public users;
    mapping(address => Booking[]) public userBookings;
    mapping(address => bool) public hasSpotBooking;
    mapping(uint => ParkingLot) public parkingLots;

    event BookingCreated(address indexed user, uint indexed parkingId, string spotName, uint payment, uint duration, uint timestamp);
    event MoneyAdded(address indexed user, uint amount);
    event PaymentMade(address indexed user, uint amount, uint timestamp);

    // Constructor
    constructor() public {
        owner = msg.sender;
    }

    function addVehicle(string memory _brand, string memory _licensePlate) public {
        // Check if the vehicle with the given license plate already exists for the user
        for (uint i = 0; i < users[msg.sender].vehicles.length; i++) {
            require(
                keccak256(abi.encodePacked(users[msg.sender].vehicles[i].licensePlate)) != keccak256(abi.encodePacked(_licensePlate)),
                "Vehicle with the same license plate already registered"
            );
        }
        // Create a new Vehicle struct with the provided details
        Vehicle memory newVehicle = Vehicle({
            brand: _brand,
            licensePlate: _licensePlate
        });

        // Add the new vehicle to the user's list of vehicles
        users[msg.sender].vehicles.push(newVehicle);

        // Mark the user as having a registered vehicle
        users[msg.sender].isVehicleRegistered = true;
    }

    function deleteVehicle(string memory _licensePlate) public {
        // Check if the vehicle with the given license plate exists
        uint indexToDelete = findVehicleIndex(_licensePlate);
        require(indexToDelete != type(uint).max, "Vehicle not found");

        // Remove the vehicle from the list
        removeVehicleAtIndex(indexToDelete);

        // If there are no more vehicles, mark the user as not having a registered vehicle
        if (users[msg.sender].vehicles.length == 0) {
            users[msg.sender].isVehicleRegistered = false;
        }
    }

    function findVehicleIndex(string memory _licensePlate) internal view returns (uint) {
        // Iterate over the user's vehicles to find the index of the vehicle with the given license plate
        for (uint i = 0; i < users[msg.sender].vehicles.length; i++) {
            if (keccak256(abi.encodePacked(users[msg.sender].vehicles[i].licensePlate)) == keccak256(abi.encodePacked(_licensePlate))) {
                return i;
            }
        }

        // Return type(uint).max if the vehicle with the given license plate is not found
        return type(uint).max;
    }

    function removeVehicleAtIndex(uint index) internal {
        // Remove the vehicle at the specified index by shifting elements
        uint lastIndex = users[msg.sender].vehicles.length - 1;
        users[msg.sender].vehicles[index] = users[msg.sender].vehicles[lastIndex];
        users[msg.sender].vehicles.pop();
    }
    function getUserInfo() public view returns (User memory) {   //utile dans le test
    return users[msg.sender];
}
    //booking a parking spot
   function bookSpot(
    uint parkingId,
    uint spotId,
    string memory spotName,
    uint duration
) public payable returns (bool success) {
    require(users[msg.sender].isVehicleRegistered, "Vehicle must be registered first");
    require(!hasSpotBooking[msg.sender], "Vehicle already has a parking spot booked");
    require(msg.value >= duration * parkingLots[parkingId].pricePerHour, "Insufficient funds for the booking duration");

    // Check if the parking lot exists
    // Check if the selected spot is within the valid range
    require(spotId < parkingLots[parkingId].availableSpots.length, "Invalid spot ID");
   


    // Check if the selected spot is available
    require(parkingLots[parkingId].availableSpots[spotId], "Selected spot is not available");

    // Mark the spot as booked
    parkingLots[parkingId].availableSpots[spotId] = false;

    // Record the booking details
    Booking memory newBooking = Booking({
        user: msg.sender,
        parkingId: parkingId,
        spotName: spotName,
        payment: msg.value,
        duration: duration,
        timestamp: block.timestamp
    });
    userBookings[msg.sender].push(newBooking);

    // Update user balance
    users[msg.sender].balance += msg.value;

    // Update the state to reflect the booked spot
    hasSpotBooking[msg.sender] = true;

    // Emit an event to log the booking
    emit BookingCreated(msg.sender, parkingId, spotName, msg.value, duration, block.timestamp);

    return true;
}

    //partie l flous 😛
    //check balance
    function getBalance() public view returns(uint){
        return users[msg.sender].balance;
    }
    //add money to cart
    function addMoney(uint amount) public payable {
    require(amount > 0, "Amount must be greater than zero");
    
    users[msg.sender].balance += amount;
    emit MoneyAdded(msg.sender, amount);
}
    //function to pay
    function makePayement(uint amount) public{
        require(users[msg.sender].balance>=amount,"Insufficient funds");
        users[msg.sender].balance-=amount;
emit PaymentMade(msg.sender, amount, block.timestamp);
    }
    }