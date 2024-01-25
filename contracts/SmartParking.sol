   // SPDX-License-Identifier: UNLICENSED


pragma solidity >=0.5.16 <0.9.0;

contract SmartParking {
    address public owner=msg.sender;
        uint public parkingLotCount; // Variable to keep track of the number of parkingLots


    struct Vehicle {
        string brand;
        string licensePlate;
    }

   
    struct User {
        string firstName;
        string lastName;
        string phoneNumber;
        string password;
        uint balance;
        Vehicle[] vehicles;
        bool isVehicleRegistered;
    }

    mapping(string => address) private phoneToUser;  // Mapping to track used phone numbers
    mapping(address => User) public users;

    address[] public userList;  

    struct Booking {
        address user;
        string vehicleBrand;
        string licensePlate;
        uint duration;
        uint startTime;
        uint endTime;
    }

     struct ParkingLot {
        bool[] availableSpots;
        uint availableSpotsCount; // Number of available spots
        uint pricePerHour;
    }

    mapping(address => Booking[]) public userBookings;
    mapping(address => bool) public hasSpotBooking;
    mapping(uint => ParkingLot) public parkingLots;

    event BookingCreated(address indexed user, uint indexed parkingId, string spotName, uint payment, uint duration, uint timestamp);
    event MoneyAdded(address indexed user, uint amount);
    event PaymentMade(address indexed user, uint amount, uint timestamp);


// Constructor
constructor()  {
    owner = msg.sender;
}
//-------------------------------------------------------------------------------parking info-----------------------------------------------------------------------//

function initializeParkingLot(uint numSpots, uint _pricePerHour) public {
    ParkingLot memory newParkingLot;
    newParkingLot.pricePerHour = _pricePerHour;
    newParkingLot.availableSpots = new bool[](numSpots);
    newParkingLot.availableSpotsCount = numSpots;

    for (uint i = 0; i < numSpots; i++) {
        newParkingLot.availableSpots[i] = true;
    }

    parkingLots[parkingLotCount] = newParkingLot; // Assign to the mapping using a key
    parkingLotCount++;
}

function getAvailableSpotCount() public view returns (string memory) {
    require(parkingLotCount > 0, "No parking lot exists.");

    ParkingLot storage parkingLot = parkingLots[0]; // Assuming there is only one parking lot

    if (parkingLot.availableSpotsCount == 0) {
        return "No available spots in this parking lot at the moment.";
    } else {
        return string(abi.encodePacked("Number of available spots in this parking lot: ", uintToString(parkingLot.availableSpotsCount)));
    }
}

function uintToString(uint v) internal pure returns (string memory) {
    uint w = v;
    bytes memory buffer = new bytes(32);
    uint i = 31;
    do {
        buffer[i--] = bytes1(uint8(48 + w % 10));
        w /= 10;
    } while (w > 0);
    return string(buffer);
}


//--------------------------------------------------------------------------Auth------------------------------------------------------------------------------------//
    // Fonction pour le sign in d'un utilisateur
    function signIn(string memory _phoneNumber, string memory _password) public view returns (bool) {
        User storage existingUser = users[msg.sender];

        // Vérifiez si l'utilisateur existe et si le mot de passe correspond
        if (
            keccak256(abi.encodePacked(existingUser.phoneNumber)) == keccak256(abi.encodePacked(_phoneNumber)) &&
            keccak256(abi.encodePacked(existingUser.password)) == keccak256(abi.encodePacked(_password))
        ) {
            // Utilisateur trouvé et le mot de passe correspond
            return true;
        } else {
            // Utilisateur non trouvé ou mot de passe incorrect
            return false;
        }
    }
    //sing up
    function addUser(
        string memory _firstName,
        string memory _lastName,
        string memory _phoneNumber,
        string memory _password
    ) public {
        require(bytes(_password).length >= 6, "Password must be at least 6 characters");

        // Check if the phone number is not used by other accounts
        require(phoneToUser[_phoneNumber] == address(0), "Phone number is already registered");

        User storage newUser = users[msg.sender];
        newUser.firstName = _firstName;
        newUser.lastName = _lastName;
        newUser.phoneNumber = _phoneNumber;
        newUser.password = _password;
        newUser.balance = 0;
        newUser.isVehicleRegistered = false;

        // Add the user to the mapping of phone numbers
        phoneToUser[_phoneNumber] = msg.sender;
        
        // Add the user to the list of all users
        userList.push(msg.sender);
    }
//------------------------------------------------------------------vehicules---------------------------------------------------------------------------------------//
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
//----------------------------------------------------------------------------------------payement-------------------------------------------------------------------//
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
//----------------------------------------------------------------------booking-------------------------------------------------------------------------------------//
 // Fonction pour réserver un spot de parking
    function bookParkingSpot(uint _duration, string memory _vehicleBrand, string memory _licensePlate) public payable {
        // Vérifier que le montant envoyé est suffisant pour la durée de réservation
        uint totalPrice = parkingLots[0].pricePerHour * _duration;
        //require(msg.value >= totalPrice, "Insufficient funds");

        // Vérifier si le spot est disponible
        require(parkingLots[0].availableSpotsCount > 0, "No available spots");
        require(parkingLots[0].availableSpots[0], "Spot not available");

        // Stocker les détails de la réservation
        uint currentTime = block.timestamp;
        uint endTime = currentTime + (_duration * 1 hours); // Calculer l'heure de fin

        Booking memory newBooking = Booking({
            user: msg.sender,
            vehicleBrand: _vehicleBrand,
            licensePlate: _licensePlate,
            duration: _duration,
            startTime: currentTime,
            endTime: endTime
        });

        userBookings[msg.sender].push(newBooking);
        hasSpotBooking[msg.sender] = true;

        // Mettre à jour l'état du spot de parking
        parkingLots[0].availableSpots[0] = false;
        parkingLots[0].availableSpotsCount--;

        emit BookingCreated(msg.sender, 0, "SpotName", totalPrice, _duration, currentTime);
    }

function findAvailableSpot(ParkingLot storage _parkingLot) internal view returns (uint) {
    for (uint i = 0; i < _parkingLot.availableSpots.length; i++) {
        if (_parkingLot.availableSpots[i]) {
            return i;
        }
    }
    return type(uint).max;
}
//historique ....

}



