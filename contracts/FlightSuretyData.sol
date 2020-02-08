pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    // Mapping for authorized callers.
    mapping(address => bool) private authorizedCallers;

    // Airline Datastructures.
    struct Airline {
        bool isRegistered;
        bool isFunded;
    }

    mapping(address => Airline) private airlines;

    // Insurance datastructures.
    struct FlightInsurance {
        address passenger;
        uint256 value;
    }

    mapping(bytes32 => FlightInsurance) flightInsurances;
    mapping(address => uint256) private passengerBalances;

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
        // Instantiate first airline.
        airlines[firstAirline] = Airline({
            isRegistered: true,
            isFunded: false
        });
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

    /**
    *@dev Modifier that check if caller is authorized
    */
    modifier requireAuthorizedCaller(address caller)
    {
        require(authorizedCallers[caller], "Caller is not authorized");
        _;
    }

    /**
    *@dev Modifier that check if airline is registered.
    */
    modifier requireIsAirlineRegistered()
    {
        require(airlines[msg.sender].isRegistered, "Error: Airline is not registered.");
        _;
    }

    /**
    *@dev Modifier that check if caller is authorized
    */
    modifier requireIsAirlineFunded()
    {
        require(airlines[msg.sender].isFunded, "Error: Airline has not offered seed funding.");
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
        // Fail fast for setting operating status.
        require(operational != mode, "Error: Operating Status is already set to this mode.");
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /********************************************************************************************/
    /*                                     AIRLINE FUNCTIONS                                    */
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
        // Return true boolean is successful.
        return airlines[newAirline].isRegistered;
    }

    /**
    * @dev Airline has successfully offered funding.
    *
    */
    function fundAirline
                            (
                                address airlineAddress
                            )
                            external
                            requireIsOperational
    {
        // Set isFunded boolean to true.
        airlines[airlineAddress].isFunded = true;
    }

    /**
    * @dev Returns isRegistered boolean
    *
    */
    function isAirlineRegistered(address airlineAddress) external view returns(bool) {
        return airlines[airlineAddress].isRegistered;
    }

    /**
    * @dev Returns isFunded boolean
    *
    */
    function isAirlineFunded(address airlineAddress) external view returns(bool) {
        return airlines[airlineAddress].isFunded;
    }

    /********************************************************************************************/
    /*                                   PASSENGER FUNCTIONS                                    */
    /********************************************************************************************/

   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
                            (
                                address passenger,
                                bytes32 flightKey
                            )
                            external
                            payable
                            requireIsOperational
    {
        // Create flight insurance.
        flightInsurances[flightKey] = FlightInsurance({
            passenger: msg.sender,
            value: msg.value
        });
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address passenger,
                                    bytes32 flightKey
                                )
                                external
                                payable
    {
        // Obtain flight insurance balance.
        uint256 passengerInsurance = flightInsurances[flightKey].value;
        // Calculate return amount (1.5x)
        uint256 returnAmount = passengerInsurance.mul(3).div(2);
        // Credit passenger with new amount.
        passengerBalances[passenger] = returnAmount;
    }

    
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address passengerAddress
                            )
                            external
                            payable
    {
        // Payment Protection.
        require(address(this).balance > passengerBalances[passengerAddress], "Error: Insufficient funds to refund passenger.");
        uint256 prev = passengerBalances[passengerAddress];
        passengerBalances[passengerAddress] = 0;
        msg.sender.transfer(prev);
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

