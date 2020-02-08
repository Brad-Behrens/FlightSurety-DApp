pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Business logic constants.
    uint256 private constant MULTIPARTY_CONSENSUS_LIMIT = 4;
    uint256 private constant INSURANCE_MAX_PAYMENT = 1 ether;
    uint256 public constant AIRLINE_FUND = 10 ether;

    address private contractOwner;          // Account used to deploy contract

    // Data contract.
    FlightSuretyData flightSuretyData;

    // Voting address array for multiparty consensus.
    mapping(address => address[]) private airlineVotes;

    // Number of registered airlines.
    uint256 public airlinesRegisteredCount;

    struct Flight {
        address airline;
        string flight;
        bool isRegistered;
        uint256 updatedTimestamp;
        uint8 statusCode;
        address[] insuredPassengers;
    }

    mapping(bytes32 => Flight) private flights;

 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    // AIRLINE MODIFIERS

    /**
    * @dev Modifier that requires the Airline to have been registered.
    */
    modifier requireIsAirlineRegistered()
    {
        require(flightSuretyData.isAirlineRegistered(msg.sender), "Error: Airline is not registered.");
        _;
    }

    /**
    * @dev Modifier that requires the Airline to have offered funding.
    */
    modifier requireIsAirlineFunded()
    {
        require(flightSuretyData.isAirlineFunded(msg.sender), "Error: Airline is not funded.");
        _;
    }

    // FLIGHT MODIFIERS


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                )
                                public
    {
        contractOwner = msg.sender;
        // Initalise data contract.
        flightSuretyData = FlightSuretyData(dataContract);
        // Initalise number of registered airlines.
        airlinesRegisteredCount = 1;
    }

     /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address indexed airline);
    event AirlineFunded(address indexed airline);
    event FlightRegistered(bytes32 indexed flightKey);
    event InsurancePurchased(address indexed passenger, bytes32 flightKey);

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                            public
                            pure
                            returns(bool)
    {
        return true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                            (
                                address airlineAddress
                            )
                            public
                            requireIsOperational
                            requireIsAirlineRegistered
                            requireIsAirlineFunded
    {
        // Verify airline address is valid.
        require(airlineAddress != address(0), "Error: Airline address is not valid.");

        // Register Airline via existing airline or MPC.
        if (airlinesRegisteredCount < MULTIPARTY_CONSENSUS_LIMIT) {
            // Existing funded airline can register new airline.
            flightSuretyData.registerAirline(airlineAddress);
            airlinesRegisteredCount++;
        }
        else {
            // Add airline via multiparty consensus mechanism.
            bool isDuplicate = false;
            for(uint i=0; i < airlineVotes[airlineAddress].length; i++) {
                if (airlineVotes[airlineAddress][i] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            // Verify airline has not voted twice.
            require(!isDuplicate, "Error: Duplicated votes niot allowed.");
            // Add airline vote.
            airlineVotes[airlineAddress].push(msg.sender);
            // Verify >50% of airline has voted to register new airline.
            if (airlineVotes[airlineAddress].length >= airlinesRegisteredCount.div(2)) {
                // Add new airline.
                flightSuretyData.registerAirline(airlineAddress);
                airlinesRegisteredCount++;
            }
            // Reset airlineVotes for next registration multipart vote.
            airlineVotes[airlineAddress] = new address[](0);
        }
        // Emit event.
        emit AirlineRegistered(airlineAddress);
    }

    /**
    * @dev Airline has offered funding and can participate in contract functioality.
    *
    */
    function fundAirline
                                (
                                    address airlineAddress
                                )
                                public
                                payable
                                requireIsOperational
                                requireIsAirlineRegistered
    {
        // Verify funding is greater than minimum funding requirement.
        require(msg.value >= AIRLINE_FUND, "Error: Insufficient funding by airline.");
        // Transfer funds to data contract.
        address(flightSuretyData).transfer(msg.value);
        // Authorise airline being funded.
        flightSuretyData.fundAirline(airlineAddress);
        // Emit event.
        emit AirlineFunded(airlineAddress);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    address airlineAddress,
                                    string flightNumber,
                                    uint256 timestamp
                                )
                                public
                                requireIsOperational
    {
        // Calculate flight key.
        bytes32 flightKey = getFlightKey(airlineAddress, flightNumber, timestamp);
        // Verify flight has not already been added.
        require(!flights[flightKey].isRegistered, "Error: Flight has already been registered.");
        // Create new flight.
        flights[flightKey] = Flight({
            airline: airlineAddress,
            flight: flightNumber,
            isRegistered: true,
            updatedTimestamp: timestamp,
            statusCode: STATUS_CODE_UNKNOWN,
            insuredPassengers: new address[](0)
        });
        // Emit event.
        emit FlightRegistered(flightKey);
    }

    // Returns boolean value if a flight has been successfuly registered.
    function isFlightRegistered(bytes32 flightKey) public view returns (bool) {
        return flights[flightKey].isRegistered;
    } 

    /**
    * @dev Purchase flight insurance.
    *
    */  
    function purchaseFlightInsurance
                                (
                                    bytes32 flightKey
                                )
                                public
                                payable
                                requireIsOperational
    {
        // Verify payment doesn't exceed insurance limit.
        require(msg.value > 0 && msg.value <= INSURANCE_MAX_PAYMENT, "Error: Insurance cannot exceed 1 ETH.");
        // Purchase flight insurance.
        flightSuretyData.buy(msg.sender, flightKey);
        // Push passenger on to flight.
        flights[flightKey].insuredPassengers.push(msg.sender);
        // Send funds to data contract.
        flightSuretyData.transfer(msg.value);
        // Emit event.
        emit InsurancePurchased(msg.sender, flightKey);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {
        // Obtain flight key.
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        // Obtain insured passengers array for flight.
        address[] memory passengers = flights[flightKey].insuredPassengers;
        // Verify passengers have bought insurance.
        require(passengers.length > 0, "Error: No passengers purchased insurance for this flight.");
        // Obtain flight status code.
        flights[flightKey].statusCode = statusCode;
        // Verify flight is late.
        if(statusCode == STATUS_CODE_LATE_AIRLINE) {
            // Loop through insured passengers.
            for(uint8 i = 0; i < passengers.length; i++) {
                // Credit insured passengers with compensation.
                flightSuretyData.creditInsurees(passengers[i], flightKey);
            }
        }
    }

    // Passengers can withdraw their funds.
    function withdraw
                            (
                            )
                            public
                            requireIsOperational
    {
        // Call data contract method.
        flightSuretyData.pay(msg.sender);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   