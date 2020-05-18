pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false


    // Airline Datastructures
    struct Airline {
        bool isRegistered;
        bool isFunded;
    }

    mapping(address => Airline) private airlines;
    uint256 public airlineCount;

    // Flight Datastructures
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;

    // Insurance Datastructures
    struct FlightInsurance {
        address insuree;
        uint256 amount;
        bool purchased;
        bool credited;
    }

    mapping(bytes32 => FlightInsurance) private passengerInsurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                )
                                public
    {
        contractOwner = msg.sender;
        // Instantiate first Airline
        airlines[firstAirline] = Airline({
            isRegistered: true,
            isFunded: false
        });
        // Instantiate Airline count
        airlineCount = 1;
    }

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
        require(operational, "Contract is currently not operational");
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

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
                            (
                                address newAirline
                            )
                            external
                            requireIsOperational
                            returns (bool)
    {
        // Verify airline has not already been registered.
        require(!airlines[newAirline].isRegistered, "Error: Airline has already been registered.");
        // Add new airline.
        airlines[newAirline] = Airline({
            isRegistered: true,
            isFunded: false
        });
        // Update Airline count.
        airlineCount += 1;

        return airlines[newAirline].isRegistered;
    }

    /**
    * @dev Airline offers funding and can participate in contract functionality
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function fundAirline
                            (
                                address airline
                            )
                            external
                            requireIsOperational
    {
        // Set isFunded boolean to true.
        airlines[airline].isFunded = true;
    }


    /**
    * @dev Returns isRegistered boolean
    *
    */
    function isAirlineRegistered(address airline) public view returns(bool) {
        return airlines[airline].isRegistered;
    }

    /**
    * @dev Returns isFunded boolean
    *
    */
    function isAirlineFunded(address airline) public view returns(bool) {
        return airlines[airline].isFunded;
    }

    /**
    * @dev Returns integer value of airlineCount
    *
    */
    function getAirlineCount() public view returns(uint256) {
        return airlineCount;
    }

    /**
    * @dev Register flight
    *
    */
    function registerFlight
                            (
                                address airline,
                                string flight,
                                uint256 timestamp
                            )
                            external
                            requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        // Register flight.
        flights[flightKey] = Flight({
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: timestamp,
            airline: airline
        });
    }

    /**
    * @dev Returns boolean isRegistered for a flight
    *
    */
    function isFlightRegistered(address airline, string flight, uint256 timestamp) public view returns(bool) {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return flights[flightKey].isRegistered;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
                            (
                                address airline,
                                string flight,
                                uint256 timestamp
                            )
                            external
                            payable
                            requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        passengerInsurances[flightKey] = FlightInsurance({
            insuree: msg.sender,
            amount: msg.value,
            purchased: true,
            credited: false
        });
    }

    /**
    * @dev Returns Insurance purchased boolean
    *
    */
    function isInsurancePurchased(address airline, string flight, uint256 timestamp) public view returns(bool) {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return passengerInsurances[flightKey].purchased;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    string flight,
                                    uint256 timestamp
                                )
                                external
                                requireIsOperational
    {
        // Obtain purchased insurance amount
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint256 insuranceValue = passengerInsurances[flightKey].amount;

        // Insurance policy
        uint256 flightCredit = insuranceValue.mul(15).div(10);
        passengerInsurances[flightKey].amount = flightCredit;
        passengerInsurances[flightKey].credited = true;
    }

    function getCreditAmount(address airline, string flight, uint256 timestamp) public view returns(uint256) {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return passengerInsurances[flightKey].amount;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function withdraw
                            (
                                address airline,
                                string flight, 
                                uint256 timestamp
                            )
                            external
                            requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint256 passengerCredits = passengerInsurances[flightKey].amount;
        // Verify credits have been awarded to passenger.
        require(passengerCredits > 0, "Passenger has not been awarded credits for flight insurance.");
        // Debit before Credit
        passengerInsurances[flightKey].amount = 0;
        msg.sender.transfer(passengerCredits);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (
                            )
                            public
                            payable
    {
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}
