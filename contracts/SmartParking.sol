contract SmartParking {
    address public owner = msg.sender;
    uint public parkingLotCount;

    uint public pricePerHour; // Variable d'état pour le prix par heure

        struct Vehicle {
        string brand;  // Ajout de la propriété `brand`
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

    struct Booking {
        address user;
        uint parkingId;
        string spotName;
        uint payment;
        uint duration;
        uint timestamp;
        string vehicleBrand;
        string vehicleModel;
        string vehicleLicensePlate;
        ReservationState state;
    }

    struct ParkingLot {
        bool[] availableSpots;
        uint availableSpotsCount;
        uint pricePerHour;
    }
 mapping(string => address) private phoneToUser;  // Mapping to track used phone numbers
    address[] public userList; 
    mapping(address => User) public users;
    mapping(address => Booking[]) public userBookings;
    mapping(address => bool) public hasSpotBooking;
    mapping(uint => ParkingLot) public parkingLots;

    enum ReservationState { Pending, Confirmed, Cancelled }
    mapping(string => Booking[]) public userBookingsByLicensePlate; // Correction du type

    event BookingCreated(address indexed user, uint indexed parkingId, string spotName, uint payment, uint duration, uint timestamp);
    event MoneyAdded(address indexed user, uint amount);
    event PaymentMade(address indexed user, uint amount, uint timestamp);

    constructor() {
        owner = msg.sender;
    }
//-------------------------------------------------------------------------------parking info-----------------------------------------------------------------------//
 function setPricePerHour(uint _price) public {
        require(msg.sender == owner, "Only owner can set price per hour");
        pricePerHour = _price;
    }

 function initializeParkingLot(uint numSpots) public {
        parkingLotCount++;
        parkingLots[parkingLotCount].availableSpotsCount = numSpots;
        parkingLots[parkingLotCount].pricePerHour = pricePerHour;
        
        // Initialize available spots
        parkingLots[parkingLotCount].availableSpots = new bool[](numSpots);
        for (uint i = 0; i < numSpots; i++) {
            parkingLots[parkingLotCount].availableSpots[i] = true;
        }
    }

function findAvailableSpot(ParkingLot storage _parkingLot) internal view returns (uint) {
    for (uint i = 0; i < _parkingLot.availableSpots.length; i++) {
        if (_parkingLot.availableSpots[i]) {
            return i;
        }
    }
    return type(uint).max;
}
function getAvailableSpotCount() public view returns (string memory) {
    require(parkingLotCount > 0, "No parking lot exists.");

    ParkingLot storage parkingLot = parkingLots[parkingLotCount]; // Access the last initialized parking lot

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
 
    function makeBooking(string memory _spotName, uint _duration, string memory _vehicleLicensePlate) public {
    require(_duration > 0, "Duration must be greater than zero.");
    require(parkingLots[1].availableSpotsCount > 0, "No available spots in this parking lot.");
    require(users[msg.sender].balance >= pricePerHour * _duration, "Insufficient balance.");

    // Calculate payment
    uint _payment = pricePerHour * _duration;

    // Create new booking
    Booking memory newBooking = Booking({
        user: msg.sender,
        parkingId: 1, // Assuming you have only one parking lot
        spotName: _spotName,
        payment: _payment,
        duration: _duration,
        timestamp: block.timestamp,
        vehicleBrand: users[msg.sender].vehicles[0].brand, // Assuming user has only one vehicle
        vehicleModel: "", // You may add this information if needed
        vehicleLicensePlate: _vehicleLicensePlate,
        state: ReservationState.Pending
    });

    // Update available spots count
    parkingLots[1].availableSpotsCount--;

    // Add booking to user's bookings
    userBookings[msg.sender].push(newBooking);

    // Deduct payment from user's balance
    users[msg.sender].balance -= _payment;

    // Emit event
    emit BookingCreated(msg.sender, 1, _spotName, _payment, _duration, block.timestamp);
}

//historique des bookings 
function getMyBooking(string memory licensePlate) external view returns (uint[] memory timestamps, uint[] memory durations, string[] memory models, string[] memory brands) {
        Booking[] storage bookings = userBookingsByLicensePlate[licensePlate];

        uint length = bookings.length;

        timestamps = new uint[](length);
        durations = new uint[](length);
        models = new string[](length);
        brands = new string[](length);

        for (uint i = 0; i < length; i++) {
            timestamps[i] = bookings[i].timestamp;
            durations[i] = bookings[i].duration;
            brands[i] = getVehicleBrandByLicensePlate(licensePlate);
            models[i] = getVehicleModelByLicensePlate(licensePlate);
        }

        return (timestamps, durations, models, brands);
    }

    function getVehicleBrandByLicensePlate(string memory licensePlate) internal view returns (string memory) {
        // Recherchez le véhicule correspondant dans la liste des véhicules de l'utilisateur
        User storage user = users[msg.sender];
        uint vehiclesCount = user.vehicles.length;

        for (uint i = 0; i < vehiclesCount; i++) {
            if (keccak256(abi.encodePacked(user.vehicles[i].licensePlate)) == keccak256(abi.encodePacked(licensePlate))) {
                return user.vehicles[i].brand;
            }
        }

        // Si la plaque d'immatriculation n'est pas trouvée, retournez une chaîne vide
        return "";
    }

    function getVehicleModelByLicensePlate(string memory licensePlate) internal view returns (string memory) {
        // Recherchez le véhicule correspondant dans la liste des véhicules de l'utilisateur
        User storage user = users[msg.sender];
        uint vehiclesCount = user.vehicles.length;

        for (uint i = 0; i < vehiclesCount; i++) {
            if (keccak256(abi.encodePacked(user.vehicles[i].licensePlate)) == keccak256(abi.encodePacked(licensePlate))) {
                return user.vehicles[i].brand;
            }
        }

        // Si la plaque d'immatriculation n'est pas trouvée, retournez une chaîne vide
        return "";
    }

}





